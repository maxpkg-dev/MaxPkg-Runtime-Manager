-- Handles Runtime HTTP requests and file downloads.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgHttpModule (
        logger,

        fn download url targetPath = (
            if (url == undefined or url == "" or targetPath == undefined or targetPath == "") do return false
            local client = undefined
            try (
                makeDir (getFilenamePath targetPath) all: true
                client = dotNetObject "System.Net.WebClient"
                client.Headers.Add "User-Agent" "MaxPkg-Runtime/1.0"
                client.DownloadFile url targetPath
                client.Dispose()
                client = undefined
                local isDownloaded = doesFileExist targetPath
                if (not isDownloaded) do logger.logError "http" ("Download completed without a file: " + targetPath)
                return isDownloaded
            ) catch (
                logger.logError "http" ("Download failed: " + getCurrentException())
                try (
                    if (client != undefined) do client.Dispose()
                ) catch (
                )
                try (
                    if (doesFileExist targetPath) do deleteFile targetPath
                ) catch (
                )
                return false
            )
        ),

        fn post url body = (
            if (url == undefined or url == "") do return undefined
            if (body == undefined) do body = ""
            local client = undefined
            try (
                client = dotNetObject "System.Net.WebClient"
                local encodingClass = dotNetClass "System.Text.Encoding"
                client.Encoding = encodingClass.UTF8
                client.Headers.Add "User-Agent" "MaxPkg-Runtime/1.0"
                client.Headers.Add "Content-Type" "application/x-www-form-urlencoded"
                client.Headers.Add "Accept" "text/plain"
                local responseBody = client.UploadString url body
                client.Dispose()
                return responseBody
            ) catch (
                logger.logError "http" ("Request failed: " + getCurrentException())
                try (
                    if (client != undefined) do client.Dispose()
                ) catch (
                )
                return undefined
            )
        )
    )

    MaxPkgHttpModule()
)
