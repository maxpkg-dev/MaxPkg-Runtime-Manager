-- Runs the MaxPkg Runtime smoke test suite.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg
    local testRoot = getFilenamePath (getSourceFileName())
    local runtimeRoot = getFilenamePath (substring testRoot 1 (testRoot.count - 1))
    local startupFile = runtimeRoot + "startup.ms"
    local utilsModule = fileIn (runtimeRoot + @"core\utils.ms")
    local iniModule = fileIn (runtimeRoot + @"core\ini.ms")
    local resultDialogModule = fileIn (runtimeRoot + @"ui\common\result-dialog.ms")
    local repositoryModule = fileIn (runtimeRoot + @"core\repository.ms")
    local scannerModule = fileIn (runtimeRoot + @"core\scanner.ms")
    local installerModule = fileIn (runtimeRoot + @"core\installer.ms")
    local loggerModule = fileIn (runtimeRoot + @"core\logger.ms")
    local httpModule = fileIn (runtimeRoot + @"core\http.ms")
    local imageCacheModule = fileIn (runtimeRoot + @"core\image-cache.ms")
    local notifierModule = fileIn (runtimeRoot + @"core\notifier.ms")
    local selfUpdaterModule = fileIn (runtimeRoot + @"core\self-updater.ms")
    if (resultDialogModule == undefined) do throw "Reusable Runtime result dialog module is unavailable."
    if (not (doesFileExist (runtimeRoot + @"ui\common\result-dialog.html"))) do throw "Runtime result dialog HTML is unavailable."
    if (not (doesFileExist (runtimeRoot + @"ui\common\result-dialog.css"))) do throw "Runtime result dialog styles are unavailable."
    if (not (doesFileExist (runtimeRoot + @"ui\common\result-dialog.js"))) do throw "Runtime result dialog behavior is unavailable."
    local resultDialogInfo = resultDialogModule.createDialogData()
    if (resultDialogInfo == undefined or not (isProperty resultDialogInfo #heading) or not (isProperty resultDialogInfo #versionText)) do throw "Runtime result dialog data could not be created."
    installerModule.utils = utilsModule
    if ((installerModule.normalizePackageReference "  Prune   Scene  ") != "prune-scene") do throw "Human-readable package reference normalization failed."
    if ((installerModule.normalizePackageReference "3dground/prune-scene") != "3dground/prune-scene") do throw "Canonical package reference normalization changed an existing slug."
    if ((installerModule.packageSearchSignature "scene prune") != (installerModule.packageSearchSignature "Prune Scene")) do throw "Package search terms depend on word order."
    local guidClass = dotNetClass "System.Guid"
    local deleteTestGuid = guidClass.NewGuid()
    local deleteTestId = deleteTestGuid.ToString()
    local deleteTestRoot = (utilsModule.ensureSlash (getDir #temp)) + "maxpkg-delete-test-" + deleteTestId + @"\"
    local deleteTestFilePath = deleteTestRoot + "read-only.tmp"
    local deleteTestStream = undefined
    makeDir deleteTestRoot all: true
    deleteTestStream = createFile deleteTestFilePath
    if (deleteTestStream == undefined) do throw "Could not create the read-only deletion test file."
    format "MaxPkg" to: deleteTestStream
    close deleteTestStream
    setFileAttribute deleteTestFilePath #readOnly true
    if (not (utilsModule.forceDeleteFile deleteTestFilePath)) do throw "Read-only file deletion failed."
    if (not (utilsModule.writeText deleteTestFilePath "Before")) do throw "Could not create the read-only overwrite test file."
    setFileAttribute deleteTestFilePath #readOnly true
    if (not (utilsModule.writeText deleteTestFilePath "After")) do throw "Read-only file overwrite failed."
    if ((utilsModule.readText deleteTestFilePath) != "After") do throw "Read-only file overwrite produced unexpected content."
    local updateCopySourceRoot = deleteTestRoot + @"update-source\"
    local updateCopyTargetRoot = deleteTestRoot + @"update-target\"
    local updateCopySourceFilePath = updateCopySourceRoot + "startup.ms"
    local updateCopyTargetFilePath = updateCopyTargetRoot + "startup.ms"
    if (not (utilsModule.writeText updateCopySourceFilePath "Updated Runtime")) do throw "Could not create the Runtime update source file."
    if (not (utilsModule.writeText updateCopyTargetFilePath "Previous Runtime")) do throw "Could not create the Runtime update target file."
    setFileAttribute updateCopyTargetFilePath #readOnly true
    loggerModule.initialize deleteTestRoot
    if (not (isProperty loggerModule #clearLogForNewSession) or not (isProperty loggerModule #trimOversizedLog)) do throw "Runtime log cleanup API is unavailable."
    local environmentClass = dotNetClass "System.Environment"
    environmentClass.SetEnvironmentVariable loggerModule.sessionEnvironmentName "maxpkg-smoke-previous-session"
    if (not (utilsModule.writeText loggerModule.logFile "Previous session")) do throw "Could not create the previous-session log test file."
    setFileAttribute loggerModule.logFile #readOnly true
    if (not (loggerModule.clearLogForNewSession()) or doesFileExist loggerModule.logFile) do throw "Previous-session Runtime log was not removed."
    if (not (utilsModule.writeText loggerModule.logFile "Oversized log")) do throw "Could not create the oversized log test file."
    loggerModule.maxLogBytes = 1
    if (not (loggerModule.trimOversizedLog()) or doesFileExist loggerModule.logFile) do throw "Oversized Runtime log was not removed."
    loggerModule.maxLogBytes = 5242880
    httpModule.logger = loggerModule
    httpModule.utils = utilsModule
    if (not (isProperty httpModule #curlAvailable) or not (isProperty httpModule #getString) or not (isProperty httpModule #shouldUseCurl) or not (isProperty httpModule #activateCurlFallback)) do throw "HTTP fallback API is unavailable."
    if (httpModule.curlAvailable()) do (
        if (not (httpModule.activateCurlFallback()) or not (httpModule.shouldUseCurl())) do throw "CURL transport did not remain active for the current session."
        local reloadedHttpModule = fileIn (runtimeRoot + @"core\http.ms")
        reloadedHttpModule.logger = loggerModule
        reloadedHttpModule.utils = utilsModule
        if (not (reloadedHttpModule.shouldUseCurl())) do throw "CURL transport did not survive a Runtime module reload."
    )
    imageCacheModule.http = httpModule
    imageCacheModule.utils = utilsModule
    imageCacheModule.logger = loggerModule
    imageCacheModule.cacheRoot = deleteTestRoot + @"image-cache\"
    imageCacheModule.maxCacheBytes = 10
    imageCacheModule.maxCacheFiles = 1
    if (not (imageCacheModule.initialize())) do throw "Manager image cache could not be initialized."
    if (not (isProperty imageCacheModule #localImageUrl) or not (isProperty imageCacheModule #pruneCache)) do throw "Manager image cache API is unavailable."
    local firstCachedImagePath = imageCacheModule.cacheRoot + "first.png"
    local secondCachedImagePath = imageCacheModule.cacheRoot + "second.png"
    if (not (utilsModule.writeText firstCachedImagePath "123456")) do throw "Could not create the first image cache test file."
    if (not (utilsModule.writeText secondCachedImagePath "123456")) do throw "Could not create the second image cache test file."
    local fileClass = dotNetClass "System.IO.File"
    local dateTimeClass = dotNetClass "System.DateTime"
    fileClass.SetLastWriteTimeUtc firstCachedImagePath (dateTimeClass.UtcNow.AddMinutes -2)
    fileClass.SetLastWriteTimeUtc secondCachedImagePath (dateTimeClass.UtcNow.AddMinutes -1)
    if (not (imageCacheModule.pruneCache())) do throw "Manager image cache cleanup failed."
    local directoryClass = dotNetClass "System.IO.Directory"
    if ((directoryClass.GetFiles imageCacheModule.cacheRoot).count > 1) do throw "Manager image cache exceeded its file limit."
    notifierModule.logger = loggerModule
    if (not (notifierModule.initialize())) do throw "Runtime notifier could not be initialized."
    if (notifierModule.notificationIcon == undefined or notifierModule.notificationIcon.Icon == undefined) do throw "The notification information icon could not be loaded."
    if (not (notifierModule.shutdown())) do throw "Runtime notifier could not be released."
    selfUpdaterModule.utils = utilsModule
    selfUpdaterModule.logger = loggerModule
    selfUpdaterModule.http = httpModule
    if (not (selfUpdaterModule.copyRuntimeTree updateCopySourceRoot updateCopyTargetRoot)) do throw "Runtime update could not overwrite an existing file."
    if ((utilsModule.readText updateCopyTargetFilePath) != "Updated Runtime") do throw "Runtime update produced unexpected file content."
    deleteTestStream = createFile deleteTestFilePath
    if (deleteTestStream == undefined) do throw "Could not recreate the read-only deletion test file."
    format "MaxPkg" to: deleteTestStream
    close deleteTestStream
    setFileAttribute deleteTestFilePath #readOnly true
    if (not (utilsModule.forceDeleteFolder deleteTestRoot)) do throw "Read-only folder deletion failed."
    local apiTestFilePath = (utilsModule.ensureSlash (getDir #temp)) + "maxpkg-api-response-" + deleteTestId + ".ini"
    local apiTestStream = createFile apiTestFilePath
    if (apiTestStream == undefined) do throw "Could not create the Runtime API parser test file."
    format "[Catalog]\nPage=1\nPageSize=24\nTotal=1\nTotalPages=1\n\n[test-package-guid]\nGuid=test-package-guid\nSlug=test-package\nName=Test Package\nVersion=1.2.3\nDescription=Line one\\nLine two\nMin3dsMax=2012\nMax3dsMax=2026\nPurchaseUrl=https://developer.example/buy\nPurchaseButtonLabel=Get license\nDownloadUrl=https://maxpkg.dev/api/runtime/v1/download/package/test-package-guid/1.2.3\n" to: apiTestStream
    close apiTestStream
    repositoryModule.ini = iniModule
    repositoryModule.utils = utilsModule
    local parsedApiResponse = repositoryModule.parsePackages apiTestFilePath
    if (not parsedApiResponse.success or parsedApiResponse.packages.count != 1) do throw "Runtime API catalog response parsing failed."
    if (parsedApiResponse.packageInfo.description != "Line one\r\nLine two") do throw "Runtime API escaped newline parsing failed."
    if (parsedApiResponse.packageInfo.purchaseUrl != "https://developer.example/buy") do throw "Runtime API PurchaseUrl parsing failed."
    if (parsedApiResponse.packageInfo.purchaseButtonLabel != "Get license") do throw "Runtime API PurchaseButtonLabel parsing failed."
    if (parsedApiResponse.packageInfo.downloadUrl == "") do throw "Runtime API DownloadUrl parsing failed."
    local compatibleApiResponse = repositoryModule.enforceMinimum3dsMax parsedApiResponse requireCompatiblePackage: true
    if (not compatibleApiResponse.success or compatibleApiResponse.packages.count != 1) do throw "Maximum 3ds Max version incorrectly restricted package compatibility."
    utilsModule.forceDeleteFile apiTestFilePath
    local manifestTestFilePath = (utilsModule.ensureSlash (getDir #temp)) + "maxpkg-manifest-" + deleteTestId + ".ini"
    local manifestTestStream = createFile manifestTestFilePath
    if (manifestTestStream == undefined) do throw "Could not create the manifest parser test file."
    format "[package]\npackageGuid=test-package-guid\nname=Test Package\nversion=1.2.3\nruntime=MaxScript\nentry=test.ms\npurchase=https://developer.example/buy\npurchaseButtonLabel=Support\n" to: manifestTestStream
    close manifestTestStream
    scannerModule.ini = iniModule
    scannerModule.utils = utilsModule
    scannerModule.logger = loggerModule
    local parsedManifestPackage = scannerModule.packageFromManifest manifestTestFilePath
    if (parsedManifestPackage.purchaseButtonLabel != "Support") do throw "Manifest purchaseButtonLabel parsing failed."
    utilsModule.forceDeleteFile manifestTestFilePath
    if (not (fileIn startupFile)) do throw "Initial Runtime startup failed."
    if (MaxPkg == undefined) do throw "MaxPkg global was not created."
    if (maxpkg != MaxPkg) do throw "Lowercase maxpkg did not resolve to the MaxPkg global."
    if (not (isProperty maxpkg #install)) do throw "Lowercase maxpkg API is unavailable."
    if (MaxPkg.version == undefined) do throw "MaxPkg.version is unavailable."
    if (not (MaxPkg.isStarted())) do throw "Initial Runtime is not marked as started."
    if (MaxPkg.settings == undefined) do throw "MaxPkg settings were not loaded."
    if (not (isProperty MaxPkg.settings #toolbarSubtitleMode)) do throw "Toolbar subtitle mode is unavailable."
    if (not (isProperty MaxPkg.settings #toolbarButtonSize)) do throw "Toolbar button size is unavailable."
    if (not (isProperty MaxPkg.settings #toolbarDockPosition)) do throw "Toolbar dock position is unavailable."
    if (not (isProperty MaxPkg.settings #managerFirstOpenCompleted)) do throw "Manager first-open state is unavailable."
    if (not (isProperty MaxPkg.settings #managerFullCards)) do throw "Manager full-card setting is unavailable."
    if (MaxPkg.settings.toolbarDockPosition != "top" and MaxPkg.settings.toolbarDockPosition != "bottom") do throw "Toolbar dock position is invalid."
    if (not (isProperty MaxPkg.settings #apiEndpoint)) do throw "API endpoint setting is unavailable."
    MaxPkg.settings.toolbarOrder = #()
    if (not (MaxPkg.resetToolbarOrder())) do throw "Empty toolbar order could not be synchronized."
    if ((classOf MaxPkg.settings.toolbarOrder) != Array) do throw "Toolbar order synchronization did not preserve an array."
    local runtimeStatus = MaxPkg.getStatus()
    if (runtimeStatus.connection != "configured") do throw "Default API endpoint fallback is unavailable."
    if ((classOf (MaxPkg.getPackages())) != Array) do throw "MaxPkg.getPackages() did not return an array."
    if (MaxPkg.getSettings() == undefined) do throw "MaxPkg.getSettings() is unavailable."
    if (MaxPkg.getStatus() == undefined) do throw "MaxPkg.getStatus() is unavailable."
    if ((MaxPkg.getPackage "__maxpkg_missing_package__") != undefined) do throw "MaxPkg.getPackage() resolved a missing package."
    if (not (doesFileExist (runtimeRoot + @"ui\manager\index.html"))) do throw "Manager HTML is missing."
    if (not (doesFileExist (runtimeRoot + "uninstall.ms"))) do throw "Runtime uninstaller is missing."
    if (not (doesFileExist (runtimeRoot + @"core\notifier.ms"))) do throw "Reusable Runtime notifier module is missing."

    local firstRuntime = MaxPkg
    if (not (firstRuntime.openManager())) do throw "Manager could not be opened before restart."
    if (not (fileIn startupFile)) do throw "Second Runtime startup failed."
    if (MaxPkg == firstRuntime) do throw "Runtime instance was not replaced."
    if (firstRuntime.isStarted()) do throw "Previous Runtime remained started."
    if (not (MaxPkg.isStarted())) do throw "Replacement Runtime is not marked as started."

    local secondRuntime = MaxPkg
    if (not (fileIn startupFile)) do throw "Third Runtime startup failed."
    if (MaxPkg == secondRuntime) do throw "Second Runtime instance was not replaced."
    if (secondRuntime.isStarted()) do throw "Second Runtime remained started."
    if (not (MaxPkg.isStarted())) do throw "Third Runtime is not marked as started."

    local discoveredPackages = MaxPkg.scan()
    if ((classOf discoveredPackages) != Array) do throw "MaxPkg.scan() did not return an array."
    if ((MaxPkg.run "__maxpkg_missing_package__") != false) do throw "Missing package resolution did not fail safely."
    local invalidInstallStatus = maxpkg.install undefined showNotification: false
    if (invalidInstallStatus.success or invalidInstallStatus.errorMessage == "") do throw "Lowercase maxpkg installation call did not return a useful failure status."
    if ((MaxPkg.uninstall "__maxpkg_missing_package__" showNotification: false) != false) do throw "Missing package uninstall did not fail safely."
    local missingUpdateStatus = MaxPkg.updatePackage "__maxpkg_missing_package__"
    if (missingUpdateStatus.success or missingUpdateStatus.errorMessage == "") do throw "Missing package update did not return a useful failure status."
    if ((MaxPkg.setToolbarVisible "__maxpkg_missing_package__" true) != false) do throw "Missing toolbar package did not fail safely."
    if ((MaxPkg.setToolbarOrder undefined) != false) do throw "Invalid toolbar package order did not fail safely."
    if ((MaxPkg.openPackageFolder "__maxpkg_missing_package__") != false) do throw "Missing package folder did not fail safely."
    if (MaxPkg.openPackageLink "__maxpkg_missing_package__" "homepage" != false) do throw "Missing package link did not fail safely."
    if (MaxPkg.openPackageHelp "__maxpkg_missing_package__" != false) do throw "Missing package Help did not fail safely."
    if (MaxPkg.isBusy()) do throw "Critical operation lock was not released."
    format "MAXPKG_RESTART_OK\n"
    format "MAXPKG_SMOKE_OK\n"
    true
)
