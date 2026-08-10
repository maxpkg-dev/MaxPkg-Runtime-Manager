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
        if (not (makeFileWritable filePath)) do return false
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

    local temporaryRoot = ensureSlash (getDir #temp)
    local runtimeRoot = if (temporaryRoot != "") then temporaryRoot + @"MaxPkg-Runtime-Manager\" else ""
    local startupShimPath = (ensureSlash (getDir #userStartupScripts)) + "maxpkg-runtime-startup.ms"
    local userMacrosRoot = ensureSlash (getDir #userMacros)
    local managerMacroPaths = #(
        userMacrosRoot + "maxpkg-runtime-manager.mcr",
        userMacrosRoot + "MaxPkg-MaxPkg_Manager.mcr"
    )
    local resultDialogModule = undefined
    local runtimeVersion = "Unknown"
    local isSuccess = true

    try (
        resultDialogModule = fileIn (runtimeRoot + @"ui\common\result-dialog.ms")
        local uninstallIniModule = fileIn (runtimeRoot + @"core\ini.ms")
        local uninstallUtilsModule = fileIn (runtimeRoot + @"core\utils.ms")
        local uninstallThemesModule = fileIn (runtimeRoot + @"core\themes.ms")
        uninstallThemesModule.initialize runtimeRoot uninstallIniModule uninstallUtilsModule undefined
        local selectedManagerTheme = getINISetting (runtimeRoot + "settings.ini") "General" "ManagerTheme"
        if (selectedManagerTheme == undefined or selectedManagerTheme == "") do selectedManagerTheme = "default"
        resultDialogModule.configureTheme uninstallThemesModule selectedManagerTheme
        if (not (resultDialogModule.prepareTemporaryAssets())) do resultDialogModule = undefined
    ) catch (
        resultDialogModule = undefined
    )
    try (
        runtimeVersion = getINISetting (runtimeRoot + "version.ini") "Runtime" "Version"
    ) catch (
        runtimeVersion = "Unknown"
    )

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
    if (temporaryRoot == "" or (toLower runtimeRoot) == (toLower temporaryRoot)) then (
        isSuccess = false
    ) else if (not (forceDeleteFolder runtimeRoot)) then (
        isSuccess = false
    )
    if (resultDialogModule != undefined) then (
        local dialogInfo = resultDialogModule.createDialogData()
        dialogInfo.windowTitle = "MaxPkg Runtime Removal"
        if (isSuccess) then (
            dialogInfo.heading = "Removal complete"
            dialogInfo.summary = "MaxPkg Runtime has been removed from this 3ds Max installation."
            dialogInfo.versionText = runtimeVersion
            dialogInfo.startupText = "Disabled"
            dialogInfo.guideTitle = "What happens now?"
            dialogInfo.guideStepOneTitle = "MaxPkg will no longer start"
            dialogInfo.guideStepOneContent = "The Manager and its automatic startup have been removed from this 3ds Max installation."
            dialogInfo.guideStepTwoTitle = "Your scenes are safe"
            dialogInfo.guideStepTwoContent = "Removing MaxPkg does not change your 3ds Max scene files."
            dialogInfo.guideStepThreeTitle = "Come back at any time"
            dialogInfo.guideStepThreeContent = "You can reinstall MaxPkg whenever you want by visiting maxpkg.dev."
            dialogInfo.statusKind = "removal"
        ) else (
            dialogInfo.heading = "Removal incomplete"
            dialogInfo.summary = "Some MaxPkg files could not be removed. Close 3ds Max before deleting the remaining folder manually."
            dialogInfo.versionText = runtimeVersion
            dialogInfo.startupText = "Needs attention"
            dialogInfo.guideTitle = "Finish removing MaxPkg"
            dialogInfo.guideStepOneTitle = "Restart 3ds Max"
            dialogInfo.guideStepOneContent = "Restart 3ds Max to release any MaxPkg files that are still in use."
            dialogInfo.guideStepTwoTitle = "Run the uninstaller again"
            dialogInfo.guideStepTwoContent = "Start the MaxPkg uninstaller once more after restarting 3ds Max."
            dialogInfo.guideStepThreeTitle = "Get help"
            dialogInfo.guideStepThreeContent = "Your scene files were not changed. Visit maxpkg.dev if you need additional help."
            dialogInfo.statusKind = "error"
        )
        resultDialogModule.showDialog dialogInfo
    ) else if (isSuccess) then (
        messageBox "MaxPkg Runtime was uninstalled." title: "MaxPkg"
    ) else (
        messageBox "MaxPkg Runtime could not be removed completely. Close 3ds Max and remove the remaining files manually." title: "MaxPkg"
    )
    isSuccess
)
