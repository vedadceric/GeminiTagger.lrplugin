return {
    LrSdkVersion = 11.0,
    LrSdkMinimumVersion = 6.0,

    LrToolkitIdentifier = 'com.vedadceric.geminitagger',
    LrPluginName = 'Gemini AI Metadata Tagger',
    LrPluginInfoUrl = 'https://github.com/vedadceric/GeminiTagger.lrplugin',

    LrInitPlugin = 'PluginInit.lua',
    LrPluginInfoProvider = 'GeminiSettings.lua',

    LrLibraryMenuItems = {
        {
            title = 'Generate Title, Caption & Keywords (Gemini AI)',
            file = 'TagPhotos.lua',
            enabledWhen = 'photosAvailable',
        },
    },

    VERSION = { major = 1, minor = 0, revision = 0, build = 1 },
}
