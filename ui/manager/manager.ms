(
    local managerOwner = undefined

    rollout MaxPkgRuntimeManagerRollout "MaxPkg Manager" width:520 height:410 (
        listBox packageList "Installed packages" pos:[12,12] width:496 height:15
        button runButton "Run" pos:[12,292] width:90 height:26
        button uninstallButton "Uninstall" pos:[108,292] width:90 height:26
        button hideButton "Hide button" pos:[214,292] width:90 height:26
        button upButton "Move up" pos:[310,292] width:90 height:26
        button downButton "Move down" pos:[406,292] width:90 height:26
        button toolbarButton "Hide toolbar" pos:[12,330] width:110 height:26
        button refreshButton "Refresh" pos:[310,330] width:90 height:26
        button closeButton "Close" pos:[406,330] width:90 height:26

        on MaxPkgRuntimeManagerRollout open do if managerOwner != undefined do managerOwner.refresh()
        on runButton pressed do if managerOwner != undefined do managerOwner.runSelected()
        on uninstallButton pressed do if managerOwner != undefined do managerOwner.uninstallSelected()
        on hideButton pressed do if managerOwner != undefined do managerOwner.toggleSelected()
        on upButton pressed do if managerOwner != undefined do managerOwner.moveSelected -1
        on downButton pressed do if managerOwner != undefined do managerOwner.moveSelected 1
        on toolbarButton pressed do if managerOwner != undefined do managerOwner.toggleToolbar()
        on refreshButton pressed do if managerOwner != undefined do managerOwner.refreshAll()
        on closeButton pressed do destroyDialog MaxPkgRuntimeManagerRollout
    )

    struct MaxPkgManagerModule (
        owner,
        settingsModule,
        logger,
        rolloutRef,

        fn packageLabels = (
            local packageNames = #()
            for package in owner.packages do append packageNames (package.name + "  v" + package.version + "  -  " + package.developer)
            return packageNames
        ),

        fn selectedPackage = (
            local index = rolloutRef.packageList.selection
            if index < 1 or index > owner.packages.count do return undefined
            return owner.packages[index]
        ),

        fn refresh = (
            if owner.settings == undefined do return false
            rolloutRef.packageList.items = packageLabels()
            rolloutRef.toolbarButton.caption = if owner.settings.toolbarVisible then "Hide toolbar" else "Show toolbar"
            return true
        ),

        fn hiddenIndex guid = (
            for index in 1 to owner.settings.hiddenPackages.count where (toLower owner.settings.hiddenPackages[index]) == (toLower guid) do return index
            return 0
        ),

        fn toggleSelected = (
            local package = selectedPackage()
            if package == undefined do return false
            local index = hiddenIndex package.guid
            if index > 0 then deleteItem owner.settings.hiddenPackages index else append owner.settings.hiddenPackages package.guid
            if not (settingsModule.save()) do (
                local rollbackIndex = hiddenIndex package.guid
                if index > 0 then append owner.settings.hiddenPackages package.guid else if rollbackIndex > 0 do deleteItem owner.settings.hiddenPackages rollbackIndex
                logger.logError "manager" ("Could not save toolbar visibility for " + package.guid)
                return false
            )
            return owner.rebuildToolbar()
        ),

        fn completeOrder = (
            local order = copy owner.settings.toolbarOrder
            for package in owner.packages do (
                local exists = false
                for guid in order where (toLower guid) == (toLower package.guid) do exists = true
                if not exists do append order package.guid
            )
            return order
        ),

        fn moveSelected direction = (
            local package = selectedPackage()
            if package == undefined do return false
            local order = completeOrder()
            local currentIndex = 0
            for index in 1 to order.count where (toLower order[index]) == (toLower package.guid) do currentIndex = index
            local targetIndex = currentIndex + direction
            if currentIndex < 1 or targetIndex < 1 or targetIndex > order.count do return false
            local swapGuid = order[targetIndex]
            order[targetIndex] = order[currentIndex]
            order[currentIndex] = swapGuid
            local previousOrder = owner.settings.toolbarOrder
            owner.settings.toolbarOrder = order
            if not (settingsModule.save()) do (
                owner.settings.toolbarOrder = previousOrder
                logger.logError "manager" ("Could not save toolbar order for " + package.guid)
                return false
            )
            return owner.rebuildToolbar()
        ),

        fn toggleToolbar = (
            local previousVisibility = owner.settings.toolbarVisible
            owner.settings.toolbarVisible = not previousVisibility
            if not (settingsModule.save()) do (
                owner.settings.toolbarVisible = previousVisibility
                logger.logError "manager" "Could not save toolbar visibility."
                return false
            )
            local isRebuilt = owner.rebuildToolbar()
            refresh()
            return isRebuilt
        ),

        fn refreshAll = (
            owner.scan()
            local isRebuilt = owner.rebuildToolbar()
            refresh()
            return isRebuilt
        ),

        fn runSelected = (
            local package = selectedPackage()
            if package == undefined do return false
            return owner.run package.guid
        ),

        fn uninstallSelected = (
            local package = selectedPackage()
            if package == undefined do return false
            if not (queryBox ("Uninstall " + package.name + "?") title:"MaxPkg") do return false
            local isUninstalled = owner.uninstall package.guid
            refresh()
            return isUninstalled
        ),

        fn open = (
            try (
                destroyDialog rolloutRef
            ) catch (
            )
            try (
                createDialog rolloutRef width:520 height:410 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
                return true
            ) catch (
                logger.logError "manager" ("Could not open Manager: " + getCurrentException())
                return false
            )
        ),

        fn close = (
            try (
                destroyDialog rolloutRef
                return true
            ) catch (
                logger.logWarning "manager" ("Could not close Manager: " + getCurrentException())
                return false
            )
        ),

        fn shutdownManager = (
            local isClosed = close()
            if isClosed do managerOwner = undefined
            return isClosed
        ),

        fn initialize runtimeOwner moduleInstance = (
            owner = runtimeOwner
            rolloutRef = MaxPkgRuntimeManagerRollout
            managerOwner = moduleInstance
            return true
        )
    )

    MaxPkgManagerModule()
)
