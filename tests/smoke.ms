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
    local guidClass = dotNetClass "System.Guid"
    local deleteTestId = guidClass.NewGuid().ToString()
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
    deleteTestStream = createFile deleteTestFilePath
    if (deleteTestStream == undefined) do throw "Could not recreate the read-only deletion test file."
    format "MaxPkg" to: deleteTestStream
    close deleteTestStream
    setFileAttribute deleteTestFilePath #readOnly true
    if (not (utilsModule.forceDeleteFolder deleteTestRoot)) do throw "Read-only folder deletion failed."
    if (not (fileIn startupFile)) do throw "Initial Runtime startup failed."
    if (MaxPkg == undefined) do throw "MaxPkg global was not created."
    if (maxpkg != MaxPkg) do throw "Lowercase maxpkg did not resolve to the MaxPkg global."
    if (not (isProperty maxpkg #install)) do throw "Lowercase maxpkg API is unavailable."
    if (MaxPkg.version == undefined) do throw "MaxPkg.version is unavailable."
    if (not (MaxPkg.isStarted())) do throw "Initial Runtime is not marked as started."
    if (MaxPkg.settings == undefined) do throw "MaxPkg settings were not loaded."
    if (not (isProperty MaxPkg.settings #toolbarSubtitleMode)) do throw "Toolbar subtitle mode is unavailable."
    if (not (isProperty MaxPkg.settings #toolbarButtonSize)) do throw "Toolbar button size is unavailable."
    if (not (isProperty MaxPkg.settings #apiEndpoint)) do throw "API endpoint setting is unavailable."
    if (MaxPkg.getStatus().connection != "configured") do throw "Default API endpoint fallback is unavailable."
    if ((classOf (MaxPkg.getPackages())) != Array) do throw "MaxPkg.getPackages() did not return an array."
    if (MaxPkg.getSettings() == undefined) do throw "MaxPkg.getSettings() is unavailable."
    if (MaxPkg.getStatus() == undefined) do throw "MaxPkg.getStatus() is unavailable."
    if ((MaxPkg.getPackage "__maxpkg_missing_package__") != undefined) do throw "MaxPkg.getPackage() resolved a missing package."
    if (not (doesFileExist (runtimeRoot + @"ui\manager\index.html"))) do throw "Manager HTML is missing."
    if (not (doesFileExist (runtimeRoot + "uninstall.ms"))) do throw "Runtime uninstaller is missing."

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
    if (maxpkg.install undefined != false) do throw "Lowercase maxpkg installation call did not fail safely."
    if ((MaxPkg.updatePackage "__maxpkg_missing_package__") != false) do throw "Missing package update did not fail safely."
    if ((MaxPkg.setToolbarVisible "__maxpkg_missing_package__" true) != false) do throw "Missing toolbar package did not fail safely."
    if ((MaxPkg.openPackageFolder "__maxpkg_missing_package__") != false) do throw "Missing package folder did not fail safely."
    if (MaxPkg.openPackageLink "__maxpkg_missing_package__" "homepage" != false) do throw "Missing package link did not fail safely."
    if (MaxPkg.openPackageHelp "__maxpkg_missing_package__" != false) do throw "Missing package Help did not fail safely."
    if (MaxPkg.isBusy()) do throw "Critical operation lock was not released."
    format "MAXPKG_RESTART_OK\n"
    format "MAXPKG_SMOKE_OK\n"
    true
)
