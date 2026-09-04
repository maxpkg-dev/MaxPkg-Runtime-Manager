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
    local themesModule = fileIn (runtimeRoot + @"core\themes.ms")
    local resultDialogModule = fileIn (runtimeRoot + @"ui\common\result-dialog.ms")
    local repositoryModule = fileIn (runtimeRoot + @"core\repository.ms")
    local scannerModule = fileIn (runtimeRoot + @"core\scanner.ms")
    local installerModule = fileIn (runtimeRoot + @"core\installer.ms")
    local loggerModule = fileIn (runtimeRoot + @"core\logger.ms")
    local httpModule = fileIn (runtimeRoot + @"core\http.ms")
    local imageCacheModule = fileIn (runtimeRoot + @"core\image-cache.ms")
    local notifierModule = fileIn (runtimeRoot + @"core\notifier.ms")
    local uiScaleModule = fileIn (runtimeRoot + @"core\ui-scale.ms")
    if ((uiScaleModule.scalePercentageFromDpi 96.0) != 100) do throw "100 percent UI scale calculation failed."
    if ((uiScaleModule.scalePercentageFromDpi 144.0) != 150) do throw "150 percent UI scale calculation failed."
    if ((uiScaleModule.scalePercentageFromDpi 384.0) != 300) do throw "Maximum UI scale limit failed."
    local selfUpdaterModule = fileIn (runtimeRoot + @"core\self-updater.ms")
    local updaterModule = fileIn (runtimeRoot + @"core\updater.ms")
    local updateTimestamp = updaterModule.updateCheckTimestamp()
    local elapsedUpdateHours = updaterModule.elapsedHoursSince updateTimestamp
    if (elapsedUpdateHours == undefined or (abs elapsedUpdateHours) > 0.1) do throw "Package update timestamp interval calculation failed."
    themesModule.initialize runtimeRoot iniModule utilsModule undefined
    resultDialogModule.configureTheme themesModule "default"
    if ((themesModule.listThemes "manager").count < 1) do throw "Manager themes are unavailable."
    if ((themesModule.listThemes "toolbar").count < 1) do throw "Toolbar themes are unavailable."
    if ((themesModule.resolveThemeId "manager" "missing-theme") != "default") do throw "Missing Manager theme did not use the default fallback."
    if ((themesModule.resolveThemeId "toolbar" "missing-theme") != "default") do throw "Missing Toolbar theme did not use the default fallback."
    local renderedManagerCss = themesModule.renderManagerCss "default"
    local renderedToolbarCss = themesModule.renderToolbarCss "default"
    if (renderedManagerCss == "" or renderedToolbarCss == "") do throw "Runtime theme CSS is empty."
    if ((findString renderedManagerCss "{{") != undefined or (findString renderedToolbarCss "{{") != undefined) do throw "Runtime theme CSS contains unresolved tokens."
    local toolbarScriptContent = utilsModule.readText (runtimeRoot + @"ui\toolbar\toolbar.js")
    local toolbarSourceContent = utilsModule.readText (runtimeRoot + @"core\toolbar.ms")
    local managerScriptContent = utilsModule.readText (runtimeRoot + @"ui\manager\manager.js")
    local managerHtmlContent = utilsModule.readText (runtimeRoot + @"ui\manager\index.html")
    if ((findString toolbarScriptContent "var outerInset = toolbarDensity() === \"compact\" ? 1 : 5;") == undefined) do throw "Floating Toolbar outer inset does not follow Toolbar spacing."
    if ((findString toolbarScriptContent "wrap.className.indexOf(\"wrap-compact\")") == undefined) do throw "Toolbar overflow axis is not selected from the rendered structure."
    if ((findString toolbarSourceContent "fn updateFloatingGeometry toolbarMode workingArea scalePercentage") == undefined) do throw "Floating Toolbar DPI geometry updater is unavailable."
    if ((findString toolbarSourceContent "uiScale.browserScalePercentage floatingBrowser") == undefined) do throw "Floating Toolbar does not measure DPI from its live browser host."
    if ((findString toolbarSourceContent "then 6 else 12") == undefined) do throw "Compact docked Toolbar does not compensate for CUI host height."
    if ((findString toolbarSourceContent "wrap wrap-normal") == undefined) do throw "Docked text Toolbar is missing its normal-layout marker."
    if ((findString renderedToolbarCss ".toolbar-density-compact .wrap-normal") == undefined) do throw "Compact docked Toolbar client-height styles are unavailable."
    if ((findString renderedToolbarCss ".toolbar-density-compact.toolbar-icons-small .wrap:not(.wrap-compact) .name") == undefined or (findString renderedToolbarCss ".toolbar-density-compact.toolbar-icons-medium .wrap:not(.wrap-compact) .name") == undefined or (findString renderedToolbarCss ".toolbar-density-compact.toolbar-icons-large .wrap:not(.wrap-compact) .name") == undefined) do throw "Compact docked Toolbar text rows can clip at Small, Medium, or Large icon size."
    if ((findString managerScriptContent "return \"topcompact\"") != undefined or (findString managerScriptContent "return \"bottomcompact\"") != undefined) do throw "Toolbar side and spacing are not serialized independently."
    local buttonLayoutPosition = findString managerHtmlContent "id=\"toolbarWidthOptions\""
    local additionalLinePosition = findString managerHtmlContent "id=\"toolbarTextOptions\""
    if (buttonLayoutPosition == undefined or additionalLinePosition == undefined or additionalLinePosition < buttonLayoutPosition) do throw "Additional line is not placed after Button layout."
    if ((findString managerHtmlContent "Left (Compact)") == undefined or (findString managerHtmlContent "Right (Compact)") == undefined or (findString managerHtmlContent "Horizontal (Compact)") == undefined or (findString managerHtmlContent "Vertical (Compact)") == undefined) do throw "Compact toolbar modes are missing their Compact labels."
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
    if (not (isProperty httpModule #curlAvailable) or not (isProperty httpModule #getString) or not (isProperty httpModule #shouldUseCurl) or not (isProperty httpModule #activateCurlFallback) or not (isProperty httpModule #httpStatusCodeFromException) or not (isProperty httpModule #dotNetStringAttempt) or not (isProperty httpModule #dotNetDownloadAttempt)) do throw "HTTP fallback API is unavailable."
    if ((httpModule.httpStatusCodeFromException "The remote server returned an error: (404) Not Found.") != 404) do throw "HTTP 404 classification failed."
    if ((httpModule.httpStatusCodeFromException "The remote server returned an error: (500) Internal Server Error.") != 500) do throw "HTTP 500 classification failed."
    if ((httpModule.httpStatusCodeFromException "The request was aborted: Could not create SSL/TLS secure channel.") != 0) do throw "HTTP transport failure classification failed."
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
    if (not (isProperty imageCacheModule #localImageUrl) or not (isProperty imageCacheModule #pruneCache) or not (isProperty imageCacheModule #pollDownloads) or not (isProperty imageCacheModule #cancelDownloads)) do throw "Manager image cache API is unavailable."
    if (imageCacheModule.maxConcurrentDownloads != 3) do throw "The image download queue has an unexpected concurrency limit."
    if (not (imageCacheModule.cancelDownloads())) do throw "The empty image download queue could not be cancelled."
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
    format "[Catalog]\nPage=1\nPageSize=24\nTotalItems=1\nTotalPages=1\n\n[test-package-guid]\nGuid=test-package-guid\nSlug=test-package\nName=Test Package\nVersion=1.2.3\nDescription=Line one\\nLine two\nMin3dsMax=2012\nMax3dsMax=2026\nPurchaseUrl=https://developer.example/buy\nPurchaseButtonLabel=Get license\nRating=4.8\nReviewCount=12\nDownloadCount=3456\nDownloadUrl=https://maxpkg.dev/api/runtime/v1/download/package/test-package-guid/1.2.3\n" to: apiTestStream
    close apiTestStream
    repositoryModule.ini = iniModule
    repositoryModule.utils = utilsModule
    local parsedApiResponse = repositoryModule.parsePackages apiTestFilePath
    if (not parsedApiResponse.success or parsedApiResponse.packages.count != 1) do throw "Runtime API catalog response parsing failed."
    if (parsedApiResponse.packageInfo.description != "Line one\r\nLine two") do throw "Runtime API escaped newline parsing failed."
    if (parsedApiResponse.packageInfo.purchaseUrl != "https://developer.example/buy") do throw "Runtime API PurchaseUrl parsing failed."
    if (parsedApiResponse.packageInfo.purchaseButtonLabel != "Get license") do throw "Runtime API PurchaseButtonLabel parsing failed."
    if (parsedApiResponse.packageInfo.rating != 4.8 or parsedApiResponse.packageInfo.reviewCount != 12) do throw "Runtime API rating statistics parsing failed."
    if (parsedApiResponse.packageInfo.downloadCount != 3456) do throw "Runtime API download statistics parsing failed."
    if (parsedApiResponse.packageInfo.downloadUrl == "") do throw "Runtime API DownloadUrl parsing failed."
    local compatibleApiResponse = repositoryModule.enforceMinimum3dsMax parsedApiResponse requireCompatiblePackage: true
    if (not compatibleApiResponse.success or compatibleApiResponse.packages.count != 1) do throw "Maximum 3ds Max version incorrectly restricted package compatibility."

    apiTestStream = createFile apiTestFilePath
    if (apiTestStream == undefined) do throw "Could not create the Runtime collections API parser test file."
    format "[meta]\nFeaturedCount=2\nCount=1\n\n[collection_1]\nSlug=must-have\nName=Must-Have\nDescription=Essential tools for everyday work.\nIcon=sparkles\nAccentColor=#e74b7a\nCount=3\n" to: apiTestStream
    close apiTestStream
    local parsedCollectionsResponse = repositoryModule.parseCollections apiTestFilePath
    if (not parsedCollectionsResponse.success or parsedCollectionsResponse.featuredCount != 2 or parsedCollectionsResponse.collections.count != 1) do throw "Runtime API collections response parsing failed."
    local parsedCollectionInfo = parsedCollectionsResponse.collections[1]
    if (parsedCollectionInfo.slug != "must-have" or parsedCollectionInfo.collectionName != "Must-Have" or parsedCollectionInfo.iconName != "sparkles") do throw "Runtime API collection identity parsing failed."
    if (parsedCollectionInfo.accentColor != "#e74b7a" or parsedCollectionInfo.packageCount != 3) do throw "Runtime API collection presentation parsing failed."

    apiTestStream = createFile apiTestFilePath
    if (apiTestStream == undefined) do throw "Could not create the Runtime categories API parser test file."
    format "[category_1]\nSlug=utilities\nName=Utilities\nDescription=Helpful utilities for everyday work\nCount=12\n\n[category_2]\nSlug=empty\nName=Empty\nDescription=No compatible packages\nCount=0\n" to: apiTestStream
    close apiTestStream
    local parsedCategoriesResponse = repositoryModule.parseCategories apiTestFilePath
    if (not parsedCategoriesResponse.success or parsedCategoriesResponse.categories.count != 1) do throw "Runtime API categories response parsing failed."
    local parsedCategoryInfo = parsedCategoriesResponse.categories[1]
    if (parsedCategoryInfo.slug != "utilities" or parsedCategoryInfo.categoryName != "Utilities" or parsedCategoryInfo.categoryDescription == "" or parsedCategoryInfo.packageCount != 12) do throw "Runtime API category parsing failed."

    struct MaxPkgRepositoryOwnerFixtureData (version = "9.8.7")
    repositoryModule.owner = MaxPkgRepositoryOwnerFixtureData()
    local featuredFormContent = utilsModule.join (repositoryModule.catalogFormFields "" "utilities" "popular" 1 24 "stable" featuredOnly: true collectionSlug: "must-have") separator: "&"
    if ((findString featuredFormContent "featured=true") == undefined or (findString featuredFormContent "collection=") != undefined or (findString featuredFormContent "category=utilities") != undefined) do throw "Featured catalog fields are invalid."
    local collectionFormContent = utilsModule.join (repositoryModule.catalogFormFields "" "utilities" "popular" 1 24 "stable" collectionSlug: "must-have") separator: "&"
    if ((findString collectionFormContent "collection=must-have") == undefined or (findString collectionFormContent "featured=true") != undefined or (findString collectionFormContent "category=utilities") != undefined) do throw "Curated collection catalog fields are invalid."
    if ((findString collectionFormContent "max3dsMax=") == undefined or (findString collectionFormContent "runtimeVersion=9.8.7") == undefined or (findString collectionFormContent "channel=stable") == undefined) do throw "Collection compatibility fields are unavailable."
    local categoryFormContent = utilsModule.join (repositoryModule.catalogFormFields "scene search" "utilities" "popular" 2 24 "stable") separator: "&"
    if ((findString categoryFormContent "category=utilities") == undefined or (findString categoryFormContent "query=scene%20search") == undefined or (findString categoryFormContent "page=2") == undefined) do throw "Category catalog fields are invalid."
    local categoryCompatibilityFields = utilsModule.join (repositoryModule.commonFormFields "stable") separator: "&"
    if ((findString categoryCompatibilityFields "max3dsMax=") == undefined or (findString categoryCompatibilityFields "runtimeVersion=9.8.7") == undefined or (findString categoryCompatibilityFields "channel=stable") == undefined) do throw "Category compatibility fields are unavailable."
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
    if (not (isProperty MaxPkg.settings #toolbarDensity)) do throw "Toolbar density is unavailable."
    if (not (isProperty MaxPkg.settings #toolbarIconSize)) do throw "Toolbar icon size is unavailable."
    if (not (isProperty MaxPkg.settings #floatingHorizontalX)) do throw "Floating Horizontal X position is unavailable."
    if (not (isProperty MaxPkg.settings #floatingHorizontalY)) do throw "Floating Horizontal Y position is unavailable."
    if (not (isProperty MaxPkg.settings #floatingVerticalX)) do throw "Floating Vertical X position is unavailable."
    if (not (isProperty MaxPkg.settings #floatingVerticalY)) do throw "Floating Vertical Y position is unavailable."
    if (not (isProperty MaxPkg.settings #toolbarTheme)) do throw "Toolbar theme setting is unavailable."
    if (not (isProperty MaxPkg.settings #managerTheme)) do throw "Manager theme setting is unavailable."
    if (not (isProperty MaxPkg.settings #managerFirstOpenCompleted)) do throw "Manager first-open state is unavailable."
    if (not (isProperty MaxPkg.settings #managerFullCards)) do throw "Manager full-card setting is unavailable."
    if (not (isProperty MaxPkg.settings #lastPackageUpdateCheck)) do throw "Package update check timestamp is unavailable."
    if (not (isProperty MaxPkg.settings #packageUpdateCache)) do throw "Package update cache is unavailable."
    if ((classOf MaxPkg.settings.packageUpdateCache) != Array) do throw "Package update cache is not an array."
    local supportedToolbarPositions = #("top", "bottom", "left", "right", "floatinghorizontal", "floatingvertical")
    if ((findItem supportedToolbarPositions MaxPkg.settings.toolbarDockPosition) == 0) do throw "Toolbar dock position is invalid."
    if ((findItem #("regular", "compact") MaxPkg.settings.toolbarDensity) == 0) do throw "Toolbar density is invalid."
    if ((findItem #("small", "medium", "large") MaxPkg.settings.toolbarIconSize) == 0) do throw "Toolbar icon size is invalid."
    if ((findItem #("icon", "small", "medium", "large") MaxPkg.settings.toolbarButtonSize) == 0) do throw "Toolbar button layout is invalid."
    if (not (isProperty MaxPkg #resetToolbarPosition)) do throw "Floating Toolbar position reset is unavailable."
    if (not (isProperty MaxPkg.settings #apiEndpoint)) do throw "API endpoint setting is unavailable."
    MaxPkg.settings.toolbarOrder = #()
    if (not (MaxPkg.resetToolbarOrder())) do throw "Empty toolbar order could not be synchronized."
    if ((classOf MaxPkg.settings.toolbarOrder) != Array) do throw "Toolbar order synchronization did not preserve an array."
    local runtimeStatus = MaxPkg.getStatus()
    if (runtimeStatus.connection != "configured") do throw "Default API endpoint fallback is unavailable."
    if ((classOf (MaxPkg.getPackages())) != Array) do throw "MaxPkg.getPackages() did not return an array."
    if ((MaxPkg.getPackages()).count > 0) do (
        local cachedUpdateTestPackage = (MaxPkg.getPackages())[1]
        local previousPackageUpdateCache = #()
        for cacheEntry in MaxPkg.settings.packageUpdateCache do append previousPackageUpdateCache cacheEntry
        MaxPkg.settings.packageUpdateCache = #(cachedUpdateTestPackage.guid + "@999.0.0")
        MaxPkg.scan()
        if ((MaxPkg.getStatus()).updateCount < 1) do throw "Cached package update was not applied."
        MaxPkg.settings.packageUpdateCache = previousPackageUpdateCache
        MaxPkg.scan()
    )
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
