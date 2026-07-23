-- Reloads Runtime and opens Manager for interactive testing.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg

    local testRoot = getFilenamePath (getSourceFileName())
    local runtimeRoot = getFilenamePath (substring testRoot 1 (testRoot.count - 1))
    local startupFile = runtimeRoot + "startup.ms"

    if not (fileIn startupFile) do throw "MaxPkg Runtime startup failed."
    if MaxPkg == undefined or not (MaxPkg.isStarted()) do throw "MaxPkg Runtime is not ready."
    if not (MaxPkg.openManager()) do throw "MaxPkg Manager could not be opened."

    format "MAXPKG_MANAGER_READY\n"
    true
)
