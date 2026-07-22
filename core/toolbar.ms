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

        fn packageButtonHtml package = (
            local iconHtml = "<span class='fallback'>+</span>"
            if package.icon != "" and doesFileExist package.icon do
                iconHtml = "<img class='ico' src='" + (utils.htmlEscape (utils.fileUrl package.icon)) + "'>"
            local title = utils.htmlEscape package.buttonName
            local versionText = "v" + (utils.htmlEscape package.version)
            return "<a class='toolBtn' href='maxpkg://run/" + package.guid + "' title='" + (utils.htmlEscape package.name) + "'>" + iconHtml + "<span class='txt'><span class='name'>" + title + "</span><span class='version'>" + versionText + "</span></span></a>"
        ),

        fn buildHtml = (
            local html = "<!doctype html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'><meta charset='utf-8'>"
            html += "<style>"
            html += "html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:#3b3b3b;font-family:Segoe UI,Arial,sans-serif;font-size:12px;color:#ddd}"
            html += "*{box-sizing:border-box}"
            html += ".wrap{position:relative;height:50px;overflow:hidden;border-top:1px solid #4b4b4b;border-bottom:1px solid #222}"
            html += ".brand,.arrow,.toolBtn{height:38px;border:1px solid #666;border-radius:4px;background:#484848;color:#eee;text-decoration:none}"
            html += ".brand,.arrow{position:absolute;top:5px;display:block}"
            html += ".brand{line-height:36px;padding:0 10px;font-weight:bold}"
            html += ".brand:hover,.arrow:hover,.toolBtn:hover{background:#566783;border-color:#8aa7d8;color:#fff}"
            html += ".arrow{display:none;width:25px;line-height:34px;text-align:center;font-size:18px}"
            html += ".viewport{position:absolute;top:5px;height:40px;overflow:hidden}"
            html += ".strip{position:absolute;left:0;top:0;height:40px;white-space:nowrap}"
            html += ".toolBtn{display:inline-block;vertical-align:top;width:116px;margin-right:5px;padding:3px 6px;overflow:hidden}"
            html += ".ico,.fallback{float:left;width:24px;height:24px;margin:3px 6px 0 0;border-radius:3px}"
            html += ".fallback{line-height:23px;text-align:center;background:#607ec7;color:white;font-size:18px}"
            html += ".txt{display:block;overflow:hidden}"
            html += ".name,.version{display:block;width:75px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}"
            html += ".name{font-weight:bold;line-height:15px;color:#f0f0f0}"
            html += ".version{font-size:10px;line-height:13px;color:#bbb}"
            html += "</style></head><body>"
            html += "<div class='wrap' id='wrap'><a class='brand' id='brand' href='maxpkg://ui/openManager'>maxpkg</a><a class='arrow' id='leftArrow' href='maxpkg://ui/scrollLeft'>&lsaquo;</a><div class='viewport' id='viewport'><div class='strip' id='strip'>"
            for package in orderedPackages() do html += packageButtonHtml package
            html += "</div></div><a class='arrow' id='rightArrow' href='maxpkg://ui/scrollRight'>&rsaquo;</a></div>"
            html += "<script>"
            html += "var scrollOffset=0;"
            html += "var scrollStep=160;"
            html += "function byId(elementId){return document.getElementById(elementId);}"
            html += "function measureStrip(){var links=byId('strip').getElementsByTagName('a');var totalWidth=0;var index=0;for(index=0;index<links.length;index+=1){totalWidth+=links[index].offsetWidth+5;}return totalWidth;}"
            html += "function layout(){var wrap=byId('wrap');var viewport=byId('viewport');var strip=byId('strip');var leftArrow=byId('leftArrow');var rightArrow=byId('rightArrow');var brand=byId('brand');var edge=7;var gap=5;var fullWidth=measureStrip();var cursor=edge;var rightEdge=wrap.clientWidth-edge;var availableWidth=0;var maxOffset=0;brand.style.left=cursor+'px';cursor+=brand.offsetWidth+gap;availableWidth=rightEdge-cursor;strip.style.width=(fullWidth>0?fullWidth:1)+'px';if(fullWidth>availableWidth){leftArrow.style.display='block';rightArrow.style.display='block';leftArrow.style.left=cursor+'px';cursor+=leftArrow.offsetWidth+gap;availableWidth=rightEdge-cursor-rightArrow.offsetWidth-gap;if(availableWidth<20){availableWidth=20;}viewport.style.left=cursor+'px';viewport.style.width=availableWidth+'px';rightArrow.style.left=(cursor+availableWidth+gap)+'px';}else{leftArrow.style.display='none';rightArrow.style.display='none';scrollOffset=0;viewport.style.left=cursor+'px';viewport.style.width=(availableWidth>0?availableWidth:1)+'px';}maxOffset=Math.max(0,fullWidth-availableWidth);if(scrollOffset>maxOffset){scrollOffset=maxOffset;}if(scrollOffset<0){scrollOffset=0;}strip.style.left=(-scrollOffset)+'px';}"
            html += "function moveLeft(){scrollOffset-=scrollStep;layout();}"
            html += "function moveRight(){scrollOffset+=scrollStep;layout();}"
            html += "window.onload=layout;"
            html += "window.onresize=layout;"
            html += "</script></body></html>"
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

        fn initialize runtimeOwner utilsModule loggerModule moduleInstance = (
            owner = runtimeOwner
            utils = utilsModule
            logger = loggerModule
            rolloutRef = MaxPkgRuntimeToolbarRollout
            toolbarOwner = moduleInstance
            return true
        )
    )

    MaxPkgToolbarModule()
)
