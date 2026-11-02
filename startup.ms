-- MaxPkg Runtime bootstrap and safe repeated startup.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg
    local sourcePath = getSourceFileName()
    if (sourcePath == undefined or sourcePath == "") do sourcePath = getThisScriptFileName()
    local runtimeRoot = getFilenamePath sourcePath
    local runtimeFile = runtimeRoot + @"core\runtime.ms"
    local isStarted = false
    -- Manager 2.0 owns 3ds Max 2022 and newer once it is installed; 1.x must not start next to it.
    local managerFolder = (getDir #temp) + @"\MaxPkg-Runtime-Manager-Qt\"
    local isManager2Installed = (maxVersion())[1] >= 24000 and doesFileExist (managerFolder + @"python\startup.py") and doesFileExist (managerFolder + "version.ini")

    if (isManager2Installed) do format "MaxPkg Runtime 1.x was not started because Manager 2.0 is installed.\n"
    if (not isManager2Installed and doesFileExist runtimeFile) do (
        local loadedRuntime = fileIn runtimeFile
        if (loadedRuntime != undefined and MaxPkg != undefined) do isStarted = MaxPkg.start()
    )

    isStarted
)
