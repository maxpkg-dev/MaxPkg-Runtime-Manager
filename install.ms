-- Installs MaxPkg Runtime and creates its startup loader.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg

    fn ensureSlash folderPath = (
        if folderPath == undefined or folderPath == "" do return ""
        local normalizedPath = substituteString folderPath "/" "\\"
        if (substring normalizedPath normalizedPath.count 1) == "\\" do return normalizedPath
        return normalizedPath + "\\"
    )

    fn copyTree sourceRoot targetRoot = (
        if sourceRoot == "" or targetRoot == "" do return false
        if not (doesDirectoryExist sourceRoot) do return false
        try (
            local directoryClass = dotNetClass "System.IO.Directory"
            local searchOption = dotNetClass "System.IO.SearchOption"
            makeDir targetRoot all:true
            local files = directoryClass.GetFiles sourceRoot "*" searchOption.AllDirectories
            for sourceFile in files do (
                local relativePath = substring sourceFile (sourceRoot.count + 1) (sourceFile.count - sourceRoot.count)
                local targetFile = targetRoot + relativePath
                makeDir (getFilenamePath targetFile) all:true
                if not (copyFile sourceFile targetFile) do return false
            )
            return true
        ) catch (
            return false
        )
    )

    fn writeStartupShim shimPath runtimeStartupPath = (
        local stream = undefined
        try (
            stream = createFile shimPath
            if stream == undefined do return false
            local safePath = substituteString runtimeStartupPath "\\" "/"
            format "fileIn @\"%\"\n" safePath to:stream
            close stream
            return true
        ) catch (
            try (
                if stream != undefined do close stream
            ) catch (
            )
            return false
        )
    )

    local sourceFile = getSourceFileName()
    if sourceFile == undefined or sourceFile == "" do sourceFile = getThisScriptFileName()
    local sourceRoot = ensureSlash (getFilenamePath sourceFile)
    local targetRoot = ensureSlash ((getDir #userScripts) + "\\MaxPkg Runtime")
    local startupFolder = ensureSlash (getDir #userStartupScripts)
    local shimPath = startupFolder + "maxpkg-runtime-startup.ms"

    try (
        makeDir targetRoot all:true
        if not (copyTree (sourceRoot + "core\\") (targetRoot + "core\\")) do throw "Could not copy Runtime core files."
        if not (copyTree (sourceRoot + "ui\\") (targetRoot + "ui\\")) do throw "Could not copy Runtime UI files."
        makeDir (targetRoot + "data\\packages\\") all:true
        makeDir (targetRoot + "logs\\") all:true
        if not (copyFile (sourceRoot + "startup.ms") (targetRoot + "startup.ms")) do throw "Could not copy startup.ms."
        if not (copyFile (sourceRoot + "version.ini") (targetRoot + "version.ini")) do throw "Could not copy version.ini."
        if not (writeStartupShim shimPath (targetRoot + "startup.ms")) do throw "Could not create the startup script."
        fileIn (targetRoot + "startup.ms")
        if MaxPkg == undefined do throw "Runtime did not create the MaxPkg global."
        messageBox ("MaxPkg Runtime installed.\n\n" + targetRoot) title:"MaxPkg"
    ) catch (
        messageBox ("MaxPkg Runtime installation failed.\n\n" + getCurrentException()) title:"MaxPkg"
    )
)
