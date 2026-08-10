-- Verifies that MaxPkg Runtime installs into the 3ds Max temporary folder.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    fn ensureSlash folderPath = (
        if (folderPath == undefined or folderPath == "") do return ""
        local normalizedPath = substituteString folderPath "/" @"\"
        if ((substring normalizedPath normalizedPath.count 1) == @"\") do return normalizedPath
        return normalizedPath + @"\"
    )

    fn readFileContent filePath = (
        if (not (doesFileExist filePath)) do return ""
        local fileClass = dotNetClass "System.IO.File"
        return fileClass.ReadAllText filePath
    )

    local testRoot = ensureSlash (getFilenamePath (getSourceFileName()))
    local projectRoot = ensureSlash (getFilenamePath (substring testRoot 1 (testRoot.count - 1)))
    local expectedRuntimeRoot = (ensureSlash (getDir #temp)) + @"MaxPkg-Runtime-Manager\"
    local startupShimPath = (ensureSlash (getDir #userStartupScripts)) + "maxpkg-runtime-startup.ms"
    local managerMacroPath = (ensureSlash (getDir #userMacros)) + "maxpkg-runtime-manager.mcr"
    local expectedStartupPath = expectedRuntimeRoot + "startup.ms"

    try (
        fileIn (projectRoot + "install.ms")

        if (not (doesFileExist expectedStartupPath)) do throw "Installed startup.ms is missing."
        if (not (doesFileExist (expectedRuntimeRoot + @"core\runtime.ms"))) do throw "Installed core/runtime.ms is missing."
        if (not (doesFileExist (expectedRuntimeRoot + @"themes\manager\default.ini"))) do throw "Installed Manager default theme is missing."
        if (not (doesFileExist (expectedRuntimeRoot + @"themes\toolbar\default.ini"))) do throw "Installed Toolbar default theme is missing."
        if (not (doesFileExist (expectedRuntimeRoot + "version.ini"))) do throw "Installed version.ini is missing."
        if (not (doesFileExist (expectedRuntimeRoot + "uninstall.ms"))) do throw "Installed uninstall.ms is missing."
        if (not (doesFileExist startupShimPath)) do throw "The startup loader is missing."
        if (not (doesFileExist managerMacroPath)) do throw "The Manager MacroScript is missing."

        local startupShimContent = readFileContent startupShimPath
        local managerMacroContent = readFileContent managerMacroPath
        local normalizedExpectedPath = substituteString expectedStartupPath @"\" "/"
        local escapedExpectedPath = substituteString expectedStartupPath @"\" @"\\"
        if (findString startupShimContent normalizedExpectedPath == undefined) do throw "The startup loader does not point to the temporary Runtime folder."
        if (findString managerMacroContent escapedExpectedPath == undefined) do throw "The Manager MacroScript does not point to the temporary Runtime folder."

        format "MAXPKG_INSTALL_LOCATION_OK %\n" expectedRuntimeRoot
    ) catch (
        format "MAXPKG_INSTALL_LOCATION_FAILED %\n" (getCurrentException())
    )

    quitMax #noPrompt
)
