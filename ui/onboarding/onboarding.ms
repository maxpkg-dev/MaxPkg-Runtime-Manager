-- Hosts the non-modal, themed post-install onboarding.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local onboardingOwner = undefined
    rollout MaxPkgOnboardingRollout "Welcome to MaxPkg" width: 760 height: 580 (
        dotNetControl browser "System.Windows.Forms.WebBrowser" pos: [0, 0] width: 760 height: 580
        on browser Navigating eventSender navigationArgs do (
            if (onboardingOwner != undefined) do onboardingOwner.handleNavigation navigationArgs
        )
        on browser DocumentCompleted eventSender documentArgs do (
            if (onboardingOwner != undefined) do onboardingOwner.handleDocumentReady()
        )
        on MaxPkgOnboardingRollout open do (
            if (onboardingOwner != undefined) do onboardingOwner.handleDialogOpened()
        )
        on MaxPkgOnboardingRollout resized dialogSize do (
            if (onboardingOwner != undefined) do onboardingOwner.synchronizeSize()
        )
        on MaxPkgOnboardingRollout close do (
            if (onboardingOwner != undefined) do onboardingOwner.handleDialogClosed()
        )
    )

    struct MaxPkgOnboardingModule (
        owner,
        manager,
        themes,
        uiScale,
        utils,
        logger,
        runtimeRoot = "",
        rolloutRef,
        dialogOpen = false,
        browserReady = false,
        renderedTheme = "",
        errorMessage = "",
        reloadWhenClosed = false,
        reloadCallback = undefined,

        fn updateMode = (
            if (owner == undefined or owner.settings == undefined) do return ""
            if (owner.settings.autoCheckPackages and owner.settings.downloadUpdatesAutomatically) do return "automatic"
            if (not owner.settings.autoCheckPackages and not owner.settings.downloadUpdatesAutomatically) do return "manual"
            return ""
        ),

        fn refresh = (
            if (not dialogOpen or not browserReady or owner.settings == undefined) do return true
            try (
                local documentControl = rolloutRef.browser.Document
                local themeId = themes.resolveThemeId "manager" owner.settings.managerTheme
                if (renderedTheme != themeId) do (
                    local iconRoot = runtimeRoot + @"data\themes\onboarding\" + themeId + @"\icons\"
                    if (not (themes.renderIconDirectory "manager" themeId iconRoot)) do throw "Could not prepare onboarding icons."
                    local themePayload = documentControl.GetElementById "themePayload"
                    themePayload.InnerText = themes.renderOnboardingCss themeId
                    themePayload.SetAttribute "data-icon-root" (utils.fileUrl iconRoot)
                    documentControl.InvokeScript "setOnboardingTheme"
                    renderedTheme = themeId
                )
                local statePayload = documentControl.GetElementById "onboardingPayload"
                statePayload.InnerText = "{\"mode\":" + (utils.jsonString (updateMode())) + ",\"error\":" + (utils.jsonString errorMessage) + "}"
                documentControl.InvokeScript "setOnboardingState"
                return true
            ) catch (
                logger.logError "onboarding" ("Could not refresh onboarding: " + getCurrentException())
                return false
            )
        ),

        fn saveUpdateMode requestedMode = (
            if (requestedMode != "automatic" and requestedMode != "manual") do return false
            if (owner.settings == undefined) do return false
            local previousAutoCheck = owner.settings.autoCheckPackages
            local previousAutoInstall = owner.settings.downloadUpdatesAutomatically
            local useAutomaticUpdates = requestedMode == "automatic"
            owner.settings.autoCheckPackages = useAutomaticUpdates
            owner.settings.downloadUpdatesAutomatically = useAutomaticUpdates
            errorMessage = ""
            local isSaved = false
            try (
                isSaved = owner.saveSettings()
            ) catch (
                logger.logError "onboarding" ("Could not save update mode: " + getCurrentException())
            )
            if (not isSaved) do (
                owner.settings.autoCheckPackages = previousAutoCheck
                owner.settings.downloadUpdatesAutomatically = previousAutoInstall
                -- Restore both persisted fields if the settings write only partly succeeded.
                try (
                    if (not (owner.saveSettings())) do logger.logError "onboarding" "Could not restore previous update settings on disk."
                ) catch (
                    logger.logError "onboarding" ("Could not restore update settings: " + getCurrentException())
                )
                errorMessage = "Could not save your update preference. Your previous choice is still active. Please try again."
            )
            refresh()
            if (manager != undefined) do manager.refresh()
            return isSaved
        ),

        fn destroyOnboarding = (
            if (not dialogOpen) do return true
            try (
                destroyDialog rolloutRef
                return true
            ) catch (
                logger.logError "onboarding" ("Could not close onboarding: " + getCurrentException())
                return false
            )
        ),

        fn handleNavigation navigationArgs = (
            local navigationUrl = navigationArgs.Url.AbsoluteUri as string
            if (not (matchPattern navigationUrl pattern: "maxpkg://onboarding/*" ignoreCase: true)) do return true
            navigationArgs.Cancel = true
            local commandPath = substring navigationUrl 21 (navigationUrl.count - 20)
            errorMessage = ""
            try (
                case commandPath of (
                    "close": (return destroyOnboarding())
                    "discover": (if (not (owner.openManager tab: "discover")) do errorMessage = "Could not open the script catalog. Please try again.")
                    "toolbar": (if (not (owner.openManager settingsPage: "toolbar")) do errorMessage = "Could not open toolbar settings. Please try again.")
                    "updates/automatic": (return saveUpdateMode "automatic")
                    "updates/manual": (return saveUpdateMode "manual")
                    default: (return false)
                )
            ) catch (
                errorMessage = "Could not complete this action. Please try again."
                logger.logError "onboarding" (commandPath + ": " + getCurrentException())
            )
            refresh()
            return errorMessage == ""
        ),

        fn synchronizeSize = (
            if (not dialogOpen) do return false
            local dialogSize = getDialogSize rolloutRef
            rolloutRef.browser.width = amax 1 dialogSize.x
            rolloutRef.browser.height = amax 1 dialogSize.y
            rolloutRef.browser.Dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            if (uiScale != undefined) do uiScale.applyBrowserScale rolloutRef.browser constrainViewport: true
            return true
        ),

        fn handleDocumentReady = (
            if (rolloutRef.browser.Document == undefined) do return false
            if (rolloutRef.browser.ReadyState != (dotNetClass "System.Windows.Forms.WebBrowserReadyState").Complete) do return false
            browserReady = true
            renderedTheme = ""
            synchronizeSize()
            return refresh()
        ),

        fn handleDialogOpened = (
            dialogOpen = true
            browserReady = false
            local browserControl = rolloutRef.browser
            browserControl.ScriptErrorsSuppressed = true
            browserControl.ScrollBarsEnabled = false
            browserControl.IsWebBrowserContextMenuEnabled = false
            browserControl.AllowWebBrowserDrop = false
            browserControl.WebBrowserShortcutsEnabled = false
            synchronizeSize()
            browserControl.Navigate (utils.fileUrl (runtimeRoot + @"ui\onboarding\index.html"))
            return true
        ),

        fn handleDialogClosed = (
            dialogOpen = false
            browserReady = false
            renderedTheme = ""
            enableAccelerators = true
            if (reloadWhenClosed and reloadCallback != undefined) do (
                reloadWhenClosed = false
                reloadCallback()
            )
            return true
        ),

        fn showOnboarding = (
            if (dialogOpen) do (
                windows.setFocus rolloutRef.hwnd
                return refresh()
            )
            if (owner == undefined or owner.settings == undefined) do return false
            if (not (doesFileExist (runtimeRoot + @"ui\onboarding\index.html"))) do return false
            errorMessage = ""
            try (
                local screenClass = dotNetClass "System.Windows.Forms.Screen"
                local cursorClass = dotNetClass "System.Windows.Forms.Cursor"
                local screenInfo = screenClass.FromPoint cursorClass.Position
                local workingArea = screenInfo.WorkingArea
                local dialogWidth = amin 760 (amax 1 (workingArea.Width - 24))
                local dialogHeight = amin 580 (amax 1 (workingArea.Height - 64))
                local dialogPosition = [workingArea.Left + (workingArea.Width - dialogWidth) / 2, workingArea.Top + (workingArea.Height - dialogHeight) / 2]
                createDialog rolloutRef width: dialogWidth height: dialogHeight pos: dialogPosition style: #(#style_titlebar, #style_sysmenu, #style_resizing) modal: false escapeEnable: true
                return true
            ) catch (
                dialogOpen = false
                browserReady = false
                logger.logError "onboarding" ("Could not open onboarding: " + getCurrentException())
                return false
            )
        ),

        fn shutdown = (
            reloadWhenClosed = false
            return destroyOnboarding()
        ),

        fn initialize runtimeOwner runtimePath moduleInstance = (
            owner = runtimeOwner
            runtimeRoot = runtimePath
            rolloutRef = MaxPkgOnboardingRollout
            onboardingOwner = moduleInstance
            return true
        )
    )
    MaxPkgOnboardingModule()
)
