(
    struct MaxPkgSettingsData (
        filePath = "",
        packageRoots = #(),
        hiddenPackages = #(),
        toolbarOrder = #(),
        toolbarVisible = true,
        updateFrequencyHours = 24,
        notifications = true,
        managerLastSelection = "",
        updateUrl = "",
        runtimeUpdateUrl = ""
    )

    struct MaxPkgSettingsModule (
        utils,
        ini,
        logger,
        settingsData,

        fn splitList sourceContent = (
            if sourceContent == undefined or sourceContent == "" do return #()
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

        fn load runtimeRoot = (
            settingsData = MaxPkgSettingsData()
            settingsData.filePath = runtimeRoot + "data\\settings.ini"
            makeDir (getFilenamePath settingsData.filePath) all:true
            settingsData.packageRoots = splitList (ini.read settingsData.filePath "Packages" "Roots")
            settingsData.hiddenPackages = splitList (ini.read settingsData.filePath "Toolbar" "Hidden")
            settingsData.toolbarOrder = splitList (ini.read settingsData.filePath "Toolbar" "Order")
            settingsData.toolbarVisible = utils.boolValue (ini.read settingsData.filePath "Toolbar" "Visible" defaultValue:"true") defaultValue:true
            settingsData.updateFrequencyHours = integerValue (ini.read settingsData.filePath "Updates" "FrequencyHours" defaultValue:"24") 24 "Updates.FrequencyHours"
            settingsData.notifications = utils.boolValue (ini.read settingsData.filePath "Updates" "Notifications" defaultValue:"true") defaultValue:true
            settingsData.managerLastSelection = ini.read settingsData.filePath "Manager" "LastSelection"
            settingsData.updateUrl = ini.read settingsData.filePath "Updates" "BatchUrl"
            settingsData.runtimeUpdateUrl = ini.read settingsData.filePath "Updates" "RuntimeUrl"
            logger.logInfo "settings" ("Loaded " + settingsData.filePath)
            return settingsData
        ),

        fn save = (
            if settingsData == undefined do return false
            local isSaved = true
            if not (ini.write settingsData.filePath "Packages" "Roots" (utils.join settingsData.packageRoots separator:"|")) do isSaved = false
            if not (ini.write settingsData.filePath "Toolbar" "Hidden" (utils.join settingsData.hiddenPackages separator:"|")) do isSaved = false
            if not (ini.write settingsData.filePath "Toolbar" "Order" (utils.join settingsData.toolbarOrder separator:"|")) do isSaved = false
            if not (ini.write settingsData.filePath "Toolbar" "Visible" (if settingsData.toolbarVisible then "true" else "false")) do isSaved = false
            if not (ini.write settingsData.filePath "Updates" "FrequencyHours" (settingsData.updateFrequencyHours as string)) do isSaved = false
            if not (ini.write settingsData.filePath "Updates" "Notifications" (if settingsData.notifications then "true" else "false")) do isSaved = false
            if not (ini.write settingsData.filePath "Updates" "BatchUrl" settingsData.updateUrl) do isSaved = false
            if not (ini.write settingsData.filePath "Updates" "RuntimeUrl" settingsData.runtimeUpdateUrl) do isSaved = false
            if not (ini.write settingsData.filePath "Manager" "LastSelection" settingsData.managerLastSelection) do isSaved = false
            if not isSaved do logger.logError "settings" ("Could not save all settings to " + settingsData.filePath)
            return isSaved
        )
    )

    MaxPkgSettingsModule()
)
