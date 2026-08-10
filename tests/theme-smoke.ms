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

    local managerCss = themesModule.renderManagerCss "default"
    local toolbarCss = themesModule.renderToolbarCss "default"
    local resultDialogCss = themesModule.renderResultDialogCss "default"
    if (managerCss == "" or toolbarCss == "" or resultDialogCss == "") do throw "Theme CSS rendering returned empty content."
    if ((findString managerCss "{{") != undefined) do throw "Manager CSS contains unresolved theme tokens."
    if ((findString toolbarCss "{{") != undefined) do throw "Toolbar CSS contains unresolved theme tokens."
    if ((findString resultDialogCss "{{") != undefined) do throw "Result dialog CSS contains unresolved theme tokens."
    if (not (themesModule.prepareManagerAssets "default")) do throw "Manager theme assets could not be generated."
    if (not (themesModule.prepareToolbarAssets "default")) do throw "Toolbar theme assets could not be generated."

    format "MAXPKG_THEME_SMOKE_OK\n"
    quitMax #noPrompt
)
