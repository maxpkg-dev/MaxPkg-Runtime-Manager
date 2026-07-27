-- Shows branded Runtime installation and removal results in a non-modal rollout.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local resultDialogOwner = undefined

    rollout MaxPkgResultDialogRollout "MaxPkg Runtime" width: 720 height: 580 (
        dotNetControl browser "System.Windows.Forms.WebBrowser" pos: [0, 0] width: 720 height: 580

        on browser Navigating eventSender navigationArgs do (
            if (resultDialogOwner != undefined) do resultDialogOwner.handleNavigation navigationArgs
        )

        on browser DocumentCompleted eventSender documentArgs do (
            if (resultDialogOwner != undefined) do resultDialogOwner.handleDocumentReady eventSender documentArgs
        )

        on MaxPkgResultDialogRollout open do (
            if (resultDialogOwner != undefined) do resultDialogOwner.handleDialogOpened browser
        )

        on MaxPkgResultDialogRollout resized dialogSize do (
            if (resultDialogOwner != undefined) then (
                resultDialogOwner.handleDialogResized dialogSize browser
            ) else (
                browser.width = dialogSize.x
                browser.height = dialogSize.y
            )
        )

        on MaxPkgResultDialogRollout close do (
            try (
                enableAccelerators = true
            ) catch (
            )
            if (resultDialogOwner != undefined) do resultDialogOwner.handleDialogClosed()
        )
    )

    struct MaxPkgResultDialogData (
        windowTitle = "MaxPkg Runtime",
        heading = "",
        summary = "",
        versionText = "",
        startupText = "",
        guideTitle = "",
        guideStepOneTitle = "",
        guideStepOneContent = "",
        guideStepTwoTitle = "",
        guideStepTwoContent = "",
        guideStepThreeTitle = "",
        guideStepThreeContent = "",
        statusKind = "success",
        primaryButtonText = "",
        primaryActionCallback = undefined
    )

    struct MaxPkgResultDialogModule (
        rolloutRef,
        dialogInfo,
        dialogOpen = false,
        browserReady = false,
        commonRoot = "",
        htmlFilePath = "",
        temporaryAssetRoot = "",
        minimumDialogWidth = 640,
        minimumDialogHeight = 580,

        fn createDialogData = (
            return MaxPkgResultDialogData()
        ),

        fn launchWebsite websiteUrl = (
            if (websiteUrl == undefined or websiteUrl == "") do return false
            try (
                shellLaunch websiteUrl ""
                return true
            ) catch (
                return false
            )
        ),

        fn setElementContent documentControl elementId sourceContent = (
            if (documentControl == undefined) do return false
            local htmlElement = documentControl.GetElementById elementId
            if (htmlElement == undefined) do return false
            htmlElement.InnerText = if (sourceContent == undefined) then "" else sourceContent as string
            return true
        ),

        fn setElementClass documentControl elementId classContent = (
            if (documentControl == undefined) do return false
            local htmlElement = documentControl.GetElementById elementId
            if (htmlElement == undefined) do return false
            htmlElement.SetAttribute "className" classContent
            return true
        ),

        fn populateDocument browserControl = (
            if (browserControl == undefined or browserControl.Document == undefined or dialogInfo == undefined) do return false
            local documentControl = browserControl.Document
            setElementClass documentControl "resultBody" ("result-body status-" + (toLower dialogInfo.statusKind))
            setElementContent documentControl "resultHeading" dialogInfo.heading
            setElementContent documentControl "resultSummary" dialogInfo.summary
            setElementContent documentControl "versionText" dialogInfo.versionText
            setElementContent documentControl "startupText" dialogInfo.startupText
            setElementContent documentControl "guideTitle" dialogInfo.guideTitle
            setElementContent documentControl "guideStepOneTitle" dialogInfo.guideStepOneTitle
            setElementContent documentControl "guideStepOneContent" dialogInfo.guideStepOneContent
            setElementContent documentControl "guideStepTwoTitle" dialogInfo.guideStepTwoTitle
            setElementContent documentControl "guideStepTwoContent" dialogInfo.guideStepTwoContent
            setElementContent documentControl "guideStepThreeTitle" dialogInfo.guideStepThreeTitle
            setElementContent documentControl "guideStepThreeContent" dialogInfo.guideStepThreeContent
            setElementContent documentControl "primaryAction" dialogInfo.primaryButtonText
            if (dialogInfo.primaryButtonText != "" and dialogInfo.primaryActionCallback != undefined) then (
                setElementClass documentControl "primaryAction" "button button-primary"
            ) else (
                setElementClass documentControl "primaryAction" "button button-primary is-hidden"
            )
            browserReady = true
            return true
        ),

        fn synchronizeBrowserSize browserControl = (
            if (browserControl == undefined or rolloutRef == undefined) do return false
            try (
                local currentDialogSize = getDialogSize rolloutRef
                browserControl.width = currentDialogSize.x
                browserControl.height = currentDialogSize.y
                return true
            ) catch (
                return false
            )
        ),

        fn configureBrowser browserControl = (
            if (browserControl == undefined or not (doesFileExist htmlFilePath)) do return false
            browserControl.ScriptErrorsSuppressed = true
            browserControl.ScrollBarsEnabled = false
            browserControl.IsWebBrowserContextMenuEnabled = false
            browserControl.AllowWebBrowserDrop = false
            browserControl.WebBrowserShortcutsEnabled = false
            browserControl.Dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            browserReady = false
            local htmlFileUri = dotNetObject "System.Uri" htmlFilePath
            browserControl.Navigate htmlFileUri.AbsoluteUri
            return true
        ),

        fn cleanupTemporaryAssets = (
            if (temporaryAssetRoot == "" or not (doesDirectoryExist temporaryAssetRoot)) do return true
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                local searchOption = dotNetClass "System.IO.SearchOption"
                local temporaryFiles = directoryClass.GetFiles temporaryAssetRoot "*" searchOption.AllDirectories
                for temporaryFilePath in temporaryFiles do (
                    try (
                        setFileAttribute temporaryFilePath #readOnly false
                    ) catch (
                    )
                )
                directoryClass.Delete temporaryAssetRoot true
                temporaryAssetRoot = ""
                return true
            ) catch (
                return false
            )
        ),

        fn prepareTemporaryAssets = (
            if (commonRoot == "" or not (doesDirectoryExist commonRoot)) do return false
            cleanupTemporaryAssets()
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                local searchOption = dotNetClass "System.IO.SearchOption"
                local guidClass = dotNetClass "System.Guid"
                local temporaryGuid = guidClass.NewGuid()
                local temporaryGuidText = temporaryGuid.ToString()
                local temporaryRoot = (getDir #temp) + @"\maxpkg-result-dialog-" + temporaryGuidText + @"\"
                local sourceFiles = directoryClass.GetFiles commonRoot "*" searchOption.AllDirectories
                makeDir temporaryRoot all: true
                temporaryAssetRoot = temporaryRoot
                for sourceFilePath in sourceFiles do (
                    local relativeFilePath = substring sourceFilePath (commonRoot.count + 1) (sourceFilePath.count - commonRoot.count)
                    local targetFilePath = temporaryRoot + relativeFilePath
                    makeDir (getFilenamePath targetFilePath) all: true
                    if (not (copyFile sourceFilePath targetFilePath)) do throw ("Could not prepare result window asset: " + sourceFilePath)
                )
                htmlFilePath = temporaryAssetRoot + "result-dialog.html"
                return true
            ) catch (
                cleanupTemporaryAssets()
                return false
            )
        ),

        fn handleDocumentReady browserControl documentArgs = (
            if (browserControl == undefined or browserControl.Document == undefined) do return false
            synchronizeBrowserSize browserControl
            return populateDocument browserControl
        ),

        fn destroyResultDialog = (
            if (not dialogOpen or rolloutRef == undefined) do return true
            try (
                destroyDialog rolloutRef
            ) catch (
                return false
            )
            dialogOpen = false
            browserReady = false
            return true
        ),

        fn runPrimaryAction = (
            if (dialogInfo == undefined or dialogInfo.primaryActionCallback == undefined) do return false
            local actionCallback = dialogInfo.primaryActionCallback
            destroyResultDialog()
            try (
                actionCallback()
                return true
            ) catch (
                return false
            )
        ),

        fn handleNavigation navigationArgs = (
            local navigationUrl = ""
            try (
                navigationUrl = navigationArgs.Url.AbsoluteUri as string
            ) catch (
                return false
            )
            if (matchPattern navigationUrl pattern: "maxpkg://result/*" ignoreCase: true) do (
                navigationArgs.Cancel = true
                if (matchPattern navigationUrl pattern: "maxpkg://result/primary*" ignoreCase: true) then (
                    runPrimaryAction()
                ) else if (matchPattern navigationUrl pattern: "maxpkg://result/done*" ignoreCase: true) then (
                    destroyResultDialog()
                )
                return true
            )
            if ((matchPattern navigationUrl pattern: "https://*" ignoreCase: true) or (matchPattern navigationUrl pattern: "http://*" ignoreCase: true)) do (
                navigationArgs.Cancel = true
                return launchWebsite navigationUrl
            )
            return true
        ),

        fn handleDialogOpened browserControl = (
            dialogOpen = true
            synchronizeBrowserSize browserControl
            return configureBrowser browserControl
        ),

        fn handleDialogResized dialogSize browserControl = (
            local constrainedDialogSize = [amax minimumDialogWidth dialogSize.x, amax minimumDialogHeight dialogSize.y]
            if (constrainedDialogSize.x != dialogSize.x or constrainedDialogSize.y != dialogSize.y) do (
                setDialogSize rolloutRef constrainedDialogSize
                return true
            )
            browserControl.width = constrainedDialogSize.x
            browserControl.height = constrainedDialogSize.y
            return true
        ),

        fn handleDialogClosed = (
            dialogOpen = false
            browserReady = false
            cleanupTemporaryAssets()
            return true
        ),

        fn showDialog newDialogInfo = (
            if (newDialogInfo == undefined or rolloutRef == undefined) do return false
            destroyResultDialog()
            dialogInfo = newDialogInfo
            rolloutRef.title = dialogInfo.windowTitle
            dialogOpen = true
            try (
                local dialogStyle = #(#style_titlebar, #style_sysmenu, #style_resizing)
                createDialog rolloutRef width: 720 height: 580 style: dialogStyle
                return true
            ) catch (
                dialogOpen = false
                browserReady = false
                cleanupTemporaryAssets()
                return false
            )
        )
    )

    local moduleInstance = MaxPkgResultDialogModule()
    moduleInstance.rolloutRef = MaxPkgResultDialogRollout
    moduleInstance.commonRoot = getFilenamePath (getSourceFileName())
    moduleInstance.htmlFilePath = moduleInstance.commonRoot + "result-dialog.html"
    resultDialogOwner = moduleInstance
    moduleInstance
)
