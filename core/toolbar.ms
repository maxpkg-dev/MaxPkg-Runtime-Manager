-- Builds and controls the dockable MaxPkg toolbar.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local toolbarOwner = undefined

    rollout MaxPkgRuntimeToolbarRollout "" width:1200 height:50 (
        dotNetControl browser "System.Windows.Forms.WebBrowser" pos:[0,0] width:1200 height:50

        on browser Navigating sender args do (
            if toolbarOwner != undefined do toolbarOwner.onNavigate args
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
            if toolbarOwner != undefined do toolbarOwner.onOpen browser
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
        runtimeRoot,
        rolloutRef,

        fn isHidden guid = (
            for hiddenGuid in owner.settings.hiddenPackages where (toLower hiddenGuid) == (toLower guid) do return true
            return false
        ),

        fn comparePackages leftPackage rightPackage = (
            if leftPackage.toolbarOrder < rightPackage.toolbarOrder do return -1
            if leftPackage.toolbarOrder > rightPackage.toolbarOrder do return 1
            if (toLower leftPackage.name) < (toLower rightPackage.name) do return -1
            if (toLower leftPackage.name) > (toLower rightPackage.name) do return 1
            return 0
        ),

        fn orderedPackages = (
            local visible = #()
            local used = #()
            local remaining = #()
            for wantedGuid in owner.settings.toolbarOrder do (
                for package in owner.packages where package.toolbarVisible and not (isHidden package.guid) and (toLower package.guid) == (toLower wantedGuid) do (
                    append visible package
                    append used package.guid
                )
            )
            for package in owner.packages where package.toolbarVisible and not (isHidden package.guid) do (
                local exists = false
                for guid in used where (toLower guid) == (toLower package.guid) do exists = true
                if not exists do append remaining package
            )
            qsort remaining comparePackages
            join visible remaining
            return visible
        ),

        fn packageButtonHtml packageInfo = (
            local iconHtml = "<span class='fallback'>+</span>"
            if (packageInfo.icon != "" and doesFileExist packageInfo.icon) do (
                iconHtml = "<img class='ico' src='" + (utils.htmlEscape (utils.fileUrl packageInfo.icon)) + "'>"
            )
            local buttonLabel = utils.htmlEscape packageInfo.buttonName
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
            return "<a class='toolBtn " + buttonSizeClass + "' href='maxpkg://run/" + packageInfo.guid + "' title='" + (utils.htmlEscape packageInfo.name) + "'>" + iconHtml + "<span class='" + labelContainerClass + "'><span class='name'>" + buttonLabel + "</span>" + subtitleHtml + "</span></a>"
        ),

        fn assetContent relativePath = (
            local assetPath = runtimeRoot + relativePath
            local sourceContent = utils.readText assetPath
            if sourceContent == "" do logger.logWarning "toolbar" ("UI asset is empty or unavailable: " + assetPath)
            return sourceContent
        ),

        fn buildHtml = (
            local brandIconFilePath = runtimeRoot + @"ui\common\icons\maxpkg-logo.svg"
            local brandIconUrl = utils.htmlEscape (utils.fileUrl brandIconFilePath)
            local html = "<!doctype html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'><meta charset='utf-8'>"
            html += "<style>" + (assetContent @"ui\common\css\variables.css")
            html += assetContent @"ui\common\css\layout.css"
            html += assetContent @"ui\common\css\typography.css"
            html += assetContent @"ui\toolbar\toolbar.css"
            html += "</style></head><body>"
            html += "<div class='wrap' id='wrap'><a class='brand' id='brand' href='maxpkg://ui/openManager' title='Open MaxPkg Manager'><img class='brand-icon' src='" + brandIconUrl + "' alt=''><span>maxpkg</span></a><a class='arrow' id='leftArrow' href='maxpkg://ui/scrollLeft'>&lsaquo;</a><div class='viewport' id='viewport'><div class='strip' id='strip'>"
            for package in orderedPackages() do html += packageButtonHtml package
            html += "</div></div><a class='arrow' id='rightArrow' href='maxpkg://ui/scrollRight'>&rsaquo;</a></div>"
            html += "<script>" + (assetContent @"ui\toolbar\toolbar.js") + "</script></body></html>"
            return html
        ),

        fn configureBrowser browser = (
            browser.ScriptErrorsSuppressed = true
            browser.ScrollBarsEnabled = false
            browser.IsWebBrowserContextMenuEnabled = false
            browser.AllowWebBrowserDrop = false
            browser.WebBrowserShortcutsEnabled = false
            browser.DocumentText = buildHtml()
            return true
        ),

        fn unregister = (
            try (
                if rolloutRef.dialogBar do cui.UnRegisterDialogBar rolloutRef
                return true
            ) catch (
                logger.logWarning "toolbar" ("Could not unregister toolbar: " + getCurrentException())
                return false
            )
        ),

        fn onNavigate args = (
            local url = ""
            try (
                url = args.Url.AbsoluteUri as string
            ) catch (
                logger.logWarning "toolbar" ("Could not read navigation URL: " + getCurrentException())
                return false
            )
            if matchPattern url pattern:"maxpkg://*" ignoreCase:true do (
                args.Cancel = true
                try (
                    enableAccelerators = true
                ) catch (
                )
                if matchPattern url pattern:"maxpkg://run/*" ignoreCase:true do (
                    local prefix = "maxpkg://run/"
                    local guid = substring url (prefix.count + 1) (url.count - prefix.count)
                    owner.run guid
                )
                if matchPattern url pattern:"maxpkg://ui/*" ignoreCase:true do (
                    local prefix = "maxpkg://ui/"
                    local command = substring url (prefix.count + 1) (url.count - prefix.count)
                    case command of (
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

        fn onOpen browser = (
            unregister()
            try (
                setDialogPos rolloutRef [-1000,-1000]
            ) catch (
            )
            try (
                cui.RegisterDialogBar rolloutRef style:#(#cui_floatable, #cui_dock_horz, #cui_handles, #cui_max_sized, #style_toolwindow, #style_sysmenu)
                cui.DockDialogBar rolloutRef #cui_dock_top
                return configureBrowser browser
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
            if isReleased do toolbarOwner = undefined
            return isReleased
        ),

        fn build = (
            if not owner.settings.toolbarVisible do return hideToolbar()
            try (
                rolloutRef.browser.DocumentText = buildHtml()
                return true
            ) catch (
                hideToolbar()
                try (
                    createDialog rolloutRef width:1200 height:50 style:#(#style_sysmenu, #style_toolwindow)
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
