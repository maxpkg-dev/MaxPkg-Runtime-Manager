-- Downloads, validates, and installs MaxPkg packages.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgInstallStatusData (
        success = false,
        errorCode = "",
        errorMessage = "",
        packageGuid = ""
    )

    struct MaxPkgInstallerModule (
        owner,
        operations,
        manager,
        api,
        http,
        logger,
        utils,
        repository,

        fn isUrl sourceContent = (
            if (sourceContent == undefined or sourceContent == "") do return false
            return ((matchPattern sourceContent pattern: "http://*" ignoreCase: true) or (matchPattern sourceContent pattern: "https://*" ignoreCase: true))
        ),

        fn normalizePackageReference packageReference = (
            if (packageReference == undefined) do return ""
            local normalizedReference = utils.trim (packageReference as string)
            if (normalizedReference == "") do return ""
            local referenceParts = filterString normalizedReference " \t\r\n"
            if (referenceParts.count < 2) do return normalizedReference
            normalizedReference = toLower (utils.join referenceParts separator: "-")
            while ((findString normalizedReference "--") != undefined) do (
                normalizedReference = substituteString normalizedReference "--" "-"
            )
            return normalizedReference
        ),

        fn packageSearchSignature packageReference = (
            if (packageReference == undefined) do return ""
            local normalizedReference = toLower (utils.trim (packageReference as string))
            normalizedReference = substituteString normalizedReference "-" " "
            normalizedReference = substituteString normalizedReference "_" " "
            local referenceParts = filterString normalizedReference " \t\r\n"
            sort referenceParts
            return utils.join referenceParts separator: " "
        ),

        fn findCatalogPackage packageReference = (
            local catalogResponse = repository.catalog queryText: packageReference pageNumber: 1 pageSize: 24 channelName: owner.runtimeChannel
            if (not catalogResponse.success) do return undefined
            local referenceSignature = packageSearchSignature packageReference
            local matchingPackages = #()
            for packageInfo in catalogResponse.packages do (
                local nameSignature = packageSearchSignature packageInfo.packageName
                local slugSignature = packageSearchSignature packageInfo.slug
                if (referenceSignature != "" and (nameSignature == referenceSignature or slugSignature == referenceSignature)) do (
                    append matchingPackages packageInfo
                )
            )
            if (matchingPackages.count == 1) do return matchingPackages[1]
            if (catalogResponse.packages.count == 1) do return catalogResponse.packages[1]
            return undefined
        ),

        fn resolvePackageReference packageReference = (
            local normalizedReference = normalizePackageReference packageReference
            local resolveResponse = repository.resolvePackage normalizedReference channelName: owner.runtimeChannel
            if (resolveResponse.success and resolveResponse.packageInfo != undefined) do return resolveResponse
            local catalogPackage = findCatalogPackage packageReference
            if (catalogPackage == undefined or catalogPackage.guid == "") do return resolveResponse
            return repository.resolvePackage catalogPackage.guid channelName: owner.runtimeChannel
        ),

        fn expectedGuid packageSource = (
            if (packageSource == undefined or packageSource == "") do return ""
            local sourcePath = packageSource as string
            if (isUrl sourcePath) do (
                try (
                    local sourceUri = dotNetObject "System.Uri" sourcePath
                    sourcePath = sourceUri.LocalPath
                ) catch (
                    return ""
                )
            )
            local nameParts = filterString (getFilenameFile sourcePath) "@"
            if (nameParts.count < 3) do return ""
            return nameParts[nameParts.count]
        ),

        fn cleanupDownload downloadPath = (
            if (downloadPath == "" or not (doesFileExist downloadPath)) do return true
            local isDeleted = utils.forceDeleteFile downloadPath
            if (not isDeleted) do logger.logWarning "installer" ("Could not remove temporary download " + downloadPath)
            return isDeleted
        ),

        fn failureStatus errorCode errorMessage packageGuid: "" = (
            return MaxPkgInstallStatusData success: false errorCode: errorCode errorMessage: errorMessage packageGuid: packageGuid
        ),

        fn installSource packageSource = (
            if (packageSource == undefined or packageSource == "") do (
                logger.logError "installer" "Package source is empty."
                return false
            )
            local sourcePath = packageSource as string
            local downloadPath = ""
            if (isUrl sourcePath) do (
                local guidClass = dotNetClass "System.Guid"
                local guidValue = guidClass.NewGuid()
                local downloadId = guidValue.ToString()
                downloadPath = (utils.ensureSlash (getDir #temp)) + "maxpkg-download-" + downloadId + ".mzp"
                if (not (http.download sourcePath downloadPath)) do (
                    cleanupDownload downloadPath
                    return false
                )
                sourcePath = downloadPath
            )
            if (not (doesFileExist sourcePath)) do (
                logger.logError "installer" ("Package file not found: " + sourcePath)
                return false
            )
            local isInstalled = false
            try (
                if (not (utils.clearFolderReadOnly (getDir #userStartupScripts))) do throw "Could not remove read-only protection from the 3ds Max startup scripts."
                fileIn sourcePath
                logger.logInfo "installer" ("Executed " + sourcePath)
                isInstalled = true
            ) catch (
                logger.logError "installer" ("Installation failed: " + getCurrentException())
                isInstalled = false
            )
            if (downloadPath != "") do cleanupDownload downloadPath
            return isInstalled
        ),

        fn install packageSource = (
            local installStatus = MaxPkgInstallStatusData()
            if (packageSource == undefined or packageSource == "") do (
                return failureStatus "INVALID_REQUEST" "Package reference is empty."
            )
            local resolvedSource = packageSource as string
            local expectedPackageGuid = ""
            if (not (isUrl resolvedSource) and not (doesFileExist resolvedSource)) do (
                local resolveResponse = resolvePackageReference resolvedSource
                if (not resolveResponse.success or resolveResponse.packageInfo == undefined) do (
                    installStatus.errorCode = if (resolveResponse.errorCode != "") then resolveResponse.errorCode else "PACKAGE_NOT_FOUND"
                    installStatus.errorMessage = if (resolveResponse.errorMessage != "") then resolveResponse.errorMessage else "The requested package could not be resolved."
                    return installStatus
                )
                resolvedSource = resolveResponse.packageInfo.downloadUrl
                expectedPackageGuid = resolveResponse.packageInfo.guid
                if (resolvedSource == "") do (
                    installStatus.errorCode = "ARTIFACT_NOT_FOUND"
                    installStatus.errorMessage = "The Runtime API did not provide a package DownloadUrl."
                    installStatus.packageGuid = expectedPackageGuid
                    return installStatus
                )
            )
            if (expectedPackageGuid == "") do expectedPackageGuid = expectedGuid resolvedSource
            installStatus.packageGuid = expectedPackageGuid
            if (not (operations.begin "install" packageGuid: expectedPackageGuid)) do (
                installStatus.errorCode = "RUNTIME_BUSY"
                installStatus.errorMessage = "Another package operation is already running."
                return installStatus
            )
            local isSuccess = false
            try (
                local packageCountBefore = owner.packages.count
                isSuccess = installSource resolvedSource
                owner.scan()
                if (isSuccess) do (
                    if (expectedPackageGuid != "") then
                        isSuccess = api.contains owner.packages expectedPackageGuid
                    else
                        isSuccess = owner.packages.count >= packageCountBefore
                )
                owner.rebuildToolbar()
                try (
                    manager.refresh()
                ) catch (
                    logger.logWarning "installer" ("Manager refresh failed: " + getCurrentException())
                )
            ) catch (
                logger.logError "installer" ("Install operation failed: " + getCurrentException())
                isSuccess = false
                installStatus.errorCode = "INTERNAL_ERROR"
                installStatus.errorMessage = "Package installation failed: " + getCurrentException()
            )
            installStatus.success = operations.finish success: isSuccess
            if (not installStatus.success and installStatus.errorMessage == "") do (
                installStatus.errorCode = "INSTALL_FAILED"
                installStatus.errorMessage = "The package could not be installed or verified."
            )
            return installStatus
        )
    )

    MaxPkgInstallerModule()
)
