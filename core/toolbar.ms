-- Builds and controls docked and floating MaxPkg toolbars.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local toolbarOwner = undefined

    rollout MaxPkgRuntimeToolbarRollout "" width: 1200 height: 50 (
        dotNetControl browser "System.Windows.Forms.WebBrowser" pos: [0,0] width: 1200 height: 50
        timer toolbarLayoutTimer interval: 100 active: false

        on browser Navigating eventSender navigationArgs do (
            if (toolbarOwner != undefined) do toolbarOwner.onNavigate navigationArgs
        )

        on browser DocumentCompleted eventSender eventArgs do (
            if (toolbarOwner != undefined) do toolbarOwner.onDocumentReady eventSender eventArgs
        )

        on MaxPkgRuntimeToolbarRollout resized dialogSize do (
            browser.width = amax 1 dialogSize.x
            browser.height = amax 1 dialogSize.y
            if (toolbarOwner != undefined and toolbarOwner.uiScale != undefined) do toolbarOwner.uiScale.applyBrowserScale browser
            try (
                browser.Document.InvokeScript "layout"
            ) catch (
            )
            toolbarLayoutTimer.active = true
        )

        on MaxPkgRuntimeToolbarRollout open do (
            if (toolbarOwner != undefined) do toolbarOwner.onOpen browser
            toolbarLayoutTimer.active = true
        )

        on toolbarLayoutTimer tick do (
            toolbarLayoutTimer.active = false
            if (toolbarOwner != undefined) do toolbarOwner.syncDockedBrowser browser
        )

        on MaxPkgRuntimeToolbarRollout close do (
            toolbarLayoutTimer.active = false
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
        uiScale,
        runtimeRoot,
        rolloutRef,
        activeBrowser,
        floatingForm,
        floatingBrowser,
        floatingDragHandle,
        floatingOwnerWindow,
        floatingDragging = false,
        floatingDragOffset,
        floatingCloseAllowed = false,
        floatingNaturalWidth = 1,
        floatingNaturalHeight = 1,
        floatingScalePercentage = 100,
        dragNormalColor,
        dragHoverColor,
        dragPressedColor,
        dragDotColor,

        fn isFloatingMode toolbarMode = (
            return toolbarMode == "floatinghorizontal" or toolbarMode == "floatingvertical"
        ),

        fn isVerticalMode toolbarMode = (
            return toolbarMode == "left" or toolbarMode == "right" or toolbarMode == "floatingvertical"
        ),

        fn usesIconOnlyStructure toolbarMode = (
            if (isVerticalMode toolbarMode or isFloatingMode toolbarMode) do return true
            return owner.settings.toolbarButtonSize == "icon"
        ),

        fn iconOnlyButtonLength = (
            local isCompactDensity = owner.settings.toolbarDensity == "compact"
            case owner.settings.toolbarIconSize of (
                "small": return if (isCompactDensity) then 18 else 22
                "medium": return if (isCompactDensity) then 22 else 26
                default: return if (isCompactDensity) then 26 else 30
            )
        ),

        fn iconOnlyOuterPadding = (
            return if (owner.settings.toolbarDensity == "compact") then 2 else 10
        ),

        fn iconOnlyToolbarThickness = (
            return (iconOnlyButtonLength()) + (iconOnlyOuterPadding())
        ),

        fn iconOnlyButtonGap = (
            return if (owner.settings.toolbarDensity == "compact") then 2 else 4
        ),

        fn textButtonHeight = (
            case owner.settings.toolbarIconSize of (
                "small": return 30
                "medium": return 34
                default: return 38
            )
        ),

        fn textToolbarThickness = (
            -- Horizontal CUI docking consumes four pixels before the WebBrowser
            -- receives its client height. Compact HTML needs a full 40 px client
            -- area for a 38 px button with one pixel above and below.
            local outerPadding = if (owner.settings.toolbarDensity == "compact") then 6 else 12
            return (textButtonHeight()) + outerPadding
        ),

        fn isHidden packageGuid = (
            for hiddenGuid in owner.settings.hiddenPackages where (toLower hiddenGuid) == (toLower packageGuid) do return true
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
                for packageInfo in owner.packages where packageInfo.toolbarVisible and not (isHidden packageInfo.guid) and (toLower packageInfo.guid) == (toLower wantedGuid) do (
                    append visiblePackages packageInfo
                    append usedGuids packageInfo.guid
                )
            )
            for packageInfo in owner.packages where packageInfo.toolbarVisible and not (isHidden packageInfo.guid) do (
                local guidExists = false
                for usedGuid in usedGuids where (toLower usedGuid) == (toLower packageInfo.guid) do guidExists = true
                if (not guidExists) do append remainingPackages packageInfo
            )
            qsort remainingPackages comparePackages
            join visiblePackages remainingPackages
            return visiblePackages
        ),

        fn packageButtonHtml packageInfo toolbarMode = (
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
            local buttonSizeClass = if (usesIconOnlyStructure toolbarMode) then "size-icon" else case owner.settings.toolbarButtonSize of (
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

        fn availableUpdateCount = (
            local updateCount = 0
            for packageInfo in owner.packages where packageInfo.updateAvailable do updateCount += 1
            return updateCount
        ),

        fn assetContent relativePath = (
            local assetPath = runtimeRoot + relativePath
            local sourceContent = utils.readText assetPath
            if (sourceContent == "") do logger.logWarning "toolbar" ("UI asset is empty or unavailable: " + assetPath)
            return sourceContent
        ),

        fn buildHtml toolbarMode = (
            if (themes != undefined) do themes.prepareToolbarAssets owner.settings.toolbarTheme
            local brandIconFilePath = runtimeRoot + @"data\themes\toolbar\icons\maxpkg-logo.svg"
            local brandIconUrl = utils.htmlEscape (utils.fileUrl brandIconFilePath)
            local themeCss = if (themes != undefined) then themes.renderToolbarCss owner.settings.toolbarTheme else ""
            local updateCount = availableUpdateCount()
            local updateBadgeHtml = if (updateCount > 0) then "<span class='brand-update-badge'>" + (updateCount as string) + "</span>" else ""
            local brandTitle = if (updateCount > 0) then ((updateCount as string) + " package update(s) available. Open MaxPkg Manager") else "Open MaxPkg Manager"
            local brandClass = if (usesIconOnlyStructure toolbarMode) then "brand brand-compact" else "brand"
            local brandHtml = "<a class='" + brandClass + "' id='brand' href='maxpkg://ui/openManager' title='" + (utils.htmlEscape brandTitle) + "'><img class='brand-icon' src='" + brandIconUrl + "' alt=''><span class='brand-label'>maxpkg</span>" + updateBadgeHtml + "</a>"
            local html = "<!doctype html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'><meta charset='utf-8'>"
            html += "<style>" + themeCss + "</style></head><body class='toolbar-mode-" + toolbarMode + " toolbar-density-" + owner.settings.toolbarDensity + " toolbar-icons-" + owner.settings.toolbarIconSize + "' data-toolbar-mode='" + toolbarMode + "'>"
            if (usesIconOnlyStructure toolbarMode) then (
                html += "<div class='wrap wrap-compact' id='wrap'><div class='viewport viewport-compact' id='viewport'><div class='strip strip-compact' id='strip'>" + brandHtml
                for packageInfo in orderedPackages() do html += packageButtonHtml packageInfo toolbarMode
                html += "</div></div><a class='arrow' id='leftArrow' href='maxpkg://ui/scrollLeft'>&lsaquo;</a><a class='arrow' id='rightArrow' href='maxpkg://ui/scrollRight'>&rsaquo;</a></div>"
            ) else (
                html += "<div class='wrap wrap-normal' id='wrap'>" + brandHtml + "<a class='arrow' id='leftArrow' href='maxpkg://ui/scrollLeft'>&lsaquo;</a><div class='viewport' id='viewport'><div class='strip' id='strip'>"
                for packageInfo in orderedPackages() do html += packageButtonHtml packageInfo toolbarMode
                html += "</div></div><a class='arrow' id='rightArrow' href='maxpkg://ui/scrollRight'>&rsaquo;</a></div>"
            )
            html += "<script>" + (assetContent @"ui\toolbar\toolbar.js") + "</script></body></html>"
            return html
        ),

        fn configureBrowser browserControl toolbarMode = (
            local dockStyle = dotNetClass "System.Windows.Forms.DockStyle"
            browserControl.Dock = dockStyle.Fill
            browserControl.ScriptErrorsSuppressed = true
            browserControl.ScrollBarsEnabled = false
            browserControl.IsWebBrowserContextMenuEnabled = false
            browserControl.AllowWebBrowserDrop = false
            browserControl.WebBrowserShortcutsEnabled = false
            activeBrowser = browserControl
            browserControl.DocumentText = buildHtml toolbarMode
            return true
        ),

        fn invokeLayout browserControl = (
            if (browserControl == undefined or browserControl.Document == undefined) do return false
            try (
                browserControl.Document.InvokeScript "layout"
                return true
            ) catch (
                return false
            )
        ),

        fn syncDockedBrowser browserControl = (
            if (browserControl == undefined) do return false
            local dialogSize = try (getDialogSize rolloutRef) catch ([browserControl.width, browserControl.height])
            browserControl.width = amax 1 dialogSize.x
            browserControl.height = amax 1 dialogSize.y
            if (uiScale != undefined) do uiScale.applyBrowserScale browserControl
            return invokeLayout browserControl
        ),

        fn onDocumentReady browserControl eventArgs = (
            if (browserControl == undefined or browserControl.Document == undefined) do return false
            if (uiScale != undefined) do uiScale.applyBrowserScale browserControl
            return invokeLayout browserControl
        ),

        fn unregisterDockedToolbar = (
            try (
                if (rolloutRef.dialogBar) do cui.UnRegisterDialogBar rolloutRef
                return true
            ) catch (
                return true
            )
        ),

        fn destroyDockedToolbar = (
            unregisterDockedToolbar()
            try (
                destroyDialog rolloutRef
            ) catch (
            )
            return true
        ),

        fn detachFloatingEvents = (
            try (if (floatingBrowser != undefined) do dotNet.removeEventHandler floatingBrowser "Navigating" toolbarOwner.handleFloatingNavigating) catch ()
            try (if (floatingBrowser != undefined) do dotNet.removeEventHandler floatingBrowser "DocumentCompleted" toolbarOwner.handleFloatingDocumentCompleted) catch ()
            try (if (floatingDragHandle != undefined) do dotNet.removeEventHandler floatingDragHandle "Paint" toolbarOwner.handleDragPaint) catch ()
            try (if (floatingDragHandle != undefined) do dotNet.removeEventHandler floatingDragHandle "MouseEnter" toolbarOwner.handleDragMouseEnter) catch ()
            try (if (floatingDragHandle != undefined) do dotNet.removeEventHandler floatingDragHandle "MouseLeave" toolbarOwner.handleDragMouseLeave) catch ()
            try (if (floatingDragHandle != undefined) do dotNet.removeEventHandler floatingDragHandle "MouseDown" toolbarOwner.handleDragMouseDown) catch ()
            try (if (floatingDragHandle != undefined) do dotNet.removeEventHandler floatingDragHandle "MouseMove" toolbarOwner.handleDragMouseMove) catch ()
            try (if (floatingDragHandle != undefined) do dotNet.removeEventHandler floatingDragHandle "MouseUp" toolbarOwner.handleDragMouseUp) catch ()
            try (if (floatingForm != undefined) do dotNet.removeEventHandler floatingForm "FormClosing" toolbarOwner.handleFloatingFormClosing) catch ()
            return true
        ),

        fn disposeFloatingToolbar = (
            local formToDispose = floatingForm
            local browserToDispose = floatingBrowser
            local handleToDispose = floatingDragHandle
            local ownerWindowToRelease = floatingOwnerWindow
            floatingCloseAllowed = true
            detachFloatingEvents()
            floatingForm = undefined
            floatingBrowser = undefined
            floatingDragHandle = undefined
            floatingOwnerWindow = undefined
            floatingDragging = false
            floatingDragOffset = undefined
            floatingScalePercentage = 100
            activeBrowser = undefined
            try (
                if (formToDispose != undefined) do (
                    formToDispose.Hide()
                    formToDispose.Close()
                    formToDispose.Dispose()
                )
            ) catch (
            )
            try (if (browserToDispose != undefined) do browserToDispose.Dispose()) catch ()
            try (if (handleToDispose != undefined) do handleToDispose.Dispose()) catch ()
            try (if (ownerWindowToRelease != undefined) do ownerWindowToRelease.ReleaseHandle()) catch ()
            floatingCloseAllowed = false
            return true
        ),

        fn hideToolbar = (
            disposeFloatingToolbar()
            destroyDockedToolbar()
            try (
                enableAccelerators = true
            ) catch (
            )
            return true
        ),

        fn screenForPosition positionX positionY = (
            local screenClass = dotNetClass "System.Windows.Forms.Screen"
            if (positionX < 0 or positionY < 0) do (
                try (
                    local maxWindowPointer = dotNetObject "System.IntPtr" (windows.getMAXHWND())
                    return screenClass.FromHandle maxWindowPointer
                ) catch (
                    return screenClass.PrimaryScreen
                )
            )
            local screenPoint = dotNetObject "System.Drawing.Point" positionX positionY
            return screenClass.FromPoint screenPoint
        ),

        fn scaledSize baseSize scalePercentage = (
            return amax 1 (floor (((baseSize as float) * scalePercentage / 100.0) + 0.5))
        ),

        fn requestedFloatingPosition toolbarMode workingArea = (
            local savedX = if (toolbarMode == "floatingvertical") then owner.settings.floatingVerticalX else owner.settings.floatingHorizontalX
            local savedY = if (toolbarMode == "floatingvertical") then owner.settings.floatingVerticalY else owner.settings.floatingHorizontalY
            if (savedX < 0 or savedY < 0) do (
                local actualFormWidth = if (floatingForm != undefined) then floatingForm.Width else floatingNaturalWidth
                local actualFormHeight = if (floatingForm != undefined) then floatingForm.Height else floatingNaturalHeight
                local centeredX = workingArea.Left + (floor (((workingArea.Width - actualFormWidth) as float) / 2.0))
                local centeredY = workingArea.Top + (floor (((workingArea.Height - actualFormHeight) as float) / 2.0))
                return [centeredX, centeredY]
            )
            return [savedX, savedY]
        ),

        fn clampFloatingPosition requestedPosition formWidth formHeight workingArea = (
            local maximumX = amax workingArea.Left (workingArea.Right - formWidth)
            local maximumY = amax workingArea.Top (workingArea.Bottom - formHeight)
            return [amax workingArea.Left (amin maximumX requestedPosition.x), amax workingArea.Top (amin maximumY requestedPosition.y)]
        ),

        fn applyFloatingSize workingArea = (
            if (floatingForm == undefined) do return false
            local targetWidth = amin floatingNaturalWidth (amax 1 (workingArea.Width - 48))
            local targetHeight = amin floatingNaturalHeight (amax 1 (workingArea.Height - 48))
            local minimumFormSize = dotNetObject "System.Drawing.Size" 1 1
            local unlimitedFormSize = dotNetObject "System.Drawing.Size" 0 0
            local fixedFormSize = dotNetObject "System.Drawing.Size" targetWidth targetHeight
            floatingForm.MinimumSize = minimumFormSize
            floatingForm.MaximumSize = unlimitedFormSize
            floatingForm.ClientSize = fixedFormSize
            floatingForm.MinimumSize = fixedFormSize
            floatingForm.MaximumSize = fixedFormSize
            return true
        ),

        fn updateFloatingGeometry toolbarMode workingArea scalePercentage = (
            if (floatingForm == undefined or floatingDragHandle == undefined) do return false
            local normalizedScalePercentage = amax 1 scalePercentage
            local buttonLength = scaledSize (iconOnlyButtonLength()) normalizedScalePercentage
            local floatingThickness = scaledSize (iconOnlyToolbarThickness()) normalizedScalePercentage
            local buttonGap = scaledSize (iconOnlyButtonGap()) normalizedScalePercentage
            local outerPadding = scaledSize (iconOnlyOuterPadding()) normalizedScalePercentage
            local handleSize = scaledSize 17 normalizedScalePercentage
            local visibleButtonCount = (orderedPackages()).count + 1
            local contentLength = (visibleButtonCount * buttonLength) + ((visibleButtonCount - 1) * buttonGap)
            floatingNaturalWidth = if (toolbarMode == "floatingvertical") then floatingThickness else handleSize + contentLength + outerPadding
            floatingNaturalHeight = if (toolbarMode == "floatingvertical") then handleSize + contentLength + outerPadding else floatingThickness
            if (toolbarMode == "floatingvertical") then (
                floatingDragHandle.Height = handleSize
            ) else (
                floatingDragHandle.Width = handleSize
            )
            floatingScalePercentage = normalizedScalePercentage
            return applyFloatingSize workingArea
        ),

        fn persistFloatingPosition = (
            if (floatingForm == undefined) do return false
            local toolbarMode = owner.settings.toolbarDockPosition
            if (toolbarMode == "floatingvertical") then (
                owner.settings.floatingVerticalX = floatingForm.Left as integer
                owner.settings.floatingVerticalY = floatingForm.Top as integer
            ) else if (toolbarMode == "floatinghorizontal") then (
                owner.settings.floatingHorizontalX = floatingForm.Left as integer
                owner.settings.floatingHorizontalY = floatingForm.Top as integer
            ) else (
                return false
            )
            if (not (owner.saveSettings())) do logger.logWarning "toolbar" "Could not save the Floating Toolbar position."
            return true
        ),

        fn themeColor settingName fallbackColor = (
            local themeFilePath = runtimeRoot + @"themes\toolbar\" + owner.settings.toolbarTheme + ".ini"
            if (not (doesFileExist themeFilePath)) do themeFilePath = runtimeRoot + @"themes\toolbar\default.ini"
            local colorContent = getINISetting themeFilePath "Colors" settingName
            if (colorContent == "") do colorContent = fallbackColor
            try (
                return (dotNetClass "System.Drawing.ColorTranslator").FromHtml colorContent
            ) catch (
                return (dotNetClass "System.Drawing.ColorTranslator").FromHtml fallbackColor
            )
        ),

        fn prepareDragColors = (
            dragNormalColor = themeColor "toolbarBackground" "#444444"
            dragHoverColor = themeColor "buttonHoverBackground" "#536070"
            dragPressedColor = themeColor "buttonBackground" "#404040"
            dragDotColor = themeColor "buttonSecondaryText" "#aeb6c2"
            return true
        ),

        fn handleDragPaint handleSender paintArgs = (
            if (handleSender == undefined or paintArgs == undefined) do return true
            local dotBrush = undefined
            try (
                dotBrush = dotNetObject "System.Drawing.SolidBrush" dragDotColor
                local centerX = (handleSender.ClientSize.Width as float) / 2.0
                local centerY = (handleSender.ClientSize.Height as float) / 2.0
                local dotSize = amax 2.0 ((amin handleSender.ClientSize.Width handleSender.ClientSize.Height) as float * 0.12)
                local dotGap = dotSize * 1.7
                local columnOffset = dotGap * 0.5
                local rowOffset = dotGap
                for columnIndex in 0 to 1 do (
                    for rowIndex in 0 to 2 do (
                        local dotX = centerX - columnOffset + (columnIndex * dotGap) - (dotSize * 0.5)
                        local dotY = centerY - rowOffset + (rowIndex * dotGap) - (dotSize * 0.5)
                        paintArgs.Graphics.FillEllipse dotBrush dotX dotY dotSize dotSize
                    )
                )
                dotBrush.Dispose()
            ) catch (
                try (if (dotBrush != undefined) do dotBrush.Dispose()) catch ()
            )
            return true
        ),

        fn handleDragMouseEnter handleSender eventArgs = (
            if (handleSender != undefined and not floatingDragging) do handleSender.BackColor = dragHoverColor
            return true
        ),

        fn handleDragMouseLeave handleSender eventArgs = (
            if (handleSender != undefined and not floatingDragging) do handleSender.BackColor = dragNormalColor
            return true
        ),

        fn handleDragMouseDown handleSender eventArgs = (
            if (eventArgs == undefined or eventArgs.Button != (dotNetClass "System.Windows.Forms.MouseButtons").Left) do return true
            floatingDragging = true
            floatingDragOffset = [eventArgs.X as integer, eventArgs.Y as integer]
            handleSender.BackColor = dragPressedColor
            handleSender.Capture = true
            return true
        ),

        fn handleDragMouseMove handleSender eventArgs = (
            if (not floatingDragging or floatingForm == undefined or floatingDragOffset == undefined) do return true
            try (
                local cursorPosition = (dotNetClass "System.Windows.Forms.Cursor").Position
                local requestedPosition = [cursorPosition.X - floatingDragOffset.x, cursorPosition.Y - floatingDragOffset.y]
                local targetScreen = screenForPosition requestedPosition.x requestedPosition.y
                local normalizedPosition = clampFloatingPosition requestedPosition floatingForm.Width floatingForm.Height targetScreen.WorkingArea
                floatingForm.Location = dotNetObject "System.Drawing.Point" normalizedPosition.x normalizedPosition.y
                local detectedScalePercentage = if (uiScale != undefined) then uiScale.browserScalePercentage floatingBrowser else 100
                if (detectedScalePercentage != floatingScalePercentage) do (
                    updateFloatingGeometry owner.settings.toolbarDockPosition targetScreen.WorkingArea detectedScalePercentage
                    normalizedPosition = clampFloatingPosition requestedPosition floatingForm.Width floatingForm.Height targetScreen.WorkingArea
                    floatingForm.Location = dotNetObject "System.Drawing.Point" normalizedPosition.x normalizedPosition.y
                    if (uiScale != undefined) do uiScale.applyBrowserScale floatingBrowser
                    invokeLayout floatingBrowser
                )
            ) catch (
            )
            return true
        ),

        fn handleDragMouseUp handleSender eventArgs = (
            if (eventArgs != undefined and eventArgs.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left) do (
                floatingDragging = false
                floatingDragOffset = undefined
                handleSender.Capture = false
                handleSender.BackColor = dragHoverColor
                persistFloatingPosition()
            )
            return true
        ),

        fn handleFloatingFormClosing formSender eventArgs = (
            if (not floatingCloseAllowed and eventArgs != undefined) do eventArgs.Cancel = true
            return true
        ),

        fn handleFloatingNavigating browserSender navigationArgs = (
            return toolbarOwner.onNavigate navigationArgs
        ),

        fn handleFloatingDocumentCompleted browserSender eventArgs = (
            return onDocumentReady browserSender eventArgs
        ),

        fn createFloatingToolbar toolbarMode = (
            disposeFloatingToolbar()
            destroyDockedToolbar()
            try (
                local formBorderStyle = dotNetClass "System.Windows.Forms.FormBorderStyle"
                local formStartPosition = dotNetClass "System.Windows.Forms.FormStartPosition"
                local dockStyle = dotNetClass "System.Windows.Forms.DockStyle"
                local cursorClass = dotNetClass "System.Windows.Forms.Cursors"
                floatingForm = dotNetObject "System.Windows.Forms.Form"
                floatingBrowser = dotNetObject "System.Windows.Forms.WebBrowser"
                floatingDragHandle = dotNetObject "System.Windows.Forms.Panel"
                floatingForm.FormBorderStyle = formBorderStyle.None
                floatingForm.ControlBox = false
                floatingForm.ShowInTaskbar = false
                floatingForm.TopMost = false
                floatingForm.StartPosition = formStartPosition.Manual
                floatingForm.AutoScaleMode = (dotNetClass "System.Windows.Forms.AutoScaleMode").None
                floatingForm.Text = "MaxPkg Toolbar"
                floatingBrowser.ScriptErrorsSuppressed = true
                floatingBrowser.ScrollBarsEnabled = false
                floatingBrowser.IsWebBrowserContextMenuEnabled = false
                floatingBrowser.AllowWebBrowserDrop = false
                floatingBrowser.WebBrowserShortcutsEnabled = false
                floatingDragHandle.Cursor = cursorClass.SizeAll
                prepareDragColors()
                floatingDragHandle.BackColor = dragNormalColor
                floatingForm.Controls.Add floatingBrowser
                floatingForm.Controls.Add floatingDragHandle
                local savedX = if (toolbarMode == "floatingvertical") then owner.settings.floatingVerticalX else owner.settings.floatingHorizontalX
                local savedY = if (toolbarMode == "floatingvertical") then owner.settings.floatingVerticalY else owner.settings.floatingHorizontalY
                local targetScreen = screenForPosition savedX savedY
                local workingArea = targetScreen.WorkingArea
                if (toolbarMode == "floatingvertical") then (
                    floatingDragHandle.Dock = dockStyle.Top
                    floatingBrowser.Dock = dockStyle.Fill
                ) else (
                    floatingDragHandle.Dock = dockStyle.Left
                    floatingBrowser.Dock = dockStyle.Fill
                )
                updateFloatingGeometry toolbarMode workingArea 100
                local requestedPosition = requestedFloatingPosition toolbarMode workingArea
                local normalizedPosition = clampFloatingPosition requestedPosition floatingForm.Width floatingForm.Height workingArea
                floatingForm.Location = dotNetObject "System.Drawing.Point" normalizedPosition.x normalizedPosition.y
                dotNet.addEventHandler floatingBrowser "Navigating" handleFloatingNavigating
                dotNet.addEventHandler floatingBrowser "DocumentCompleted" handleFloatingDocumentCompleted
                dotNet.addEventHandler floatingDragHandle "Paint" handleDragPaint
                dotNet.addEventHandler floatingDragHandle "MouseEnter" handleDragMouseEnter
                dotNet.addEventHandler floatingDragHandle "MouseLeave" handleDragMouseLeave
                dotNet.addEventHandler floatingDragHandle "MouseDown" handleDragMouseDown
                dotNet.addEventHandler floatingDragHandle "MouseMove" handleDragMouseMove
                dotNet.addEventHandler floatingDragHandle "MouseUp" handleDragMouseUp
                dotNet.addEventHandler floatingForm "FormClosing" handleFloatingFormClosing
                activeBrowser = floatingBrowser
                configureBrowser floatingBrowser toolbarMode
                try (
                    local maxWindowPointer = dotNetObject "System.IntPtr" (windows.getMAXHWND())
                    floatingOwnerWindow = dotNetObject "System.Windows.Forms.NativeWindow"
                    floatingOwnerWindow.AssignHandle maxWindowPointer
                    floatingForm.Show floatingOwnerWindow
                ) catch (
                    logger.logWarning "toolbar" ("Could not assign the Floating Toolbar to the 3ds Max window: " + getCurrentException())
                    try (if (floatingOwnerWindow != undefined) do floatingOwnerWindow.ReleaseHandle()) catch ()
                    floatingOwnerWindow = undefined
                    floatingForm.Show()
                )
                local scalePercentage = if (uiScale != undefined) then uiScale.browserScalePercentage floatingBrowser else 100
                updateFloatingGeometry toolbarMode workingArea scalePercentage
                requestedPosition = requestedFloatingPosition toolbarMode workingArea
                normalizedPosition = clampFloatingPosition requestedPosition floatingForm.Width floatingForm.Height workingArea
                floatingForm.Location = dotNetObject "System.Drawing.Point" normalizedPosition.x normalizedPosition.y
                if (uiScale != undefined) do uiScale.applyBrowserScale floatingBrowser
                invokeLayout floatingBrowser
                return true
            ) catch (
                logger.logError "toolbar" ("Could not create the Floating Toolbar: " + getCurrentException())
                disposeFloatingToolbar()
                return false
            )
        ),

        fn dockToolbar toolbarMode = (
            local dockLocation = case toolbarMode of (
                "bottom": #cui_dock_bottom
                "bottomcompact": #cui_dock_bottom
                "left": #cui_dock_left
                "right": #cui_dock_right
                default: #cui_dock_top
            )
            cui.DockDialogBar rolloutRef dockLocation
            return true
        ),

        fn createDockedToolbar toolbarMode = (
            disposeFloatingToolbar()
            destroyDockedToolbar()
            try (
                local isVertical = isVerticalMode toolbarMode
                local iconOnlyThickness = iconOnlyToolbarThickness()
                local dialogWidth = if (isVertical) then iconOnlyThickness else 1200
                local dialogHeight = if (isVertical) then 600 else if (usesIconOnlyStructure toolbarMode) then iconOnlyThickness else textToolbarThickness()
                createDialog rolloutRef width: dialogWidth height: dialogHeight style: #(#style_sysmenu, #style_toolwindow)
                return true
            ) catch (
                logger.logError "toolbar" ("Could not create the docked Toolbar: " + getCurrentException())
                return false
            )
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
                        "scrollLeft": try (if (activeBrowser != undefined) do activeBrowser.Document.InvokeScript "moveLeft") catch ()
                        "scrollRight": try (if (activeBrowser != undefined) do activeBrowser.Document.InvokeScript "moveRight") catch ()
                    )
                )
            )
            return true
        ),

        fn onOpen browserControl = (
            unregisterDockedToolbar()
            try (
                setDialogPos rolloutRef [-1000,-1000]
            ) catch (
            )
            try (
                local toolbarMode = owner.settings.toolbarDockPosition
                local registrationStyle = if (isVerticalMode toolbarMode) then #(#cui_floatable, #cui_dock_vert, #cui_handles, #cui_max_sized, #style_toolwindow, #style_sysmenu) else #(#cui_floatable, #cui_dock_horz, #cui_handles, #cui_max_sized, #style_toolwindow, #style_sysmenu)
                cui.RegisterDialogBar rolloutRef style: registrationStyle
                dockToolbar toolbarMode
                return configureBrowser browserControl toolbarMode
            ) catch (
                logger.logError "toolbar" ("Could not register toolbar: " + getCurrentException())
                return false
            )
        ),

        fn shutdownToolbar = (
            local isReleased = hideToolbar()
            if (isReleased) do toolbarOwner = undefined
            return isReleased
        ),

        fn resetFloatingPosition = (
            local toolbarMode = owner.settings.toolbarDockPosition
            if (not (isFloatingMode toolbarMode)) do return false
            local previousX = if (toolbarMode == "floatingvertical") then owner.settings.floatingVerticalX else owner.settings.floatingHorizontalX
            local previousY = if (toolbarMode == "floatingvertical") then owner.settings.floatingVerticalY else owner.settings.floatingHorizontalY
            if (toolbarMode == "floatingvertical") then (
                owner.settings.floatingVerticalX = -1
                owner.settings.floatingVerticalY = -1
            ) else (
                owner.settings.floatingHorizontalX = -1
                owner.settings.floatingHorizontalY = -1
            )
            if (not (owner.saveSettings())) do (
                if (toolbarMode == "floatingvertical") then (
                    owner.settings.floatingVerticalX = previousX
                    owner.settings.floatingVerticalY = previousY
                ) else (
                    owner.settings.floatingHorizontalX = previousX
                    owner.settings.floatingHorizontalY = previousY
                )
                return false
            )
            if (not owner.settings.toolbarVisible) do return true
            if (not (toolbarOwner.build())) do return false
            return persistFloatingPosition()
        ),

        fn build = (
            if (not owner.settings.toolbarVisible) do return hideToolbar()
            local toolbarMode = owner.settings.toolbarDockPosition
            if (isFloatingMode toolbarMode) do return createFloatingToolbar toolbarMode
            return createDockedToolbar toolbarMode
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
