-- Finishes or rolls back an interrupted Manager 2.0 upgrade and restarts the 1.x Runtime when needed.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

-- Runs from the backup folder (backup\runtime\core\manager2-recovery.ms), so it must not use any Runtime module.
-- It is started by a tiny startup script written before the Manager 2.0 installer runs, and directly by the
-- upgrade module when Manager 2.0 failed to load. The plan file next to the backup describes what to restore.
(
    global MaxPkg

    fn ensureSlash folderPath = (
        if (folderPath == undefined or folderPath == "") do return ""
        local normalizedPath = substituteString folderPath "/" @"\"
        if ((substring normalizedPath normalizedPath.count 1) == @"\") do return normalizedPath
        return normalizedPath + @"\"
    )

    fn makeWritable filePath = (
        try (
            if (doesFileExist filePath) do setFileAttribute filePath #readOnly false
            return true
        ) catch (
            return false
        )
    )

    fn deleteFileSafe filePath = (
        if (filePath == undefined or filePath == "" or not (doesFileExist filePath)) do return true
        makeWritable filePath
        try (
            deleteFile filePath
        ) catch (
        )
        return not (doesFileExist filePath)
    )

    fn deleteFolderSafe folderPath = (
        if (folderPath == undefined or folderPath == "" or not (doesDirectoryExist folderPath)) do return true
        try (
            local directoryClass = dotNetClass "System.IO.Directory"
            local searchOption = dotNetClass "System.IO.SearchOption"
            local existingFiles = directoryClass.GetFiles folderPath "*" searchOption.AllDirectories
            for existingFile in existingFiles do makeWritable existingFile
            directoryClass.Delete folderPath true
        ) catch (
        )
        return not (doesDirectoryExist folderPath)
    )

    fn copyFileSafe sourceFile targetFile = (
        if (not (doesFileExist sourceFile)) do return false
        try (
            makeDir (getFilenamePath targetFile) all: true
            makeWritable targetFile
            local fileClass = dotNetClass "System.IO.File"
            fileClass.Copy sourceFile targetFile true
            return doesFileExist targetFile
        ) catch (
            format "MaxPkg recovery could not copy %: %\n" targetFile (getCurrentException())
            return false
        )
    )

    fn copyTreeSafe sourceRoot targetRoot = (
        local isCopied = true
        try (
            local directoryClass = dotNetClass "System.IO.Directory"
            local searchOption = dotNetClass "System.IO.SearchOption"
            local sourceFiles = directoryClass.GetFiles sourceRoot "*" searchOption.AllDirectories
            for sourceFile in sourceFiles do (
                local relativeFile = substring sourceFile (sourceRoot.count + 1) (sourceFile.count - sourceRoot.count)
                if (not (copyFileSafe sourceFile (targetRoot + relativeFile))) do isCopied = false
            )
        ) catch (
            format "MaxPkg recovery could not copy %: %\n" sourceRoot (getCurrentException())
            isCopied = false
        )
        return isCopied
    )

    fn runPythonFile pythonFile = (
        if (not (doesFileExist pythonFile)) do return false
        try (
            local pythonPath = substituteString (substituteString pythonFile @"\" "/") "'" @"\'"
            python.Execute ("import runpy; runpy.run_path('" + pythonPath + "', run_name='__main__')")
            return true
        ) catch (
            format "MaxPkg recovery could not run %: %\n" pythonFile (getCurrentException())
            return false
        )
    )

    fn readPlan planFile planKey = (
        if (not (doesFileExist planFile)) do return ""
        try (
            local planContent = getINISetting planFile "Plan" planKey
            if (planContent == undefined) do return ""
            return planContent
        ) catch (
            return ""
        )
    )

    fn managerLoaded = (
        return MaxPkg != undefined and isProperty MaxPkg #isPackageManager
    )

    local scriptFile = getSourceFileName()
    local coreFolder = getFilenamePath scriptFile
    local runtimeBackupRoot = ensureSlash (getFilenamePath (substring coreFolder 1 (coreFolder.count - 1)))
    local backupRoot = ensureSlash (getFilenamePath (substring runtimeBackupRoot 1 (runtimeBackupRoot.count - 1)))
    local planFile = backupRoot + "upgrade.ini"
    local flagFile = backupRoot + "in-progress.flag"
    local runtimeRoot = ensureSlash (readPlan planFile "RuntimeRoot")
    local recoveryShim = readPlan planFile "RecoveryShim"
    local qtRoot = ensureSlash (readPlan planFile "QtRoot")
    local qtShim = readPlan planFile "QtShim"
    local qtMacro = readPlan planFile "QtMacro"
    local expectedVersion = readPlan planFile "ExpectedVersion"
    local isForced = (readPlan planFile "ForceRestore") == "true"
    local isRestored = false

    if (runtimeRoot == "" or not (doesFileExist flagFile)) then (
        -- Nothing is pending: only remove the leftover trigger.
        deleteFileSafe recoveryShim
    ) else (
        local qtVersion = ""
        if (qtRoot != "" and doesFileExist (qtRoot + "version.ini")) do (
            try (
                qtVersion = getINISetting (qtRoot + "version.ini") "Runtime" "Version"
            ) catch (
                qtVersion = ""
            )
        )
        local isManagerInstalled = (not isForced) and qtVersion == expectedVersion and doesFileExist (qtRoot + @"python\startup.py") and doesFileExist qtShim

        if (isManagerInstalled) then (
            format "MaxPkg recovery: Manager % is installed; finishing the upgrade.\n" qtVersion
        ) else (
            format "MaxPkg recovery: restoring the 1.x Runtime from %\n" backupRoot
            if (managerLoaded()) do (
                runPythonFile (qtRoot + @"python\stop.py")
                MaxPkg = undefined
            )
            deleteFileSafe qtShim
            deleteFileSafe qtMacro
            deleteFolderSafe qtRoot
            isRestored = copyTreeSafe runtimeBackupRoot runtimeRoot
            makeDir (runtimeRoot + @"logs\") all: true
            makeDir (runtimeRoot + @"data\packages\") all: true
            local fileCount = 0
            try (
                fileCount = (readPlan planFile "FileCount") as integer
            ) catch (
                fileCount = 0
            )
            if (fileCount == undefined) do fileCount = 0
            for fileIndex in 1 to fileCount do (
                local originalFile = readPlan planFile ("File" + (fileIndex as string))
                local backupFile = backupRoot + @"files\" + (fileIndex as string) + ".bak"
                if (originalFile != "") do (
                    if (not (copyFileSafe backupFile originalFile)) do isRestored = false
                )
            )
        )

        deleteFileSafe flagFile
        deleteFileSafe recoveryShim
        deleteFolderSafe backupRoot

        if (isRestored) do (
            try (
                fileIn (runtimeRoot + "startup.ms")
            ) catch (
                format "MaxPkg recovery could not start the restored Runtime: %\n" (getCurrentException())
            )
        )
    )

    isRestored
)
