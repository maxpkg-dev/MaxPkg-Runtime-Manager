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

    fn forceDeleteFolder folderPath = (
        if (folderPath == undefined or folderPath == "" or not (doesDirectoryExist folderPath)) do return true
        try (
            local directoryClass = dotNetClass "System.IO.Directory"
            local searchOption = dotNetClass "System.IO.SearchOption"
            local existingFiles = directoryClass.GetFiles folderPath "*" searchOption.AllDirectories
            for existingFile in existingFiles do (
                if (not (makeFileWritable existingFile)) do return false
            )
            directoryClass.Delete folderPath true
            return not (doesDirectoryExist folderPath)
        ) catch (
            return false
        )
    )

    fn clearFolderReadOnly folderPath = (
        local normalizedFolderPath = ensureSlash folderPath
        if (normalizedFolderPath == "" or not (doesDirectoryExist normalizedFolderPath)) do return true
        local isWritable = true
        try (
            local directoryClass = dotNetClass "System.IO.Directory"
            local searchOption = dotNetClass "System.IO.SearchOption"
            local existingFiles = directoryClass.GetFiles normalizedFolderPath "*" searchOption.AllDirectories
            for existingFile in existingFiles do (
                if (not (makeFileWritable existingFile)) do isWritable = false
            )
        ) catch (
            isWritable = false
        )
        return isWritable
    )

    fn replaceFile sourceFilePath targetFilePath = (
        if (not (doesFileExist sourceFilePath)) do throw ("Runtime source file does not exist:\n" + sourceFilePath)
        local targetFolder = getFilenamePath targetFilePath
        if (not (makeDir targetFolder all: true)) do throw ("Could not create target folder:\n" + targetFolder)
        if (not (forceDeleteFile targetFilePath)) do throw ("Could not remove the previous Runtime file:\n" + targetFilePath)
        if (not (copyFile sourceFilePath targetFilePath)) do throw ("Could not copy Runtime file:\n" + sourceFilePath + "\n\nto:\n" + targetFilePath)
        return true
    )

    fn copyTree sourceRoot targetRoot = (
        if (sourceRoot == "" or targetRoot == "") do throw "Runtime copy paths are empty."
        if (not (doesDirectoryExist sourceRoot)) do throw ("Runtime source folder does not exist:\n" + sourceRoot)
        local directoryClass = dotNetClass "System.IO.Directory"
        local searchOption = dotNetClass "System.IO.SearchOption"
        if (not (makeDir targetRoot all: true)) do throw ("Could not create Runtime folder:\n" + targetRoot)
        local sourceFiles = directoryClass.GetFiles sourceRoot "*" searchOption.AllDirectories
        for sourceFile in sourceFiles do (
            local relativePath = substring sourceFile (sourceRoot.count + 1) (sourceFile.count - sourceRoot.count)
            local targetFile = targetRoot + relativePath
            replaceFile sourceFile targetFile
        )
        return true
    )

    fn writeStartupShim shimPath runtimeStartupPath = (
        local stream = undefined
        try (
            makeDir (getFilenamePath shimPath) all: true
            if (not (clearFolderReadOnly (getFilenamePath shimPath))) do return false
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
    local temporaryRoot = ensureSlash (getDir #temp)
    local targetRoot = if (temporaryRoot != "") then temporaryRoot + @"MaxPkg-Runtime-Manager\" else ""
    local startupFolder = ensureSlash (getDir #userStartupScripts)
    local shimPath = startupFolder + "maxpkg-runtime-startup.ms"
    local resultDialogModule = undefined
    local themesModule = undefined
    local runtimeVersion = "Unknown"
    local installationErrorMessage = ""

    try (
        resultDialogModule = fileIn (sourceRoot + @"ui\common\result-dialog.ms")
        local installIniModule = fileIn (sourceRoot + @"core\ini.ms")
        local installUtilsModule = fileIn (sourceRoot + @"core\utils.ms")
        themesModule = fileIn (sourceRoot + @"core\themes.ms")
        themesModule.initialize sourceRoot installIniModule installUtilsModule undefined
        resultDialogModule.configureTheme themesModule "default"
        if (not (resultDialogModule.prepareTemporaryAssets())) do resultDialogModule = undefined
    ) catch (
        resultDialogModule = undefined
        themesModule = undefined
    )
    try (
        runtimeVersion = getINISetting (sourceRoot + "version.ini") "Runtime" "Version"
    ) catch (
        runtimeVersion = "Unknown"
    )

    try (
        if (targetRoot == "") do throw "The 3ds Max temporary folder is unavailable."
        if ((toLower sourceRoot) == (toLower targetRoot)) do throw "Runtime cannot be installed over its source folder."
        if (MaxPkg != undefined and isProperty MaxPkg #shutdown) do (
            try (
                MaxPkg.shutdown()
            ) catch (
            )
        )
        makeDir targetRoot all: true
        if (not (forceDeleteFolder (targetRoot + @"core\"))) do throw ("Could not remove the previous Runtime core folder:\n" + (targetRoot + @"core\"))
        if (not (forceDeleteFolder (targetRoot + @"ui\"))) do throw ("Could not remove the previous Runtime UI folder:\n" + (targetRoot + @"ui\"))
        copyTree (sourceRoot + @"core\") (targetRoot + @"core\")
        copyTree (sourceRoot + @"ui\") (targetRoot + @"ui\")
        copyTree (sourceRoot + @"themes\") (targetRoot + @"themes\")
        makeDir (targetRoot + @"data\packages\") all: true
        makeDir (targetRoot + @"logs\") all: true
        replaceFile (sourceRoot + "startup.ms") (targetRoot + "startup.ms")
        replaceFile (sourceRoot + "version.ini") (targetRoot + "version.ini")
        replaceFile (sourceRoot + "uninstall.ms") (targetRoot + "uninstall.ms")
        if (not (writeStartupShim shimPath (targetRoot + "startup.ms"))) do throw "Could not create the startup script."
        if (not (writeManagerMacro targetRoot)) do throw "Could not create the MaxPkg Manager MacroScript."
        fileIn (targetRoot + "startup.ms")
        if (MaxPkg == undefined) do throw "Runtime did not create the MaxPkg global."
        if (resultDialogModule != undefined) then (
            local successDialogInfo = resultDialogModule.createDialogData()
            successDialogInfo.windowTitle = "MaxPkg Runtime Setup"
            successDialogInfo.heading = "Installation complete"
            successDialogInfo.summary = "MaxPkg is ready. Find, install, update, and organize useful 3ds Max scripts in one simple place."
            successDialogInfo.versionText = runtimeVersion
            successDialogInfo.startupText = "Enabled"
            successDialogInfo.guideTitle = "Quick guide"
            successDialogInfo.guideStepOneTitle = "Open MaxPkg Manager"
            successDialogInfo.guideStepOneContent = "Click Open Manager below. You will see your installed scripts and the Discover catalog."
            successDialogInfo.guideStepTwoTitle = "Find and install a script"
            successDialogInfo.guideStepTwoContent = "Open Discover and search for a tool, for example Prune Scene. Click Install and MaxPkg will take care of the rest."
            successDialogInfo.guideStepThreeTitle = "Run it from the toolbar"
            successDialogInfo.guideStepThreeContent = "After installation, the script button appears on the MaxPkg toolbar. Click it whenever you need the tool."
            successDialogInfo.primaryButtonText = "Open Manager"
            fn showInstalledManager = (
                if (MaxPkg != undefined and MaxPkg.isStarted()) do MaxPkg.openManager()
                return true
            )
            successDialogInfo.primaryActionCallback = showInstalledManager
            resultDialogModule.showDialog successDialogInfo
        ) else (
            messageBox ("MaxPkg Runtime installed.\n\n" + targetRoot) title: "MaxPkg"
        )
    ) catch (
        installationErrorMessage = getCurrentException()
        if (resultDialogModule != undefined) then (
            local failureDialogInfo = resultDialogModule.createDialogData()
            failureDialogInfo.windowTitle = "MaxPkg Runtime Setup"
            failureDialogInfo.heading = "Installation incomplete"
            failureDialogInfo.summary = "MaxPkg could not finish installing, but your 3ds Max scenes and existing scripts were not changed."
            failureDialogInfo.versionText = runtimeVersion
            failureDialogInfo.startupText = "Not enabled"
            failureDialogInfo.guideTitle = "Quick help"
            failureDialogInfo.guideStepOneTitle = "Close MaxPkg windows"
            failureDialogInfo.guideStepOneContent = "Close the Manager and any other MaxPkg windows, then run install.ms again."
            failureDialogInfo.guideStepTwoTitle = "Restart 3ds Max"
            failureDialogInfo.guideStepTwoContent = "If installation still does not finish, restart 3ds Max and try once more."
            failureDialogInfo.guideStepThreeTitle = "Get a fresh installer"
            failureDialogInfo.guideStepThreeContent = "Visit maxpkg.dev to download the latest MaxPkg Runtime installer and find additional help."
            failureDialogInfo.statusKind = "error"
            resultDialogModule.showDialog failureDialogInfo
        ) else (
            messageBox ("MaxPkg Runtime installation failed.\n\n" + installationErrorMessage) title: "MaxPkg"
        )
    )
)
