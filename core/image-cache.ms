-- Maintains a bounded local cache for remote Manager images.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgImageDownloadData (
        imageKey = "",
        sourceUrl = "",
        cachedFilePath = "",
        partialFilePath = "",
        curlProcess = undefined,
        startedAtUtc = undefined
    )

    struct MaxPkgImageCacheModule (
        http,
        utils,
        logger,
        cacheRoot = "",
        maxCacheBytes = 104857600,
        maxFileBytes = 26214400,
        maxCacheFiles = 300,
        maxAgeDays = 14,
        failedKeys = #(),
        pendingDownloads = #(),
        activeDownloads = #(),
        maxConcurrentDownloads = 3,
        downloadTimeoutMilliseconds = 95000,
        initialized = false,

        fn imageExtension sourceUrl = (
            try (
                local sourceUri = dotNetObject "System.Uri" sourceUrl
                local extensionContent = toLower (getFilenameType sourceUri.AbsolutePath)
                local supportedExtensions = #(".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg")
                for supportedExtension in supportedExtensions where extensionContent == supportedExtension do return extensionContent
            ) catch (
            )
            return ".img"
        ),

        fn browserImageSource sourceUrl fallbackUrl: "" = (
            if (sourceUrl == undefined or sourceUrl == "") do return fallbackUrl
            local extensionContent = ""
            try (
                local sourceUri = dotNetObject "System.Uri" sourceUrl
                extensionContent = toLower (getFilenameType sourceUri.AbsolutePath)
            ) catch (
            )
            if ((extensionContent == ".webp" or extensionContent == ".avif") and fallbackUrl != "") do return fallbackUrl
            return sourceUrl
        ),

        fn cacheKey sourceUrl = (
            try (
                local encodingClass = dotNetClass "System.Text.Encoding"
                local hashClass = dotNetClass "System.Security.Cryptography.SHA256"
                local bitConverterClass = dotNetClass "System.BitConverter"
                local hashAlgorithm = hashClass.Create()
                local sourceBytes = encodingClass.UTF8.GetBytes sourceUrl
                local hashBytes = hashAlgorithm.ComputeHash sourceBytes
                local hashContent = toLower (substituteString (bitConverterClass.ToString hashBytes) "-" "")
                hashAlgorithm.Dispose()
                return hashContent
            ) catch (
                logger.logWarning "image-cache" ("Could not hash an image URL: " + getCurrentException())
                return ""
            )
        ),

        fn keyFailed imageKey = (
            for failedKey in failedKeys where failedKey == imageKey do return true
            return false
        ),

        fn markKeyFailed imageKey = (
            if (imageKey != "" and not (keyFailed imageKey)) do append failedKeys imageKey
            return false
        ),

        fn removeCachedFile filePath = (
            if (filePath == undefined or filePath == "") do return true
            return utils.forceDeleteFile filePath
        ),

        fn pruneCache preserveFilePath: "" = (
            if (cacheRoot == "" or not (doesDirectoryExist cacheRoot)) do return true
            try (
                local directoryInfo = dotNetObject "System.IO.DirectoryInfo" cacheRoot
                local dateTimeClass = dotNetClass "System.DateTime"
                local cutoffTime = dateTimeClass.UtcNow.AddDays (-maxAgeDays)
                local cachedFiles = directoryInfo.GetFiles()
                for cachedFileInfo in cachedFiles where (toLower (getFilenameType cachedFileInfo.FullName)) != ".part" do (
                    if (cachedFileInfo.FullName != preserveFilePath and (dateTimeClass.Compare cachedFileInfo.LastWriteTimeUtc cutoffTime) < 0) do removeCachedFile cachedFileInfo.FullName
                )

                directoryInfo.Refresh()
                cachedFiles = directoryInfo.GetFiles()
                local cachedFileCount = 0
                local cachedByteCount = 0
                for cachedFileInfo in cachedFiles where (toLower (getFilenameType cachedFileInfo.FullName)) != ".part" and doesFileExist cachedFileInfo.FullName do (
                    cachedFileCount += 1
                    cachedByteCount += cachedFileInfo.Length
                )

                while (cachedFileCount > maxCacheFiles or cachedByteCount > maxCacheBytes) do (
                    local oldestFileInfo = undefined
                    for cachedFileInfo in cachedFiles where (toLower (getFilenameType cachedFileInfo.FullName)) != ".part" and cachedFileInfo.FullName != preserveFilePath and doesFileExist cachedFileInfo.FullName do (
                        if (oldestFileInfo == undefined or (dateTimeClass.Compare cachedFileInfo.LastWriteTimeUtc oldestFileInfo.LastWriteTimeUtc) < 0) do oldestFileInfo = cachedFileInfo
                    )
                    if (oldestFileInfo == undefined) do exit
                    local removedFileSize = oldestFileInfo.Length
                    if (removeCachedFile oldestFileInfo.FullName) then (
                        cachedFileCount -= 1
                        cachedByteCount -= removedFileSize
                    ) else (
                        exit
                    )
                )
                return true
            ) catch (
                logger.logWarning "image-cache" ("Could not prune the image cache: " + getCurrentException())
                return false
            )
        ),

        fn initialize = (
            if (initialized) do return true
            if (cacheRoot == "") do cacheRoot = (utils.ensureSlash (getDir #temp)) + @"MaxPkg-Runtime-Manager\cache\images\"
            try (
                makeDir cacheRoot all: true
                initialized = doesDirectoryExist cacheRoot
                if (initialized) do (
                    local directoryInfo = dotNetObject "System.IO.DirectoryInfo" cacheRoot
                    local partialFiles = directoryInfo.GetFiles "*.part"
                    for partialFileInfo in partialFiles do removeCachedFile partialFileInfo.FullName
                    pruneCache()
                )
                return initialized
            ) catch (
                logger.logWarning "image-cache" ("Could not initialize the image cache: " + getCurrentException())
                initialized = false
                return false
            )
        ),

        fn downloadQueued imageKey = (
            for downloadInfo in pendingDownloads where downloadInfo.imageKey == imageKey do return true
            for downloadInfo in activeDownloads where downloadInfo.imageKey == imageKey do return true
            return false
        ),

        fn queueDownload imageKey sourceUrl cachedFilePath = (
            if (imageKey == "" or sourceUrl == "" or cachedFilePath == "") do return false
            if (downloadQueued imageKey) do return true
            local downloadInfo = MaxPkgImageDownloadData imageKey: imageKey sourceUrl: sourceUrl cachedFilePath: cachedFilePath partialFilePath: (cachedFilePath + ".part")
            append pendingDownloads downloadInfo
            return true
        ),

        fn startPendingDownloads = (
            local startedDownloadCount = 0
            local dateTimeClass = dotNetClass "System.DateTime"
            while (activeDownloads.count < maxConcurrentDownloads and pendingDownloads.count > 0) do (
                local downloadInfo = pendingDownloads[1]
                deleteItem pendingDownloads 1
                removeCachedFile downloadInfo.partialFilePath
                downloadInfo.curlProcess = http.startCurlToFile downloadInfo.sourceUrl downloadInfo.partialFilePath "GET"
                if (downloadInfo.curlProcess == undefined) then (
                    markKeyFailed downloadInfo.imageKey
                ) else (
                    downloadInfo.startedAtUtc = dateTimeClass.UtcNow
                    append activeDownloads downloadInfo
                    startedDownloadCount += 1
                )
            )
            return startedDownloadCount
        ),

        fn downloadedFileIsValid filePath = (
            if (filePath == "" or not (doesFileExist filePath)) do return false
            try (
                local cachedFileInfo = dotNetObject "System.IO.FileInfo" filePath
                return cachedFileInfo.Length > 0 and cachedFileInfo.Length <= maxFileBytes
            ) catch (
                return false
            )
        ),

        fn moveCompletedDownload downloadInfo = (
            if (not (downloadedFileIsValid downloadInfo.partialFilePath)) do return false
            try (
                removeCachedFile downloadInfo.cachedFilePath
                local fileClass = dotNetClass "System.IO.File"
                fileClass.Move downloadInfo.partialFilePath downloadInfo.cachedFilePath
                return doesFileExist downloadInfo.cachedFilePath
            ) catch (
                logger.logWarning "image-cache" ("Could not store a downloaded image: " + getCurrentException())
                removeCachedFile downloadInfo.partialFilePath
                return false
            )
        ),

        fn finishDownload downloadInfo = (
            local isDownloaded = http.finishCurlToFile downloadInfo.curlProcess downloadInfo.sourceUrl downloadInfo.partialFilePath "GET"
            downloadInfo.curlProcess = undefined
            if (isDownloaded and moveCompletedDownload downloadInfo) then (
                pruneCache preserveFilePath: downloadInfo.cachedFilePath
                return true
            ) else (
                removeCachedFile downloadInfo.partialFilePath
                markKeyFailed downloadInfo.imageKey
                return false
            )
        ),

        fn downloadTimedOut downloadInfo = (
            if (downloadInfo.startedAtUtc == undefined) do return false
            try (
                local elapsedTime = (dotNetClass "System.DateTime").UtcNow.Subtract downloadInfo.startedAtUtc
                return elapsedTime.TotalMilliseconds > downloadTimeoutMilliseconds
            ) catch (
                return false
            )
        ),

        fn pollDownloads = (
            startPendingDownloads()
            if (activeDownloads.count == 0) do return 0
            local remainingDownloads = #()
            local completedDownloadCount = 0
            for downloadInfo in activeDownloads do (
                local downloadCompleted = false
                try (
                    downloadCompleted = downloadInfo.curlProcess.HasExited
                ) catch (
                    downloadCompleted = true
                )
                if (downloadCompleted) then (
                    finishDownload downloadInfo
                    completedDownloadCount += 1
                ) else if (downloadTimedOut downloadInfo) then (
                    http.cancelCurlProcess downloadInfo.curlProcess downloadInfo.partialFilePath
                    downloadInfo.curlProcess = undefined
                    markKeyFailed downloadInfo.imageKey
                    completedDownloadCount += 1
                    logger.logWarning "image-cache" ("Image download timed out: " + downloadInfo.sourceUrl)
                ) else (
                    append remainingDownloads downloadInfo
                )
            )
            activeDownloads = remainingDownloads
            startPendingDownloads()
            return completedDownloadCount
        ),

        fn cancelDownloads = (
            pendingDownloads = #()
            for downloadInfo in activeDownloads do (
                http.cancelCurlProcess downloadInfo.curlProcess downloadInfo.partialFilePath
                downloadInfo.curlProcess = undefined
            )
            activeDownloads = #()
            return true
        ),

        fn shutdown = (
            cancelDownloads()
            return true
        ),

        fn localImageUrl sourceUrl fallbackUrl: "" = (
            local selectedUrl = browserImageSource sourceUrl fallbackUrl: fallbackUrl
            if (selectedUrl == "" or http == undefined or not (http.isHttpUrl selectedUrl) or not (http.shouldUseCurl())) do return selectedUrl
            if (not (initialize())) do return selectedUrl
            local imageKey = cacheKey selectedUrl
            if (imageKey == "" or keyFailed imageKey) do return ""
            local cachedFilePath = cacheRoot + imageKey + (imageExtension selectedUrl)
            if (doesFileExist cachedFilePath) do (
                try (
                    local fileClass = dotNetClass "System.IO.File"
                    fileClass.SetLastWriteTimeUtc cachedFilePath (dotNetClass "System.DateTime").UtcNow
                ) catch (
                )
                return utils.fileUrl cachedFilePath
            )
            queueDownload imageKey selectedUrl cachedFilePath
            startPendingDownloads()
            return ""
        )
    )

    MaxPkgImageCacheModule()
)
