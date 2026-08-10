-- Verifies Runtime theme discovery, fallback, CSS rendering, and icon generation.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local testRoot = getFilenamePath (getSourceFileName())
    local runtimeRoot = getFilenamePath (substring testRoot 1 (testRoot.count - 1))
    local utilsModule = fileIn (runtimeRoot + @"core\utils.ms")
    local iniModule = fileIn (runtimeRoot + @"core\ini.ms")
    local themesModule = fileIn (runtimeRoot + @"core\themes.ms")
    themesModule.initialize runtimeRoot iniModule utilsModule undefined

    local guidClass = dotNetClass "System.Guid"
    local discoveryTestRoot = (utilsModule.ensureSlash (getDir #temp)) + "maxpkg-theme-discovery-" + ((guidClass.NewGuid()).ToString()) + @"\"
    local discoveryManagerFolder = discoveryTestRoot + @"themes\manager\"
    if (not (utilsModule.writeText (discoveryManagerFolder + "custom.ini") "[Theme]\nName=Custom\n\n[Colors]\naccent=#123456\n")) do throw "Custom theme fixture could not be created."
    if (not (utilsModule.writeText (discoveryManagerFolder + "broken.ini") "[Theme]\nName=Broken\n\n[Colors]\naccent=not-a-color\n")) do throw "Broken theme fixture could not be created."
    local discoveryThemesModule = fileIn (runtimeRoot + @"core\themes.ms")
    discoveryThemesModule.initialize discoveryTestRoot iniModule utilsModule undefined
    local discoveredCustomThemes = discoveryThemesModule.listThemes "manager"
    if (discoveredCustomThemes.count != 1 or discoveredCustomThemes[1].themeId != "custom") do throw "Theme auto-discovery accepted an invalid INI or missed a valid INI."
    if ((discoveryThemesModule.resolveThemeId "manager" "custom") != "custom") do throw "Custom theme could not be resolved."
    if ((discoveryThemesModule.resolveThemeId "manager" "broken") != "default") do throw "Broken theme did not use the default fallback."
    utilsModule.forceDeleteFolder discoveryTestRoot

    local managerThemes = themesModule.listThemes "manager"
    local toolbarThemes = themesModule.listThemes "toolbar"
    if (managerThemes.count < 1) do throw "Manager default theme was not discovered."
    if (toolbarThemes.count < 1) do throw "Toolbar default theme was not discovered."
    if ((themesModule.resolveThemeId "manager" "missing-theme") != "default") do throw "Missing Manager theme did not fall back to default."
    if ((themesModule.resolveThemeId "toolbar" "missing-theme") != "default") do throw "Missing Toolbar theme did not fall back to default."

    for managerThemeInfo in managerThemes do (
        local managerCss = themesModule.renderManagerCss managerThemeInfo.themeId
        if (managerCss == "") do throw ("Manager theme CSS is empty: " + managerThemeInfo.themeId)
        if ((findString managerCss "{{") != undefined) do throw ("Manager theme contains unresolved tokens: " + managerThemeInfo.themeId)
        if (not (themesModule.prepareManagerAssets managerThemeInfo.themeId)) do throw ("Manager theme assets could not be generated: " + managerThemeInfo.themeId)
    )
    for toolbarThemeInfo in toolbarThemes do (
        local toolbarCss = themesModule.renderToolbarCss toolbarThemeInfo.themeId
        if (toolbarCss == "") do throw ("Toolbar theme CSS is empty: " + toolbarThemeInfo.themeId)
        if ((findString toolbarCss "{{") != undefined) do throw ("Toolbar theme contains unresolved tokens: " + toolbarThemeInfo.themeId)
        if (not (themesModule.prepareToolbarAssets toolbarThemeInfo.themeId)) do throw ("Toolbar theme assets could not be generated: " + toolbarThemeInfo.themeId)
    )
    local selectedManagerTheme = iniModule.read (runtimeRoot + "settings.ini") "General" "ManagerTheme" defaultValue: "default"
    local selectedToolbarTheme = iniModule.read (runtimeRoot + "settings.ini") "Toolbar" "Theme" defaultValue: "default"
    if (not (themesModule.prepareManagerAssets (themesModule.resolveThemeId "manager" selectedManagerTheme))) do throw "Selected Manager theme could not be restored after testing."
    if (not (themesModule.prepareToolbarAssets (themesModule.resolveThemeId "toolbar" selectedToolbarTheme))) do throw "Selected Toolbar theme could not be restored after testing."
    local resultDialogCss = themesModule.renderResultDialogCss "default"
    if (resultDialogCss == "") do throw "Result dialog theme CSS is empty."
    if ((findString resultDialogCss "{{") != undefined) do throw "Result dialog CSS contains unresolved theme tokens."

    format "MAXPKG_THEME_SMOKE_OK\n"
    quitMax #noPrompt
)
