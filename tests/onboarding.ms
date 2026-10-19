-- Verifies onboarding preferences, themes, and automatic package installation in isolation.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local testRoot = getFilenamePath (getSourceFileName())
    local runtimeRoot = getFilenamePath (substring testRoot 1 (testRoot.count - 1))
    local utilsModule = fileIn (runtimeRoot + @"core\utils.ms")
    local iniModule = fileIn (runtimeRoot + @"core\ini.ms")
    local settingsModule = fileIn (runtimeRoot + @"core\settings.ms")
    local themesModule = fileIn (runtimeRoot + @"core\themes.ms")
    local onboardingModule = fileIn (runtimeRoot + @"ui\onboarding\onboarding.ms")
    local updaterModule = fileIn (runtimeRoot + @"core\updater.ms")
    local operationsModule = fileIn (runtimeRoot + @"core\operations.ms")
    local installerModule = fileIn (runtimeRoot + @"core\installer.ms")
    local selfUpdaterModule = fileIn (runtimeRoot + @"core\self-updater.ms")
    local apiModule = fileIn (runtimeRoot + @"core\api.ms")
    local fixtureGuid = (dotNetClass "System.Guid").NewGuid()
    local fixtureRoot = (utilsModule.ensureSlash (getDir #temp)) + "maxpkg-onboarding-test-" + (fixtureGuid.ToString()) + @"\"
    makeDir fixtureRoot all: true
    struct OnboardingLoggerFixtureData (
        fn logInfo area content = (return true),
        fn logWarning area content = (return true),
        fn logError area content = (return true)
    )
    struct OnboardingPackageFixtureData (
        guid = "onboarding-test-package",
        version = "1.0.0",
        latestVersion = "2.0.0",
        downloadUrl = "",
        updateAvailable = true
    )
    struct OnboardingManagerFixtureData (
        refreshCount = 0,
        fn refresh = (refreshCount += 1; return true),
        fn notify content notificationType: "info" = (return true)
    )
    struct OnboardingOwnerFixtureData (
        settings,
        settingsManager,
        packages = #(),
        operation,
        runtimeChannel = "stable",
        fixtureFile,
        saveFails = false,
        fn saveSettings = (
            if (saveFails) do return false
            return settingsManager.save()
        ),
        fn scan = (
            packages[1].version = getINISetting fixtureFile "Package" "Version"
            return packages
        ),
        fn rebuildToolbar = (return true),
        fn startPendingRuntimeUpdateCheck = (return true)
    )
    struct OnboardingInstallerUtilsFixtureData (
        -- This local fixture has no startup files; never touch user startup attributes.
        fn clearFolderReadOnly folderPath = (return true)
    )
    struct OnboardingResponseFixtureData (success = true, errorCode = "", errorMessage = "", packages = #())
    struct OnboardingRepositoryFixtureData (
        responseInfo,
        requestCount = 0,
        fn updates installedVersions channelName: "stable" = (requestCount += 1; return responseInfo)
    )
    struct OnboardingCompletionFixtureData (Cancelled = false, Error = undefined)
    local loggerFixture = OnboardingLoggerFixtureData()
    local managerFixture = OnboardingManagerFixtureData()
    settingsModule.utils = utilsModule
    settingsModule.ini = iniModule
    settingsModule.logger = loggerFixture
    local settingsInfo = settingsModule.load fixtureRoot
    local ownerFixture = OnboardingOwnerFixtureData settings: settingsInfo settingsManager: settingsModule fixtureFile: (fixtureRoot + "fixture.ini")
    onboardingModule.initialize ownerFixture runtimeRoot onboardingModule
    onboardingModule.logger = loggerFixture
    onboardingModule.utils = utilsModule
    onboardingModule.manager = managerFixture
    themesModule.initialize runtimeRoot iniModule utilsModule loggerFixture
    onboardingModule.themes = themesModule
    local failureMessage = ""
    try (
        if ((onboardingModule.updateMode()) != "") do throw "Check-only mode must leave both choices unselected."
        if (not (onboardingModule.saveUpdateMode "automatic")) do throw "Automatic choice could not be saved."
        if ((onboardingModule.updateMode()) != "automatic") do throw "Automatic choice did not enable both flags."
        if ((getINISetting settingsInfo.filePath "Updates" "DownloadAutomatically") != "true") do throw "Automatic installation choice was not persisted."
        ownerFixture.saveFails = true
        if (onboardingModule.saveUpdateMode "manual") do throw "Failed settings write reported success."
        if ((onboardingModule.updateMode()) != "automatic" or onboardingModule.errorMessage == "") do throw "Failed settings write did not restore the choice and report the error."
        ownerFixture.saveFails = false
        if (not (onboardingModule.saveUpdateMode "manual")) do throw "Manual choice could not be saved."
        if (settingsInfo.autoCheckPackages or settingsInfo.downloadUpdatesAutomatically) do throw "Manual mode left automatic updates enabled."
        if (not settingsInfo.autoCheckRuntime) do throw "Script update preference changed Runtime updates."
        local reloadedSettingsModule = fileIn (runtimeRoot + @"core\settings.ms")
        reloadedSettingsModule.utils = utilsModule
        reloadedSettingsModule.ini = iniModule
        reloadedSettingsModule.logger = loggerFixture
        local reloadedSettings = reloadedSettingsModule.load fixtureRoot
        if (reloadedSettings.autoCheckPackages or reloadedSettings.downloadUpdatesAutomatically) do throw "Manual mode did not survive settings reload."
        for themeInfo in (themesModule.listThemes "manager") do (
            local renderedCss = themesModule.renderOnboardingCss themeInfo.themeId
            if (renderedCss == "" or (findString renderedCss "{{") != undefined) do throw ("Invalid onboarding theme: " + themeInfo.themeId)
        )
        if ((themesModule.renderOnboardingCss "missing-theme") != (themesModule.renderOnboardingCss "default")) do throw "Onboarding theme fallback failed."
        onboardingModule.dialogOpen = true
        selfUpdaterModule.onboarding = onboardingModule
        selfUpdaterModule.logger = loggerFixture
        if (not (selfUpdaterModule.reloadRuntime()) or not onboardingModule.reloadWhenClosed) do throw "Runtime reload did not wait for onboarding."
        onboardingModule.dialogOpen = false
        onboardingModule.reloadWhenClosed = false

        local packageFixture = OnboardingPackageFixtureData downloadUrl: (fixtureRoot + "update.ms")
        ownerFixture.packages = #(packageFixture)
        setINISetting ownerFixture.fixtureFile "Package" "Version" "1.0.0"
        local packageScript = "(local fixtureRoot = getFilenamePath (getSourceFileName()); setINISetting (fixtureRoot + \"fixture.ini\") \"Package\" \"Version\" \"2.0.0\"; true)"
        if (not (utilsModule.writeText packageFixture.downloadUrl packageScript)) do throw "Could not create disposable update package."
        operationsModule.owner = ownerFixture
        operationsModule.logger = loggerFixture
        installerModule.owner = ownerFixture
        installerModule.logger = loggerFixture
        installerModule.utils = OnboardingInstallerUtilsFixtureData()
        updaterModule.owner = ownerFixture
        updaterModule.operations = operationsModule
        updaterModule.logger = loggerFixture
        updaterModule.installer = installerModule
        updaterModule.api = apiModule
        updaterModule.manager = managerFixture
        updaterModule.settingsManager = settingsModule
        local responseFixture = OnboardingResponseFixtureData packages: #(packageFixture)
        local repositoryFixture = OnboardingRepositoryFixtureData responseInfo: responseFixture
        updaterModule.repository = repositoryFixture
        local completionFixture = OnboardingCompletionFixtureData()
        if (updaterModule.applyAvailableUpdates #(packageFixture) automatic: true) do throw "Manual mode installed an automatic update."
        onboardingModule.saveUpdateMode "automatic"
        operationsModule.begin "install"
        if (updaterModule.applyAvailableUpdates #(packageFixture) automatic: true) do throw "Automatic update ignored the operation lock."
        if (operationsModule.current.kind != "install") do throw "Automatic update released another operation's lock."
        operationsModule.finish()
        updaterModule.backgroundCheckInfo = updaterModule.performUpdateCheck()
        updaterModule.automaticInstallRequested = true
        onboardingModule.saveUpdateMode "manual"
        updaterModule.backgroundCheckCompleted undefined completionFixture
        if (packageFixture.version != "1.0.0") do throw "Switching to manual during a check did not prevent installation."
        onboardingModule.saveUpdateMode "automatic"
        updaterModule.backgroundCheckInfo = updaterModule.performUpdateCheck()
        updaterModule.automaticInstallRequested = false
        updaterModule.backgroundCheckCompleted undefined completionFixture
        if (packageFixture.version != "1.0.0") do throw "Manual check unexpectedly installed an update."
        local requestsBeforeInstall = repositoryFixture.requestCount
        updaterModule.backgroundCheckInfo = updaterModule.performUpdateCheck()
        updaterModule.automaticInstallRequested = true
        updaterModule.backgroundCheckCompleted undefined completionFixture
        if (packageFixture.version != "2.0.0") do throw "Automatic completion did not install the disposable package."
        if (repositoryFixture.requestCount != requestsBeforeInstall + 1) do throw "Automatic installation made a duplicate update request."
        if (operationsModule.isBusy()) do throw "Automatic update leaked the operation lock."
        responseFixture.success = false
        responseFixture.errorMessage = "Fixture offline"
        updaterModule.backgroundCheckInfo = updaterModule.performUpdateCheck()
        updaterModule.automaticInstallRequested = true
        updaterModule.backgroundCheckCompleted undefined completionFixture
        if (packageFixture.version != "2.0.0" or operationsModule.isBusy()) do throw "Offline check changed the package or leaked the lock."
        packageFixture.latestVersion = "3.0.0"
        if (not (utilsModule.writeText packageFixture.downloadUrl "throw \"Expected fixture installation failure\"")) do throw "Could not prepare failed update."
        if (updaterModule.applyAvailableUpdates #(packageFixture) automatic: true) do throw "Failed installer reported success."
        if (operationsModule.isBusy()) do throw "Failed installer leaked the operation lock."
        if (not (utilsModule.writeText packageFixture.downloadUrl "true")) do throw "Could not prepare unchanged-version update."
        if (updaterModule.applyAvailableUpdates #(packageFixture) automatic: true) do throw "Unchanged package version reported successful update."
        if (operationsModule.isBusy()) do throw "Version verification failure leaked the lock."
        if (updaterModule.automaticInstallRequested) do throw "Automatic completion retained an immediate retry."
        if (not (utilsModule.forceDeleteFolder fixtureRoot)) do throw "Could not remove disposable fixture."
        format "MAXPKG_ONBOARDING_OK\n"
    ) catch (
        failureMessage = getCurrentException()
    )
    utilsModule.forceDeleteFolder fixtureRoot
    if (failureMessage != "") do throw failureMessage
    true
)
