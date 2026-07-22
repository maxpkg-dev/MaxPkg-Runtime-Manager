(
    struct MaxPkgLoggerModule (
        logFile,

        fn initialize runtimeRoot = (
            local logFolder = runtimeRoot + "logs\\"
            makeDir logFolder all:true
            logFile = logFolder + "maxpkg.log"
            return true
        ),

        fn writeEntry level area message = (
            local line = "[" + (localTime as string) + "] [" + level + "] [" + area + "] " + (message as string)
            local fileWriteError = ""
            try (
                local stream = openFile logFile mode:"a"
                if stream != undefined do (
                    format "%\n" line to:stream
                    close stream
                )
            ) catch (
                fileWriteError = getCurrentException()
            )
            if fileWriteError != "" do format "MaxPkg [LOGGER ERROR] %\n" fileWriteError
            format "MaxPkg %\n" line
            return line
        ),

        fn logInfo area message = (
            return writeEntry "INFO" area message
        ),

        fn logWarning area message = (
            return writeEntry "WARN" area message
        ),

        fn logError area message = (
            return writeEntry "ERROR" area message
        )
    )

    MaxPkgLoggerModule()
)
