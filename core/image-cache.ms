-- Maintains a bounded local cache for remote Manager images.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
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
                for cachedFileInfo in cachedFiles do (
                    if (cachedFileInfo.FullName != preserveFilePath and (dateTimeClass.Compare cachedFileInfo.LastWriteTimeUtc cutoffTime) < 0) do removeCachedFile cachedFileInfo.FullName
                )

                directoryInfo.Refresh()
                cachedFiles = directoryInfo.GetFiles()
                local cachedFileCount = 0
                local cachedByteCount = 0
                for cachedFileInfo in cachedFiles where doesFileExist cachedFileInfo.FullName do (
                    cachedFileCount += 1
                    cachedByteCount += cachedFileInfo.Length
                )

                while (cachedFileCount > maxCacheFiles or cachedByteCount > maxCacheBytes) do (
                    local oldestFileInfo = undefined
                    for cachedFileInfo in cachedFiles where cachedFileInfo.FullName != preserveFilePath and doesFileExist cachedFileInfo.FullName do (
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
                if (initialized) do pruneCache()
                return initialized
            ) catch (
                logger.logWarning "image-cache" ("Could not initialize the image cache: " + getCurrentException())
                initialized = false
                return false
            )
        ),

        fn localImageUrl sourceUrl fallbackUrl: "" = (
            local selectedUrl = browserImageSource sourceUrl fallbackUrl: fallbackUrl
            if (selectedUrl == "" or http == undefined or not (http.isHttpUrl selectedUrl) or not (http.shouldUseCurl())) do return selectedUrl
            if (not (initialize())) do return selectedUrl
            local imageKey = cacheKey selectedUrl
            if (imageKey == "" or keyFailed imageKey) do return selectedUrl
            local cachedFilePath = cacheRoot + imageKey + (imageExtension selectedUrl)
            if (doesFileExist cachedFilePath) do (
                try (
                    local fileClass = dotNetClass "System.IO.File"
                    fileClass.SetLastWriteTimeUtc cachedFilePath (dotNetClass "System.DateTime").UtcNow
                ) catch (
                )
                return utils.fileUrl cachedFilePath
            )

            if (not (http.download selectedUrl cachedFilePath)) do (
                markKeyFailed imageKey
                return selectedUrl
            )
            try (
                local cachedFileInfo = dotNetObject "System.IO.FileInfo" cachedFilePath
                if (cachedFileInfo.Length <= 0 or cachedFileInfo.Length > maxFileBytes) do (
                    removeCachedFile cachedFilePath
                    markKeyFailed imageKey
                    return selectedUrl
                )
            ) catch (
                removeCachedFile cachedFilePath
                markKeyFailed imageKey
                return selectedUrl
            )

            pruneCache preserveFilePath: cachedFilePath
            if (doesFileExist cachedFilePath) do return utils.fileUrl cachedFilePath
            return selectedUrl
        )
    )

    MaxPkgImageCacheModule()
)
