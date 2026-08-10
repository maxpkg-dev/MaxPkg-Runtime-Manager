-- Discovers, validates, and renders IE9-compatible Runtime themes.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgThemeInfoData (
        themeId = "default",
        displayName = "Default",
        filePath = ""
    )

    struct MaxPkgThemePaletteData (
        themeId = "default",
        displayName = "Default",
        colorKeys = #(),
        colorContents = #()
    )

    struct MaxPkgThemesModule (
        runtimeRoot = "",
        ini,
        utils,
        logger,

        fn normalizedThemeKind requestedThemeKind = (
            if ((toLower (requestedThemeKind as string)) == "toolbar") do return "toolbar"
            return "manager"
        ),

        fn themeFolderPath requestedThemeKind = (
            local themeKind = normalizedThemeKind requestedThemeKind
            return runtimeRoot + @"themes\" + themeKind + @"\"
        ),

        fn isSafeThemeId requestedThemeId = (
            if (requestedThemeId == undefined or requestedThemeId == "") do return false
            local allowedCharacters = "abcdefghijklmnopqrstuvwxyz0123456789-_"
            local normalizedThemeId = toLower (requestedThemeId as string)
            for characterIndex in 1 to normalizedThemeId.count do (
                local characterContent = substring normalizedThemeId characterIndex 1
                if ((findString allowedCharacters characterContent) == undefined) do return false
            )
            return true
        ),

        fn normalizedThemeId requestedThemeId = (
            if (not (isSafeThemeId requestedThemeId)) do return "default"
            return toLower (requestedThemeId as string)
        ),

        fn themeFilePath requestedThemeKind requestedThemeId = (
            local themeId = normalizedThemeId requestedThemeId
            return (themeFolderPath requestedThemeKind) + themeId + ".ini"
        ),

        fn isValidColorContent sourceContent = (
            if (sourceContent == undefined or sourceContent == "") do return false
            try (
                local regexClass = dotNetClass "System.Text.RegularExpressions.Regex"
                local colorPattern = @"^(#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?|rgba?\([0-9., ]+\)|transparent)$"
                return regexClass.IsMatch (sourceContent as string) colorPattern
            ) catch (
                return false
            )
        ),

        fn themeFileHasUsableColors sourceFilePath = (
            if (not (doesFileExist sourceFilePath)) do return false
            local sourceKeys = ini.sectionKeys sourceFilePath "Colors"
            if ((classOf sourceKeys) != Array) do return false
            for colorKey in sourceKeys do (
                if (isValidColorContent (ini.read sourceFilePath "Colors" colorKey)) do return true
            )
            return false
        ),

        fn colorIndex colorKeys colorKey = (
            for keyIndex in 1 to colorKeys.count do (
                if ((toLower colorKeys[keyIndex]) == (toLower colorKey)) do return keyIndex
            )
            return 0
        ),

        fn appendOrReplaceColor paletteInfo colorKey colorContent = (
            if (not (isValidColorContent colorContent)) do return false
            local existingIndex = colorIndex paletteInfo.colorKeys colorKey
            if (existingIndex > 0) then (
                paletteInfo.colorContents[existingIndex] = colorContent
            ) else (
                append paletteInfo.colorKeys colorKey
                append paletteInfo.colorContents colorContent
            )
            return true
        ),

        fn readThemeIntoPalette paletteInfo sourceFilePath isDefaultTheme: false = (
            if (not (doesFileExist sourceFilePath)) do return false
            local themeName = ini.read sourceFilePath "Theme" "Name" defaultValue: paletteInfo.displayName
            if (themeName != "") do paletteInfo.displayName = themeName
            local sourceKeys = ini.sectionKeys sourceFilePath "Colors"
            if ((classOf sourceKeys) != Array) do sourceKeys = #()
            for colorKey in sourceKeys do (
                local colorContent = ini.read sourceFilePath "Colors" colorKey
                if (not (appendOrReplaceColor paletteInfo colorKey colorContent)) do (
                    if (logger != undefined) do logger.logWarning "themes" ("Invalid color [Colors] " + colorKey + " in " + sourceFilePath)
                )
            )
            if (isDefaultTheme and paletteInfo.colorKeys.count == 0) do return false
            return true
        ),

        fn loadPalette requestedThemeKind requestedThemeId = (
            local themeKind = normalizedThemeKind requestedThemeKind
            local requestedId = normalizedThemeId requestedThemeId
            local defaultFilePath = themeFilePath themeKind "default"
            local paletteInfo = MaxPkgThemePaletteData themeId: requestedId
            if (not (readThemeIntoPalette paletteInfo defaultFilePath isDefaultTheme: true)) do (
                if (logger != undefined) do logger.logError "themes" ("Default theme is missing or empty: " + defaultFilePath)
                return paletteInfo
            )
            local requestedFilePath = themeFilePath themeKind requestedId
            if (requestedId != "default") then (
                if (themeFileHasUsableColors requestedFilePath) then (
                    readThemeIntoPalette paletteInfo requestedFilePath
                ) else (
                    if (logger != undefined) do logger.logWarning "themes" ("Theme " + requestedId + " was not found; using default " + themeKind + " theme.")
                    paletteInfo.themeId = "default"
                    paletteInfo.displayName = ini.read defaultFilePath "Theme" "Name" defaultValue: "Default"
                )
            )
            return paletteInfo
        ),

        fn compareThemeInfo leftTheme rightTheme = (
            if ((toLower leftTheme.displayName) < (toLower rightTheme.displayName)) do return -1
            if ((toLower leftTheme.displayName) > (toLower rightTheme.displayName)) do return 1
            return 0
        ),

        fn listThemes requestedThemeKind = (
            local discoveredThemes = #()
            local folderPath = themeFolderPath requestedThemeKind
            if (not (doesDirectoryExist folderPath)) do return discoveredThemes
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                local searchOptionClass = dotNetClass "System.IO.SearchOption"
                local themeFiles = directoryClass.GetFiles folderPath "*.ini" searchOptionClass.TopDirectoryOnly
                for sourceFilePath in themeFiles do (
                    local themeId = toLower (getFilenameFile sourceFilePath)
                    if (isSafeThemeId themeId and themeFileHasUsableColors sourceFilePath) do (
                        local displayName = ini.read sourceFilePath "Theme" "Name" defaultValue: themeId
                        append discoveredThemes (MaxPkgThemeInfoData themeId: themeId displayName: displayName filePath: sourceFilePath)
                    )
                )
                qsort discoveredThemes compareThemeInfo
            ) catch (
                if (logger != undefined) do logger.logWarning "themes" ("Could not discover themes in " + folderPath + ": " + getCurrentException())
            )
            return discoveredThemes
        ),

        fn resolveThemeId requestedThemeKind requestedThemeId = (
            local themeId = normalizedThemeId requestedThemeId
            if (themeFileHasUsableColors (themeFilePath requestedThemeKind themeId)) do return themeId
            if (themeId != "default" and logger != undefined) do logger.logWarning "themes" ("Theme " + themeId + " is unavailable; using default.")
            return "default"
        ),

        fn applyPalette sourceContent paletteInfo = (
            local renderedContent = sourceContent
            for colorIndexNumber in 1 to paletteInfo.colorKeys.count do (
                local tokenContent = "{{" + paletteInfo.colorKeys[colorIndexNumber] + "}}"
                renderedContent = substituteString renderedContent tokenContent paletteInfo.colorContents[colorIndexNumber]
            )
            if ((findString renderedContent "{{") != undefined and logger != undefined) do logger.logWarning "themes" ("Theme " + paletteInfo.themeId + " does not define every template token.")
            return renderedContent
        ),

        fn writeTextFile targetFilePath sourceContent = (
            local fileStream = undefined
            try (
                makeDir (getFilenamePath targetFilePath) all: true
                if (doesFileExist targetFilePath and utils != undefined) do utils.makeFileWritable targetFilePath
                fileStream = createFile targetFilePath
                if (fileStream == undefined) do return false
                format "%" sourceContent to: fileStream
                close fileStream
                fileStream = undefined
                return doesFileExist targetFilePath
            ) catch (
                try (if (fileStream != undefined) do close fileStream) catch ()
                if (logger != undefined) do logger.logError "themes" ("Could not write theme asset " + targetFilePath + ": " + getCurrentException())
                return false
            )
        ),

        fn renderTemplateFiles requestedThemeKind requestedThemeId relativeTemplatePaths = (
            local paletteInfo = loadPalette requestedThemeKind requestedThemeId
            local renderedContent = ""
            for relativeTemplatePath in relativeTemplatePaths do (
                local templateFilePath = runtimeRoot + relativeTemplatePath
                local templateContent = if (utils != undefined) then utils.readText templateFilePath else ""
                if (templateContent == "") then (
                    if (logger != undefined) do logger.logWarning "themes" ("Theme template is empty or unavailable: " + templateFilePath)
                ) else (
                    renderedContent += applyPalette templateContent paletteInfo
                    renderedContent += "\r\n"
                )
            )
            return renderedContent
        ),

        fn managerTemplatePaths = (
            return #(@"ui\common\css\variables.css", @"ui\common\css\layout.css", @"ui\common\css\typography.css", @"ui\common\css\buttons.css", @"ui\common\css\cards.css", @"ui\common\css\forms.css", @"ui\common\css\badges.css", @"ui\common\css\dialogs.css", @"ui\common\css\notifications.css", @"ui\common\css\tables.css", @"ui\manager\manager.css")
        ),

        fn toolbarTemplatePaths = (
            return #(@"ui\common\css\layout.css", @"ui\common\css\typography.css", @"ui\toolbar\toolbar.css")
        ),

        fn resultDialogTemplatePaths = (
            return #(@"ui\common\css\variables.css", @"ui\common\css\layout.css", @"ui\common\css\typography.css", @"ui\common\css\buttons.css", @"ui\common\result-dialog.css")
        ),

        fn renderManagerCss requestedThemeId = (
            return renderTemplateFiles "manager" requestedThemeId (managerTemplatePaths())
        ),

        fn renderToolbarCss requestedThemeId = (
            return renderTemplateFiles "toolbar" requestedThemeId (toolbarTemplatePaths())
        ),

        fn renderResultDialogCss requestedThemeId = (
            return renderTemplateFiles "manager" requestedThemeId (resultDialogTemplatePaths())
        ),

        fn renderIconDirectory requestedThemeKind requestedThemeId targetFolderPath = (
            local sourceIconFolderPath = runtimeRoot + @"ui\common\icons\"
            if (not (doesDirectoryExist sourceIconFolderPath)) do return false
            local paletteInfo = loadPalette requestedThemeKind requestedThemeId
            local isSuccess = true
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                local searchOptionClass = dotNetClass "System.IO.SearchOption"
                local sourceIconFiles = directoryClass.GetFiles sourceIconFolderPath "*.svg" searchOptionClass.TopDirectoryOnly
                makeDir targetFolderPath all: true
                for sourceIconFilePath in sourceIconFiles do (
                    local iconTemplateContent = utils.readText sourceIconFilePath
                    local renderedIconContent = applyPalette iconTemplateContent paletteInfo
                    local targetIconFilePath = targetFolderPath + getFilenameFile sourceIconFilePath + getFilenameType sourceIconFilePath
                    if (not (writeTextFile targetIconFilePath renderedIconContent)) do isSuccess = false
                )
            ) catch (
                if (logger != undefined) do logger.logError "themes" ("Could not render themed icons: " + getCurrentException())
                return false
            )
            return isSuccess
        ),

        fn managerAssetRoot = (
            return runtimeRoot + @"data\themes\manager\"
        ),

        fn toolbarAssetRoot = (
            return runtimeRoot + @"data\themes\toolbar\"
        ),

        fn prepareManagerAssets requestedThemeId = (
            local targetRoot = managerAssetRoot()
            local renderedCss = renderManagerCss requestedThemeId
            local isCssWritten = writeTextFile (targetRoot + "theme.css") renderedCss
            local areIconsWritten = renderIconDirectory "manager" requestedThemeId (targetRoot + @"icons\")
            return isCssWritten and areIconsWritten
        ),

        fn prepareToolbarAssets requestedThemeId = (
            local targetRoot = toolbarAssetRoot()
            local paletteInfo = loadPalette "toolbar" requestedThemeId
            local sourceIconFilePath = runtimeRoot + @"ui\common\icons\maxpkg-logo.svg"
            local targetIconFilePath = targetRoot + @"icons\maxpkg-logo.svg"
            local sourceIconContent = utils.readText sourceIconFilePath
            if (sourceIconContent == "") do return false
            return writeTextFile targetIconFilePath (applyPalette sourceIconContent paletteInfo)
        ),

        fn prepareResultDialogAssets requestedThemeId targetRoot = (
            if (targetRoot == undefined or targetRoot == "") do return false
            local normalizedTargetRoot = utils.ensureSlash targetRoot
            local isCssWritten = writeTextFile (normalizedTargetRoot + "theme.css") (renderResultDialogCss requestedThemeId)
            local areIconsWritten = renderIconDirectory "manager" requestedThemeId (normalizedTargetRoot + @"icons\")
            return isCssWritten and areIconsWritten
        ),

        fn initialize runtimePath iniModule utilsModule loggerModule = (
            runtimeRoot = utilsModule.ensureSlash runtimePath
            ini = iniModule
            utils = utilsModule
            logger = loggerModule
            return runtimeRoot != ""
        )
    )

    MaxPkgThemesModule()
)
