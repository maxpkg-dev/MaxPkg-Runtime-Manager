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
