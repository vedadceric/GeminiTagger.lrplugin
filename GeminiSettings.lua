local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrHttp = import 'LrHttp'
local LrDialogs = import 'LrDialogs'
local LrStringUtils = import 'LrStringUtils'

local bind = LrView.bind

return {
    startDialog = function(propertyTable)
        local prefs = LrPrefs.prefsForPlugin()

        propertyTable.apiKey = prefs.apiKey or ''
        propertyTable.modelName = prefs.modelName or 'gemini-3.5-flash-lite'
        propertyTable.apiVersion = prefs.apiVersion or 'v1beta'
        propertyTable.language = prefs.language or 'English'
        propertyTable.maxKeywords = prefs.maxKeywords or 50

        propertyTable:addObserver('apiKey', function(props, key, newValue)
            prefs.apiKey = newValue
        end)
        propertyTable:addObserver('modelName', function(props, key, newValue)
            prefs.modelName = newValue
        end)
        propertyTable:addObserver('apiVersion', function(props, key, newValue)
            prefs.apiVersion = newValue
        end)
        propertyTable:addObserver('language', function(props, key, newValue)
            prefs.language = newValue
        end)
        propertyTable:addObserver('maxKeywords', function(props, key, newValue)
            prefs.maxKeywords = newValue
        end)
    end,

    sectionsForTopOfDialog = function(f, propertyTable)
        local function checkAvailableModels()
            LrTasks.startAsyncTask(function()
                local apiKey = LrStringUtils.trimWhitespace(propertyTable.apiKey or '')
                if apiKey == '' then
                    LrDialogs.message('Missing API Key', 'Please enter your Gemini API Key first.', 'warning')
                    return
                end

                local apiVer = propertyTable.apiVersion or 'v1beta'
                local url = 'https://generativelanguage.googleapis.com/' .. apiVer .. '/models?key=' .. apiKey
                local body, headers = LrHttp.get(url)

                if body and headers and headers.status == 200 then
                    local availableModels = {}
                    for block in body:gmatch('{(.-)}') do
                        if block:find('generateContent') then
                            local fullName = block:match('"name"%s*:%s*"models/([^"]+)"')
                            if fullName and fullName:find('gemini') and not fullName:find('embedding') and not fullName:find('tts') and not fullName:find('image') then
                                table.insert(availableModels, fullName)
                            end
                        end
                    end

                    if #availableModels > 0 then
                        local selectedModel = nil

                        local preferredOrder = {
                            'gemini-3.5-flash-lite',
                            'gemini-3.8-flash',
                            'gemini-3.6-flash',
                            'gemini-3.1-flash-lite',
                        }

                        for _, prefModel in ipairs(preferredOrder) do
                            for _, m in ipairs(availableModels) do
                                if m == prefModel then
                                    selectedModel = m
                                    break
                                end
                            end
                            if selectedModel then break end
                        end

                        if not selectedModel then
                            for _, m in ipairs(availableModels) do
                                if m:find('flash') then
                                    selectedModel = m
                                    break
                                end
                            end
                        end

                        if selectedModel then
                            propertyTable.modelName = selectedModel
                        end

                        LrDialogs.message(
                            'Available Gemini Models (' .. apiVer .. ')',
                            'Your API key supports the following models:\n\n' ..
                            table.concat(availableModels, '\n') ..
                            '\n\nActive Model ID has been set to: ' .. tostring(propertyTable.modelName),
                            'info'
                        )
                    else
                        LrDialogs.message('No Models Found', 'Connected to API (' .. apiVer .. '), but no compatible Gemini vision/text models were returned.', 'warning')
                    end
                else
                    LrDialogs.message(
                        'API Error',
                        'Could not fetch models from ' .. apiVer .. '. HTTP Status: ' .. tostring(headers and headers.status or 'N/A') .. '\n\n' .. tostring(body):sub(1, 300),
                        'critical'
                    )
                end
            end)
        end

        return {
            {
                title = 'Google Gemini AI Settings',
                bind_to_object = propertyTable,
                synopsis = bind 'modelName',

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'Gemini API Key:',
                        width = LrView.share 'label_width',
                    },
                    f:password_field {
                        value = bind 'apiKey',
                        width_in_chars = 40,
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'API Endpoint Version:',
                        width = LrView.share 'label_width',
                    },
                    f:popup_menu {
                        value = bind 'apiVersion',
                        items = {
                            { title = 'v1beta (Default / Recommended)', value = 'v1beta' },
                            { title = 'v1 (Stable Production)', value = 'v1' },
                        },
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'Select Gemini Model:',
                        width = LrView.share 'label_width',
                    },
                    f:popup_menu {
                        value = bind 'modelName',
                        items = {
                            { title = '[Free Tier] Gemini 3.5 Flash-Lite (Best Daily Quota)', value = 'gemini-3.5-flash-lite' },
                            { title = '[Free Tier] Gemini 3.8 Flash (Highest Free Quality)', value = 'gemini-3.8-flash' },
                            { title = '[Free Tier] Gemini 3.6 Flash', value = 'gemini-3.6-flash' },
                            { title = '[Free Tier] Gemini 3.1 Flash-Lite', value = 'gemini-3.1-flash-lite' },
                            { title = '[Paid Only] Gemini 4 Hydrogen', value = 'gemini-4-hydrogen' },
                            { title = '[Paid Only] Gemini 4 Argon', value = 'gemini-4-argon' },
                            { title = '[Paid Only] Gemini 4 Neon', value = 'gemini-4-neon' },
                            { title = '[Paid Only] Gemini 4 Carbon', value = 'gemini-4-carbon' },
                        },
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'Active Model ID:',
                        width = LrView.share 'label_width',
                    },
                    f:edit_field {
                        value = bind 'modelName',
                        width_in_chars = 28,
                    },
                    f:push_button {
                        title = 'Auto-Detect Free Model',
                        action = checkAvailableModels,
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'Output Language:',
                        width = LrView.share 'label_width',
                    },
                    f:popup_menu {
                        value = bind 'language',
                        items = {
                            { title = 'English (Stock / Standard)', value = 'English' },
                            { title = 'Bosnian / Croatian / Serbian', value = 'Bosnian' },
                        },
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'Max Keywords:',
                        width = LrView.share 'label_width',
                    },
                    f:edit_field {
                        value = bind 'maxKeywords',
                        width_in_chars = 5,
                        min = 5,
                        max = 50,
                        precision = 0,
                    },
                },
            },
        }
    end,

    sectionsForBottomOfDialog = function(f, propertyTable)
        return {
            {
                title = 'About Gemini AI Metadata Tagger',
                synopsis = 'v1.0.0 — Vedad Ceric (2026)',

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'Plugin:',
                        width = LrView.share 'about_label_width',
                    },
                    f:static_text {
                        title = 'Gemini AI Metadata Tagger (Version 1.0.0)',
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'Author:',
                        width = LrView.share 'about_label_width',
                    },
                    f:static_text {
                        title = 'Vedad Ceric © 2026',
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'Email:',
                        width = LrView.share 'about_label_width',
                    },
                    f:push_button {
                        title = 'vedadc2@gmail.com',
                        action = function()
                            LrHttp.openUrlInBrowser('mailto:vedadc2@gmail.com')
                        end,
                    },
                },

                f:row {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = 'GitHub:',
                        width = LrView.share 'about_label_width',
                    },
                    f:push_button {
                        title = 'https://github.com/vedadceric',
                        action = function()
                            LrHttp.openUrlInBrowser('https://github.com/vedadceric')
                        end,
                    },
                },
            },
        }
    end,
}