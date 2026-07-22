(
    global MaxPkg
    local testRoot = getFilenamePath (getSourceFileName())
    local runtimeRoot = getFilenamePath (substring testRoot 1 (testRoot.count - 1))
    local startupFile = runtimeRoot + "startup.ms"
    if not (fileIn startupFile) do throw "Initial Runtime startup failed."
    if MaxPkg == undefined do throw "MaxPkg global was not created."
    if MaxPkg.version == undefined do throw "MaxPkg.version is unavailable."
    if not (MaxPkg.isStarted()) do throw "Initial Runtime is not marked as started."
    if MaxPkg.settings == undefined do throw "MaxPkg settings were not loaded."

    local firstRuntime = MaxPkg
    if not (firstRuntime.openManager()) do throw "Manager could not be opened before restart."
    if not (fileIn startupFile) do throw "Second Runtime startup failed."
    if MaxPkg == firstRuntime do throw "Runtime instance was not replaced."
    if firstRuntime.isStarted() do throw "Previous Runtime remained started."
    if not (MaxPkg.isStarted()) do throw "Replacement Runtime is not marked as started."

    local secondRuntime = MaxPkg
    if not (fileIn startupFile) do throw "Third Runtime startup failed."
    if MaxPkg == secondRuntime do throw "Second Runtime instance was not replaced."
    if secondRuntime.isStarted() do throw "Second Runtime remained started."
    if not (MaxPkg.isStarted()) do throw "Third Runtime is not marked as started."

    local discoveredPackages = MaxPkg.scan()
    if classOf discoveredPackages != Array do throw "MaxPkg.scan() did not return an array."
    if MaxPkg.run "__maxpkg_missing_package__" != false do throw "Missing package resolution did not fail safely."
    if MaxPkg.install undefined != false do throw "Empty package installation did not fail safely."
    if MaxPkg.isBusy() do throw "Critical operation lock was not released."
    format "MAXPKG_RESTART_OK\n"
    format "MAXPKG_SMOKE_OK\n"
)
