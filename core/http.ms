-- Handles Runtime HTTP requests and file downloads with a curl fallback.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgHttpModule (
        logger,
        utils,
        curlExecutable = undefined,
        curlFallbackActive = false,
        sessionTransportEnvironmentName = "MAXPKG_HTTP_TRANSPORT",

        fn enableTls12 = (
            try (
                local servicePointManagerClass = dotNetClass "System.Net.ServicePointManager"
                local securityProtocolClass = dotNetClass "System.Net.SecurityProtocolType"
                servicePointManagerClass.SecurityProtocol = securityProtocolClass.Tls12
                return true
            ) catch (
                return false
            )
        ),

        fn isHttpUrl sourceUrl = (
            if (sourceUrl == undefined or sourceUrl == "") do return false
            try (
                local sourceUri = dotNetObject "System.Uri" sourceUrl
                local sourceScheme = toLower sourceUri.Scheme
                return sourceUri.IsAbsoluteUri and (sourceScheme == "http" or sourceScheme == "https")
            ) catch (
                return false
            )
        ),

        fn resolveCurlExecutable = (
            if (curlExecutable != undefined) do return curlExecutable
            curlExecutable = ""
            try (
                local environmentClass = dotNetClass "System.Environment"
                local systemRoot = environmentClass.GetEnvironmentVariable "SystemRoot"
                if (systemRoot != undefined and systemRoot != "") do (
                    local systemCurlFile = systemRoot + @"\System32\curl.exe"
                    if (doesFileExist systemCurlFile) do (
                        curlExecutable = systemCurlFile
                        return curlExecutable
                    )
                )
                local executableSearchPath = environmentClass.GetEnvironmentVariable "PATH"
                if (executableSearchPath != undefined and executableSearchPath != "") do (
                    local searchDirectories = filterString executableSearchPath ";"
                    for searchDirectory in searchDirectories while curlExecutable == "" do (
                        local normalizedDirectory = substituteString (utils.trim searchDirectory) "\"" ""
                        if (normalizedDirectory != "") do (
                            local candidateFilePath = (utils.ensureSlash normalizedDirectory) + "curl.exe"
                            if (doesFileExist candidateFilePath) do curlExecutable = candidateFilePath
                        )
                    )
                )
            ) catch (
                logger.logWarning "http" ("Could not locate curl.exe: " + getCurrentException())
                curlExecutable = ""
            )
            return curlExecutable
        ),

        fn curlAvailable = (
            return (resolveCurlExecutable()) != ""
        ),

        fn sessionUsesCurl = (
            if (curlFallbackActive) do return true
            try (
                local environmentClass = dotNetClass "System.Environment"
                local sessionTransport = environmentClass.GetEnvironmentVariable sessionTransportEnvironmentName
                if (sessionTransport != undefined and (toLower sessionTransport) == "curl") do (
                    curlFallbackActive = true
                    return true
                )
            ) catch (
                return false
            )
            return false
        ),

        fn shouldUseCurl = (
            return sessionUsesCurl() and curlAvailable()
        ),

        fn activateCurlFallback = (
            if (curlFallbackActive) do return true
            if (not (curlAvailable())) do return false
            curlFallbackActive = true
            try (
                local environmentClass = dotNetClass "System.Environment"
                environmentClass.SetEnvironmentVariable sessionTransportEnvironmentName "curl"
            ) catch (
                logger.logWarning "http" ("Could not preserve CURL transport for the current session: " + getCurrentException())
            )
            logger.logInfo "http" "Switched HTTP transport to curl for the current 3ds Max session."
            return true
        ),

        fn quoteCurlArgument argumentContent = (
            if (argumentContent == undefined) do return ""
            local normalizedArgument = argumentContent as string
            if ((findString normalizedArgument "\"") != undefined or (findString normalizedArgument "\r") != undefined or (findString normalizedArgument "\n") != undefined) do return ""
            return "\"" + normalizedArgument + "\""
        ),

        fn removeFile filePath = (
            if (filePath == undefined or filePath == "" or not (doesFileExist filePath)) do return true
            if (utils != undefined) do return utils.forceDeleteFile filePath
            try (
                setFileAttribute filePath #readOnly false
                deleteFile filePath
                return not (doesFileExist filePath)
            ) catch (
                return false
            )
        ),

        fn runCurlToFile sourceUrl targetFilePath requestMethod requestBodyFilePath: "" = (
            if (not (isHttpUrl sourceUrl) or targetFilePath == undefined or targetFilePath == "") do return false
            local curlFilePath = resolveCurlExecutable()
            if (curlFilePath == "") do return false
            local quotedUrl = quoteCurlArgument sourceUrl
            local quotedTargetFilePath = quoteCurlArgument targetFilePath
            if (quotedUrl == "" or quotedTargetFilePath == "") do return false

            local curlArguments = "--silent --show-error --location --fail --connect-timeout 12 --max-time 90 --user-agent \"MaxPkg-Runtime/1.0\" --output " + quotedTargetFilePath
            curlArguments += " --request " + requestMethod
            curlArguments += " --header \"Accept: */*\" --header \"Cache-Control: no-cache, no-store, max-age=0\" --header \"Pragma: no-cache\""
            if (requestBodyFilePath != "") do (
                local quotedBodyFilePath = quoteCurlArgument ("@" + requestBodyFilePath)
                if (quotedBodyFilePath == "") do return false
                curlArguments += " --header \"Content-Type: application/x-www-form-urlencoded\" --data-binary " + quotedBodyFilePath
            )
            curlArguments += " " + quotedUrl

            local curlProcess = undefined
            try (
                removeFile targetFilePath
                makeDir (getFilenamePath targetFilePath) all: true
                local processStartInfo = dotNetObject "System.Diagnostics.ProcessStartInfo"
                processStartInfo.FileName = curlFilePath
                processStartInfo.Arguments = curlArguments
                processStartInfo.UseShellExecute = false
                processStartInfo.CreateNoWindow = true
                processStartInfo.RedirectStandardError = true
                curlProcess = dotNetObject "System.Diagnostics.Process"
                curlProcess.StartInfo = processStartInfo
                if (not (curlProcess.Start())) do throw "curl.exe could not be started."
                local standardErrorContent = curlProcess.StandardError.ReadToEnd()
                curlProcess.WaitForExit()
                local exitCode = curlProcess.ExitCode
                curlProcess.Dispose()
                curlProcess = undefined
                if (exitCode != 0) do (
                    removeFile targetFilePath
                    logger.logWarning "http" ("curl failed with exit code " + (exitCode as string) + ": " + standardErrorContent)
                    return false
                )
                if (not (doesFileExist targetFilePath)) do (
                    logger.logWarning "http" ("curl completed without a file: " + targetFilePath)
                    return false
                )
                logger.logInfo "http" ("curl fallback completed: " + requestMethod + " " + sourceUrl)
                return true
            ) catch (
                logger.logWarning "http" ("curl fallback failed: " + getCurrentException())
                try (
                    if (curlProcess != undefined) do curlProcess.Dispose()
                ) catch (
                )
                removeFile targetFilePath
                return false
            )
        ),

        fn download sourceUrl targetFilePath = (
            if (not (isHttpUrl sourceUrl) or targetFilePath == undefined or targetFilePath == "") do return false
            if (shouldUseCurl()) do return runCurlToFile sourceUrl targetFilePath "GET"
            local webClient = undefined
            try (
                enableTls12()
                makeDir (getFilenamePath targetFilePath) all: true
                webClient = dotNetObject "System.Net.WebClient"
                webClient.Headers.Add "User-Agent" "MaxPkg-Runtime/1.0"
                webClient.DownloadFile sourceUrl targetFilePath
                webClient.Dispose()
                webClient = undefined
                local isDownloaded = doesFileExist targetFilePath
                if (not isDownloaded) do logger.logError "http" ("Download completed without a file: " + targetFilePath)
                return isDownloaded
            ) catch (
                logger.logWarning "http" (".NET download failed; trying curl: " + getCurrentException())
                try (
                    if (webClient != undefined) do webClient.Dispose()
                ) catch (
                )
                removeFile targetFilePath
                if (activateCurlFallback() and runCurlToFile sourceUrl targetFilePath "GET") do return true
                logger.logError "http" ("Download failed with all available transports: " + sourceUrl)
                return false
            )
        ),

        fn requestStringWithCurl sourceUrl requestMethod requestBody = (
            local guidClass = dotNetClass "System.Guid"
            local requestId = (guidClass.NewGuid()).ToString()
            local tempRoot = utils.ensureSlash (getDir #temp)
            local responseFilePath = tempRoot + "maxpkg-http-response-" + requestId + ".tmp"
            local bodyFilePath = tempRoot + "maxpkg-http-body-" + requestId + ".tmp"
            local responseBody = undefined
            try (
                local isPrepared = requestMethod != "POST" or utils.writeText bodyFilePath requestBody
                if (isPrepared) do (
                    local requestBodySource = if (requestMethod == "POST") then bodyFilePath else ""
                    local isDownloaded = runCurlToFile sourceUrl responseFilePath requestMethod requestBodyFilePath: requestBodySource
                    if (isDownloaded) do responseBody = utils.readText responseFilePath
                )
            ) catch (
                logger.logWarning "http" ("Could not read curl response: " + getCurrentException())
                responseBody = undefined
            )
            removeFile bodyFilePath
            removeFile responseFilePath
            return responseBody
        ),

        fn getString sourceUrl = (
            if (not (isHttpUrl sourceUrl)) do return undefined
            if (shouldUseCurl()) do return requestStringWithCurl sourceUrl "GET" ""
            local webClient = undefined
            try (
                enableTls12()
                webClient = dotNetObject "System.Net.WebClient"
                local encodingClass = dotNetClass "System.Text.Encoding"
                webClient.Encoding = encodingClass.UTF8
                webClient.Headers.Add "User-Agent" "MaxPkg-Runtime/1.0"
                webClient.Headers.Add "Accept" "text/plain"
                webClient.Headers.Add "Cache-Control" "no-cache, no-store, max-age=0"
                webClient.Headers.Add "Pragma" "no-cache"
                local responseBody = webClient.DownloadString sourceUrl
                webClient.Dispose()
                return responseBody
            ) catch (
                logger.logWarning "http" (".NET request failed; trying curl: " + getCurrentException())
                try (
                    if (webClient != undefined) do webClient.Dispose()
                ) catch (
                )
                if (not (activateCurlFallback())) do return undefined
                return requestStringWithCurl sourceUrl "GET" ""
            )
        ),

        fn post sourceUrl requestBody = (
            if (not (isHttpUrl sourceUrl)) do return undefined
            if (requestBody == undefined) do requestBody = ""
            if (shouldUseCurl()) do return requestStringWithCurl sourceUrl "POST" requestBody
            local webClient = undefined
            try (
                enableTls12()
                webClient = dotNetObject "System.Net.WebClient"
                local encodingClass = dotNetClass "System.Text.Encoding"
                webClient.Encoding = encodingClass.UTF8
                webClient.Headers.Add "User-Agent" "MaxPkg-Runtime/1.0"
                webClient.Headers.Add "Content-Type" "application/x-www-form-urlencoded"
                webClient.Headers.Add "Accept" "text/plain"
                webClient.Headers.Add "Cache-Control" "no-cache, no-store, max-age=0"
                webClient.Headers.Add "Pragma" "no-cache"
                local responseBody = webClient.UploadString sourceUrl requestBody
                webClient.Dispose()
                return responseBody
            ) catch (
                logger.logWarning "http" (".NET request failed; trying curl: " + getCurrentException())
                try (
                    if (webClient != undefined) do webClient.Dispose()
                ) catch (
                )
                if (not (activateCurlFallback())) do return undefined
                return requestStringWithCurl sourceUrl "POST" requestBody
            )
        )
    )

    MaxPkgHttpModule()
)
