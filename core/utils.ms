-- Provides shared string, path, encoding, and HTML helpers.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgUtilsModule (
        defaultApiEndpoint = "https://maxpkg.dev/api/runtime/v1/",

        fn ensureSlash folderPath = (
            if (folderPath == undefined or folderPath == "") do return ""
            local normalizedPath = substituteString (folderPath as string) "/" @"\"
            if ((substring normalizedPath normalizedPath.count 1) == @"\") do return normalizedPath
            return normalizedPath + @"\"
        ),

        fn trim sourceContent = (
            if (sourceContent == undefined) do return ""
            return trimLeft (trimRight (sourceContent as string))
        ),

        fn boolValue sourceContent defaultValue: false = (
            local normalizedContent = toLower (trim sourceContent)
            if (normalizedContent == "true" or normalizedContent == "1" or normalizedContent == "yes") do return true
            if (normalizedContent == "false" or normalizedContent == "0" or normalizedContent == "no") do return false
            return defaultValue
        ),

        fn uniqueStrings sourceStrings = (
            local uniqueEntries = #()
            for sourceString in sourceStrings where sourceString != undefined and sourceString != "" do (
                local sourceExists = false
                for existingString in uniqueEntries while not sourceExists where (toLower existingString) == (toLower sourceString) do sourceExists = true
                if (not sourceExists) do append uniqueEntries sourceString
            )
            return uniqueEntries
        ),

        fn pathInside childPath parentPath = (
            local normalizedChildPath = toLower (ensureSlash childPath)
            local normalizedParentPath = toLower (ensureSlash parentPath)
            if (normalizedChildPath == "" or normalizedParentPath == "") do return false
            return matchPattern normalizedChildPath pattern: (normalizedParentPath + "*") ignoreCase: true
        ),

        fn makeFileWritable filePath = (
            if (filePath == undefined or filePath == "" or not (doesFileExist filePath)) do return true
            try (
                setFileAttribute filePath #readOnly false
                return true
            ) catch (
                return false
            )
        ),

        fn forceDeleteFile filePath = (
            if (filePath == undefined or filePath == "" or not (doesFileExist filePath)) do return true
            if (not (makeFileWritable filePath)) do return false
            try (
                deleteFile filePath
                return not (doesFileExist filePath)
            ) catch (
                return false
            )
        ),

        fn clearFolderReadOnly folderPath = (
            local normalizedFolderPath = ensureSlash folderPath
            if (normalizedFolderPath == "" or not (doesDirectoryExist normalizedFolderPath)) do return true
            local isWritable = true
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                local searchOption = dotNetClass "System.IO.SearchOption"
                local filePaths = directoryClass.GetFiles normalizedFolderPath "*" searchOption.AllDirectories
                for currentFilePath in filePaths do (
                    if (not (makeFileWritable currentFilePath)) do isWritable = false
                )
            ) catch (
                isWritable = false
            )
            return isWritable
        ),

        fn forceDeleteFolder folderPath = (
            local normalizedFolderPath = ensureSlash folderPath
            if (normalizedFolderPath == "" or not (doesDirectoryExist normalizedFolderPath)) do return true
            clearFolderReadOnly normalizedFolderPath
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                directoryClass.Delete normalizedFolderPath true
                return not (doesDirectoryExist normalizedFolderPath)
            ) catch (
                return false
            )
        ),

        fn htmlEscape sourceContent = (
            local escapedContent = trim sourceContent
            escapedContent = substituteString escapedContent "&" "&amp;"
            escapedContent = substituteString escapedContent "<" "&lt;"
            escapedContent = substituteString escapedContent ">" "&gt;"
            escapedContent = substituteString escapedContent "\"" "&quot;"
            escapedContent = substituteString escapedContent "'" "&#39;"
            return escapedContent
        ),

        fn jsonEscape sourceContent = (
            if (sourceContent == undefined) do return ""
            local escapedContent = sourceContent as string
            escapedContent = substituteString escapedContent "\\" "\\\\"
            escapedContent = substituteString escapedContent "\"" "\\\""
            escapedContent = substituteString escapedContent "\r" "\\r"
            escapedContent = substituteString escapedContent "\n" "\\n"
            escapedContent = substituteString escapedContent "\t" "\\t"
            return escapedContent
        ),

        fn jsonString sourceContent = (
            return "\"" + (jsonEscape sourceContent) + "\""
        ),

        fn formEncode sourceContent = (
            local uriClass = dotNetClass "System.Uri"
            return uriClass.EscapeDataString (trim sourceContent)
        ),

        fn formField fieldName fieldContent = (
            return (formEncode fieldName) + "=" + (formEncode fieldContent)
        ),

        fn current3dsMaxYear = (
            local versionInfo = maxVersion()
            if (versionInfo.count >= 8) do return versionInfo[8]
            return 1998 + ((versionInfo[1] / 1000) as integer)
        ),

        fn normalizeApiEndpoint endpointContent = (
            local normalizedEndpoint = trim endpointContent
            if (normalizedEndpoint == "") do return ""
            normalizedEndpoint = substituteString normalizedEndpoint @"\" "/"
            local queryIndex = findString normalizedEndpoint "?"
            if (queryIndex != undefined) do (
                normalizedEndpoint = if (queryIndex > 1) then substring normalizedEndpoint 1 (queryIndex - 1) else ""
            )
            local fragmentIndex = findString normalizedEndpoint "#"
            if (fragmentIndex != undefined) do (
                normalizedEndpoint = if (fragmentIndex > 1) then substring normalizedEndpoint 1 (fragmentIndex - 1) else ""
            )
            while (normalizedEndpoint.count > 0 and (substring normalizedEndpoint normalizedEndpoint.count 1) == "/") do (
                normalizedEndpoint = substring normalizedEndpoint 1 (normalizedEndpoint.count - 1)
            )
            if (normalizedEndpoint == "") do return ""
            return normalizedEndpoint + "/"
        ),

        fn resolveApiEndpoint endpointContent = (
            local normalizedEndpoint = normalizeApiEndpoint endpointContent
            if (normalizedEndpoint == "") do return defaultApiEndpoint
            return normalizedEndpoint
        ),

        fn apiEndpointUrl baseEndpoint actionName = (
            local normalizedEndpoint = resolveApiEndpoint baseEndpoint
            local normalizedActionName = trim actionName
            while (normalizedActionName.count > 0 and (substring normalizedActionName 1 1) == "/") do (
                normalizedActionName = substring normalizedActionName 2 (normalizedActionName.count - 1)
            )
            return normalizedEndpoint + normalizedActionName
        ),

        fn fileUrl filePath = (
            if (filePath == undefined or filePath == "") do return ""
            local uri = dotNetObject "System.Uri" filePath
            return uri.AbsoluteUri
        ),

        fn writeText filePath sourceContent = (
            local stream = undefined
            try (
                makeDir (getFilenamePath filePath) all: true
                if (not (makeFileWritable filePath)) do return false
                stream = createFile filePath
                if (stream == undefined) do return false
                format "%" sourceContent to: stream
                close stream
                return true
            ) catch (
                try (
                    if (stream != undefined) do close stream
                ) catch (
                )
                return false
            )
        ),

        fn readText filePath = (
            if (filePath == undefined or filePath == "" or not (doesFileExist filePath)) do return ""
            try (
                local fileClass = dotNetClass "System.IO.File"
                return fileClass.ReadAllText filePath
            ) catch (
                return ""
            )
        ),

        fn join sourceValues separator: "," = (
            local joinedContent = ""
            for sourceIndex in 1 to sourceValues.count do (
                if (sourceIndex > 1) do joinedContent += separator
                joinedContent += (sourceValues[sourceIndex] as string)
            )
            return joinedContent
        )
    )

    MaxPkgUtilsModule()
)
