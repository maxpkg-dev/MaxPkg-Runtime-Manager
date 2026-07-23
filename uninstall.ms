-- Uninstalls MaxPkg Runtime and removes its startup and MacroScript files.
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
        makeFileWritable filePath
        try (
            deleteFile filePath
            return not (doesFileExist filePath)
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
            local filePaths = directoryClass.GetFiles normalizedFolderPath "*" searchOption.AllDirectories
            for currentFilePath in filePaths do (
                if (not (makeFileWritable currentFilePath)) do isWritable = false
            )
        ) catch (
            isWritable = false
        )
        return isWritable
    )

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
    )

    local userScriptsRoot = ensureSlash (getDir #userScripts)
    local runtimeRoot = userScriptsRoot + @"MaxPkg Runtime\"
    local startupShimPath = (ensureSlash (getDir #userStartupScripts)) + "maxpkg-runtime-startup.ms"
    local userMacrosRoot = ensureSlash (getDir #userMacros)
    local managerMacroPaths = #(
        userMacrosRoot + "maxpkg-runtime-manager.mcr",
        userMacrosRoot + "MaxPkg-MaxPkg_Manager.mcr"
    )
    local isSuccess = true

    try (
        if (MaxPkg != undefined and isProperty MaxPkg #shutdown) do MaxPkg.shutdown()
    ) catch (
        isSuccess = false
    )
    MaxPkg = undefined

    for managerMacroPath in managerMacroPaths do (
        if (not (forceDeleteFile managerMacroPath)) do isSuccess = false
    )
    if (not (forceDeleteFile startupShimPath)) do isSuccess = false
    if (userScriptsRoot == "" or (toLower runtimeRoot) == (toLower userScriptsRoot)) then (
        isSuccess = false
    ) else if (not (forceDeleteFolder runtimeRoot)) then (
        isSuccess = false
    )

    if (isSuccess) then (
        messageBox "MaxPkg Runtime was uninstalled." title: "MaxPkg"
    ) else (
        messageBox "MaxPkg Runtime could not be removed completely. Close 3ds Max and remove the remaining files manually." title: "MaxPkg"
    )
    isSuccess
)
