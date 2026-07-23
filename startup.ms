-- MaxPkg Runtime bootstrap and safe repeated startup.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg
    local sourcePath = getSourceFileName()
    if (sourcePath == undefined or sourcePath == "") do sourcePath = getThisScriptFileName()
    local runtimeRoot = getFilenamePath sourcePath
    local runtimeFile = runtimeRoot + "core\\runtime.ms"
    local isStarted = false

    if doesFileExist runtimeFile do (
        local loadedRuntime = fileIn runtimeFile
        if loadedRuntime != undefined and MaxPkg != undefined do isStarted = MaxPkg.start()
    )

    isStarted
)
