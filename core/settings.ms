-- Loads, validates, migrates, and saves Runtime settings.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgSettingsData (
        filePath = "",
        packageRoots = #(),
        hiddenPackages = #(),
        toolbarOrder = #(),
        toolbarVisible = true,
        toolbarSubtitleMode = "version",
        toolbarButtonSize = "medium",
        updateFrequencyHours = 24,
        notifications = true,
        autoCheckPackages = true,
        autoCheckRuntime = true,
        downloadUpdatesAutomatically = false,
        managerLastSelection = "",
        managerLastTab = "installed",
        managerSort = "name",
        managerFilter = "all",
        managerPositionX = -1,
        managerPositionY = -1,
        managerWidth = 900,
        managerHeight = 650,
        language = "English",
        autoStart = true,
        openManagerOnStartup = false,
        developerMode = false,
        debugLogging = false,
        updateUrl = "",
        runtimeUpdateUrl = ""
    )

    struct MaxPkgSettingsModule (
        utils,
        ini,
        logger,
        settingsData,

        fn splitList sourceContent = (
            if (sourceContent == undefined or sourceContent == "") do return #()
            return filterString sourceContent "|"
        ),

        fn integerValue sourceContent fallbackValue settingName = (
            try (
                return sourceContent as integer
            ) catch (
                logger.logWarning "settings" ("Invalid integer for " + settingName + ": " + (sourceContent as string) + "; using " + (fallbackValue as string))
                return fallbackValue
            )
        ),

        fn normalizeUpdateFrequency requestedFrequencyHours = (
            local allowedFrequencies = #(1, 6, 12, 24, 48, 168)
            for allowedFrequencyHours in allowedFrequencies where (allowedFrequencyHours == requestedFrequencyHours) do return allowedFrequencyHours
            logger.logWarning "settings" ("Unsupported update frequency: " + (requestedFrequencyHours as string) + "; using 24")
            return 24
        ),

        fn normalizeToolbarSubtitleMode requestedMode = (
            local normalizedMode = toLower (utils.trim requestedMode)
            if (normalizedMode == "none" or normalizedMode == "version" or normalizedMode == "developer") do return normalizedMode
            logger.logWarning "settings" ("Unsupported toolbar subtitle mode: " + (requestedMode as string) + "; using version")
            return "version"
        ),

        fn normalizeToolbarButtonSize requestedSize = (
            local normalizedSize = toLower (utils.trim requestedSize)
            if (normalizedSize == "large" or normalizedSize == "medium" or normalizedSize == "small" or normalizedSize == "icon") do return normalizedSize
            logger.logWarning "settings" ("Unsupported toolbar button size: " + (requestedSize as string) + "; using medium")
            return "medium"
        ),

        fn load runtimeRoot = (
            settingsData = MaxPkgSettingsData()
            settingsData.filePath = runtimeRoot + "settings.ini"
            local legacySettingsFilePath = runtimeRoot + @"data\settings.ini"
            if (doesFileExist legacySettingsFilePath) do (
                if (not (doesFileExist settingsData.filePath) and copyFile legacySettingsFilePath settingsData.filePath) then (
                    deleteFile legacySettingsFilePath
                    logger.logInfo "settings" ("Migrated settings to " + settingsData.filePath)
                ) else if (doesFileExist settingsData.filePath) then (
                    deleteFile legacySettingsFilePath
                    logger.logInfo "settings" ("Removed legacy settings file " + legacySettingsFilePath)
                ) else (
                    logger.logWarning "settings" ("Could not migrate settings from " + legacySettingsFilePath)
                )
            )
            settingsData.packageRoots = splitList (ini.read settingsData.filePath "Packages" "Roots")
            settingsData.hiddenPackages = splitList (ini.read settingsData.filePath "Toolbar" "Hidden")
            settingsData.toolbarOrder = splitList (ini.read settingsData.filePath "Toolbar" "Order")
            settingsData.toolbarVisible = utils.boolValue (ini.read settingsData.filePath "Toolbar" "Visible" defaultValue: "true") defaultValue: true
            settingsData.toolbarSubtitleMode = normalizeToolbarSubtitleMode (ini.read settingsData.filePath "Toolbar" "SubtitleMode" defaultValue: "version")
            settingsData.toolbarButtonSize = normalizeToolbarButtonSize (ini.read settingsData.filePath "Toolbar" "ButtonSize" defaultValue: "medium")
            settingsData.updateFrequencyHours = normalizeUpdateFrequency (integerValue (ini.read settingsData.filePath "Updates" "FrequencyHours" defaultValue: "24") 24 "Updates.FrequencyHours")
            settingsData.notifications = utils.boolValue (ini.read settingsData.filePath "Updates" "Notifications" defaultValue: "true") defaultValue: true
            settingsData.autoCheckPackages = utils.boolValue (ini.read settingsData.filePath "Updates" "AutoCheckPackages" defaultValue: "true") defaultValue: true
            settingsData.autoCheckRuntime = utils.boolValue (ini.read settingsData.filePath "Updates" "AutoCheckRuntime" defaultValue: "true") defaultValue: true
            settingsData.downloadUpdatesAutomatically = utils.boolValue (ini.read settingsData.filePath "Updates" "DownloadAutomatically" defaultValue: "false") defaultValue: false
            settingsData.managerLastSelection = ini.read settingsData.filePath "Manager" "LastSelection"
            settingsData.managerLastTab = ini.read settingsData.filePath "Manager" "LastTab" defaultValue: "installed"
            settingsData.managerSort = ini.read settingsData.filePath "Manager" "Sort" defaultValue: "name"
            settingsData.managerFilter = ini.read settingsData.filePath "Manager" "Filter" defaultValue: "all"
            settingsData.managerPositionX = integerValue (ini.read settingsData.filePath "Manager" "PositionX" defaultValue: "-1") -1 "Manager.PositionX"
            settingsData.managerPositionY = integerValue (ini.read settingsData.filePath "Manager" "PositionY" defaultValue: "-1") -1 "Manager.PositionY"
            settingsData.managerWidth = integerValue (ini.read settingsData.filePath "Manager" "Width" defaultValue: "900") 900 "Manager.Width"
            settingsData.managerHeight = integerValue (ini.read settingsData.filePath "Manager" "Height" defaultValue: "650") 650 "Manager.Height"
            settingsData.language = ini.read settingsData.filePath "General" "Language" defaultValue: "English"
            settingsData.autoStart = utils.boolValue (ini.read settingsData.filePath "General" "AutoStart" defaultValue: "true") defaultValue: true
            settingsData.openManagerOnStartup = utils.boolValue (ini.read settingsData.filePath "General" "OpenManagerOnStartup" defaultValue: "false") defaultValue: false
            settingsData.developerMode = utils.boolValue (ini.read settingsData.filePath "Developer" "Enabled" defaultValue: "false") defaultValue: false
            settingsData.debugLogging = utils.boolValue (ini.read settingsData.filePath "Developer" "DebugLogging" defaultValue: "false") defaultValue: false
            settingsData.updateUrl = ini.read settingsData.filePath "Updates" "BatchUrl"
            settingsData.runtimeUpdateUrl = ini.read settingsData.filePath "Updates" "RuntimeUrl"
            logger.logInfo "settings" ("Loaded " + settingsData.filePath)
            return settingsData
        ),

        fn save = (
            if (settingsData == undefined) do return false
            settingsData.updateFrequencyHours = normalizeUpdateFrequency settingsData.updateFrequencyHours
            settingsData.toolbarSubtitleMode = normalizeToolbarSubtitleMode settingsData.toolbarSubtitleMode
            settingsData.toolbarButtonSize = normalizeToolbarButtonSize settingsData.toolbarButtonSize
            local isSaved = true
            if (not (ini.write settingsData.filePath "Packages" "Roots" (utils.join settingsData.packageRoots separator: "|"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "Hidden" (utils.join settingsData.hiddenPackages separator: "|"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "Order" (utils.join settingsData.toolbarOrder separator: "|"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "Visible" (if (settingsData.toolbarVisible) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "SubtitleMode" settingsData.toolbarSubtitleMode)) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "ButtonSize" settingsData.toolbarButtonSize)) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "FrequencyHours" (settingsData.updateFrequencyHours as string))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "Notifications" (if (settingsData.notifications) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "AutoCheckPackages" (if (settingsData.autoCheckPackages) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "AutoCheckRuntime" (if (settingsData.autoCheckRuntime) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "DownloadAutomatically" (if (settingsData.downloadUpdatesAutomatically) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "BatchUrl" settingsData.updateUrl)) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "RuntimeUrl" settingsData.runtimeUpdateUrl)) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "LastSelection" settingsData.managerLastSelection)) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "LastTab" settingsData.managerLastTab)) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "Sort" settingsData.managerSort)) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "Filter" settingsData.managerFilter)) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "PositionX" (settingsData.managerPositionX as string))) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "PositionY" (settingsData.managerPositionY as string))) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "Width" (settingsData.managerWidth as string))) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "Height" (settingsData.managerHeight as string))) do isSaved = false
            if (not (ini.write settingsData.filePath "General" "Language" settingsData.language)) do isSaved = false
            if (not (ini.write settingsData.filePath "General" "AutoStart" (if (settingsData.autoStart) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "General" "OpenManagerOnStartup" (if (settingsData.openManagerOnStartup) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Developer" "Enabled" (if (settingsData.developerMode) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Developer" "DebugLogging" (if (settingsData.debugLogging) then "true" else "false"))) do isSaved = false
            if (not isSaved) do logger.logError "settings" ("Could not save all settings to " + settingsData.filePath)
            return isSaved
        )
    )

    MaxPkgSettingsModule()
)
