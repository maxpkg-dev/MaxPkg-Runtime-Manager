-- Hosts Manager HTML UI and routes commands to Runtime.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local managerOwner = undefined

    rollout MaxPkgRuntimeManagerRollout "MaxPkg Manager" width: 900 height: 650 (
        dotNetControl browser "System.Windows.Forms.WebBrowser" pos: [0, 0] width: 900 height: 650

        on browser Navigating sender navigationArgs do (
            if (managerOwner != undefined) do managerOwner.onNavigate navigationArgs
        )

        on browser DocumentCompleted sender documentArgs do (
            if (managerOwner != undefined) do managerOwner.onDocumentReady sender documentArgs
        )

        on browser Enter sender focusArgs do (
            if (managerOwner != undefined) do managerOwner.setManagerFocusState true
        )

        on MaxPkgRuntimeManagerRollout open do (
            if (managerOwner != undefined) do managerOwner.handleDialogOpened browser
        )

        on MaxPkgRuntimeManagerRollout resized dialogSize do (
            if (managerOwner != undefined) then (
                managerOwner.handleDialogResized dialogSize browser
            ) else (
                browser.width = dialogSize.x
                browser.height = dialogSize.y
            )
        )

        on MaxPkgRuntimeManagerRollout moved dialogPosition do (
            if (managerOwner != undefined) do managerOwner.onMove dialogPosition
        )

        on MaxPkgRuntimeManagerRollout close do (
            try (
                enableAccelerators = true
            ) catch (
            )
            if (managerOwner != undefined) do managerOwner.handleDialogClosed()
        )
    )

    struct MaxPkgManagerModule (
        owner,
        utils,
        logger,
        http,
        imageCache,
        themes,
        uiScale,
        runtimeRoot,
        rolloutRef,
        dialogOpen = false,
        browserReady = false,
        focusTimer = undefined,
        imageDownloadTimer = undefined,
        runtimeUninstallTimer = undefined,
        runtimeUninstallFilePath = "",
        minimumDialogWidth = 720,
        minimumDialogHeight = 520,

        fn setManagerFocusState isFocused = (
            try (
                enableAccelerators = not isFocused
                return true
            ) catch (
                logger.logWarning "manager" ("Could not change 3ds Max accelerator state: " + getCurrentException())
                return false
            )
        ),

        fn managerContainsKeyboardFocus = (
            if (not dialogOpen or rolloutRef == undefined) do return false
            try (
                local browserControl = rolloutRef.browser
                if (browserControl == undefined) do return false
                return browserControl.ContainsFocus
            ) catch (
                return false
            )
        ),

        fn synchronizeManagerFocus = (
            local managerHasFocus = managerContainsKeyboardFocus()
            if (enableAccelerators == managerHasFocus) do setManagerFocusState managerHasFocus
            return managerHasFocus
        ),

        fn handleFocusTimerTick eventSender eventArgs = (
            synchronizeManagerFocus()
            return true
        ),

        fn stopFocusTimer = (
            if (focusTimer == undefined) do return true
            try (
                focusTimer.Stop()
                dotNet.removeEventHandler focusTimer "Tick" handleFocusTimerTick
                focusTimer.Dispose()
            ) catch (
                logger.logWarning "manager" ("Could not stop Manager focus tracking: " + getCurrentException())
            )
            focusTimer = undefined
            return true
        ),

        fn startFocusTimer = (
            stopFocusTimer()
            try (
                focusTimer = dotNetObject "System.Windows.Forms.Timer"
                focusTimer.Interval = 75
                dotNet.addEventHandler focusTimer "Tick" handleFocusTimerTick
                focusTimer.Start()
                synchronizeManagerFocus()
                return true
            ) catch (
                focusTimer = undefined
                setManagerFocusState false
                logger.logWarning "manager" ("Could not start Manager focus tracking: " + getCurrentException())
                return false
            )
        ),

        fn handleRuntimeUninstallTimer eventSender eventArgs = (
            local scheduledUninstallFilePath = runtimeUninstallFilePath
            try (
                runtimeUninstallTimer.Stop()
                dotNet.removeEventHandler runtimeUninstallTimer "Tick" handleRuntimeUninstallTimer
                runtimeUninstallTimer.Dispose()
            ) catch (
                logger.logWarning "manager" ("Could not release Runtime uninstall timer: " + getCurrentException())
            )
            runtimeUninstallTimer = undefined
            runtimeUninstallFilePath = ""
            if (scheduledUninstallFilePath == "" or not (doesFileExist scheduledUninstallFilePath)) do (
                logger.logError "manager" "Runtime uninstaller is unavailable."
                return false
            )
            try (
                fileIn scheduledUninstallFilePath
                return true
            ) catch (
                logger.logError "manager" ("Runtime uninstall failed: " + getCurrentException())
                return false
            )
        ),

        fn stopRuntimeUninstallTimer = (
            if (runtimeUninstallTimer == undefined) do return true
            try (
                runtimeUninstallTimer.Stop()
                dotNet.removeEventHandler runtimeUninstallTimer "Tick" handleRuntimeUninstallTimer
                runtimeUninstallTimer.Dispose()
            ) catch (
                logger.logWarning "manager" ("Could not stop Runtime uninstall timer: " + getCurrentException())
            )
            runtimeUninstallTimer = undefined
            runtimeUninstallFilePath = ""
            return true
        ),

        fn scheduleRuntimeUninstall = (
            local uninstallFilePath = runtimeRoot + "uninstall.ms"
            if (not (doesFileExist uninstallFilePath)) do (
                logger.logError "manager" ("Runtime uninstaller not found: " + uninstallFilePath)
                return false
            )
            stopRuntimeUninstallTimer()
            try (
                runtimeUninstallFilePath = uninstallFilePath
                runtimeUninstallTimer = dotNetObject "System.Windows.Forms.Timer"
                runtimeUninstallTimer.Interval = 150
                dotNet.addEventHandler runtimeUninstallTimer "Tick" handleRuntimeUninstallTimer
                runtimeUninstallTimer.Start()
                return true
            ) catch (
                stopRuntimeUninstallTimer()
                logger.logError "manager" ("Could not schedule Runtime uninstall: " + getCurrentException())
                return false
            )
        ),

        fn boolJson isEnabled = (
            return (if (isEnabled) then "true" else "false")
        ),

        fn stringArrayJson sourceStrings = (
            local stringEntries = #()
            for sourceString in sourceStrings do append stringEntries (utils.jsonString sourceString)
            return "[" + (utils.join stringEntries separator: ",") + "]"
        ),

        fn packageIsHidden packageGuid = (
            for hiddenGuid in owner.settings.hiddenPackages where (toLower hiddenGuid) == (toLower packageGuid) do return true
            return false
        ),

        fn changelogJson changelogEntries = (
            local changelogContent = #()
            for changelogEntry in changelogEntries do (
                local entryContent = "{"
                entryContent += "\"changeType\":" + (utils.jsonString changelogEntry.changeType) + ","
                entryContent += "\"messageContent\":" + (utils.jsonString changelogEntry.messageContent) + ","
                entryContent += "\"versionContent\":" + (utils.jsonString changelogEntry.versionContent) + ","
                entryContent += "\"releaseDateContent\":" + (utils.jsonString changelogEntry.releaseDateContent)
                entryContent += "}"
                append changelogContent entryContent
            )
            return "[" + (utils.join changelogContent separator: ",") + "]"
        ),

        fn cachedImageUrl sourceUrl fallbackUrl: "" = (
            if (imageCache == undefined) do return sourceUrl
            return imageCache.localImageUrl sourceUrl fallbackUrl: fallbackUrl
        ),

        fn screenshotsJson screenshotEntries = (
            local screenshotContent = #()
            for screenshotEntry in screenshotEntries do (
                local fullImageUrl = cachedImageUrl screenshotEntry.imageUrl
                local thumbnailImageUrl = cachedImageUrl screenshotEntry.thumbnailUrl fallbackUrl: screenshotEntry.imageUrl
                local entryContent = "{"
                entryContent += "\"url\":" + (utils.jsonString fullImageUrl) + ","
                entryContent += "\"thumbnailUrl\":" + (utils.jsonString thumbnailImageUrl) + ","
                entryContent += "\"title\":" + (utils.jsonString screenshotEntry.titleContent) + ","
                entryContent += "\"caption\":" + (utils.jsonString screenshotEntry.captionContent) + ","
                entryContent += "\"sortOrder\":" + (screenshotEntry.sortOrder as string)
                entryContent += "}"
                append screenshotContent entryContent
            )
            return "[" + (utils.join screenshotContent separator: ",") + "]"
        ),

        fn optionalString sourceData propertyName = (
            if (not (isProperty sourceData propertyName)) do return ""
            local propertyContent = getProperty sourceData propertyName
            if (propertyContent == undefined) do return ""
            return propertyContent as string
        ),

        fn optionalBoolean sourceData propertyName = (
            if (not (isProperty sourceData propertyName)) do return false
            return getProperty sourceData propertyName
        ),

        fn optionalNumberJson sourceData propertyName defaultNumber: 0 = (
            if (not (isProperty sourceData propertyName)) do return defaultNumber as string
            try (
                return (getProperty sourceData propertyName) as string
            ) catch (
                return defaultNumber as string
            )
        ),

        fn packageJson packageInfo = (
            local isRemotePackage = optionalBoolean packageInfo #isRemote
            local toolbarVisible = if (isRemotePackage) then false else packageInfo.toolbarVisible and not (packageIsHidden packageInfo.guid)
            local iconUrl = optionalString packageInfo #iconUrl
            local packageIconUrl = optionalString packageInfo #packageIconUrl
            local coverImageUrl = optionalString packageInfo #coverImageUrl
            local screenshotEntries = if (isProperty packageInfo #screenshotEntries) then packageInfo.screenshotEntries else #()
            local packagePageUrl = utils.packagePageUrl owner.settings.apiEndpoint packageInfo.slug
            if (iconUrl == "" and packageInfo.iconFile != "" and doesFileExist packageInfo.iconFile) do iconUrl = utils.fileUrl packageInfo.iconFile
            if (packageIconUrl != "") then (
                packageIconUrl = cachedImageUrl packageIconUrl
            ) else if (iconUrl != "") then (
                iconUrl = cachedImageUrl iconUrl
            ) else if (coverImageUrl != "") do (
                coverImageUrl = cachedImageUrl coverImageUrl
            )
            local packageContent = "{"
            packageContent += "\"guid\":" + (utils.jsonString packageInfo.guid) + ","
            packageContent += "\"slug\":" + (utils.jsonString packageInfo.slug) + ","
            packageContent += "\"packagePageUrl\":" + (utils.jsonString packagePageUrl) + ","
            packageContent += "\"name\":" + (utils.jsonString packageInfo.packageName) + ","
            packageContent += "\"buttonName\":" + (utils.jsonString packageInfo.buttonName) + ","
            packageContent += "\"version\":" + (utils.jsonString packageInfo.version) + ","
            packageContent += "\"developer\":" + (utils.jsonString packageInfo.developer) + ","
            packageContent += "\"description\":" + (utils.jsonString packageInfo.description) + ","
            packageContent += "\"fullDescription\":" + (utils.jsonString (optionalString packageInfo #fullDescription)) + ","
            packageContent += "\"category\":" + (utils.jsonString (optionalString packageInfo #category)) + ","
            packageContent += "\"helpUrl\":" + (utils.jsonString packageInfo.helpUrl) + ","
            packageContent += "\"documentationUrl\":" + (utils.jsonString packageInfo.documentationUrl) + ","
            packageContent += "\"homepageUrl\":" + (utils.jsonString packageInfo.homepageUrl) + ","
            packageContent += "\"supportUrl\":" + (utils.jsonString packageInfo.supportUrl) + ","
            packageContent += "\"purchaseUrl\":" + (utils.jsonString (optionalString packageInfo #purchaseUrl)) + ","
            packageContent += "\"purchaseButtonLabel\":" + (utils.jsonString (optionalString packageInfo #purchaseButtonLabel)) + ","
            packageContent += "\"licenseType\":" + (utils.jsonString packageInfo.licenseType) + ","
            packageContent += "\"licenseUrl\":" + (utils.jsonString packageInfo.licenseUrl) + ","
            packageContent += "\"releaseChannel\":" + (utils.jsonString packageInfo.releaseChannel) + ","
            packageContent += "\"releaseDate\":" + (utils.jsonString packageInfo.releaseDate) + ","
            packageContent += "\"minimumMaxVersion\":" + (utils.jsonString packageInfo.minimumMaxVersion) + ","
            packageContent += "\"maximumMaxVersion\":" + (utils.jsonString packageInfo.maximumMaxVersion) + ","
            packageContent += "\"manifestVersion\":" + (utils.jsonString packageInfo.manifestVersion) + ","
            packageContent += "\"packagerName\":" + (utils.jsonString packageInfo.packagerName) + ","
            packageContent += "\"packagerVersion\":" + (utils.jsonString packageInfo.packagerVersion) + ","
            packageContent += "\"changelogEntries\":" + (changelogJson packageInfo.changelogEntries) + ","
            packageContent += "\"runtime\":" + (utils.jsonString packageInfo.runtime) + ","
            packageContent += "\"entry\":" + (utils.jsonString packageInfo.entry) + ","
            packageContent += "\"iconUrl\":" + (utils.jsonString iconUrl) + ","
            packageContent += "\"packageIconUrl\":" + (utils.jsonString packageIconUrl) + ","
            packageContent += "\"coverImageUrl\":" + (utils.jsonString coverImageUrl) + ","
            packageContent += "\"screenshots\":" + (screenshotsJson screenshotEntries) + ","
            packageContent += "\"downloadUrl\":" + (utils.jsonString (optionalString packageInfo #downloadUrl)) + ","
            packageContent += "\"rating\":" + (optionalNumberJson packageInfo #rating) + ","
            packageContent += "\"reviewCount\":" + (optionalNumberJson packageInfo #reviewCount) + ","
            packageContent += "\"downloadCount\":" + (optionalNumberJson packageInfo #downloadCount) + ","
            packageContent += "\"installPath\":" + (utils.jsonString packageInfo.installPath) + ","
            packageContent += "\"toolbarVisible\":" + (boolJson toolbarVisible) + ","
            packageContent += "\"updateAvailable\":" + (boolJson packageInfo.updateAvailable) + ","
            packageContent += "\"latestVersion\":" + (utils.jsonString packageInfo.latestVersion) + ","
            packageContent += "\"isRemote\":" + (boolJson isRemotePackage) + ","
            packageContent += "\"detailsLoaded\":" + (boolJson (optionalBoolean packageInfo #detailsLoaded))
            packageContent += "}"
            return packageContent
        ),

        fn packagesJson = (
            local packageEntries = #()
            for packageInfo in owner.packages do append packageEntries (packageJson packageInfo)
            return "[" + (utils.join packageEntries separator: ",") + "]"
        ),

        fn apiPackagesJson responseInfo = (
            local packageEntries = #()
            if (responseInfo != undefined) do (
                for packageInfo in responseInfo.packages do append packageEntries (packageJson packageInfo)
            )
            return "[" + (utils.join packageEntries separator: ",") + "]"
        ),

        fn collectionJson collectionInfo = (
            local collectionContent = "{"
            collectionContent += "\"slug\":" + (utils.jsonString collectionInfo.slug) + ","
            collectionContent += "\"name\":" + (utils.jsonString collectionInfo.collectionName) + ","
            collectionContent += "\"description\":" + (utils.jsonString collectionInfo.collectionDescription) + ","
            collectionContent += "\"icon\":" + (utils.jsonString collectionInfo.iconName) + ","
            collectionContent += "\"accentColor\":" + (utils.jsonString collectionInfo.accentColor) + ","
            collectionContent += "\"count\":" + (collectionInfo.packageCount as string)
            collectionContent += "}"
            return collectionContent
        ),

        fn collectionsJson = (
            local responseInfo = owner.collectionsState
            if (responseInfo == undefined) do return "{\"loaded\":false,\"available\":false,\"message\":\"\",\"featuredCount\":0,\"items\":[]}"
            local collectionEntries = #()
            for collectionInfo in responseInfo.collections do append collectionEntries (collectionJson collectionInfo)
            local collectionsContent = "{"
            collectionsContent += "\"loaded\":true,"
            collectionsContent += "\"available\":" + (boolJson responseInfo.success) + ","
            collectionsContent += "\"message\":" + (utils.jsonString responseInfo.errorMessage) + ","
            collectionsContent += "\"errorCode\":" + (utils.jsonString responseInfo.errorCode) + ","
            collectionsContent += "\"requestId\":" + (utils.jsonString responseInfo.requestId) + ","
            collectionsContent += "\"featuredCount\":" + (responseInfo.featuredCount as string) + ","
            collectionsContent += "\"items\":[" + (utils.join collectionEntries separator: ",") + "]"
            collectionsContent += "}"
            return collectionsContent
        ),

        fn categoryJson categoryInfo = (
            local categoryContent = "{"
            categoryContent += "\"slug\":" + (utils.jsonString categoryInfo.slug) + ","
            categoryContent += "\"name\":" + (utils.jsonString categoryInfo.categoryName) + ","
            categoryContent += "\"description\":" + (utils.jsonString categoryInfo.categoryDescription) + ","
            categoryContent += "\"count\":" + (categoryInfo.packageCount as string)
            categoryContent += "}"
            return categoryContent
        ),

        fn categoriesJson = (
            local responseInfo = owner.categoriesState
            if (responseInfo == undefined) do return "{\"loaded\":false,\"available\":false,\"message\":\"\",\"items\":[]}"
            local categoryEntries = #()
            for categoryInfo in responseInfo.categories do append categoryEntries (categoryJson categoryInfo)
            local categoriesContent = "{"
            categoriesContent += "\"loaded\":true,"
            categoriesContent += "\"available\":" + (boolJson responseInfo.success) + ","
            categoriesContent += "\"message\":" + (utils.jsonString responseInfo.errorMessage) + ","
            categoriesContent += "\"errorCode\":" + (utils.jsonString responseInfo.errorCode) + ","
            categoriesContent += "\"requestId\":" + (utils.jsonString responseInfo.requestId) + ","
            categoriesContent += "\"items\":[" + (utils.join categoryEntries separator: ",") + "]"
            categoriesContent += "}"
            return categoriesContent
        ),

        fn discoverJson = (
            local responseInfo = owner.catalogState
            if (responseInfo == undefined) do return "{\"available\":false,\"message\":\"Load the catalog to browse packages.\",\"packages\":[],\"page\":1,\"pageSize\":24,\"total\":0,\"totalPages\":0,\"featured\":false,\"collection\":\"\",\"category\":\"\"}"
            local discoverContent = "{"
            discoverContent += "\"available\":" + (boolJson responseInfo.success) + ","
            discoverContent += "\"message\":" + (utils.jsonString responseInfo.errorMessage) + ","
            discoverContent += "\"errorCode\":" + (utils.jsonString responseInfo.errorCode) + ","
            discoverContent += "\"requestId\":" + (utils.jsonString responseInfo.requestId) + ","
            discoverContent += "\"packages\":" + (apiPackagesJson responseInfo) + ","
            discoverContent += "\"page\":" + (responseInfo.page as string) + ","
            discoverContent += "\"pageSize\":" + (responseInfo.pageSize as string) + ","
            discoverContent += "\"total\":" + (responseInfo.total as string) + ","
            discoverContent += "\"totalPages\":" + (responseInfo.totalPages as string) + ","
            discoverContent += "\"featured\":" + (boolJson responseInfo.featuredOnly) + ","
            discoverContent += "\"collection\":" + (utils.jsonString responseInfo.collectionSlug) + ","
            discoverContent += "\"category\":" + (utils.jsonString responseInfo.categoryFilter)
            discoverContent += "}"
            return discoverContent
        ),

        fn remoteDetailsJson = (
            local responseInfo = owner.remotePackageDetails
            if (responseInfo == undefined or not responseInfo.success or responseInfo.packageInfo == undefined) do return "null"
            return packageJson responseInfo.packageInfo
        ),

        fn themeOptionsJson requestedThemeKind = (
            if (themes == undefined) do return "[]"
            local themeOptions = themes.listThemes requestedThemeKind
            local themeContent = "["
            for themeIndex in 1 to themeOptions.count do (
                if (themeIndex > 1) do themeContent += ","
                local themeInfo = themeOptions[themeIndex]
                themeContent += "{\"id\":" + (utils.jsonString themeInfo.themeId) + ",\"name\":" + (utils.jsonString themeInfo.displayName) + "}"
            )
            themeContent += "]"
            return themeContent
        ),

        fn settingsJson = (
            local settings = owner.settings
            local settingsContent = "{"
            settingsContent += "\"toolbarVisible\":" + (boolJson settings.toolbarVisible) + ","
            settingsContent += "\"toolbarTitleMode\":" + (utils.jsonString settings.toolbarTitleMode) + ","
            settingsContent += "\"toolbarSubtitleMode\":" + (utils.jsonString settings.toolbarSubtitleMode) + ","
            settingsContent += "\"toolbarButtonSize\":" + (utils.jsonString settings.toolbarButtonSize) + ","
            settingsContent += "\"toolbarDockPosition\":" + (utils.jsonString settings.toolbarDockPosition) + ","
            settingsContent += "\"toolbarTheme\":" + (utils.jsonString settings.toolbarTheme) + ","
            settingsContent += "\"toolbarThemes\":" + (themeOptionsJson "toolbar") + ","
            settingsContent += "\"toolbarOrder\":" + (stringArrayJson settings.toolbarOrder) + ","
            settingsContent += "\"notifications\":" + (boolJson settings.notifications) + ","
            settingsContent += "\"autoCheckPackages\":" + (boolJson settings.autoCheckPackages) + ","
            settingsContent += "\"autoCheckRuntime\":" + (boolJson settings.autoCheckRuntime) + ","
            settingsContent += "\"downloadUpdatesAutomatically\":" + (boolJson settings.downloadUpdatesAutomatically) + ","
            settingsContent += "\"updateFrequencyHours\":" + (settings.updateFrequencyHours as string) + ","
            settingsContent += "\"managerLastTab\":" + (utils.jsonString settings.managerLastTab) + ","
            settingsContent += "\"managerFirstOpenCompleted\":" + (boolJson settings.managerFirstOpenCompleted) + ","
            settingsContent += "\"managerSort\":" + (utils.jsonString settings.managerSort) + ","
            settingsContent += "\"managerFilter\":" + (utils.jsonString settings.managerFilter) + ","
            settingsContent += "\"managerFullCards\":" + (boolJson settings.managerFullCards) + ","
            settingsContent += "\"language\":" + (utils.jsonString settings.language) + ","
            settingsContent += "\"managerTheme\":" + (utils.jsonString settings.managerTheme) + ","
            settingsContent += "\"managerThemes\":" + (themeOptionsJson "manager") + ","
            settingsContent += "\"autoStart\":" + (boolJson settings.autoStart) + ","
            settingsContent += "\"openManagerOnStartup\":" + (boolJson settings.openManagerOnStartup) + ","
            settingsContent += "\"developerMode\":" + (boolJson settings.developerMode) + ","
            settingsContent += "\"debugLogging\":" + (boolJson settings.debugLogging) + ","
            settingsContent += "\"apiEndpoint\":" + (utils.jsonString settings.apiEndpoint) + ","
            settingsContent += "\"defaultApiEndpoint\":" + (utils.jsonString utils.defaultApiEndpoint)
            settingsContent += "}"
            return settingsContent
        ),

        fn stateJson = (
            local updateCount = 0
            for packageInfo in owner.packages where packageInfo.updateAvailable do updateCount += 1
            local isRepositoryConfigured = (utils.resolveApiEndpoint owner.settings.apiEndpoint) != ""
            local isRepositoryOnline = owner.catalogState != undefined and owner.catalogState.success
            local connectionState = if (isRepositoryOnline and http != undefined and http.shouldUseCurl()) then "online-curl" else if (isRepositoryOnline) then "online" else if (isRepositoryConfigured) then "configured" else "offline"
            local stateContent = "{"
            stateContent += "\"runtimeVersion\":" + (utils.jsonString owner.version) + ","
            stateContent += "\"packages\":" + packagesJson() + ","
            stateContent += "\"updateCount\":" + (updateCount as string) + ","
            stateContent += "\"connection\":" + (utils.jsonString connectionState) + ","
            stateContent += "\"settings\":" + settingsJson() + ","
            stateContent += "\"collections\":" + collectionsJson() + ","
            stateContent += "\"categories\":" + categoriesJson() + ","
            stateContent += "\"discover\":" + discoverJson() + ","
            stateContent += "\"remoteDetails\":" + remoteDetailsJson()
            stateContent += "}"
            return stateContent
        ),

        fn writeBrowserPayload elementId sourceContent scriptName = (
            if (not dialogOpen or not browserReady) do return true
            try (
                local payloadElement = rolloutRef.browser.Document.GetElementById elementId
                if (payloadElement == undefined) do return false
                payloadElement.InnerText = sourceContent
                rolloutRef.browser.Document.InvokeScript scriptName
                return true
            ) catch (
                logger.logWarning "manager" ("Could not update browser payload " + elementId + ": " + getCurrentException())
                return false
            )
        ),

        fn readBrowserPayload elementId = (
            if (not dialogOpen or not browserReady) do return ""
            try (
                local payloadElement = rolloutRef.browser.Document.GetElementById elementId
                if (payloadElement == undefined or payloadElement.InnerHtml == undefined) do return ""
                return payloadElement.InnerHtml as string
            ) catch (
                logger.logWarning "manager" ("Could not read browser payload " + elementId + ": " + getCurrentException())
                return ""
            )
        ),

        fn refresh = (
            if (owner.settings == undefined) do return false
            return writeBrowserPayload "runtimePayload" (stateJson()) "setRuntimeState"
        ),

        fn handleImageDownloadTimerTick eventSender eventArgs = (
            if (imageCache == undefined) do return false
            local completedDownloadCount = imageCache.pollDownloads()
            if (completedDownloadCount > 0 and dialogOpen and browserReady) do refresh()
            return true
        ),

        fn stopImageDownloadTimer = (
            if (imageDownloadTimer == undefined) do return true
            try (
                imageDownloadTimer.Stop()
                dotNet.removeEventHandler imageDownloadTimer "Tick" handleImageDownloadTimerTick
                imageDownloadTimer.Dispose()
            ) catch (
                logger.logWarning "manager" ("Could not stop image download tracking: " + getCurrentException())
            )
            imageDownloadTimer = undefined
            return true
        ),

        fn startImageDownloadTimer = (
            stopImageDownloadTimer()
            try (
                imageDownloadTimer = dotNetObject "System.Windows.Forms.Timer"
                imageDownloadTimer.Interval = 150
                dotNet.addEventHandler imageDownloadTimer "Tick" handleImageDownloadTimerTick
                imageDownloadTimer.Start()
                return true
            ) catch (
                imageDownloadTimer = undefined
                logger.logWarning "manager" ("Could not start image download tracking: " + getCurrentException())
                return false
            )
        ),

        fn notify messageText notificationType: "info" = (
            if (not owner.settings.notifications) do return true
            return writeBrowserPayload "notificationPayload" (notificationType + "|" + messageText) "showRuntimeNotification"
        ),

        fn decodeUrl sourceContent = (
            try (
                local uriClass = dotNetClass "System.Uri"
                return uriClass.UnescapeDataString sourceContent
            ) catch (
                return sourceContent
            )
        ),

        fn queryParameter queryString parameterName defaultContent: "" = (
            if (queryString == undefined or queryString == "") do return defaultContent
            local parameterEntries = filterString queryString "&"
            for parameterEntry in parameterEntries do (
                local separatorIndex = findString parameterEntry "="
                local currentName = if (separatorIndex == undefined) then parameterEntry else substring parameterEntry 1 (separatorIndex - 1)
                if ((toLower currentName) == (toLower parameterName)) do (
                    local parameterContent = if (separatorIndex == undefined) then "" else substring parameterEntry (separatorIndex + 1) (parameterEntry.count - separatorIndex)
                    return decodeUrl parameterContent
                )
            )
            return defaultContent
        ),

        fn boolParameter queryString parameterName defaultState: false = (
            return utils.boolValue (queryParameter queryString parameterName defaultContent: (if (defaultState) then "true" else "false")) defaultValue: defaultState
        ),

        fn integerParameter queryString parameterName fallbackNumber = (
            try (
                return (queryParameter queryString parameterName defaultContent: (fallbackNumber as string)) as integer
            ) catch (
                return fallbackNumber
            )
        ),

        fn saveView queryString = (
            owner.settings.managerLastTab = queryParameter queryString "tab" defaultContent: owner.settings.managerLastTab
            owner.settings.managerFilter = queryParameter queryString "filter" defaultContent: owner.settings.managerFilter
            owner.settings.managerSort = queryParameter queryString "sort" defaultContent: owner.settings.managerSort
            return owner.saveSettings()
        ),

        fn resetToolbarPlacement = (
            local previousToolbarVisibility = owner.settings.toolbarVisible
            local previousHorizontalX = owner.settings.floatingHorizontalX
            local previousHorizontalY = owner.settings.floatingHorizontalY
            local previousVerticalX = owner.settings.floatingVerticalX
            local previousVerticalY = owner.settings.floatingVerticalY
            owner.settings.toolbarVisible = true
            owner.settings.floatingHorizontalX = -1
            owner.settings.floatingHorizontalY = -1
            owner.settings.floatingVerticalX = -1
            owner.settings.floatingVerticalY = -1
            if (not (owner.saveSettings())) do (
                owner.settings.toolbarVisible = previousToolbarVisibility
                owner.settings.floatingHorizontalX = previousHorizontalX
                owner.settings.floatingHorizontalY = previousHorizontalY
                owner.settings.floatingVerticalX = previousVerticalX
                owner.settings.floatingVerticalY = previousVerticalY
                return false
            )
            return owner.rebuildToolbar()
        ),

        fn saveSettings queryString = (
            local previousToolbarVisibility = owner.settings.toolbarVisible
            local previousToolbarTitleMode = owner.settings.toolbarTitleMode
            local previousToolbarSubtitleMode = owner.settings.toolbarSubtitleMode
            local previousToolbarButtonSize = owner.settings.toolbarButtonSize
            local previousToolbarDockPosition = owner.settings.toolbarDockPosition
            local previousToolbarTheme = owner.settings.toolbarTheme
            local previousManagerTheme = owner.settings.managerTheme
            owner.settings.language = queryParameter queryString "language" defaultContent: owner.settings.language
            owner.settings.managerTheme = queryParameter queryString "managerTheme" defaultContent: owner.settings.managerTheme
            if (themes != undefined) do owner.settings.managerTheme = themes.resolveThemeId "manager" owner.settings.managerTheme
            owner.settings.autoStart = boolParameter queryString "autoStart" defaultState: owner.settings.autoStart
            owner.settings.openManagerOnStartup = boolParameter queryString "openManagerOnStartup" defaultState: owner.settings.openManagerOnStartup
            owner.settings.managerFullCards = boolParameter queryString "managerFullCards" defaultState: owner.settings.managerFullCards
            owner.settings.notifications = boolParameter queryString "notifications" defaultState: owner.settings.notifications
            owner.settings.autoCheckPackages = boolParameter queryString "autoCheckPackages" defaultState: owner.settings.autoCheckPackages
            owner.settings.autoCheckRuntime = boolParameter queryString "autoCheckRuntime" defaultState: owner.settings.autoCheckRuntime
            owner.settings.downloadUpdatesAutomatically = boolParameter queryString "downloadUpdatesAutomatically" defaultState: owner.settings.downloadUpdatesAutomatically
            owner.settings.updateFrequencyHours = amax 1 (amin 720 (integerParameter queryString "updateFrequencyHours" owner.settings.updateFrequencyHours))
            owner.settings.apiEndpoint = queryParameter queryString "apiEndpoint" defaultContent: owner.settings.apiEndpoint
            owner.settings.toolbarVisible = boolParameter queryString "toolbarVisible" defaultState: owner.settings.toolbarVisible
            owner.settings.toolbarTitleMode = queryParameter queryString "toolbarTitleMode" defaultContent: owner.settings.toolbarTitleMode
            owner.settings.toolbarSubtitleMode = queryParameter queryString "toolbarSubtitleMode" defaultContent: owner.settings.toolbarSubtitleMode
            owner.settings.toolbarButtonSize = queryParameter queryString "toolbarButtonSize" defaultContent: owner.settings.toolbarButtonSize
            owner.settings.toolbarDockPosition = queryParameter queryString "toolbarDockPosition" defaultContent: owner.settings.toolbarDockPosition
            owner.settings.toolbarTheme = queryParameter queryString "toolbarTheme" defaultContent: owner.settings.toolbarTheme
            if (themes != undefined) do owner.settings.toolbarTheme = themes.resolveThemeId "toolbar" owner.settings.toolbarTheme
            owner.settings.developerMode = boolParameter queryString "developerMode" defaultState: owner.settings.developerMode
            owner.settings.debugLogging = boolParameter queryString "debugLogging" defaultState: owner.settings.debugLogging
            if (not (owner.saveSettings())) do return false
            if (previousToolbarVisibility != owner.settings.toolbarVisible or previousToolbarTitleMode != owner.settings.toolbarTitleMode or previousToolbarSubtitleMode != owner.settings.toolbarSubtitleMode or previousToolbarButtonSize != owner.settings.toolbarButtonSize or previousToolbarDockPosition != owner.settings.toolbarDockPosition or previousToolbarTheme != owner.settings.toolbarTheme) do owner.rebuildToolbar()
            if (previousManagerTheme != owner.settings.managerTheme and themes != undefined) do (
                if (themes.prepareManagerAssets owner.settings.managerTheme) then (
                    browserReady = false
                    rolloutRef.browser.Navigate (utils.fileUrl (runtimeRoot + @"ui\manager\index.html"))
                ) else (
                    logger.logError "themes" "Manager theme assets could not be prepared."
                )
            )
            return true
        ),

        fn commandArgument commandPath commandPrefix = (
            if (commandPath.count <= commandPrefix.count) do return ""
            return decodeUrl (substring commandPath (commandPrefix.count + 1) (commandPath.count - commandPrefix.count))
        ),

        fn handleCommand commandPath queryString = (
            local isSuccess = true
            if (commandPath == "ready") do (
                browserReady = true
                if (not owner.settings.managerFirstOpenCompleted) do (
                    owner.settings.managerFirstOpenCompleted = true
                    owner.settings.managerLastTab = "discover"
                    if (not (owner.saveSettings())) do logger.logWarning "manager" "Could not save the first Manager opening state."
                )
                return refresh()
            )
            if (commandPath == "refresh") do (
                owner.scan()
                owner.rebuildToolbar()
                notify "Package list refreshed." notificationType: "success"
            )
            if (commandPath == "check-updates") do (
                isSuccess = owner.checkUpdates()
                if (not isSuccess) do notify "An update check is already running." notificationType: "info"
            )
            if (commandPath == "collections") do (
                local collectionsResponse = owner.browseCollections()
                isSuccess = collectionsResponse.success
            )
            if (commandPath == "categories") do (
                local categoriesResponse = owner.browseCategories()
                isSuccess = categoriesResponse.success
            )
            if (commandPath == "discover") do (
                owner.settings.managerLastTab = "discover"
                owner.saveSettings()
                owner.browseCollections()
                owner.browseCategories()
                local discoverCatalogResponse = owner.browsePackages queryText: (queryParameter queryString "query") categoryFilter: "" sortMode: "popular" pageNumber: 1 pageSize: 24
                isSuccess = discoverCatalogResponse.success
                if (not isSuccess) do notify (if (discoverCatalogResponse.errorMessage != "") then discoverCatalogResponse.errorMessage else "Could not load the package catalog.") notificationType: "error"
            )
            if (commandPath == "catalog") do (
                owner.settings.managerLastTab = "discover"
                owner.saveSettings()
                local catalogResponse = owner.browsePackages queryText: (queryParameter queryString "query") categoryFilter: (queryParameter queryString "category") sortMode: (queryParameter queryString "sort" defaultContent: "popular") pageNumber: (integerParameter queryString "page" 1) pageSize: (integerParameter queryString "pageSize" 24) featuredOnly: (boolParameter queryString "featured" defaultState: false) collectionSlug: (queryParameter queryString "collection")
                isSuccess = catalogResponse.success
                if (not isSuccess) do notify (if (catalogResponse.errorMessage != "") then catalogResponse.errorMessage else "Could not load the package catalog.") notificationType: "error"
            )
            if (commandPath == "update-all") do (
                isSuccess = owner.updateAll()
                notify (if (isSuccess) then "Packages updated." else "Package update failed. Check the Runtime log.") notificationType: (if (isSuccess) then "success" else "error")
            )
            if (commandPath == "open-website") do (
                try (
                    shellLaunch "https://maxpkg.dev/" ""
                ) catch (
                    logger.logError "manager" ("Could not open maxpkg.dev: " + getCurrentException())
                    isSuccess = false
                )
                if (not isSuccess) do notify "maxpkg.dev could not be opened." notificationType: "error"
            )
            if (commandPath == "reset-toolbar-order") do (
                isSuccess = owner.resetToolbarOrder()
                notify (if (isSuccess) then "Toolbar order reset." else "Could not reset toolbar order.") notificationType: (if (isSuccess) then "success" else "error")
            )
            if (commandPath == "reset-toolbar") do (
                isSuccess = resetToolbarPlacement()
                notify (if (isSuccess) then "Toolbar restarted and its position was reset." else "Could not reset the Toolbar.") notificationType: (if (isSuccess) then "success" else "error")
            )
            if (commandPath == "save-settings") do (
                isSuccess = saveSettings queryString
                local isSilentSave = boolParameter queryString "silent" defaultState: false
                if (not isSuccess or not isSilentSave) do notify (if (isSuccess) then "Settings saved." else "Could not save settings.") notificationType: (if (isSuccess) then "success" else "error")
            )
            if (commandPath == "uninstall-runtime") do (
                isSuccess = scheduleRuntimeUninstall()
                if (not isSuccess) do (
                    notify "MaxPkg Runtime could not start uninstalling." notificationType: "error"
                    refresh()
                )
                return isSuccess
            )
            if (commandPath == "view") do isSuccess = saveView queryString
            if (matchPattern commandPath pattern: "run/*" ignoreCase: true) do (
                isSuccess = owner.run (commandArgument commandPath "run/")
                if (not isSuccess) do notify "Package could not be started." notificationType: "error"
            )
            if (matchPattern commandPath pattern: "update/*" ignoreCase: true) do (
                local installStatus = owner.updatePackage (commandArgument commandPath "update/")
                isSuccess = installStatus.success
                notify (if (isSuccess) then "Package updated." else installStatus.errorMessage) notificationType: (if (isSuccess) then "success" else "error")
            )
            if (matchPattern commandPath pattern: "install/*" ignoreCase: true) do (
                local installStatus = owner.install (commandArgument commandPath "install/") showNotification: true
                isSuccess = installStatus.success
                notify (if (isSuccess) then "Package installed." else installStatus.errorMessage) notificationType: (if (isSuccess) then "success" else "error")
            )
            if (matchPattern commandPath pattern: "remote-details/*" ignoreCase: true) do (
                local detailsResponse = owner.getRemotePackageDetails (commandArgument commandPath "remote-details/")
                isSuccess = detailsResponse.success
                local isManifestFallbackAllowed = boolParameter queryString "manifestFallback" defaultState: false
                if (not isSuccess and not isManifestFallbackAllowed) do notify (if (detailsResponse.errorMessage != "") then detailsResponse.errorMessage else "Could not load package details.") notificationType: "error"
            )
            if (matchPattern commandPath pattern: "uninstall/*" ignoreCase: true) do (
                local packageGuid = commandArgument commandPath "uninstall/"
                local packageInfo = owner.getPackage packageGuid
                if (packageInfo == undefined) then (
                    isSuccess = false
                ) else if (queryBox ("Uninstall " + packageInfo.packageName + "?") title: "MaxPkg") then (
                    isSuccess = owner.uninstall packageGuid showNotification: true
                    notify (if (isSuccess) then "Package uninstalled." else "Package could not be uninstalled.") notificationType: (if (isSuccess) then "success" else "error")
                )
            )
            if (matchPattern commandPath pattern: "toggle-package-toolbar/*" ignoreCase: true) do (
                local packageGuid = commandArgument commandPath "toggle-package-toolbar/"
                local packageInfo = owner.getPackage packageGuid
                if (packageInfo == undefined) then
                    isSuccess = false
                else
                    isSuccess = owner.setToolbarVisible packageGuid (packageIsHidden packageGuid)
            )
            if (commandPath == "set-toolbar-order") do (
                local toolbarOrderContent = readBrowserPayload "toolbarOrderPayload"
                local orderedPackageGuids = if (toolbarOrderContent == "") then #() else filterString toolbarOrderContent "|"
                isSuccess = owner.setToolbarOrder orderedPackageGuids
                if (not isSuccess) do notify "Toolbar order could not be saved." notificationType: "error"
            )
            if (matchPattern commandPath pattern: "open-folder/*" ignoreCase: true) do isSuccess = owner.openPackageFolder (commandArgument commandPath "open-folder/")
            if (matchPattern commandPath pattern: "copy-package-id/*" ignoreCase: true) do (
                local packageId = commandArgument commandPath "copy-package-id/"
                if (packageId == "") then (
                    isSuccess = false
                ) else (
                    try (
                        setClipboardText packageId
                        isSuccess = true
                    ) catch (
                        logger.logError "manager" ("Could not copy Package ID: " + getCurrentException())
                        isSuccess = false
                    )
                )
                notify (if (isSuccess) then "Package ID copied to clipboard." else "Package ID could not be copied.") notificationType: (if (isSuccess) then "success" else "error")
            )
            if (matchPattern commandPath pattern: "copy-package-link/*" ignoreCase: true) do (
                local packageSlug = commandArgument commandPath "copy-package-link/"
                local packagePageUrl = utils.packagePageUrl owner.settings.apiEndpoint packageSlug
                if (packagePageUrl == "") then (
                    isSuccess = false
                ) else (
                    try (
                        setClipboardText packagePageUrl
                        isSuccess = true
                    ) catch (
                        logger.logError "manager" ("Could not copy package link: " + getCurrentException())
                        isSuccess = false
                    )
                )
                notify (if (isSuccess) then "Package link copied to clipboard." else "Package link could not be copied.") notificationType: (if (isSuccess) then "success" else "error")
            )
            if (matchPattern commandPath pattern: "package-link/*" ignoreCase: true) do (
                local packageGuid = commandArgument commandPath "package-link/"
                local packageLinkKind = queryParameter queryString "kind"
                isSuccess = owner.openPackageLink packageGuid packageLinkKind
                if (not isSuccess) do notify "Package link could not be opened." notificationType: "error"
            )
            if (matchPattern commandPath pattern: "help/*" ignoreCase: true) do (
                isSuccess = owner.openPackageHelp (commandArgument commandPath "help/")
                if (not isSuccess) do notify "Package Help link could not be opened." notificationType: "error"
            )
            refresh()
            return isSuccess
        ),

        fn onNavigate navigationArgs = (
            local navigationUrl = ""
            try (
                navigationUrl = navigationArgs.Url.AbsoluteUri as string
            ) catch (
                logger.logWarning "manager" ("Could not read navigation URL: " + getCurrentException())
                return false
            )
            if (not (matchPattern navigationUrl pattern: "maxpkg://manager/*" ignoreCase: true)) do return true
            navigationArgs.Cancel = true
            setManagerFocusState true
            local commandText = substring navigationUrl 18 (navigationUrl.count - 17)
            local queryIndex = findString commandText "?"
            local commandPath = if (queryIndex == undefined) then commandText else substring commandText 1 (queryIndex - 1)
            local queryString = if (queryIndex == undefined) then "" else substring commandText (queryIndex + 1) (commandText.count - queryIndex)
            try (
                return handleCommand commandPath queryString
            ) catch (
                logger.logError "manager" ("Command failed (" + commandPath + "): " + getCurrentException())
                notify ("Manager action failed: " + commandPath) notificationType: "error"
                refresh()
                return false
            )
        ),

        fn configureBrowser browserControl = (
            if (themes != undefined and not (themes.prepareManagerAssets owner.settings.managerTheme)) do logger.logWarning "themes" "Manager theme assets could not be refreshed."
            local managerHtmlPath = runtimeRoot + @"ui\manager\index.html"
            if (not (doesFileExist managerHtmlPath)) do (
                logger.logError "manager" ("HTML file not found: " + managerHtmlPath)
                return false
            )
            browserControl.ScriptErrorsSuppressed = true
            browserControl.ScrollBarsEnabled = false
            browserControl.IsWebBrowserContextMenuEnabled = false
            browserControl.AllowWebBrowserDrop = false
            browserControl.WebBrowserShortcutsEnabled = true
            browserControl.Dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            browserReady = false
            browserControl.Navigate (utils.fileUrl managerHtmlPath)
            return true
        ),

        fn synchronizeBrowserSize browserControl dialogSize: undefined = (
            try (
                if (dialogSize != undefined) do (
                    browserControl.width = amax 1 dialogSize.x
                    browserControl.height = amax 1 dialogSize.y
                )
                browserControl.Dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
                if (browserControl.Parent != undefined) do browserControl.Parent.PerformLayout()
                return true
            ) catch (
                logger.logWarning "manager" ("Could not synchronize browser size: " + getCurrentException())
                return false
            )
        ),

        fn onDocumentReady browserControl documentArgs = (
            if (browserControl.Document == undefined) do return false
            synchronizeBrowserSize browserControl dialogSize: (getDialogSize rolloutRef)
            if (uiScale != undefined) do uiScale.applyBrowserScale browserControl constrainViewport: true
            return true
        ),

        fn handleDialogOpened browserControl = (
            dialogOpen = true
            synchronizeBrowserSize browserControl dialogSize: (getDialogSize rolloutRef)
            startFocusTimer()
            startImageDownloadTimer()
            return configureBrowser browserControl
        ),

        fn onResize dialogSize = (
            if (owner.settings == undefined) do return false
            owner.settings.managerWidth = amax minimumDialogWidth dialogSize.x
            owner.settings.managerHeight = amax minimumDialogHeight dialogSize.y
            return true
        ),

        fn handleDialogResized dialogSize browserControl = (
            local constrainedDialogSize = [amax minimumDialogWidth dialogSize.x, amax minimumDialogHeight dialogSize.y]
            if (constrainedDialogSize.x != dialogSize.x or constrainedDialogSize.y != dialogSize.y) do (
                setDialogSize rolloutRef constrainedDialogSize
                return true
            )
            synchronizeBrowserSize browserControl dialogSize: constrainedDialogSize
            if (uiScale != undefined) do uiScale.applyBrowserScale browserControl constrainViewport: true
            onResize constrainedDialogSize
            return true
        ),

        fn onMove dialogPosition = (
            if (owner.settings == undefined) do return false
            owner.settings.managerPositionX = dialogPosition.x
            owner.settings.managerPositionY = dialogPosition.y
            return true
        ),

        fn handleDialogClosed = (
            stopFocusTimer()
            stopImageDownloadTimer()
            if (imageCache != undefined) do imageCache.cancelDownloads()
            setManagerFocusState false
            dialogOpen = false
            browserReady = false
            if (owner.settings == undefined) do return true
            return owner.saveSettings()
        ),

        fn destroyManagerDialog = (
            if (not dialogOpen) do return true
            try (
                destroyDialog rolloutRef
            ) catch (
                logger.logWarning "manager" ("Could not close Manager: " + getCurrentException())
                return false
            )
            dialogOpen = false
            browserReady = false
            return true
        ),

        fn showManager = (
            destroyManagerDialog()
            dialogOpen = true
            try (
                local screenClass = dotNetClass "System.Windows.Forms.Screen"
                local hasSavedPosition = owner.settings.managerPositionX >= 0 and owner.settings.managerPositionY >= 0
                local targetScreenInfo = screenClass.PrimaryScreen
                if (hasSavedPosition) do (
                    local screenPoint = dotNetObject "System.Drawing.Point" owner.settings.managerPositionX owner.settings.managerPositionY
                    targetScreenInfo = screenClass.FromPoint screenPoint
                )
                local workingArea = targetScreenInfo.WorkingArea
                local availableDialogWidth = amax 1 workingArea.Width
                local availableDialogHeight = amax 1 workingArea.Height
                local minimumAvailableWidth = amin minimumDialogWidth availableDialogWidth
                local minimumAvailableHeight = amin minimumDialogHeight availableDialogHeight
                local dialogWidth = amax minimumAvailableWidth (amin owner.settings.managerWidth availableDialogWidth)
                local dialogHeight = amax minimumAvailableHeight (amin owner.settings.managerHeight availableDialogHeight)
                local dialogStyle = #(#style_titlebar, #style_sysmenu, #style_resizing)
                if (hasSavedPosition) then (
                    local maximumPositionX = workingArea.Right - dialogWidth
                    local maximumPositionY = workingArea.Bottom - dialogHeight
                    local dialogPositionX = amax workingArea.Left (amin owner.settings.managerPositionX maximumPositionX)
                    local dialogPositionY = amax workingArea.Top (amin owner.settings.managerPositionY maximumPositionY)
                    createDialog rolloutRef width: dialogWidth height: dialogHeight pos: [dialogPositionX, dialogPositionY] style: dialogStyle
                ) else (
                    createDialog rolloutRef width: dialogWidth height: dialogHeight style: dialogStyle
                )
                return true
            ) catch (
                dialogOpen = false
                logger.logError "manager" ("Could not open Manager: " + getCurrentException())
                return false
            )
        ),

        fn shutdownManager = (
            stopRuntimeUninstallTimer()
            stopImageDownloadTimer()
            if (imageCache != undefined) do imageCache.cancelDownloads()
            local isClosed = destroyManagerDialog()
            if (isClosed) do managerOwner = undefined
            return isClosed
        ),

        fn initialize runtimeOwner runtimePath utilsModule moduleInstance = (
            owner = runtimeOwner
            runtimeRoot = runtimePath
            utils = utilsModule
            rolloutRef = MaxPkgRuntimeManagerRollout
            managerOwner = moduleInstance
            return true
        )
    )

    MaxPkgManagerModule()
)
