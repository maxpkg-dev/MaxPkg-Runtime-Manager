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
        toolbarTitleMode = "packageName",
        toolbarSubtitleMode = "version",
        toolbarButtonSize = "medium",
        updateFrequencyHours = 24,
        notifications = true,
        autoCheckPackages = true,
        autoCheckRuntime = true,
        downloadUpdatesAutomatically = false,
        managerLastSelection = "",
        managerLastTab = "installed",
        managerSort = "toolbar",
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
        apiEndpoint = ""
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

        fn normalizeToolbarTitleMode requestedMode = (
            local normalizedMode = toLower (utils.trim requestedMode)
            if (normalizedMode == "packagename" or normalizedMode == "package") do return "packageName"
            if (normalizedMode == "buttonname" or normalizedMode == "button") do return "buttonName"
            logger.logWarning "settings" ("Unsupported toolbar title mode: " + (requestedMode as string) + "; using packageName")
            return "packageName"
        ),

        fn normalizeToolbarButtonSize requestedSize = (
            local normalizedSize = toLower (utils.trim requestedSize)
            if (normalizedSize == "large" or normalizedSize == "medium" or normalizedSize == "small" or normalizedSize == "icon") do return normalizedSize
            logger.logWarning "settings" ("Unsupported toolbar button size: " + (requestedSize as string) + "; using medium")
            return "medium"
        ),

        fn endpointFromLegacyUrl legacyEndpoint = (
            local normalizedEndpoint = utils.normalizeApiEndpoint legacyEndpoint
            if (normalizedEndpoint == "") do return ""
            local endpointWithoutSlash = substring normalizedEndpoint 1 (normalizedEndpoint.count - 1)
            local endpointSuffixes = #("/updates", "/runtime")
            for endpointSuffix in endpointSuffixes do (
                if (endpointWithoutSlash.count >= endpointSuffix.count) do (
                    local currentSuffix = substring endpointWithoutSlash (endpointWithoutSlash.count - endpointSuffix.count + 1) endpointSuffix.count
                    if ((toLower currentSuffix) == endpointSuffix) do (
                        local endpointLength = endpointWithoutSlash.count - endpointSuffix.count
                        if (endpointLength > 0) do (
                            endpointWithoutSlash = substring endpointWithoutSlash 1 endpointLength
                            return utils.normalizeApiEndpoint endpointWithoutSlash
                        )
                    )
                )
            )
            return normalizedEndpoint
        ),

        fn removeLegacyEndpointSettings = (
            try (
                delIniSetting settingsData.filePath "Updates" "BatchUrl"
                delIniSetting settingsData.filePath "Updates" "RuntimeUrl"
                return true
            ) catch (
                logger.logWarning "settings" ("Could not remove legacy endpoint settings from " + settingsData.filePath + ": " + getCurrentException())
                return false
            )
        ),

        fn saveEndpointSetting = (
            if (settingsData.apiEndpoint != "") do (
                local isEndpointSaved = ini.write settingsData.filePath "Endpoint" "apiEndpoint" settingsData.apiEndpoint
                try (
                    delIniSetting settingsData.filePath "Endpoint" "BaseUrl"
                ) catch (
                )
                return isEndpointSaved
            )
            try (
                delIniSetting settingsData.filePath "Endpoint" "apiEndpoint"
                delIniSetting settingsData.filePath "Endpoint" "BaseUrl"
                return true
            ) catch (
                logger.logWarning "settings" ("Could not remove the endpoint override from " + settingsData.filePath + ": " + getCurrentException())
                return false
            )
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
            settingsData.toolbarTitleMode = normalizeToolbarTitleMode (ini.read settingsData.filePath "Toolbar" "TitleMode" defaultValue: "packageName")
            settingsData.toolbarSubtitleMode = normalizeToolbarSubtitleMode (ini.read settingsData.filePath "Toolbar" "SubtitleMode" defaultValue: "version")
            settingsData.toolbarButtonSize = normalizeToolbarButtonSize (ini.read settingsData.filePath "Toolbar" "ButtonSize" defaultValue: "medium")
            settingsData.updateFrequencyHours = normalizeUpdateFrequency (integerValue (ini.read settingsData.filePath "Updates" "FrequencyHours" defaultValue: "24") 24 "Updates.FrequencyHours")
            settingsData.notifications = utils.boolValue (ini.read settingsData.filePath "Updates" "Notifications" defaultValue: "true") defaultValue: true
            settingsData.autoCheckPackages = utils.boolValue (ini.read settingsData.filePath "Updates" "AutoCheckPackages" defaultValue: "true") defaultValue: true
            settingsData.autoCheckRuntime = utils.boolValue (ini.read settingsData.filePath "Updates" "AutoCheckRuntime" defaultValue: "true") defaultValue: true
            settingsData.downloadUpdatesAutomatically = utils.boolValue (ini.read settingsData.filePath "Updates" "DownloadAutomatically" defaultValue: "false") defaultValue: false
            settingsData.managerLastSelection = ini.read settingsData.filePath "Manager" "LastSelection"
            settingsData.managerLastTab = ini.read settingsData.filePath "Manager" "LastTab" defaultValue: "installed"
            local managerSortVersion = integerValue (ini.read settingsData.filePath "Manager" "SortVersion" defaultValue: "1") 1 "Manager.SortVersion"
            if (managerSortVersion < 2) then (
                settingsData.managerSort = "toolbar"
                if (not (ini.write settingsData.filePath "Manager" "Sort" settingsData.managerSort)) do logger.logWarning "settings" "Could not migrate the Manager sorting mode."
                if (not (ini.write settingsData.filePath "Manager" "SortVersion" "2")) do logger.logWarning "settings" "Could not save the Manager sorting version."
            ) else (
                settingsData.managerSort = ini.read settingsData.filePath "Manager" "Sort" defaultValue: "toolbar"
            )
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
            local configuredApiEndpoint = ini.read settingsData.filePath "Endpoint" "apiEndpoint"
            if (configuredApiEndpoint == "") do configuredApiEndpoint = ini.read settingsData.filePath "Endpoint" "BaseUrl"
            if (configuredApiEndpoint == "") do (
                local legacyUpdateUrl = ini.read settingsData.filePath "Updates" "BatchUrl"
                local legacyRuntimeUrl = ini.read settingsData.filePath "Updates" "RuntimeUrl"
                if (legacyUpdateUrl != "") then (
                    configuredApiEndpoint = endpointFromLegacyUrl legacyUpdateUrl
                ) else if (legacyRuntimeUrl != "") then (
                    configuredApiEndpoint = endpointFromLegacyUrl legacyRuntimeUrl
                )
            )
            settingsData.apiEndpoint = utils.normalizeApiEndpoint configuredApiEndpoint
            logger.logInfo "settings" ("Loaded " + settingsData.filePath)
            return settingsData
        ),

        fn save = (
            if (settingsData == undefined) do return false
            settingsData.updateFrequencyHours = normalizeUpdateFrequency settingsData.updateFrequencyHours
            settingsData.toolbarTitleMode = normalizeToolbarTitleMode settingsData.toolbarTitleMode
            settingsData.toolbarSubtitleMode = normalizeToolbarSubtitleMode settingsData.toolbarSubtitleMode
            settingsData.toolbarButtonSize = normalizeToolbarButtonSize settingsData.toolbarButtonSize
            settingsData.apiEndpoint = utils.normalizeApiEndpoint settingsData.apiEndpoint
            local isSaved = true
            if (not (ini.write settingsData.filePath "Packages" "Roots" (utils.join settingsData.packageRoots separator: "|"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "Hidden" (utils.join settingsData.hiddenPackages separator: "|"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "Order" (utils.join settingsData.toolbarOrder separator: "|"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "Visible" (if (settingsData.toolbarVisible) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "TitleMode" settingsData.toolbarTitleMode)) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "SubtitleMode" settingsData.toolbarSubtitleMode)) do isSaved = false
            if (not (ini.write settingsData.filePath "Toolbar" "ButtonSize" settingsData.toolbarButtonSize)) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "FrequencyHours" (settingsData.updateFrequencyHours as string))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "Notifications" (if (settingsData.notifications) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "AutoCheckPackages" (if (settingsData.autoCheckPackages) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "AutoCheckRuntime" (if (settingsData.autoCheckRuntime) then "true" else "false"))) do isSaved = false
            if (not (ini.write settingsData.filePath "Updates" "DownloadAutomatically" (if (settingsData.downloadUpdatesAutomatically) then "true" else "false"))) do isSaved = false
            if (not (saveEndpointSetting())) do isSaved = false
            if (not (removeLegacyEndpointSettings())) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "LastSelection" settingsData.managerLastSelection)) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "LastTab" settingsData.managerLastTab)) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "Sort" settingsData.managerSort)) do isSaved = false
            if (not (ini.write settingsData.filePath "Manager" "SortVersion" "2")) do isSaved = false
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
