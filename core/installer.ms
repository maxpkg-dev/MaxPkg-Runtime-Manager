(
    struct MaxPkgInstallerModule (
        owner,
        operations,
        manager,
        api,
        http,
        logger,
        utils,

        fn isUrl sourceContent = (
            if sourceContent == undefined or sourceContent == "" do return false
            return ((matchPattern sourceContent pattern:"http://*" ignoreCase:true) or (matchPattern sourceContent pattern:"https://*" ignoreCase:true))
        ),

        fn expectedGuid packageSource = (
            if packageSource == undefined or packageSource == "" do return ""
            local sourcePath = packageSource as string
            if isUrl sourcePath do (
                try (
                    local sourceUri = dotNetObject "System.Uri" sourcePath
                    sourcePath = sourceUri.LocalPath
                ) catch (
                    return ""
                )
            )
            local nameParts = filterString (getFilenameFile sourcePath) "@"
            if nameParts.count < 3 do return ""
            return nameParts[nameParts.count]
        ),

        fn cleanupDownload downloadPath = (
            if downloadPath == "" or not (doesFileExist downloadPath) do return true
            try (
                deleteFile downloadPath
                return not (doesFileExist downloadPath)
            ) catch (
                logger.logWarning "installer" ("Could not remove temporary download " + downloadPath + ": " + getCurrentException())
                return false
            )
        ),

        fn installSource packageSource = (
            if packageSource == undefined or packageSource == "" do (
                logger.logError "installer" "Package source is empty."
                return false
            )
            local sourcePath = packageSource as string
            local downloadPath = ""
            if isUrl sourcePath do (
                local guidClass = dotNetClass "System.Guid"
                local guidValue = guidClass.NewGuid()
                local downloadId = guidValue.ToString()
                downloadPath = (utils.ensureSlash (getDir #temp)) + "maxpkg-download-" + downloadId + ".mzp"
                if not (http.download sourcePath downloadPath) do (
                    cleanupDownload downloadPath
                    return false
                )
                sourcePath = downloadPath
            )
            if not (doesFileExist sourcePath) do (
                logger.logError "installer" ("Package file not found: " + sourcePath)
                return false
            )
            local isInstalled = false
            try (
                fileIn sourcePath
                logger.logInfo "installer" ("Executed " + sourcePath)
                isInstalled = true
            ) catch (
                logger.logError "installer" ("Installation failed: " + getCurrentException())
                isInstalled = false
            )
            if downloadPath != "" do cleanupDownload downloadPath
            return isInstalled
        ),

        fn install packageSource = (
            if not (operations.begin "install") do return false
            local isSuccess = false
            try (
                local packageCountBefore = owner.packages.count
                local packageGuid = expectedGuid packageSource
                isSuccess = installSource packageSource
                owner.scan()
                if isSuccess do (
                    if packageGuid != "" then
                        isSuccess = api.contains owner.packages packageGuid
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
            )
            return operations.finish success:isSuccess
        )
    )

    MaxPkgInstallerModule()
)
