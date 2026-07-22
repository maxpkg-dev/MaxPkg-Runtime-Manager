(
    struct MaxPkgIniModule (
        logger,

        fn read filePath section key defaultValue:"" = (
            if not (doesFileExist filePath) do return defaultValue
            local settingContent = ""
            try (
                settingContent = getINISetting filePath section key
            ) catch (
                if logger != undefined do logger.logWarning "ini" ("Could not read [" + section + "] " + key + " from " + filePath + ": " + getCurrentException())
                return defaultValue
            )
            if settingContent == undefined or settingContent == "" do return defaultValue
            return substituteString settingContent "\\n" "\r\n"
        ),

        fn readAny filePath section keys defaultValue:"" = (
            for key in keys do (
                local settingContent = read filePath section key
                if settingContent != "" do return settingContent
            )
            return defaultValue
        ),

        fn write filePath section key settingContent = (
            try (
                makeDir (getFilenamePath filePath) all:true
                local escapedContent = substituteString (settingContent as string) "\r\n" "\\n"
                setINISetting filePath section key escapedContent
                return true
            ) catch (
                if logger != undefined do logger.logError "ini" ("Could not write [" + section + "] " + key + " to " + filePath + ": " + getCurrentException())
                return false
            )
        ),

        fn sectionKeys filePath section = (
            if not (doesFileExist filePath) do return #()
            try (
                return getINISetting filePath section
            ) catch (
                if logger != undefined do logger.logWarning "ini" ("Could not read section [" + section + "] from " + filePath + ": " + getCurrentException())
                return #()
            )
        )
    )

    MaxPkgIniModule()
)
