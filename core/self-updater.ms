-- Updates MaxPkg Runtime and restarts the updated code.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg

    struct MaxPkgSelfUpdateResultData (
        checked = false,
        updateAvailable = false,
        installed = false,
        latestVersion = "",
        errorMessage = ""
    )

    struct MaxPkgSelfUpdaterModule (
        owner,
        operations,
        installer,
        runtimeRoot,
        logger,
        utils,
        http,
        latestVersionUrl = "https://raw.githubusercontent.com/maxpkg-dev/MaxPkg-Runtime-Manager/main/version.ini",
        runtimeArchiveUrl = "https://github.com/maxpkg-dev/MaxPkg-Runtime-Manager/archive/refs/heads/main.zip",
        autoUpdateWorker = undefined,
        autoUpdateResult = undefined,

        fn downloadString sourceUrl = (
            try (
                if (http == undefined) do return ""
                local sourceContent = http.getString sourceUrl
                if (sourceContent == undefined) do return ""
                return sourceContent
            ) catch (
                logger.logWarning "self-updater" ("Could not download " + sourceUrl + ": " + getCurrentException())
                return ""
            )
        ),

        fn downloadFile sourceUrl targetFilePath = (
            try (
                if (http == undefined) do return false
                return http.download sourceUrl targetFilePath
            ) catch (
                logger.logError "self-updater" ("Could not download " + sourceUrl + ": " + getCurrentException())
                return false
            )
        ),

        fn runtimeInfoFromContent sourceContent = (
            local runtimeVersion = ""
            local runtimeChannel = "stable"
            local isRuntimeBlock = false
            local normalizedContent = substituteString (substituteString (sourceContent as string) "\r\n" "\n") "\r" "\n"
            local contentLines = filterString normalizedContent "\n"
            for lineContent in contentLines do (
                local trimmedLine = utils.trim lineContent
                if (trimmedLine != "") do (
                    if ((substring trimmedLine 1 1) == "[") then (
                        isRuntimeBlock = (toLower trimmedLine) == "[runtime]"
                    ) else if (isRuntimeBlock) do (
                        local equalsIndex = findString trimmedLine "="
                        if (equalsIndex != undefined and equalsIndex > 1) do (
                            local keyContent = toLower (utils.trim (substring trimmedLine 1 (equalsIndex - 1)))
                            local settingContent = if (equalsIndex < trimmedLine.count) then utils.trim (substring trimmedLine (equalsIndex + 1) (trimmedLine.count - equalsIndex)) else ""
                            if (keyContent == "version") do runtimeVersion = settingContent
                            if (keyContent == "channel") do runtimeChannel = settingContent
                        )
                    )
                )
            )
            return #(runtimeVersion, runtimeChannel)
        ),

        fn latestRuntimeInfo = (
            local sourceContent = downloadString latestVersionUrl
            if (sourceContent == "") do return #("", "")
            return runtimeInfoFromContent sourceContent
        ),

        fn versionNumberAt versionContent partIndex = (
            local versionParts = filterString (versionContent as string) "."
            if (versionParts.count < partIndex) do return 0
            try (
                return versionParts[partIndex] as integer
            ) catch (
                return 0
            )
        ),

        fn compareVersions leftVersion rightVersion = (
            for partIndex in 1 to 4 do (
                local leftNumber = versionNumberAt leftVersion partIndex
                local rightNumber = versionNumberAt rightVersion partIndex
                if (leftNumber > rightNumber) do return 1
                if (leftNumber < rightNumber) do return -1
            )
            return 0
        ),

        fn shouldCopyRelativeFile relativeFilePath = (
            local normalizedRelativeFilePath = toLower (substituteString (relativeFilePath as string) "/" @"\")
            if (normalizedRelativeFilePath == "settings.ini") do return false
            if (matchPattern normalizedRelativeFilePath pattern: @"data\*" ignoreCase: true) do return false
            if (matchPattern normalizedRelativeFilePath pattern: @"logs\*" ignoreCase: true) do return false
            if (matchPattern normalizedRelativeFilePath pattern: @".git\*" ignoreCase: true) do return false
            return true
        ),

        fn replaceRuntimeFile sourceFilePath targetFilePath = (
            if (not (doesFileExist sourceFilePath)) do throw ("Runtime update source file does not exist: " + sourceFilePath)
            local targetFolderPath = getFilenamePath targetFilePath
            if (not (makeDir targetFolderPath all: true)) do throw ("Could not create Runtime update folder: " + targetFolderPath)
            if (not (utils.makeFileWritable targetFilePath)) do throw ("Could not make Runtime file writable: " + targetFilePath)
            local fileClass = dotNetClass "System.IO.File"
            fileClass.Copy sourceFilePath targetFilePath true
            if (not (doesFileExist targetFilePath)) do throw ("Could not replace Runtime file: " + targetFilePath)
            return true
        ),

        fn copyRuntimeTree sourceRoot targetRoot = (
            local normalizedSourceRoot = utils.ensureSlash sourceRoot
            local normalizedTargetRoot = utils.ensureSlash targetRoot
            if (normalizedSourceRoot == "" or normalizedTargetRoot == "" or not (doesDirectoryExist normalizedSourceRoot)) do return false
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                local searchOptionClass = dotNetClass "System.IO.SearchOption"
                local sourceFiles = directoryClass.GetFiles normalizedSourceRoot "*" searchOptionClass.AllDirectories
                for sourceFilePath in sourceFiles do (
                    local relativeFilePath = substring sourceFilePath (normalizedSourceRoot.count + 1) (sourceFilePath.count - normalizedSourceRoot.count)
                    if (shouldCopyRelativeFile relativeFilePath) do (
                        local targetFilePath = normalizedTargetRoot + relativeFilePath
                        replaceRuntimeFile sourceFilePath targetFilePath
                    )
                )
                return true
            ) catch (
                logger.logError "self-updater" ("Could not copy Runtime files: " + getCurrentException())
                return false
            )
        ),

        fn extractArchive archiveFilePath extractRoot = (
            try (
                dotNet.loadAssembly "System.IO.Compression.FileSystem"
                local zipFileClass = dotNetClass "System.IO.Compression.ZipFile"
                zipFileClass.ExtractToDirectory archiveFilePath extractRoot
                return true
            ) catch (
                logger.logError "self-updater" ("Could not extract Runtime archive: " + getCurrentException())
                return false
            )
        ),

        fn findRuntimeRoot extractRoot = (
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                local searchOptionClass = dotNetClass "System.IO.SearchOption"
                local startupFiles = directoryClass.GetFiles extractRoot "startup.ms" searchOptionClass.AllDirectories
                for startupFilePath in startupFiles do (
                    local candidateRoot = utils.ensureSlash (getFilenamePath startupFilePath)
                    if (doesFileExist (candidateRoot + @"core\runtime.ms") and doesFileExist (candidateRoot + "version.ini")) do return candidateRoot
                )
            ) catch (
                logger.logError "self-updater" ("Could not locate Runtime in archive: " + getCurrentException())
            )
            return ""
        ),

        fn cleanupFolder folderPath = (
            try (
                return utils.forceDeleteFolder folderPath
            ) catch (
                return false
            )
        ),

        fn reloadRuntime = (
            local startupFile = runtimeRoot + "startup.ms"
            if (not (doesFileExist startupFile)) do return false
            try (
                local isReloaded = fileIn startupFile
                return isReloaded == true and MaxPkg != undefined
            ) catch (
                logger.logError "self-updater" ("Reload failed: " + getCurrentException())
                return false
            )
        ),

        fn installLatestRuntime = (
            local guidClass = dotNetClass "System.Guid"
            local updateGuid = guidClass.NewGuid()
            local updateId = updateGuid.ToString()
            local tempRoot = (utils.ensureSlash (getDir #temp)) + "maxpkg-runtime-self-update-" + updateId + @"\"
            local archiveFilePath = tempRoot + "runtime-main.zip"
            local extractRoot = tempRoot + @"extract\"
            local isSuccess = false
            try (
                makeDir tempRoot all: true
                if (not (downloadFile runtimeArchiveUrl archiveFilePath)) do throw "Runtime archive download failed."
                if (not (extractArchive archiveFilePath extractRoot)) do throw "Runtime archive extraction failed."
                local extractedRuntimeRoot = findRuntimeRoot extractRoot
                if (extractedRuntimeRoot == "") do throw "The Runtime archive does not contain startup.ms and core\\runtime.ms."
                isSuccess = copyRuntimeTree extractedRuntimeRoot runtimeRoot
            ) catch (
                logger.logError "self-updater" ("Runtime self-update failed: " + getCurrentException())
                isSuccess = false
            )
            cleanupFolder tempRoot
            return isSuccess
        ),

        fn update = (
            if (not (operations.begin "selfUpdate")) do return false
            local isSuccess = false
            try (
                isSuccess = installLatestRuntime()
            ) catch (
                logger.logError "self-updater" ("Self-update operation failed: " + getCurrentException())
                isSuccess = false
            )
            operations.finish success: isSuccess
            if (isSuccess) do isSuccess = reloadRuntime()
            return isSuccess
        ),

        fn operationIsSelfUpdate = (
            if (operations == undefined or operations.current == undefined) do return false
            return operations.current.kind == "selfUpdate"
        ),

        fn completeSelfUpdateOperation isSuccess = (
            if (operationIsSelfUpdate()) do return operations.finish success: isSuccess
            return isSuccess
        ),

        fn autoUpdateDoWork sender eventArgs = (
            local resultInfo = MaxPkgSelfUpdateResultData()
            local currentVersion = ""
            local currentChannel = "stable"
            try (
                local argumentContent = eventArgs.Argument as string
                local argumentParts = filterString argumentContent "|"
                if (argumentParts.count >= 1) do currentVersion = argumentParts[1]
                if (argumentParts.count >= 2) do currentChannel = argumentParts[2]

                local latestInfo = latestRuntimeInfo()
                resultInfo.checked = true
                resultInfo.latestVersion = latestInfo[1]
                local latestChannel = latestInfo[2]

                if (resultInfo.latestVersion == "") then (
                    resultInfo.errorMessage = "Could not read latest Runtime version."
                ) else if ((toLower latestChannel) != (toLower currentChannel)) then (
                    logger.logInfo "self-updater" ("Latest Runtime channel " + latestChannel + " does not match current channel " + currentChannel)
                ) else if ((compareVersions resultInfo.latestVersion currentVersion) <= 0) then (
                    logger.logInfo "self-updater" ("Runtime is current: " + currentVersion)
                ) else (
                    resultInfo.updateAvailable = true
                    logger.logInfo "self-updater" ("Updating Runtime " + currentVersion + " to " + resultInfo.latestVersion)
                    local canStartUpdateOperation = false
                    if (operations != undefined) do canStartUpdateOperation = operations.begin "selfUpdate"
                    if (canStartUpdateOperation) then (
                        resultInfo.installed = installLatestRuntime()
                        if (not resultInfo.installed) do resultInfo.errorMessage = "Runtime update installation failed."
                    ) else (
                        resultInfo.errorMessage = "Runtime update skipped because another operation is active."
                    )
                )
            ) catch (
                resultInfo.errorMessage = getCurrentException()
                logger.logError "self-updater" ("Background self-update failed: " + resultInfo.errorMessage)
            )

            autoUpdateResult = resultInfo
            eventArgs.Result = resultInfo.installed
            return true
        ),

        fn autoUpdateCompleted sender eventArgs = (
            local isOperationSuccess = false
            local shouldReload = false
            try (
                if (eventArgs.Cancelled == true) then (
                    logger.logInfo "self-updater" "Background self-update was cancelled."
                ) else if (eventArgs.Error != undefined) then (
                    logger.logError "self-updater" ("Background self-update worker failed: " + (eventArgs.Error.ToString()))
                ) else if (autoUpdateResult == undefined) then (
                    logger.logWarning "self-updater" "Background self-update finished without a result."
                ) else if (autoUpdateResult.installed) then (
                    isOperationSuccess = true
                    shouldReload = true
                    logger.logInfo "self-updater" ("Runtime updated to " + autoUpdateResult.latestVersion + ". Reloading Runtime.")
                ) else if (autoUpdateResult.errorMessage != "") then (
                    logger.logWarning "self-updater" autoUpdateResult.errorMessage
                ) else (
                    isOperationSuccess = true
                )
            ) catch (
                logger.logError "self-updater" ("Background self-update completion failed: " + getCurrentException())
            )

            completeSelfUpdateOperation isOperationSuccess
            autoUpdateWorker = undefined

            if (shouldReload) do (
                reloadRuntime()
            )

            return isOperationSuccess
        ),

        fn startAutoUpdateCheck currentVersion: "" currentChannel: "stable" = (
            if (autoUpdateWorker != undefined) do return false

            try (
                autoUpdateResult = undefined
                autoUpdateWorker = dotNetObject "CSharpUtilities.SynchronizingBackgroundWorker"
                autoUpdateWorker.WorkerSupportsCancellation = true
                dotNet.addEventHandler autoUpdateWorker "DoWork" autoUpdateDoWork
                dotNet.addEventHandler autoUpdateWorker "RunWorkerCompleted" autoUpdateCompleted
                autoUpdateWorker.RunWorkerAsync ((currentVersion as string) + "|" + (currentChannel as string))
                return true
            ) catch (
                logger.logWarning "self-updater" ("Could not start background self-update check: " + getCurrentException())
                autoUpdateWorker = undefined
                return false
            )
        ),

        fn updateIfAvailable currentVersion: "" currentChannel: "stable" = (
            local latestInfo = latestRuntimeInfo()
            local latestVersion = latestInfo[1]
            local latestChannel = latestInfo[2]
            if (latestVersion == "") do return false
            if ((toLower latestChannel) != (toLower currentChannel)) do (
                logger.logInfo "self-updater" ("Latest Runtime channel " + latestChannel + " does not match current channel " + currentChannel)
                return false
            )
            if ((compareVersions latestVersion currentVersion) <= 0) do (
                logger.logInfo "self-updater" ("Runtime is current: " + currentVersion)
                return false
            )
            logger.logInfo "self-updater" ("Updating Runtime " + currentVersion + " to " + latestVersion)
            return update()
        )
    )

    MaxPkgSelfUpdaterModule()
)
