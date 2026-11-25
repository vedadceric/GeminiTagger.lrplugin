local LrPrefs = import 'LrPrefs'
local prefs = LrPrefs.prefsForPlugin()

if prefs.apiKey == nil then
    prefs.apiKey = ''
end

if prefs.modelName == nil or prefs.modelName == '' or prefs.modelName:find('gemini%-4%-flash') then
    prefs.modelName = 'gemini-3.5-flash-lite'
end

if prefs.apiVersion == nil or prefs.apiVersion == '' then
    prefs.apiVersion = 'v1beta'
end

if prefs.language == nil or prefs.language == '' then
    prefs.language = 'English'
end

if prefs.maxKeywords == nil then
    prefs.maxKeywords = 25
end