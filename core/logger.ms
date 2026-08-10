-- Writes Runtime diagnostic and operation logs.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgLoggerModule (
        logFile,
        sessionEnvironmentName = "MAXPKG_LOG_SESSION",
        maxLogBytes = 5242880,

        fn currentSessionId = (
            local processInfo = undefined
            try (
                local processClass = dotNetClass "System.Diagnostics.Process"
                processInfo = processClass.GetCurrentProcess()
                local processStartTime = processInfo.StartTime.ToUniversalTime()
                local sessionIdentifier = (processInfo.Id as string) + "-" + (processStartTime.Ticks as string)
                processInfo.Dispose()
                return sessionIdentifier
            ) catch (
                try (
                    if (processInfo != undefined) do processInfo.Dispose()
                ) catch (
                )
                return ""
            )
        ),

        fn clearLogFile = (
            if (logFile == undefined or logFile == "" or not (doesFileExist logFile)) do return true
            try (
                setFileAttribute logFile #readOnly false
                deleteFile logFile
                return not (doesFileExist logFile)
            ) catch (
                return false
            )
        ),

        fn clearLogForNewSession = (
            local currentSessionIdentifier = currentSessionId()
            if (currentSessionIdentifier == "") do return false
            try (
                local environmentClass = dotNetClass "System.Environment"
                local previousSessionIdentifier = environmentClass.GetEnvironmentVariable sessionEnvironmentName
                if (previousSessionIdentifier != currentSessionIdentifier) do (
                    if (not (clearLogFile())) do return false
                    environmentClass.SetEnvironmentVariable sessionEnvironmentName currentSessionIdentifier
                )
                return true
            ) catch (
                return false
            )
        ),

        fn trimOversizedLog = (
            if (logFile == undefined or logFile == "" or not (doesFileExist logFile)) do return true
            try (
                local logFileInfo = dotNetObject "System.IO.FileInfo" logFile
                if (logFileInfo.Length > maxLogBytes) do return clearLogFile()
                return true
            ) catch (
                return false
            )
        ),

        fn initialize runtimeRoot = (
            local logFolderPath = runtimeRoot + @"logs\"
            makeDir logFolderPath all: true
            logFile = logFolderPath + "maxpkg.log"
            clearLogForNewSession()
            return true
        ),

        fn writeEntry logLevel logArea messageContent = (
            local logLine = "[" + (localTime as string) + "] [" + logLevel + "] [" + logArea + "] " + (messageContent as string)
            local fileWriteError = ""
            try (
                trimOversizedLog()
                local logStream = openFile logFile mode: "a"
                if (logStream != undefined) do (
                    format "%\n" logLine to: logStream
                    close logStream
                )
            ) catch (
                fileWriteError = getCurrentException()
            )
            if (fileWriteError != "") do format "MaxPkg [LOGGER ERROR] %\n" fileWriteError
            format "MaxPkg %\n" logLine
            return logLine
        ),

        fn logInfo logArea messageContent = (
            return writeEntry "INFO" logArea messageContent
        ),

        fn logWarning logArea messageContent = (
            return writeEntry "WARN" logArea messageContent
        ),

        fn logError logArea messageContent = (
            return writeEntry "ERROR" logArea messageContent
        )
    )

    MaxPkgLoggerModule()
)
