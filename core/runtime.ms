-- Composes Runtime modules and exposes the MaxPkg facade.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg

    local previousRuntime = MaxPkg
    if (previousRuntime != undefined) do (
        local isPreviousRuntimeReleased = false
        if (isProperty previousRuntime #shutdown) then (
            try (
                isPreviousRuntimeReleased = previousRuntime.shutdown()
            ) catch (
                format "MaxPkg could not shut down the previous Runtime: %\n" (getCurrentException())
            )
        ) else (
            try (
                if (isProperty previousRuntime #settings and previousRuntime.settings != undefined and isProperty previousRuntime #rebuildToolbar) then (
                    local previousToolbarVisibility = previousRuntime.settings.toolbarVisible
                    previousRuntime.settings.toolbarVisible = false
                    isPreviousRuntimeReleased = previousRuntime.rebuildToolbar()
                    previousRuntime.settings.toolbarVisible = previousToolbarVisibility
                ) else (
                    isPreviousRuntimeReleased = true
                )
            ) catch (
                format "MaxPkg could not release the legacy Runtime toolbar: %\n" (getCurrentException())
            )
        )
        if (not isPreviousRuntimeReleased) do throw "The previous MaxPkg Runtime UI could not be released. Restart 3ds Max before reloading."
        MaxPkg = undefined
    )

    local sourcePath = getSourceFileName()
    if (sourcePath == undefined or sourcePath == "") do sourcePath = getThisScriptFileName()
    local coreRoot = getFilenamePath sourcePath
    local runtimeRoot = getFilenamePath (substring coreRoot 1 (coreRoot.count - 1))

    local utilsModule = fileIn (coreRoot + @"utils.ms")
    local iniModule = fileIn (coreRoot + @"ini.ms")
    local loggerModule = fileIn (coreRoot + @"logger.ms")
    loggerModule.initialize runtimeRoot
    local notifierModule = fileIn (coreRoot + @"notifier.ms")
    notifierModule.logger = loggerModule
    iniModule.logger = loggerModule
    local settingsModule = fileIn (coreRoot + @"settings.ms")
    settingsModule.utils = utilsModule
    settingsModule.ini = iniModule
    settingsModule.logger = loggerModule
    local themesModule = fileIn (coreRoot + @"themes.ms")
    themesModule.initialize runtimeRoot iniModule utilsModule loggerModule
    local scannerModule = fileIn (coreRoot + @"scanner.ms")
    scannerModule.utils = utilsModule
    scannerModule.ini = iniModule
    scannerModule.logger = loggerModule
    local launcherModule = fileIn (coreRoot + @"launcher.ms")
    launcherModule.logger = loggerModule
    local operationModule = fileIn (coreRoot + @"operations.ms")
    operationModule.logger = loggerModule
    local httpModule = fileIn (coreRoot + @"http.ms")
    httpModule.logger = loggerModule
    httpModule.utils = utilsModule
    local imageCacheModule = fileIn (coreRoot + @"image-cache.ms")
    imageCacheModule.http = httpModule
    imageCacheModule.utils = utilsModule
    imageCacheModule.logger = loggerModule
    imageCacheModule.initialize()
    local apiModule = fileIn (coreRoot + @"api.ms")
    local repositoryModule = fileIn (coreRoot + @"repository.ms")
    local toolbarModule = fileIn (coreRoot + @"toolbar.ms")
    local managerModule = fileIn (runtimeRoot + @"ui\manager\manager.ms")
    local installerModule = fileIn (coreRoot + @"installer.ms")
    local uninstallerModule = fileIn (coreRoot + @"uninstaller.ms")
    local updaterModule = fileIn (coreRoot + @"updater.ms")
    local selfUpdaterModule = fileIn (coreRoot + @"self-updater.ms")

    struct MaxPkgRuntimeStatusData (
        isStarted = false,
        isBusy = false,
        packageCount = 0,
        updateCount = 0,
        connection = "offline",
        runtimeVersion = ""
    )

    struct MaxPkgRuntimeFacade (
        version = "1.0.0",
        runtimeChannel = "stable",
        packages = #(),
        catalogState = undefined,
        collectionsState = undefined,
        categoriesState = undefined,
        remotePackageDetails = undefined,
        settings = undefined,
        operation = undefined,
        private
        started = false,
        runtimeAutoUpdatePending = false,

        fn packageRoots = (
            local rootPaths = #((getDir #temp), runtimeRoot + @"data\packages")
            if (settings != undefined) do join rootPaths settings.packageRoots
            return utilsModule.uniqueStrings rootPaths
        ),

        fn refreshManager context = (
            try (
                return managerModule.refresh()
            ) catch (
                loggerModule.logWarning context ("Manager refresh failed: " + getCurrentException())
                return false
            )
        ),

        fn showPackageNotification notificationContent notificationTitle: "MaxPkg" isError: false = (
            return notifierModule.showNotification notificationContent notificationTitle: notificationTitle isError: isError
        ),

        fn showInstallNotification installStatus packageReference = (
            local packageLabel = if (packageReference != undefined and packageReference != "") then (packageReference as string) else "Package"
            if (installStatus.success and installStatus.packageGuid != "") do (
                local installedPackage = apiModule.resolve packages installStatus.packageGuid
                if (installedPackage != undefined and installedPackage.packageName != "") do packageLabel = installedPackage.packageName
            )
            if (installStatus.success) then (
                return showPackageNotification "Package was installed." notificationTitle: packageLabel
            ) else (
                local errorMessage = if (installStatus.errorMessage != "") then installStatus.errorMessage else "The package could not be installed."
                return showPackageNotification ("Package could not be installed.\n" + errorMessage) notificationTitle: packageLabel isError: true
            )
        ),

        fn cloneArrayValues sourceValues = (
            local clonedValues = #()
            if ((classOf sourceValues) != Array) do return clonedValues
            for sourceEntry in sourceValues do append clonedValues sourceEntry
            return clonedValues
        ),

        fn packageGuidExists packageGuids packageGuid = (
            for existingGuid in packageGuids where (toLower existingGuid) == (toLower packageGuid) do return true
            return false
        ),

        fn toolbarOrdersMatch firstOrder secondOrder = (
            if (firstOrder.count != secondOrder.count) do return false
            for orderIndex in 1 to firstOrder.count do (
                if ((toLower firstOrder[orderIndex]) != (toLower secondOrder[orderIndex])) do return false
            )
            return true
        ),

        fn synchronizeToolbarOrder = (
            if (settings == undefined) do return false
            local previousToolbarOrder = cloneArrayValues settings.toolbarOrder
            local normalizedToolbarOrder = #()
            for savedGuid in previousToolbarOrder do (
                local savedPackage = apiModule.resolve packages savedGuid
                if (savedPackage != undefined and not (packageGuidExists normalizedToolbarOrder savedPackage.guid)) do append normalizedToolbarOrder savedPackage.guid
            )
            for packageInfo in packages do (
                if (not (packageGuidExists normalizedToolbarOrder packageInfo.guid)) do append normalizedToolbarOrder packageInfo.guid
            )
            if (toolbarOrdersMatch previousToolbarOrder normalizedToolbarOrder) do return true
            settings.toolbarOrder = normalizedToolbarOrder
            if (settingsModule.save()) do return true
            settings.toolbarOrder = previousToolbarOrder
            loggerModule.logError "runtime" "Could not synchronize the toolbar package order."
            return false
        ),

        public

        fn startPendingRuntimeUpdateCheck = (
            if (not runtimeAutoUpdatePending or not started or settings == undefined) do return false
            runtimeAutoUpdatePending = false
            try (
                return selfUpdaterModule.startAutoUpdateCheck currentVersion: version currentChannel: runtimeChannel
            ) catch (
                loggerModule.logWarning "startup" ("Runtime background update check could not start: " + getCurrentException())
                return false
            )
        ),

        fn shutdown = (
            runtimeAutoUpdatePending = false
            updaterModule.shutdown()
            local isManagerClosed = managerModule.shutdownManager()
            local isToolbarClosed = toolbarModule.shutdownToolbar()
            imageCacheModule.shutdown()
            notifierModule.shutdown()
            started = false
            packages = #()
            catalogState = undefined
            collectionsState = undefined
            categoriesState = undefined
            remotePackageDetails = undefined
            settings = undefined
            operation = undefined
            operationModule.current = undefined
            if (isManagerClosed and isToolbarClosed) then
                loggerModule.logInfo "shutdown" "MaxPkg Runtime UI was released"
            else
                loggerModule.logError "shutdown" "MaxPkg Runtime UI could not be fully released"
            return isManagerClosed and isToolbarClosed
        ),

        fn isStarted = (
            return started
        ),

        fn scan = (
            try (
                packages = scannerModule.scan (packageRoots())
            ) catch (
                loggerModule.logError "runtime" ("Scan failed: " + getCurrentException())
                packages = #()
                return packages
            )
            try (
                synchronizeToolbarOrder()
            ) catch (
                loggerModule.logError "runtime" ("Toolbar order synchronization failed: " + getCurrentException())
            )
            try (
                updaterModule.applyCachedUpdates()
            ) catch (
                loggerModule.logWarning "runtime" ("Cached package updates could not be applied: " + getCurrentException())
            )
            return packages
        ),

        fn start = (
            if (started) do return true
            try (
                settings = settingsModule.load runtimeRoot
                settings.managerTheme = themesModule.resolveThemeId "manager" settings.managerTheme
                settings.toolbarTheme = themesModule.resolveThemeId "toolbar" settings.toolbarTheme
                if (not (themesModule.prepareManagerAssets settings.managerTheme)) do loggerModule.logWarning "startup" "Manager theme assets could not be prepared."
                if (not (themesModule.prepareToolbarAssets settings.toolbarTheme)) do loggerModule.logWarning "startup" "Toolbar theme assets could not be prepared."
                version = iniModule.read (runtimeRoot + "version.ini") "Runtime" "Version" defaultValue: "1.0.0"
                runtimeChannel = iniModule.read (runtimeRoot + "version.ini") "Runtime" "Channel" defaultValue: "stable"
                scan()
                started = true
                if (settings.toolbarVisible and not (toolbarModule.build())) do loggerModule.logWarning "startup" "Toolbar could not be created."
                if (settings.openManagerOnStartup) do managerModule.showManager()
                loggerModule.logInfo "startup" ("MaxPkg Runtime " + version + " is ready")
                runtimeAutoUpdatePending = settings.autoCheckRuntime
                local packageCheckStarted = false
                if (settings.autoCheckPackages) do (
                    try (
                        packageCheckStarted = updaterModule.startAutomaticCheck()
                    ) catch (
                        loggerModule.logWarning "startup" ("Package background update check could not start: " + getCurrentException())
                    )
                )
                if (not packageCheckStarted) do startPendingRuntimeUpdateCheck()
                return true
            ) catch (
                loggerModule.logError "startup" (getCurrentException())
                return false
            )
        ),

        fn openManager = (
            return managerModule.showManager()
        ),

        fn getPackages = (
            return packages
        ),

        fn getPackage packageReference = (
            return apiModule.resolve packages packageReference
        ),

        fn browseCollections = (
            collectionsState = repositoryModule.collections channelName: runtimeChannel
            return collectionsState
        ),

        fn browseCategories = (
            categoriesState = repositoryModule.categories channelName: runtimeChannel
            return categoriesState
        ),

        fn browsePackages queryText: "" categoryFilter: "" sortMode: "popular" pageNumber: 1 pageSize: 24 featuredOnly: false collectionSlug: "" = (
            catalogState = repositoryModule.catalog queryText: queryText categoryFilter: categoryFilter sortMode: sortMode pageNumber: pageNumber pageSize: pageSize channelName: runtimeChannel featuredOnly: featuredOnly collectionSlug: collectionSlug
            return catalogState
        ),

        fn getRemotePackageDetails packageReference = (
            remotePackageDetails = repositoryModule.packageDetails packageReference channelName: runtimeChannel
            return remotePackageDetails
        ),

        fn resolveRemotePackage packageReference = (
            return repositoryModule.resolvePackage packageReference channelName: runtimeChannel
        ),

        fn getSettings = (
            return settings
        ),

        fn saveSettings = (
            if (settings == undefined) do return false
            return settingsModule.save()
        ),

        fn getStatus = (
            local statusInfo = MaxPkgRuntimeStatusData()
            statusInfo.isStarted = started
            statusInfo.isBusy = operationModule.isBusy()
            statusInfo.packageCount = packages.count
            for packageInfo in packages where packageInfo.updateAvailable do statusInfo.updateCount += 1
            statusInfo.connection = if (settings != undefined and (utilsModule.resolveApiEndpoint settings.apiEndpoint) != "") then "configured" else "offline"
            statusInfo.runtimeVersion = version
            return statusInfo
        ),

        fn run package = (
            local resolved = apiModule.resolve packages package
            if (resolved == undefined) do (
                loggerModule.logError "api" ("Package not found: " + (package as string))
                return false
            )
            return launcherModule.run resolved
        ),

        fn install packageReference showNotification: true = (
            local installStatus = installerModule.install packageReference
            if (showNotification) do showInstallNotification installStatus packageReference
            return installStatus
        ),

        fn uninstall packageReference showNotification: true = (
            local resolvedPackage = apiModule.resolve packages packageReference
            if (resolvedPackage == undefined) do (
                if (showNotification) do showPackageNotification "The package could not be found." isError: true
                return false
            )
            local packageName = resolvedPackage.packageName
            local isUninstalled = uninstallerModule.uninstall resolvedPackage
            if (showNotification) do (
                if (isUninstalled) then (
                    showPackageNotification "Package was removed." notificationTitle: packageName
                ) else (
                    showPackageNotification "Package could not be removed." notificationTitle: packageName isError: true
                )
            )
            return isUninstalled
        ),

        fn checkUpdates = (
            return updaterModule.startManualCheck()
        ),

        fn updateAll = (
            return updaterModule.updateAll()
        ),

        fn updatePackage packageReference = (
            local resolvedPackage = apiModule.resolve packages packageReference
            if (resolvedPackage == undefined) do return installerModule.failureStatus "PACKAGE_NOT_FOUND" "The installed package was not found."
            if (not resolvedPackage.updateAvailable) do return installerModule.failureStatus "VERSION_NOT_FOUND" "No compatible package update is available." packageGuid: resolvedPackage.guid
            if (resolvedPackage.downloadUrl == "") do return installerModule.install resolvedPackage.guid
            return installerModule.install resolvedPackage.downloadUrl
        ),

        fn selfUpdate = (
            return selfUpdaterModule.update()
        ),

        fn rebuildToolbar = (
            if (settings == undefined) do return false
            return toolbarModule.build()
        ),

        fn setToolbarVisible packageReference isVisible = (
            local resolvedPackage = apiModule.resolve packages packageReference
            if (resolvedPackage == undefined) do return false
            local previousHiddenPackages = cloneArrayValues settings.hiddenPackages
            local hiddenPackageIndex = 0
            for hiddenIndex in 1 to settings.hiddenPackages.count do (
                if ((toLower settings.hiddenPackages[hiddenIndex]) == (toLower resolvedPackage.guid)) do hiddenPackageIndex = hiddenIndex
            )
            if (isVisible) then (
                if (hiddenPackageIndex > 0) do deleteItem settings.hiddenPackages hiddenPackageIndex
            ) else if (hiddenPackageIndex == 0) then (
                append settings.hiddenPackages resolvedPackage.guid
            )
            if (not (settingsModule.save())) do (
                settings.hiddenPackages = previousHiddenPackages
                loggerModule.logError "runtime" ("Could not save toolbar visibility for " + resolvedPackage.guid)
                return false
            )
            local isToolbarRebuilt = rebuildToolbar()
            refreshManager "set-toolbar-visible"
            return isToolbarRebuilt
        ),

        fn resetToolbarOrder = (
            local previousToolbarOrder = cloneArrayValues settings.toolbarOrder
            settings.toolbarOrder = #()
            for packageInfo in packages do append settings.toolbarOrder packageInfo.guid
            if (not (settingsModule.save())) do (
                settings.toolbarOrder = previousToolbarOrder
                loggerModule.logError "runtime" "Could not reset toolbar order."
                return false
            )
            local isToolbarRebuilt = rebuildToolbar()
            refreshManager "reset-toolbar-order"
            return isToolbarRebuilt
        ),

        fn setToolbarOrder requestedPackageGuids = (
            if ((classOf requestedPackageGuids) != Array) do return false
            local previousToolbarOrder = cloneArrayValues settings.toolbarOrder
            local reorderedGuids = #()
            for requestedGuid in requestedPackageGuids do (
                local resolvedPackage = apiModule.resolve packages requestedGuid
                if (resolvedPackage != undefined and not (packageGuidExists reorderedGuids resolvedPackage.guid)) do append reorderedGuids resolvedPackage.guid
            )
            for packageInfo in packages do (
                if (not (packageGuidExists reorderedGuids packageInfo.guid)) do append reorderedGuids packageInfo.guid
            )
            settings.toolbarOrder = reorderedGuids
            if (not (settingsModule.save())) do (
                settings.toolbarOrder = previousToolbarOrder
                loggerModule.logError "runtime" "Could not save the toolbar package order."
                return false
            )
            local isToolbarRebuilt = rebuildToolbar()
            refreshManager "set-toolbar-order"
            return isToolbarRebuilt
        ),

        fn openPackageFolder packageReference = (
            local resolvedPackage = apiModule.resolve packages packageReference
            if (resolvedPackage == undefined or resolvedPackage.installPath == "" or not (doesDirectoryExist resolvedPackage.installPath)) do return false
            try (
                shellLaunch resolvedPackage.installPath ""
                return true
            ) catch (
                loggerModule.logError "runtime" ("Could not open package folder " + resolvedPackage.installPath + ": " + getCurrentException())
                return false
            )
        ),

        fn packageLinkUrl packageInfo packageLinkKind = (
            local normalizedLinkKind = toLower (utilsModule.trim packageLinkKind)
            return case normalizedLinkKind of (
                "homepage": packageInfo.homepageUrl
                "documentation": packageInfo.documentationUrl
                "support": packageInfo.supportUrl
                "purchase": packageInfo.purchaseUrl
                "license": packageInfo.licenseUrl
                "maxpkg": utilsModule.packagePageUrl settings.apiEndpoint packageInfo.slug
                default: ""
            )
        ),

        fn openPackageLink packageReference packageLinkKind = (
            local resolvedPackage = apiModule.resolve packages packageReference
            if (resolvedPackage == undefined and catalogState != undefined and catalogState.success) do (
                for catalogPackageInfo in catalogState.packages while resolvedPackage == undefined do (
                    if ((toLower catalogPackageInfo.guid) == (toLower packageReference) or (toLower catalogPackageInfo.slug) == (toLower packageReference)) do resolvedPackage = catalogPackageInfo
                )
            )
            if (resolvedPackage == undefined and remotePackageDetails != undefined and remotePackageDetails.success) do (
                local remoteInfo = remotePackageDetails.packageInfo
                if (remoteInfo != undefined and ((toLower remoteInfo.guid) == (toLower packageReference) or (toLower remoteInfo.slug) == (toLower packageReference))) do resolvedPackage = remoteInfo
            )
            if (resolvedPackage == undefined) do return false
            local packageUrl = packageLinkUrl resolvedPackage packageLinkKind
            if (packageUrl == "") do return false
            try (
                local packageUri = dotNetObject "System.Uri" (utilsModule.trim packageUrl)
                local packageScheme = toLower packageUri.Scheme
                if (packageScheme != "http" and packageScheme != "https") do (
                    loggerModule.logError "runtime" ("Refused unsupported package URL for " + resolvedPackage.guid + ": " + packageUrl)
                    return false
                )
                shellLaunch packageUri.AbsoluteUri ""
                return true
            ) catch (
                loggerModule.logError "runtime" ("Could not open package " + packageLinkKind + " link for " + resolvedPackage.guid + ": " + getCurrentException())
                return false
            )
        ),

        fn openPackageHelp packageReference = (
            return openPackageLink packageReference "documentation"
        ),

        fn packageInstalled packageGuid = (
            scan()
            rebuildToolbar()
            refreshManager "package-installed"
            return apiModule.contains packages packageGuid
        ),

        fn packageRemoved packageGuid = (
            scan()
            rebuildToolbar()
            refreshManager "package-removed"
            return not (apiModule.contains packages packageGuid)
        ),

        fn isBusy = (
            operation = operationModule.current
            return operationModule.isBusy()
        )
    )

    MaxPkg = MaxPkgRuntimeFacade()

    toolbarModule.initialize MaxPkg runtimeRoot utilsModule loggerModule toolbarModule
    toolbarModule.themes = themesModule
    managerModule.initialize MaxPkg runtimeRoot utilsModule managerModule
    managerModule.themes = themesModule
    managerModule.logger = loggerModule
    managerModule.http = httpModule
    managerModule.imageCache = imageCacheModule
    operationModule.owner = MaxPkg
    repositoryModule.owner = MaxPkg
    repositoryModule.runtimeRoot = runtimeRoot
    repositoryModule.http = httpModule
    repositoryModule.ini = iniModule
    repositoryModule.utils = utilsModule
    repositoryModule.logger = loggerModule
    installerModule.owner = MaxPkg
    installerModule.operations = operationModule
    installerModule.manager = managerModule
    installerModule.api = apiModule
    installerModule.http = httpModule
    installerModule.logger = loggerModule
    installerModule.utils = utilsModule
    installerModule.repository = repositoryModule
    uninstallerModule.owner = MaxPkg
    uninstallerModule.operations = operationModule
    uninstallerModule.api = apiModule
    uninstallerModule.manager = managerModule
    uninstallerModule.runtimeRoot = runtimeRoot
    uninstallerModule.utils = utilsModule
    uninstallerModule.logger = loggerModule
    updaterModule.owner = MaxPkg
    updaterModule.operations = operationModule
    updaterModule.manager = managerModule
    updaterModule.logger = loggerModule
    updaterModule.installer = installerModule
    updaterModule.api = apiModule
    updaterModule.repository = repositoryModule
    updaterModule.settingsManager = settingsModule
    selfUpdaterModule.owner = MaxPkg
    selfUpdaterModule.operations = operationModule
    selfUpdaterModule.installer = installerModule
    selfUpdaterModule.runtimeRoot = runtimeRoot
    selfUpdaterModule.logger = loggerModule
    selfUpdaterModule.utils = utilsModule
    selfUpdaterModule.http = httpModule

    MaxPkg
)
