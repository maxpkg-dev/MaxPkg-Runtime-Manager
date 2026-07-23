-- Provides safe INI file reading and writing helpers.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgIniModule (
        logger,

        fn read filePath iniSection key defaultValue: "" = (
            if (not (doesFileExist filePath)) do return defaultValue
            local settingContent = ""
            try (
                settingContent = getINISetting filePath iniSection key
            ) catch (
                if (logger != undefined) do logger.logWarning "ini" ("Could not read [" + iniSection + "] " + key + " from " + filePath + ": " + getCurrentException())
                return defaultValue
            )
            if (settingContent == undefined or settingContent == "") do return defaultValue
            return substituteString settingContent "\\n" "\r\n"
        ),

        fn readAny filePath iniSection keys defaultValue: "" = (
            for key in keys do (
                local settingContent = read filePath iniSection key
                if (settingContent != "") do return settingContent
            )
            return defaultValue
        ),

        fn write filePath iniSection key settingContent = (
            try (
                makeDir (getFilenamePath filePath) all: true
                local escapedContent = substituteString (settingContent as string) "\r\n" "\\n"
                setINISetting filePath iniSection key escapedContent
                return true
            ) catch (
                if (logger != undefined) do logger.logError "ini" ("Could not write [" + iniSection + "] " + key + " to " + filePath + ": " + getCurrentException())
                return false
            )
        ),

        fn sectionKeys filePath iniSection = (
            if (not (doesFileExist filePath)) do return #()
            try (
                return getINISetting filePath iniSection
            ) catch (
                if (logger != undefined) do logger.logWarning "ini" ("Could not read section [" + iniSection + "] from " + filePath + ": " + getCurrentException())
                return #()
            )
        )
    )

    MaxPkgIniModule()
)
