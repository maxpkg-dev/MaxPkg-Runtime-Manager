(
    struct MaxPkgUtilsModule (
        fn ensureSlash folderPath = (
            if folderPath == undefined or folderPath == "" do return ""
            local normalizedPath = substituteString (folderPath as string) "/" "\\"
            if (substring normalizedPath normalizedPath.count 1) == "\\" do return normalizedPath
            return normalizedPath + "\\"
        ),

        fn trim sourceContent = (
            if sourceContent == undefined do return ""
            return trimLeft (trimRight (sourceContent as string))
        ),

        fn boolValue sourceContent defaultValue:false = (
            local normalizedContent = toLower (trim sourceContent)
            if normalizedContent == "true" or normalizedContent == "1" or normalizedContent == "yes" do return true
            if normalizedContent == "false" or normalizedContent == "0" or normalizedContent == "no" do return false
            return defaultValue
        ),

        fn uniqueStrings sourceStrings = (
            local uniqueEntries = #()
            for sourceString in sourceStrings where sourceString != undefined and sourceString != "" do (
                local exists = false
                for existingString in uniqueEntries while not exists where (toLower existingString) == (toLower sourceString) do exists = true
                if not exists do append uniqueEntries sourceString
            )
            return uniqueEntries
        ),

        fn pathInside childPath parentPath = (
            local child = toLower (ensureSlash childPath)
            local parent = toLower (ensureSlash parentPath)
            if child == "" or parent == "" do return false
            return matchPattern child pattern:(parent + "*") ignoreCase:true
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

        fn fileUrl filePath = (
            if filePath == undefined or filePath == "" do return ""
            local uri = dotNetObject "System.Uri" filePath
            return uri.AbsoluteUri
        ),

        fn writeText filePath content = (
            local stream = undefined
            try (
                makeDir (getFilenamePath filePath) all:true
                stream = createFile filePath
                if stream == undefined do return false
                format "%" content to:stream
                close stream
                return true
            ) catch (
                try (
                    if stream != undefined do close stream
                ) catch (
                )
                return false
            )
        ),

        fn join sourceValues separator:"," = (
            local joinedContent = ""
            for index in 1 to sourceValues.count do (
                if index > 1 do joinedContent += separator
                joinedContent += (sourceValues[index] as string)
            )
            return joinedContent
        )
    )

    MaxPkgUtilsModule()
)
