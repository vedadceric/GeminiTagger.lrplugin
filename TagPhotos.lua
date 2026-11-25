local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrHttp = import 'LrHttp'
local LrPrefs = import 'LrPrefs'
local LrProgressScope = import 'LrProgressScope'
local LrStringUtils = import 'LrStringUtils'

-- Pure Lua Base64 encoder
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function encodeBase64(data)
    return ((data:gsub('.', function(x) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6-i) or 0) end
        return b64chars:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

-- Helper function to escape JSON strings
local function escapeJson(str)
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    return str
end

-- Helper function to unescape JSON strings
local function unescapeJson(str)
    if not str then return "" end
    str = str:gsub('\\n', '\n')
    str = str:gsub('\\r', '\r')
    str = str:gsub('\\t', '\t')
    str = str:gsub('\\"', '"')
    str = str:gsub('\\\\', '\\')
    return str
end

-- Extract full escaped string value for a given JSON key
local function extractJsonStringField(jsonStr, key)
    local _, valueStart = jsonStr:find('"' .. key .. '"%s*:%s*"')
    if not valueStart then return nil end

    local i = valueStart + 1
    local len = #jsonStr
    while i <= len do
        local c = jsonStr:sub(i, i)
        if c == '\\' then
            i = i + 2
        elseif c == '"' then
            return jsonStr:sub(valueStart + 1, i - 1)
        else
            i = i + 1
        end
    end
    return nil
end

-- Parse response from Gemini API
local function parseGeminiResponse(responseBody)
    local rawText = extractJsonStringField(responseBody, 'text')
    if not rawText then
        return nil, nil, nil
    end

    local textContent = unescapeJson(rawText)
    textContent = textContent:gsub('```json', ''):gsub('```', '')

    local title = extractJsonStringField(textContent, 'title')
    local caption = extractJsonStringField(textContent, 'caption')
    local keywordsRaw = textContent:match('"keywords"%s*:%s*%[(.-)%]')

    local keywords = {}
    if keywordsRaw then
        for kw in keywordsRaw:gmatch('"(.-)"') do
            local cleanKw = LrStringUtils.trimWhitespace(unescapeJson(kw))
            if cleanKw ~= "" then
                table.insert(keywords, cleanKw)
            end
        end
    end

    return unescapeJson(title), unescapeJson(caption), keywords
end

-- Asynchronously fetch JPEG thumbnail from Lightroom
local function getJpegData(photo, maxDim)
    local jpegData = nil
    local done = false

    photo:requestJpegThumbnail(maxDim, maxDim, function(data, errorMsg)
        jpegData = data
        done = true
    end)

    local timeout = 0
    while not done and timeout < 100 do
        LrTasks.sleep(0.1)
        timeout = timeout + 1
    end

    return jpegData
end

LrTasks.startAsyncTask(function()
    local prefs = LrPrefs.prefsForPlugin()
    local apiKey = LrStringUtils.trimWhitespace(prefs.apiKey or '')

    if apiKey == '' then
        LrDialogs.message('Missing API Key', 'Please open File > Plug-in Manager and enter your Google Gemini API key.', 'critical')
        return
    end

    local catalog = LrApplication.activeCatalog()
    local targetPhotos = catalog:getTargetPhotos()

    if #targetPhotos == 0 then
        LrDialogs.message('No Photos Selected', 'Please select at least one photo in the Library module.', 'info')
        return
    end

    local progress = LrProgressScope {
        title = 'Gemini AI is analyzing photos...',
    }

    local successCount = 0
    local errorCount = 0
    local lastError = ''

    for i, photo in ipairs(targetPhotos) do
        if progress:isCanceled() then break end
        progress:setPortionComplete(i - 1, #targetPhotos)
        
        local fileName = photo:getFormattedMetadata('fileName')
        progress:setCaption('Processing (' .. i .. '/' .. #targetPhotos .. '): ' .. fileName)

        -- Read existing Title, Caption, and Keywords from Lightroom
        local existingTitle = LrStringUtils.trimWhitespace(photo:getFormattedMetadata('title') or '')
        local existingCaption = LrStringUtils.trimWhitespace(photo:getFormattedMetadata('caption') or '')
        local existingKwObjects = photo:getRawMetadata('keywords') or {}
        
        local existingKwNames = {}
        local existingKwLookup = {}
        for _, kwObj in ipairs(existingKwObjects) do
            local name = kwObj:getName()
            if name and name ~= '' then
                table.insert(existingKwNames, name)
                existingKwLookup[string.lower(name)] = true
            end
        end

        local maxKw = math.floor(tonumber(prefs.maxKeywords) or 50)
        local currentKwCount = #existingKwNames
        local neededKw = math.max(0, maxKw - currentKwCount)

        -- Generate 1024px preview image
        local jpegBytes = getJpegData(photo, 1024)

        if jpegBytes then
            local base64Image = encodeBase64(jpegBytes)
            local lang = prefs.language or 'English'
            local model = LrStringUtils.trimWhitespace(prefs.modelName or 'gemini-3.5-flash-lite')
            if model == '' then model = 'gemini-3.5-flash-lite' end
            local apiVer = prefs.apiVersion or 'v1beta'

            -- Build context instruction if Title or Caption already exist
            local metadataContextInstruction = ''
            if existingTitle ~= '' or existingCaption ~= '' then
                metadataContextInstruction = string.format(
                    'IMPORTANT CONTEXT FROM EXISTING METADATA: The user has already provided initial notes in Title ("%s") and/or Caption ("%s"). ' ..
                    'You MUST base the new "title" and "caption" on this provided text (preserving exact locations, names, events, or facts mentioned) while refining and expanding them with visual details from the image into polished commercial stock metadata. ',
                    existingTitle, existingCaption
                )
            else
                metadataContextInstruction = 'Generate "title" and "caption" directly from visual analysis of the image. '
            end

            -- Build keyword instruction based on remaining slots up to maxKw
            local keywordInstruction = ''
            if neededKw > 0 then
                local exclusionNote = ''
                if currentKwCount > 0 then
                    exclusionNote = 'Do NOT repeat or include any of these already-assigned keywords: [' .. table.concat(existingKwNames, ', ') .. ']. '
                end
                keywordInstruction = string.format(
                    '3. "keywords": Generate an array of EXACTLY %d NEW, unique, relevant single-word or two-word tags ordered by relevance (so that combined with the %d existing tags, the total reaches %d). ' ..
                    '%sCover main subjects, actions, background elements, colors, lighting, weather/time of day, camera angle/composition, mood, and concepts. ',
                    neededKw, currentKwCount, maxKw, exclusionNote
                )
            else
                keywordInstruction = '3. "keywords": Return an empty array [] because the photo already has the maximum number of keywords. '
            end

            local prompt = string.format(
                'Analyze this photograph for commercial stock photography and catalog metadata. ' ..
                'Provide output strictly as a valid JSON object with keys: "title", "caption", and "keywords" (an array of strings). ' ..
                'Output Language: %s. ' ..
                '%s' ..
                'Rules: ' ..
                '1. "title": Concise, commercial, descriptive title (5-10 words, no punctuation at the end). ' ..
                '2. "caption": Detailed, natural description of the scene, subjects, lighting, and mood (15-30 words). ' ..
                '%s' ..
                'Do not include markdown formatting, only raw JSON.',
                lang, metadataContextInstruction, keywordInstruction
            )

            local payload = string.format([[{
                "contents": [{
                    "parts": [
                        {"text": "%s"},
                        {
                            "inline_data": {
                                "mime_type": "image/jpeg",
                                "data": "%s"
                            }
                        }
                    ]
                }],
                "generationConfig": {
                    "temperature": 0.4,
                    "responseMimeType": "application/json"
                }
            }]], escapeJson(prompt), base64Image)

            local url = 'https://generativelanguage.googleapis.com/' .. apiVer .. '/models/' .. model .. ':generateContent?key=' .. apiKey
            local headers = {
                { field = 'Content-Type', value = 'application/json' },
            }

            local responseBody, responseHeaders = LrHttp.post(url, payload, headers)

            if responseBody and responseHeaders.status == 200 then
                local title, caption, keywords = parseGeminiResponse(responseBody)

                if title or caption or (keywords and #keywords > 0) then
                    catalog:withWriteAccessDo('Gemini AI Metadata', function()
                        if title and title ~= '' then
                            photo:setRawMetadata('title', title)
                        end
                        if caption and caption ~= '' then
                            photo:setRawMetadata('caption', caption)
                        end
                        if keywords and #keywords > 0 and neededKw > 0 then
                            local addedCount = 0
                            for _, kwName in ipairs(keywords) do
                                if addedCount >= neededKw then break end
                                local lowerKw = string.lower(kwName)
                                if not existingKwLookup[lowerKw] then
                                    local keywordObj = catalog:createKeyword(kwName, {}, true, nil, true)
                                    photo:addKeyword(keywordObj)
                                    existingKwLookup[lowerKw] = true
                                    addedCount = addedCount + 1
                                end
                            end
                        end
                    end)
                    successCount = successCount + 1
                else
                    errorCount = errorCount + 1
                    lastError = 'Failed to parse JSON response from the model.'
                end
            else
                errorCount = errorCount + 1
                lastError = 'HTTP Status: ' .. tostring(responseHeaders and responseHeaders.status or 'N/A') .. '\n' .. tostring(responseBody)
            end
        else
            errorCount = errorCount + 1
            lastError = 'Unable to generate JPEG preview for: ' .. fileName
        end

        progress:setPortionComplete(i, #targetPhotos)
    end

    progress:done()

    if errorCount > 0 then
        LrDialogs.message(
            'Completed with Errors',
            string.format('Successfully processed: %d\nErrors: %d\n\nLast error:\n%s', successCount, errorCount, lastError:sub(1, 400)),
            'warning'
        )
    else
        LrDialogs.message(
            'Completed',
            string.format('Successfully generated title, caption, and keywords for %d photo(s).', successCount),
            'info'
        )
    end
end)