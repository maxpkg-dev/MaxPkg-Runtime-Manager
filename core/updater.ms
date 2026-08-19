-- Checks for and applies installed package updates.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgUpdateCheckData (
        isSuccess = false,
        availableUpdates = #(),
        errorMessage = "",
        updateResponse = undefined
    )

    struct MaxPkgUpdaterModule (
        owner,
        operations,
        manager,
        logger,
        installer,
        api,
        repository,
        settingsManager,
        backgroundWorker,
        backgroundCheckInfo,
        backgroundRequestVersions = #(),
        showCompletionNotification = false,
        isStopping = false,

        fn versionParts versionContent = (
            local versionTokens = filterString versionContent ".-"
            local versionNumbers = #(0,0,0)
            for versionIndex in 1 to (amin versionTokens.count 3) do versionNumbers[versionIndex] = try (
                versionTokens[versionIndex] as integer
            ) catch (
                0
            )
            return versionNumbers
        ),

        fn newer candidateVersion installedVersion = (
            local candidateParts = versionParts candidateVersion
            local installedParts = versionParts installedVersion
            for versionIndex in 1 to 3 do (
                if (candidateParts[versionIndex] > installedParts[versionIndex]) do return true
                if (candidateParts[versionIndex] < installedParts[versionIndex]) do return false
            )
            return false
        ),

        fn packageVersions = (
            local installedVersions = #()
            for packageInfo in owner.packages do append installedVersions (packageInfo.guid + "@" + packageInfo.version)
            return installedVersions
        ),

        fn currentAvailableUpdates = (
            local availableUpdates = #()
            for packageInfo in owner.packages where packageInfo.updateAvailable do append availableUpdates packageInfo
            return availableUpdates
        ),

        fn applyCachedUpdates = (
            if (owner == undefined or owner.settings == undefined) do return false
            for packageInfo in owner.packages do (
                packageInfo.updateAvailable = false
                packageInfo.latestVersion = ""
                packageInfo.downloadUrl = ""
            )
            for cacheEntry in owner.settings.packageUpdateCache do (
                local cacheParts = filterString cacheEntry "@"
                if (cacheParts.count >= 2) do (
                    local cachedPackageInfo = api.resolve owner.packages cacheParts[1]
                    local cachedVersion = cacheParts[2]
                    if (cachedPackageInfo != undefined and newer cachedVersion cachedPackageInfo.version) do (
                        cachedPackageInfo.latestVersion = cachedVersion
                        cachedPackageInfo.updateAvailable = true
                    )
                )
            )
            return true
        ),

        fn updateCheckTimestamp = (
            local dateTimeClass = dotNetClass "System.DateTime"
            local cultureClass = dotNetClass "System.Globalization.CultureInfo"
            return dateTimeClass.UtcNow.ToString "o" cultureClass.InvariantCulture
        ),

        fn elapsedHoursSince timestampContent = (
            if (timestampContent == undefined or timestampContent == "") do return undefined
            local dateTimeClass = dotNetClass "System.DateTime"
            local cultureClass = dotNetClass "System.Globalization.CultureInfo"
            local dateTimeStylesClass = dotNetClass "System.Globalization.DateTimeStyles"
            local previousCheckTime = dateTimeClass.Parse timestampContent cultureClass.InvariantCulture dateTimeStylesClass.RoundtripKind
            local currentCheckTime = dateTimeClass.UtcNow
            local ticksPerHour = 36000000000.0
            return ((currentCheckTime.Ticks as float) - (previousCheckTime.Ticks as float)) / ticksPerHour
        ),

        fn saveUpdateCache availableUpdates = (
            if (owner == undefined or owner.settings == undefined or settingsManager == undefined) do return false
            local cacheEntries = #()
            for packageInfo in availableUpdates do append cacheEntries (packageInfo.guid + "@" + packageInfo.latestVersion)
            owner.settings.packageUpdateCache = cacheEntries
            owner.settings.lastPackageUpdateCheck = updateCheckTimestamp()
            if (settingsManager.save()) do return true
            logger.logWarning "updater" "Could not save the package update cache."
            return false
        ),

        fn automaticCheckDue = (
            if (owner == undefined or owner.settings == undefined) do return false
            if (not owner.settings.autoCheckPackages or owner.packages.count == 0) do return false
            if (owner.settings.lastPackageUpdateCheck == "") do return true
            try (
                local elapsedHours = elapsedHoursSince owner.settings.lastPackageUpdateCheck
                if (elapsedHours == undefined) do throw "The package update timestamp is unavailable."
                return elapsedHours >= owner.settings.updateFrequencyHours
            ) catch (
                logger.logWarning "updater" ("Invalid package update timestamp; checking now: " + getCurrentException())
                return true
            )
        ),

        fn fetchUpdateCheck installedVersions = (
            local checkInfo = MaxPkgUpdateCheckData()
            if (installedVersions.count == 0) do (
                checkInfo.isSuccess = true
                return checkInfo
            )
            local updateResponse = repository.updates installedVersions channelName: owner.runtimeChannel
            if (not updateResponse.success) do (
                checkInfo.errorMessage = (if (updateResponse.errorCode != "") then updateResponse.errorCode + ": " else "") + updateResponse.errorMessage
                return checkInfo
            )
            checkInfo.updateResponse = updateResponse
            checkInfo.isSuccess = true
            return checkInfo
        ),

        fn applyUpdateResponse checkInfo = (
            if (not checkInfo.isSuccess) do return false
            if (checkInfo.updateResponse == undefined) do return true
            for packageInfo in owner.packages do (
                local updateInfo = api.resolve checkInfo.updateResponse.packages packageInfo.guid
                packageInfo.latestVersion = if (updateInfo != undefined) then updateInfo.latestVersion else ""
                packageInfo.downloadUrl = if (updateInfo != undefined) then updateInfo.downloadUrl else ""
                packageInfo.updateAvailable = packageInfo.latestVersion != "" and packageInfo.downloadUrl != "" and newer packageInfo.latestVersion packageInfo.version
                if (packageInfo.updateAvailable) do append checkInfo.availableUpdates packageInfo
            )
            return true
        ),

        fn performUpdateCheck = (
            local checkInfo = fetchUpdateCheck (packageVersions())
            if (checkInfo.isSuccess) do applyUpdateResponse checkInfo
            return checkInfo
        ),

        fn checkUpdates = (
            local checkInfo = performUpdateCheck()
            if (not checkInfo.isSuccess) do (
                logger.logError "updater" checkInfo.errorMessage
                return currentAvailableUpdates()
            )
            saveUpdateCache checkInfo.availableUpdates
            logger.logInfo "updater" ("Available updates: " + (checkInfo.availableUpdates.count as string))
            return checkInfo.availableUpdates
        ),

        fn backgroundCheckDoWork eventSender eventArgs = (
            backgroundCheckInfo = fetchUpdateCheck backgroundRequestVersions
            eventArgs.Result = backgroundCheckInfo.isSuccess
            return true
        ),

        fn backgroundCheckCompleted eventSender eventArgs = (
            local completedCheckInfo = backgroundCheckInfo
            local isCompleted = true
            backgroundWorker = undefined
            backgroundCheckInfo = undefined
            if (isStopping) do return false
            try (
                if (eventArgs.Cancelled == true) then (
                    logger.logInfo "updater" "Background package update check was cancelled."
                ) else if (eventArgs.Error != undefined) then (
                    logger.logError "updater" ("Background package update worker failed: " + (eventArgs.Error.ToString()))
                ) else if (completedCheckInfo == undefined) then (
                    logger.logWarning "updater" "Background package update check finished without a result."
                ) else if (not completedCheckInfo.isSuccess) then (
                    logger.logWarning "updater" completedCheckInfo.errorMessage
                    if (showCompletionNotification) do manager.notify "The package update check failed. The previous result is still available." notificationType: "error"
                ) else (
                    applyUpdateResponse completedCheckInfo
                    saveUpdateCache completedCheckInfo.availableUpdates
                    logger.logInfo "updater" ("Background update check found " + (completedCheckInfo.availableUpdates.count as string) + " update(s).")
                    owner.rebuildToolbar()
                    try (
                        manager.refresh()
                    ) catch (
                        logger.logWarning "updater" ("Manager refresh failed: " + getCurrentException())
                    )
                    if (showCompletionNotification) do manager.notify ((completedCheckInfo.availableUpdates.count as string) + " update(s) available.")
                )
            ) catch (
                logger.logError "updater" ("Background package update completion failed: " + getCurrentException())
                isCompleted = false
            )
            showCompletionNotification = false
            try (
                owner.startPendingRuntimeUpdateCheck()
            ) catch (
                logger.logWarning "updater" ("Pending Runtime update check could not start: " + getCurrentException())
                isCompleted = false
            )
            return isCompleted
        ),

        fn startBackgroundCheck forceCheck: false notifyWhenComplete: false = (
            if (backgroundWorker != undefined) do return false
            if (not forceCheck and not (automaticCheckDue())) do return false
            try (
                isStopping = false
                backgroundCheckInfo = undefined
                backgroundRequestVersions = packageVersions()
                showCompletionNotification = notifyWhenComplete
                backgroundWorker = dotNetObject "CSharpUtilities.SynchronizingBackgroundWorker"
                backgroundWorker.WorkerSupportsCancellation = true
                dotNet.addEventHandler backgroundWorker "DoWork" backgroundCheckDoWork
                dotNet.addEventHandler backgroundWorker "RunWorkerCompleted" backgroundCheckCompleted
                backgroundWorker.RunWorkerAsync()
                logger.logInfo "updater" "Background package update check started."
                return true
            ) catch (
                logger.logWarning "updater" ("Could not start background package update check: " + getCurrentException())
                backgroundWorker = undefined
                backgroundCheckInfo = undefined
                return false
            )
        ),

        fn startAutomaticCheck = (
            return startBackgroundCheck()
        ),

        fn startManualCheck = (
            return startBackgroundCheck forceCheck: true notifyWhenComplete: true
        ),

        fn isBackgroundCheckRunning = (
            return backgroundWorker != undefined
        ),

        fn shutdown = (
            isStopping = true
            if (backgroundWorker != undefined) do (
                try (
                    if (backgroundWorker.IsBusy) do backgroundWorker.CancelAsync()
                ) catch (
                    logger.logWarning "updater" ("Could not cancel the background package update check: " + getCurrentException())
                )
            )
            backgroundWorker = undefined
            backgroundCheckInfo = undefined
            backgroundRequestVersions = #()
            showCompletionNotification = false
            return true
        ),

        fn updateAll = (
            if (not (operations.begin "updateAll")) do return false
            local isSuccess = false
            try (
                local availableUpdates = checkUpdates()
                isSuccess = true
                for packageInfo in availableUpdates while isSuccess do isSuccess = installer.installSource packageInfo.downloadUrl
                owner.scan()
                for updatePackageInfo in availableUpdates while isSuccess do (
                    local installedPackageInfo = api.resolve owner.packages updatePackageInfo.guid
                    if (installedPackageInfo == undefined) then
                        isSuccess = false
                    else if (newer updatePackageInfo.latestVersion installedPackageInfo.version) then
                        isSuccess = false
                )
                if (not isSuccess) do logger.logError "updater" "One or more updates could not be verified after installation."
                owner.rebuildToolbar()
                try (
                    manager.refresh()
                ) catch (
                    logger.logWarning "updater" ("Manager refresh failed: " + getCurrentException())
                )
            ) catch (
                logger.logError "updater" ("Update-all operation failed: " + getCurrentException())
                isSuccess = false
            )
            return operations.finish success: isSuccess
        )
    )

    MaxPkgUpdaterModule()
)
