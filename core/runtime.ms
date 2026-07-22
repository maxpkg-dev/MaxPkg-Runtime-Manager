(
    global MaxPkg

    local previousRuntime = MaxPkg
    if previousRuntime != undefined do (
        local isPreviousRuntimeReleased = false
        if isProperty previousRuntime #shutdown then (
            try (
                isPreviousRuntimeReleased = previousRuntime.shutdown()
            ) catch (
                format "MaxPkg could not shut down the previous Runtime: %\n" (getCurrentException())
            )
        ) else (
            try (
                if isProperty previousRuntime #settings and previousRuntime.settings != undefined and isProperty previousRuntime #rebuildToolbar then (
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
        if not isPreviousRuntimeReleased do throw "The previous MaxPkg Runtime UI could not be released. Restart 3ds Max before reloading."
        MaxPkg = undefined
    )

    local sourcePath = getSourceFileName()
    if sourcePath == undefined or sourcePath == "" do sourcePath = getThisScriptFileName()
    local coreRoot = getFilenamePath sourcePath
    local runtimeRoot = getFilenamePath (substring coreRoot 1 (coreRoot.count - 1))

    local utilsModule = fileIn (coreRoot + "utils.ms")
    local iniModule = fileIn (coreRoot + "ini.ms")
    local loggerModule = fileIn (coreRoot + "logger.ms")
    loggerModule.initialize runtimeRoot
    iniModule.logger = loggerModule
    local settingsModule = fileIn (coreRoot + "settings.ms")
    settingsModule.utils = utilsModule
    settingsModule.ini = iniModule
    settingsModule.logger = loggerModule
    local scannerModule = fileIn (coreRoot + "scanner.ms")
    scannerModule.utils = utilsModule
    scannerModule.ini = iniModule
    scannerModule.logger = loggerModule
    local launcherModule = fileIn (coreRoot + "launcher.ms")
    launcherModule.logger = loggerModule
    local operationModule = fileIn (coreRoot + "operations.ms")
    operationModule.logger = loggerModule
    local httpModule = fileIn (coreRoot + "http.ms")
    httpModule.logger = loggerModule
    local apiModule = fileIn (coreRoot + "api.ms")
    local toolbarModule = fileIn (coreRoot + "toolbar.ms")
    local managerModule = fileIn (runtimeRoot + "ui\\manager\\manager.ms")
    local installerModule = fileIn (coreRoot + "installer.ms")
    local uninstallerModule = fileIn (coreRoot + "uninstaller.ms")
    local updaterModule = fileIn (coreRoot + "updater.ms")
    local selfUpdaterModule = fileIn (coreRoot + "self-updater.ms")

    struct MaxPkgRuntimeFacade (
        version = "1.0.0",
        packages = #(),
        settings = undefined,
        operation = undefined,
        private
        started = false,

        fn packageRoots = (
            local roots = #((getDir #temp), runtimeRoot + "data\\packages")
            if settings != undefined do join roots settings.packageRoots
            return utilsModule.uniqueStrings roots
        ),

        fn refreshManager context = (
            try (
                return managerModule.refresh()
            ) catch (
                loggerModule.logWarning context ("Manager refresh failed: " + getCurrentException())
                return false
            )
        ),

        public

        fn shutdown = (
            local isManagerClosed = managerModule.shutdownManager()
            local isToolbarClosed = toolbarModule.shutdownToolbar()
            started = false
            packages = #()
            settings = undefined
            operation = undefined
            operationModule.current = undefined
            if isManagerClosed and isToolbarClosed then
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
                return packages
            ) catch (
                loggerModule.logError "runtime" ("Scan failed: " + getCurrentException())
                packages = #()
                return packages
            )
        ),

        fn start = (
            if started do return true
            try (
                settings = settingsModule.load runtimeRoot
                version = iniModule.read (runtimeRoot + "version.ini") "Runtime" "Version" defaultValue:"1.0.0"
                scan()
                started = true
                if settings.toolbarVisible and not (toolbarModule.build()) do loggerModule.logWarning "startup" "Toolbar could not be created."
                loggerModule.logInfo "startup" ("MaxPkg Runtime " + version + " is ready")
                return true
            ) catch (
                loggerModule.logError "startup" (getCurrentException())
                return false
            )
        ),

        fn openManager = (
            return managerModule.open()
        ),

        fn run package = (
            local resolved = apiModule.resolve packages package
            if resolved == undefined do (
                loggerModule.logError "api" ("Package not found: " + (package as string))
                return false
            )
            return launcherModule.run resolved
        ),

        fn install package = (
            return installerModule.install package
        ),

        fn uninstall package = (
            local resolved = apiModule.resolve packages package
            if resolved == undefined do return false
            return uninstallerModule.uninstall resolved
        ),

        fn checkUpdates = (
            return updaterModule.checkUpdates()
        ),

        fn updateAll = (
            return updaterModule.updateAll()
        ),

        fn selfUpdate = (
            return selfUpdaterModule.update()
        ),

        fn rebuildToolbar = (
            if settings == undefined do return false
            return toolbarModule.build()
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

    toolbarModule.initialize MaxPkg utilsModule loggerModule toolbarModule
    managerModule.initialize MaxPkg managerModule
    managerModule.settingsModule = settingsModule
    managerModule.logger = loggerModule
    operationModule.owner = MaxPkg
    installerModule.owner = MaxPkg
    installerModule.operations = operationModule
    installerModule.manager = managerModule
    installerModule.api = apiModule
    installerModule.http = httpModule
    installerModule.logger = loggerModule
    installerModule.utils = utilsModule
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
    updaterModule.runtimeRoot = runtimeRoot
    updaterModule.http = httpModule
    updaterModule.ini = iniModule
    updaterModule.utils = utilsModule
    updaterModule.logger = loggerModule
    updaterModule.installer = installerModule
    updaterModule.api = apiModule
    selfUpdaterModule.owner = MaxPkg
    selfUpdaterModule.operations = operationModule
    selfUpdaterModule.installer = installerModule
    selfUpdaterModule.runtimeRoot = runtimeRoot
    selfUpdaterModule.logger = loggerModule

    MaxPkg
)
