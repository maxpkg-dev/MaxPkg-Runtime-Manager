-- Builds and controls the dockable MaxPkg toolbar.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local toolbarOwner = undefined

    rollout MaxPkgRuntimeToolbarRollout "" width: 1200 height: 50 (
        dotNetControl browser "System.Windows.Forms.WebBrowser" pos: [0,0] width: 1200 height: 50

        on browser Navigating eventSender navigationArgs do (
            if (toolbarOwner != undefined) do toolbarOwner.onNavigate navigationArgs
        )

        on browser DocumentCompleted eventSender eventArgs do (
            try (
                browser.Document.InvokeScript "layout"
            ) catch (
            )
        )

        on MaxPkgRuntimeToolbarRollout resized size do (
            browser.width = size.x
            browser.height = size.y
            try (
                browser.Document.InvokeScript "layout"
            ) catch (
            )
        )

        on MaxPkgRuntimeToolbarRollout open do (
            if (toolbarOwner != undefined) do toolbarOwner.onOpen browser
        )

        on MaxPkgRuntimeToolbarRollout close do (
            try (
                enableAccelerators = true
            ) catch (
            )
        )
    )

    struct MaxPkgToolbarModule (
        owner,
        utils,
        logger,
        themes,
        runtimeRoot,
        rolloutRef,

        fn isHidden guid = (
            for hiddenGuid in owner.settings.hiddenPackages where (toLower hiddenGuid) == (toLower guid) do return true
            return false
        ),

        fn comparePackages leftPackage rightPackage = (
            if (leftPackage.toolbarOrder < rightPackage.toolbarOrder) do return -1
            if (leftPackage.toolbarOrder > rightPackage.toolbarOrder) do return 1
            if ((toLower leftPackage.packageName) < (toLower rightPackage.packageName)) do return -1
            if ((toLower leftPackage.packageName) > (toLower rightPackage.packageName)) do return 1
            return 0
        ),

        fn orderedPackages = (
            local visiblePackages = #()
            local usedGuids = #()
            local remainingPackages = #()
            for wantedGuid in owner.settings.toolbarOrder do (
                for package in owner.packages where package.toolbarVisible and not (isHidden package.guid) and (toLower package.guid) == (toLower wantedGuid) do (
                    append visiblePackages package
                    append usedGuids package.guid
                )
            )
            for package in owner.packages where package.toolbarVisible and not (isHidden package.guid) do (
                local guidExists = false
                for usedGuid in usedGuids where (toLower usedGuid) == (toLower package.guid) do guidExists = true
                if (not guidExists) do append remainingPackages package
            )
            qsort remainingPackages comparePackages
            join visiblePackages remainingPackages
            return visiblePackages
        ),

        fn packageButtonHtml packageInfo = (
            local iconHtml = "<span class='fallback'>+</span>"
            if (packageInfo.iconFile != "" and doesFileExist packageInfo.iconFile) do (
                iconHtml = "<img class='ico' src='" + (utils.htmlEscape (utils.fileUrl packageInfo.iconFile)) + "'>"
            )
            local titleSource = case owner.settings.toolbarTitleMode of (
                "buttonName": packageInfo.buttonName
                default: packageInfo.packageName
            )
            if (titleSource == "") do titleSource = packageInfo.packageName
            local buttonLabel = utils.htmlEscape titleSource
            local subtitleLabel = case owner.settings.toolbarSubtitleMode of (
                "none": ""
                "developer": utils.htmlEscape packageInfo.developer
                default: "v" + (utils.htmlEscape packageInfo.version)
            )
            local labelContainerClass = "txt single-line"
            local subtitleHtml = ""
            local buttonSizeClass = case owner.settings.toolbarButtonSize of (
                "large": "size-large"
                "small": "size-small"
                "icon": "size-icon"
                default: "size-medium"
            )
            if (subtitleLabel != "") do (
                labelContainerClass = "txt"
                subtitleHtml = "<span class='subtitle'>" + subtitleLabel + "</span>"
            )
            return "<a class='toolBtn " + buttonSizeClass + "' href='maxpkg://run/" + packageInfo.guid + "' title='" + (utils.htmlEscape packageInfo.packageName) + "'>" + iconHtml + "<span class='" + labelContainerClass + "'><span class='name'>" + buttonLabel + "</span>" + subtitleHtml + "</span></a>"
        ),

        fn assetContent relativePath = (
            local assetPath = runtimeRoot + relativePath
            local sourceContent = utils.readText assetPath
            if (sourceContent == "") do logger.logWarning "toolbar" ("UI asset is empty or unavailable: " + assetPath)
            return sourceContent
        ),

        fn buildHtml = (
            if (themes != undefined) do themes.prepareToolbarAssets owner.settings.toolbarTheme
            local brandIconFilePath = runtimeRoot + @"data\themes\toolbar\icons\maxpkg-logo.svg"
            local brandIconUrl = utils.htmlEscape (utils.fileUrl brandIconFilePath)
            local themeCss = if (themes != undefined) then themes.renderToolbarCss owner.settings.toolbarTheme else ""
            local html = "<!doctype html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'><meta charset='utf-8'>"
            html += "<style>" + themeCss
            html += "</style></head><body>"
            html += "<div class='wrap' id='wrap'><a class='brand' id='brand' href='maxpkg://ui/openManager' title='Open MaxPkg Manager'><img class='brand-icon' src='" + brandIconUrl + "' alt=''><span>maxpkg</span></a><a class='arrow' id='leftArrow' href='maxpkg://ui/scrollLeft'>&lsaquo;</a><div class='viewport' id='viewport'><div class='strip' id='strip'>"
            for package in orderedPackages() do html += packageButtonHtml package
            html += "</div></div><a class='arrow' id='rightArrow' href='maxpkg://ui/scrollRight'>&rsaquo;</a></div>"
            html += "<script>" + (assetContent @"ui\toolbar\toolbar.js") + "</script></body></html>"
            return html
        ),

        fn configureBrowser browserControl = (
            local dockStyle = dotNetClass "System.Windows.Forms.DockStyle"
            browserControl.Dock = dockStyle.Fill
            browserControl.ScriptErrorsSuppressed = true
            browserControl.ScrollBarsEnabled = false
            browserControl.IsWebBrowserContextMenuEnabled = false
            browserControl.AllowWebBrowserDrop = false
            browserControl.WebBrowserShortcutsEnabled = false
            browserControl.DocumentText = buildHtml()
            return true
        ),

        fn unregister = (
            try (
                if (rolloutRef.dialogBar) do cui.UnRegisterDialogBar rolloutRef
                return true
            ) catch (
                logger.logWarning "toolbar" ("Could not unregister toolbar: " + getCurrentException())
                return false
            )
        ),

        fn dockToolbar = (
            local dockLocation = if (owner.settings.toolbarDockPosition == "bottom") then #cui_dock_bottom else #cui_dock_top
            cui.DockDialogBar rolloutRef dockLocation
            return true
        ),

        fn onNavigate navigationArgs = (
            local navigationUrl = ""
            try (
                navigationUrl = navigationArgs.Url.AbsoluteUri as string
            ) catch (
                logger.logWarning "toolbar" ("Could not read navigation URL: " + getCurrentException())
                return false
            )
            if (matchPattern navigationUrl pattern: "maxpkg://*" ignoreCase: true) do (
                navigationArgs.Cancel = true
                try (
                    enableAccelerators = true
                ) catch (
                )
                if (matchPattern navigationUrl pattern: "maxpkg://run/*" ignoreCase: true) do (
                    local navigationPrefix = "maxpkg://run/"
                    local packageGuid = substring navigationUrl (navigationPrefix.count + 1) (navigationUrl.count - navigationPrefix.count)
                    owner.run packageGuid
                )
                if (matchPattern navigationUrl pattern: "maxpkg://ui/*" ignoreCase: true) do (
                    local navigationPrefix = "maxpkg://ui/"
                    local commandText = substring navigationUrl (navigationPrefix.count + 1) (navigationUrl.count - navigationPrefix.count)
                    case commandText of (
                        "openManager": owner.openManager()
                        "scrollLeft": try (
                            rolloutRef.browser.Document.InvokeScript "moveLeft"
                        ) catch (
                        )
                        "scrollRight": try (
                            rolloutRef.browser.Document.InvokeScript "moveRight"
                        ) catch (
                        )
                    )
                )
            )
            return true
        ),

        fn onOpen browserControl = (
            unregister()
            try (
                setDialogPos rolloutRef [-1000,-1000]
            ) catch (
            )
            try (
                cui.RegisterDialogBar rolloutRef style: #(#cui_floatable, #cui_dock_horz, #cui_handles, #cui_max_sized, #style_toolwindow, #style_sysmenu)
                dockToolbar()
                return configureBrowser browserControl
            ) catch (
                logger.logError "toolbar" ("Could not register toolbar: " + getCurrentException())
                return false
            )
        ),

        fn hideToolbar = (
            local isUnregistered = unregister()
            try (
                destroyDialog rolloutRef
            ) catch (
                logger.logWarning "toolbar" ("Could not destroy toolbar: " + getCurrentException())
                return false
            )
            return isUnregistered
        ),

        fn shutdownToolbar = (
            local isReleased = hideToolbar()
            try (
                enableAccelerators = true
            ) catch (
            )
            if (isReleased) do toolbarOwner = undefined
            return isReleased
        ),

        fn build = (
            if (not owner.settings.toolbarVisible) do return hideToolbar()
            try (
                rolloutRef.browser.DocumentText = buildHtml()
                dockToolbar()
                return true
            ) catch (
                hideToolbar()
                try (
                    createDialog rolloutRef width: 1200 height: 50 style: #(#style_sysmenu, #style_toolwindow)
                    return true
                ) catch (
                    logger.logError "toolbar" ("Could not create toolbar: " + getCurrentException())
                    return false
                )
            )
        ),

        fn initialize runtimeOwner runtimePath utilsModule loggerModule moduleInstance = (
            owner = runtimeOwner
            runtimeRoot = runtimePath
            utils = utilsModule
            logger = loggerModule
            rolloutRef = MaxPkgRuntimeToolbarRollout
            toolbarOwner = moduleInstance
            return true
        )
    )

    MaxPkgToolbarModule()
)
