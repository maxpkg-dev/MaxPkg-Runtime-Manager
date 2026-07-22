(
    struct MaxPkgUpdaterModule (
        owner,
        operations,
        manager,
        runtimeRoot,
        http,
        ini,
        utils,
        logger,
        installer,
        api,

        fn versionParts version = (
            local versionTokens = filterString version ".-"
            local versionNumbers = #(0,0,0)
            for index in 1 to (amin versionTokens.count 3) do versionNumbers[index] = try (
                versionTokens[index] as integer
            ) catch (
                0
            )
            return versionNumbers
        ),

        fn newer candidate installed = (
            local candidateParts = versionParts candidate
            local installedParts = versionParts installed
            for index in 1 to 3 do (
                if candidateParts[index] > installedParts[index] do return true
                if candidateParts[index] < installedParts[index] do return false
            )
            return false
        ),

        fn requestBody = (
            local packageVersions = #()
            for package in owner.packages do append packageVersions (package.guid + "@" + package.version)
            local uriClass = dotNetClass "System.Uri"
            return "packages=" + (uriClass.EscapeDataString (utils.join packageVersions separator:","))
        ),

        fn checkUpdates = (
            if owner.settings.updateUrl == "" do (
                logger.logInfo "updater" "BatchUrl is not configured; staying offline"
                return #()
            )
            local response = http.post owner.settings.updateUrl (requestBody())
            if response == undefined do return #()
            local responseFile = runtimeRoot + "data\\update-response.ini"
            if not (utils.writeText responseFile response) do (
                logger.logError "updater" ("Could not write update response: " + responseFile)
                return #()
            )
            local updates = #()
            for package in owner.packages do (
                local latest = ini.read responseFile package.guid "Version"
                local url = ini.read responseFile package.guid "DownloadUrl"
                package.latestVersion = latest
                package.downloadUrl = url
                package.updateAvailable = latest != "" and url != "" and newer latest package.version
                if package.updateAvailable do append updates package
            )
            logger.logInfo "updater" ("Available updates: " + (updates.count as string))
            return updates
        ),

        fn updateAll = (
            if not (operations.begin "updateAll") do return false
            local isSuccess = false
            try (
                local updates = checkUpdates()
                isSuccess = true
                for package in updates while isSuccess do isSuccess = installer.installSource package.downloadUrl
                owner.scan()
                for updatePackage in updates while isSuccess do (
                    local installedPackage = api.resolve owner.packages updatePackage.guid
                    if installedPackage == undefined then
                        isSuccess = false
                    else if newer updatePackage.latestVersion installedPackage.version do
                        isSuccess = false
                )
                if not isSuccess do logger.logError "updater" "One or more updates could not be verified after installation."
                owner.rebuildToolbar()
                try (
                    manager.refresh()
                ) catch (
                    logger.logWarning "updater" ("Manager refresh failed: " + getCurrentException())
                )
            ) catch (
                logger.logError "updater" ("Update-all operation failed: " + getCurrentException())
                isSuccess = false
            )
            return operations.finish success:isSuccess
        )
    )

    MaxPkgUpdaterModule()
)
