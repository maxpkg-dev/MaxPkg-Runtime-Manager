-- Installs MaxPkg Runtime, its startup loader, and Manager MacroScript action.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg

    fn ensureSlash folderPath = (
        if (folderPath == undefined or folderPath == "") do return ""
        local normalizedPath = substituteString folderPath "/" @"\"
        if ((substring normalizedPath normalizedPath.count 1) == @"\") do return normalizedPath
        return normalizedPath + @"\"
    )

    fn makeFileWritable filePath = (
        if (filePath == undefined or filePath == "" or not (doesFileExist filePath)) do return true
        try (
            setFileAttribute filePath #readOnly false
            return true
        ) catch (
            return false
        )
    )

    fn forceDeleteFile filePath = (
        if (filePath == undefined or filePath == "" or not (doesFileExist filePath)) do return true
        if (not (makeFileWritable filePath)) do return false
        try (
            deleteFile filePath
            return not (doesFileExist filePath)
        ) catch (
            return false
        )
    )

    fn copyTree sourceRoot targetRoot = (
        if (sourceRoot == "" or targetRoot == "") do return false
        if (not (doesDirectoryExist sourceRoot)) do return false
        try (
            local directoryClass = dotNetClass "System.IO.Directory"
            local searchOption = dotNetClass "System.IO.SearchOption"
            makeDir targetRoot all: true
            local files = directoryClass.GetFiles sourceRoot "*" searchOption.AllDirectories
            for sourceFile in files do (
                local relativePath = substring sourceFile (sourceRoot.count + 1) (sourceFile.count - sourceRoot.count)
                local targetFile = targetRoot + relativePath
                makeDir (getFilenamePath targetFile) all: true
                makeFileWritable targetFile
                if (not (copyFile sourceFile targetFile)) do return false
            )
            return true
        ) catch (
            return false
        )
    )

    fn writeStartupShim shimPath runtimeStartupPath = (
        local stream = undefined
        try (
            makeDir (getFilenamePath shimPath) all: true
            if (not (forceDeleteFile shimPath)) do return false
            stream = createFile shimPath
            if (stream == undefined) do return false
            local safePath = substituteString runtimeStartupPath @"\" "/"
            format "fileIn @\"%\"\n" safePath to: stream
            close stream
            return true
        ) catch (
            try (
                if (stream != undefined) do close stream
            ) catch (
            )
            return false
        )
    )

    fn maxScriptStringLiteral sourceContent = (
        local literalContent = sourceContent as string
        literalContent = substituteString literalContent @"\" @"\\"
        literalContent = substituteString literalContent "\"" "\\\""
        return "\"" + literalContent + "\""
    )

    fn maxScriptForwardPathLiteral sourceFilePath = (
        local literalContent = substituteString (sourceFilePath as string) @"\" "/"
        literalContent = substituteString literalContent "\"" "\\\""
        return "\"" + literalContent + "\""
    )

    fn writeManagerMacro runtimeRoot = (
        local macroRoot = ensureSlash (getDir #userMacros)
        local macroFilePath = macroRoot + "maxpkg-runtime-manager.mcr"
        local generatedMacroFilePath = macroRoot + "MaxPkg-MaxPkg_Manager.mcr"
        local runtimeStartupPath = runtimeRoot + "startup.ms"
        local iconFilePath = runtimeRoot + @"ui\common\icons\maxpkg-logo.svg"
        local macroContent = ""
        macroContent += "-- Opens MaxPkg Manager from a user-configured 3ds Max action.\n"
        macroContent += "-- Copyright (c) 2026 Lukianenko Vasyl\n"
        macroContent += "-- https://maxpkg.dev\n"
        macroContent += "-- Developed by https://3dground.net (3DGROUND)\n\n"
        macroContent += "macroScript MaxPkg_Manager\n"
        macroContent += "category: \"MaxPkg\"\n"
        macroContent += "buttonText: \"MaxPkg Manager\"\n"
        macroContent += "tooltip: \"Open MaxPkg Manager\"\n"
        macroContent += "iconName: " + (maxScriptForwardPathLiteral iconFilePath) + "\n"
        macroContent += "(\n"
        macroContent += "    on execute do (\n"
        macroContent += "        global MaxPkg\n"
        macroContent += "        try (\n"
        macroContent += "            if (MaxPkg == undefined or not (MaxPkg.isStarted())) do fileIn " + (maxScriptStringLiteral runtimeStartupPath) + "\n"
        macroContent += "            if (MaxPkg != undefined and MaxPkg.isStarted()) then (\n"
        macroContent += "                MaxPkg.openManager()\n"
        macroContent += "            ) else (\n"
        macroContent += "                messageBox \"MaxPkg Runtime is not available.\" title: \"MaxPkg\"\n"
        macroContent += "            )\n"
        macroContent += "        ) catch (\n"
        macroContent += "            messageBox (\"Could not open MaxPkg Manager.\\n\\n\" + getCurrentException()) title: \"MaxPkg\"\n"
        macroContent += "        )\n"
        macroContent += "    )\n"
        macroContent += ")\n"
        local fileStream = undefined
        try (
            makeDir macroRoot all: true
            if (not (forceDeleteFile macroFilePath)) do return false
            if (not (forceDeleteFile generatedMacroFilePath)) do return false
            fileStream = createFile macroFilePath
            if (fileStream == undefined) do return false
            format "%" macroContent to: fileStream
            close fileStream
            fileStream = undefined
            fileIn macroFilePath
            return true
        ) catch (
            try (
                if (fileStream != undefined) do close fileStream
            ) catch (
            )
            return false
        )
    )

    local sourceFile = getSourceFileName()
    if (sourceFile == undefined or sourceFile == "") do sourceFile = getThisScriptFileName()
    local sourceRoot = ensureSlash (getFilenamePath sourceFile)
    local targetRoot = ensureSlash ((getDir #userScripts) + @"\MaxPkg Runtime")
    local startupFolder = ensureSlash (getDir #userStartupScripts)
    local shimPath = startupFolder + "maxpkg-runtime-startup.ms"

    try (
        makeDir targetRoot all: true
        if (not (copyTree (sourceRoot + @"core\") (targetRoot + @"core\"))) do throw "Could not copy Runtime core files."
        if (not (copyTree (sourceRoot + @"ui\") (targetRoot + @"ui\"))) do throw "Could not copy Runtime UI files."
        makeDir (targetRoot + @"data\packages\") all: true
        makeDir (targetRoot + @"logs\") all: true
        makeFileWritable (targetRoot + "startup.ms")
        if (not (copyFile (sourceRoot + "startup.ms") (targetRoot + "startup.ms"))) do throw "Could not copy startup.ms."
        makeFileWritable (targetRoot + "version.ini")
        if (not (copyFile (sourceRoot + "version.ini") (targetRoot + "version.ini"))) do throw "Could not copy version.ini."
        makeFileWritable (targetRoot + "uninstall.ms")
        if (not (copyFile (sourceRoot + "uninstall.ms") (targetRoot + "uninstall.ms"))) do throw "Could not copy uninstall.ms."
        if (not (writeStartupShim shimPath (targetRoot + "startup.ms"))) do throw "Could not create the startup script."
        if (not (writeManagerMacro targetRoot)) do throw "Could not create the MaxPkg Manager MacroScript."
        fileIn (targetRoot + "startup.ms")
        if (MaxPkg == undefined) do throw "Runtime did not create the MaxPkg global."
        messageBox ("MaxPkg Runtime installed.\n\n" + targetRoot) title: "MaxPkg"
    ) catch (
        messageBox ("MaxPkg Runtime installation failed.\n\n" + getCurrentException()) title: "MaxPkg"
    )
)
