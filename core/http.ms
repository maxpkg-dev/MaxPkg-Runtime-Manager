-- Handles Runtime HTTP requests and file downloads with a curl fallback.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgHttpAttemptData (
        isSuccess = false,
        responseBody = undefined,
        errorMessage = "",
        statusCode = 0
    )

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

        fn httpStatusCodeFromException exceptionMessage = (
            if (exceptionMessage == undefined or exceptionMessage == "") do return 0
            for statusCode in 400 to 599 do (
                if ((findString exceptionMessage ("(" + (statusCode as string) + ")")) != undefined) do return statusCode
            )
            return 0
        ),

        fn logHttpResponseFailure requestMethod sourceUrl statusCode = (
            local failureKind = if (statusCode >= 500) then "server error" else "request error"
            logger.logWarning "http" (requestMethod + " " + sourceUrl + " returned HTTP " + (statusCode as string) + " (" + failureKind + "); CURL fallback was not activated.")
            return true
        ),

        fn activateCurlFallback sourceUrl: "" = (
            if (curlFallbackActive) do return true
            if (not (curlAvailable())) do return false
            curlFallbackActive = true
            try (
                local environmentClass = dotNetClass "System.Environment"
                environmentClass.SetEnvironmentVariable sessionTransportEnvironmentName "curl"
            ) catch (
                logger.logWarning "http" ("Could not preserve CURL transport for the current session: " + getCurrentException())
            )
            local switchMessage = "Switched HTTP transport to curl for the current 3ds Max session."
            if (sourceUrl != "") do switchMessage += " Trigger: " + sourceUrl
            logger.logInfo "http" switchMessage
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

        fn curlArguments sourceUrl targetFilePath requestMethod requestBodyFilePath: "" = (
            if (not (isHttpUrl sourceUrl) or targetFilePath == undefined or targetFilePath == "") do return false
            local quotedUrl = quoteCurlArgument sourceUrl
            local quotedTargetFilePath = quoteCurlArgument targetFilePath
            if (quotedUrl == "" or quotedTargetFilePath == "") do return ""

            local argumentContent = "--silent --show-error --location --fail --connect-timeout 12 --max-time 90 --user-agent \"MaxPkg-Runtime/1.0\" --output " + quotedTargetFilePath
            argumentContent += " --request " + requestMethod
            argumentContent += " --header \"Accept: */*\" --header \"Cache-Control: no-cache, no-store, max-age=0\" --header \"Pragma: no-cache\""
            if (requestBodyFilePath != "") do (
                local quotedBodyFilePath = quoteCurlArgument ("@" + requestBodyFilePath)
                if (quotedBodyFilePath == "") do return ""
                argumentContent += " --header \"Content-Type: application/x-www-form-urlencoded\" --data-binary " + quotedBodyFilePath
            )
            argumentContent += " " + quotedUrl
            return argumentContent
        ),

        fn startCurlToFile sourceUrl targetFilePath requestMethod requestBodyFilePath: "" = (
            if (not (isHttpUrl sourceUrl) or targetFilePath == undefined or targetFilePath == "") do return undefined
            local curlFilePath = resolveCurlExecutable()
            if (curlFilePath == "") do return undefined
            local argumentContent = curlArguments sourceUrl targetFilePath requestMethod requestBodyFilePath: requestBodyFilePath
            if (argumentContent == "") do return undefined

            local curlProcess = undefined
            try (
                removeFile targetFilePath
                makeDir (getFilenamePath targetFilePath) all: true
                local processStartInfo = dotNetObject "System.Diagnostics.ProcessStartInfo"
                local processWindowStyle = dotNetClass "System.Diagnostics.ProcessWindowStyle"
                processStartInfo.FileName = curlFilePath
                processStartInfo.Arguments = argumentContent
                processStartInfo.UseShellExecute = false
                processStartInfo.CreateNoWindow = true
                processStartInfo.WindowStyle = processWindowStyle.Hidden
                processStartInfo.RedirectStandardError = true
                curlProcess = dotNetObject "System.Diagnostics.Process"
                curlProcess.StartInfo = processStartInfo
                if (not (curlProcess.Start())) do throw "curl.exe could not be started."
                return curlProcess
            ) catch (
                logger.logWarning "http" ("Could not start curl: " + getCurrentException())
                try (
                    if (curlProcess != undefined) do curlProcess.Dispose()
                ) catch (
                )
                removeFile targetFilePath
                return undefined
            )
        ),

        fn finishCurlToFile curlProcess sourceUrl targetFilePath requestMethod = (
            if (curlProcess == undefined) do return false
            try (
                if (not curlProcess.HasExited) do return false
                local standardErrorContent = curlProcess.StandardError.ReadToEnd()
                local exitCode = curlProcess.ExitCode
                curlProcess.Dispose()
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
                logger.logWarning "http" ("Could not finish curl request: " + getCurrentException())
                try (curlProcess.Dispose()) catch ()
                removeFile targetFilePath
                return false
            )
        ),

        fn cancelCurlProcess curlProcess targetFilePath = (
            try (
                if (curlProcess != undefined) do (
                    if (not curlProcess.HasExited) do curlProcess.Kill()
                    curlProcess.Dispose()
                )
            ) catch (
            )
            removeFile targetFilePath
            return true
        ),

        fn runCurlToFile sourceUrl targetFilePath requestMethod requestBodyFilePath: "" = (
            local curlProcess = startCurlToFile sourceUrl targetFilePath requestMethod requestBodyFilePath: requestBodyFilePath
            if (curlProcess == undefined) do return false
            try (
                local didCurlExit = curlProcess.WaitForExit 95000
                if (not didCurlExit) do (
                    cancelCurlProcess curlProcess targetFilePath
                    logger.logWarning "http" ("curl timed out: " + requestMethod + " " + sourceUrl)
                    return false
                )
                return finishCurlToFile curlProcess sourceUrl targetFilePath requestMethod
            ) catch (
                logger.logWarning "http" ("curl fallback failed: " + getCurrentException())
                cancelCurlProcess curlProcess targetFilePath
                return false
            )
        ),

        fn dotNetDownloadAttempt sourceUrl targetFilePath = (
            local attemptInfo = MaxPkgHttpAttemptData()
            local webClient = undefined
            try (
                enableTls12()
                makeDir (getFilenamePath targetFilePath) all: true
                webClient = dotNetObject "System.Net.WebClient"
                webClient.Headers.Add "User-Agent" "MaxPkg-Runtime/1.0"
                webClient.DownloadFile sourceUrl targetFilePath
                webClient.Dispose()
                webClient = undefined
                attemptInfo.isSuccess = doesFileExist targetFilePath
                if (not attemptInfo.isSuccess) do attemptInfo.errorMessage = "Download completed without a file."
            ) catch (
                attemptInfo.errorMessage = getCurrentException()
                attemptInfo.statusCode = httpStatusCodeFromException attemptInfo.errorMessage
                try (
                    if (webClient != undefined) do webClient.Dispose()
                ) catch (
                )
            )
            return attemptInfo
        ),

        fn dotNetStringAttempt sourceUrl requestMethod requestBody = (
            local attemptInfo = MaxPkgHttpAttemptData()
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
                if (requestMethod == "POST") then (
                    webClient.Headers.Add "Content-Type" "application/x-www-form-urlencoded"
                    attemptInfo.responseBody = webClient.UploadString sourceUrl requestBody
                ) else (
                    attemptInfo.responseBody = webClient.DownloadString sourceUrl
                )
                webClient.Dispose()
                webClient = undefined
                attemptInfo.isSuccess = true
            ) catch (
                attemptInfo.errorMessage = getCurrentException()
                attemptInfo.statusCode = httpStatusCodeFromException attemptInfo.errorMessage
                try (
                    if (webClient != undefined) do webClient.Dispose()
                ) catch (
                )
            )
            return attemptInfo
        ),

        fn download sourceUrl targetFilePath = (
            if (not (isHttpUrl sourceUrl) or targetFilePath == undefined or targetFilePath == "") do return false
            if (shouldUseCurl()) do return runCurlToFile sourceUrl targetFilePath "GET"
            local firstAttempt = dotNetDownloadAttempt sourceUrl targetFilePath
            if (firstAttempt.isSuccess) do return true
            removeFile targetFilePath
            if (firstAttempt.statusCode > 0) do (
                logHttpResponseFailure "GET" sourceUrl firstAttempt.statusCode
                return false
            )
            logger.logWarning "http" (".NET download transport attempt 1 failed; retrying: " + firstAttempt.errorMessage)
            local retryAttempt = dotNetDownloadAttempt sourceUrl targetFilePath
            if (retryAttempt.isSuccess) do (
                logger.logInfo "http" (".NET download recovered on retry: " + sourceUrl)
                return true
            )
            removeFile targetFilePath
            if (retryAttempt.statusCode > 0) do (
                logHttpResponseFailure "GET" sourceUrl retryAttempt.statusCode
                return false
            )
            logger.logWarning "http" (".NET download transport attempt 2 failed; trying curl: " + retryAttempt.errorMessage)
            if ((activateCurlFallback sourceUrl: sourceUrl) and (runCurlToFile sourceUrl targetFilePath "GET")) do return true
            logger.logError "http" ("Download failed with all available transports: " + sourceUrl)
            return false
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
            local firstAttempt = dotNetStringAttempt sourceUrl "GET" ""
            if (firstAttempt.isSuccess) do return firstAttempt.responseBody
            if (firstAttempt.statusCode > 0) do (
                logHttpResponseFailure "GET" sourceUrl firstAttempt.statusCode
                return undefined
            )
            logger.logWarning "http" (".NET GET transport attempt 1 failed; retrying: " + firstAttempt.errorMessage)
            local retryAttempt = dotNetStringAttempt sourceUrl "GET" ""
            if (retryAttempt.isSuccess) do (
                logger.logInfo "http" (".NET GET recovered on retry: " + sourceUrl)
                return retryAttempt.responseBody
            )
            if (retryAttempt.statusCode > 0) do (
                logHttpResponseFailure "GET" sourceUrl retryAttempt.statusCode
                return undefined
            )
            logger.logWarning "http" (".NET GET transport attempt 2 failed; trying curl: " + retryAttempt.errorMessage)
            if (not (activateCurlFallback sourceUrl: sourceUrl)) do return undefined
            return requestStringWithCurl sourceUrl "GET" ""
        ),
        fn post sourceUrl requestBody = (
            if (not (isHttpUrl sourceUrl)) do return undefined
            if (requestBody == undefined) do requestBody = ""
            if (shouldUseCurl()) do return requestStringWithCurl sourceUrl "POST" requestBody
            local firstAttempt = dotNetStringAttempt sourceUrl "POST" requestBody
            if (firstAttempt.isSuccess) do return firstAttempt.responseBody
            if (firstAttempt.statusCode > 0) do (
                logHttpResponseFailure "POST" sourceUrl firstAttempt.statusCode
                return undefined
            )
            logger.logWarning "http" (".NET POST transport attempt 1 failed; retrying: " + firstAttempt.errorMessage)
            local retryAttempt = dotNetStringAttempt sourceUrl "POST" requestBody
            if (retryAttempt.isSuccess) do (
                logger.logInfo "http" (".NET POST recovered on retry: " + sourceUrl)
                return retryAttempt.responseBody
            )
            if (retryAttempt.statusCode > 0) do (
                logHttpResponseFailure "POST" sourceUrl retryAttempt.statusCode
                return undefined
            )
            logger.logWarning "http" (".NET POST transport attempt 2 failed; trying curl: " + retryAttempt.errorMessage)
            if (not (activateCurlFallback sourceUrl: sourceUrl)) do return undefined
            return requestStringWithCurl sourceUrl "POST" requestBody
        )
    )

    MaxPkgHttpModule()
)
