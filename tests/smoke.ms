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
    local repositoryModule = fileIn (runtimeRoot + @"core\repository.ms")
    local installerModule = fileIn (runtimeRoot + @"core\installer.ms")
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
    deleteTestStream = createFile deleteTestFilePath
    if (deleteTestStream == undefined) do throw "Could not recreate the read-only deletion test file."
    format "MaxPkg" to: deleteTestStream
    close deleteTestStream
    setFileAttribute deleteTestFilePath #readOnly true
    if (not (utilsModule.forceDeleteFolder deleteTestRoot)) do throw "Read-only folder deletion failed."
    local apiTestFilePath = (utilsModule.ensureSlash (getDir #temp)) + "maxpkg-api-response-" + deleteTestId + ".ini"
    local apiTestStream = createFile apiTestFilePath
    if (apiTestStream == undefined) do throw "Could not create the Runtime API parser test file."
    format "[Catalog]\nPage=1\nPageSize=24\nTotal=1\nTotalPages=1\n\n[test-package-guid]\nGuid=test-package-guid\nSlug=test-package\nName=Test Package\nVersion=1.2.3\nDescription=Line one\\nLine two\nMin3dsMax=2012\nMax3dsMax=2026\nDownloadUrl=https://maxpkg.dev/api/runtime/v1/download/package/test-package-guid/1.2.3\n" to: apiTestStream
    close apiTestStream
    repositoryModule.ini = iniModule
    repositoryModule.utils = utilsModule
    local parsedApiResponse = repositoryModule.parsePackages apiTestFilePath
    if (not parsedApiResponse.success or parsedApiResponse.packages.count != 1) do throw "Runtime API catalog response parsing failed."
    if (parsedApiResponse.packageInfo.description != "Line one\r\nLine two") do throw "Runtime API escaped newline parsing failed."
    if (parsedApiResponse.packageInfo.downloadUrl == "") do throw "Runtime API DownloadUrl parsing failed."
    local compatibleApiResponse = repositoryModule.enforceMinimum3dsMax parsedApiResponse requireCompatiblePackage: true
    if (not compatibleApiResponse.success or compatibleApiResponse.packages.count != 1) do throw "Maximum 3ds Max version incorrectly restricted package compatibility."
    utilsModule.forceDeleteFile apiTestFilePath
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
    if (MaxPkg.settings.toolbarDockPosition != "top" and MaxPkg.settings.toolbarDockPosition != "bottom") do throw "Toolbar dock position is invalid."
    if (not (isProperty MaxPkg.settings #apiEndpoint)) do throw "API endpoint setting is unavailable."
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
