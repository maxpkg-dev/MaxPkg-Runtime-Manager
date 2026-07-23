-- Checks for and applies installed package updates.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgUpdaterModule (
        owner,
        operations,
        manager,
        logger,
        installer,
        api,
        repository,

        fn versionParts versionContent = (
            local versionTokens = filterString versionContent ".-"
            local versionNumbers = #(0,0,0)
            for versionIndex in 1 to (amin versionTokens.count 3) do versionNumbers[versionIndex] = try (
                versionTokens[versionIndex] as integer
            ) catch (
                0
            )
            return versionNumbers
        ),

        fn newer candidateVersion installedVersion = (
            local candidateParts = versionParts candidateVersion
            local installedParts = versionParts installedVersion
            for versionIndex in 1 to 3 do (
                if (candidateParts[versionIndex] > installedParts[versionIndex]) do return true
                if (candidateParts[versionIndex] < installedParts[versionIndex]) do return false
            )
            return false
        ),

        fn packageVersions = (
            local packageVersions = #()
            for package in owner.packages do append packageVersions (package.guid + "@" + package.version)
            return packageVersions
        ),

        fn checkUpdates = (
            local installedVersions = packageVersions()
            if (installedVersions.count == 0) do return #()
            local updateResponse = repository.updates installedVersions channelName: owner.runtimeChannel
            if (not updateResponse.success) do (
                logger.logError "updater" ((if (updateResponse.errorCode != "") then updateResponse.errorCode + ": " else "") + updateResponse.errorMessage)
                return #()
            )
            local updates = #()
            for package in owner.packages do (
                local updateInfo = api.resolve updateResponse.packages package.guid
                package.latestVersion = if (updateInfo != undefined) then updateInfo.latestVersion else ""
                package.downloadUrl = if (updateInfo != undefined) then updateInfo.downloadUrl else ""
                package.updateAvailable = package.latestVersion != "" and package.downloadUrl != "" and newer package.latestVersion package.version
                if (package.updateAvailable) do append updates package
            )
            logger.logInfo "updater" ("Available updates: " + (updates.count as string))
            return updates
        ),

        fn updateAll = (
            if (not (operations.begin "updateAll")) do return false
            local isSuccess = false
            try (
                local updates = checkUpdates()
                isSuccess = true
                for package in updates while isSuccess do isSuccess = installer.installSource package.downloadUrl
                owner.scan()
                for updatePackage in updates while isSuccess do (
                    local installedPackage = api.resolve owner.packages updatePackage.guid
                    if (installedPackage == undefined) then
                        isSuccess = false
                    else if (newer updatePackage.latestVersion installedPackage.version) then
                        isSuccess = false
                )
                if (not isSuccess) do logger.logError "updater" "One or more updates could not be verified after installation."
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
            return operations.finish success: isSuccess
        )
    )

    MaxPkgUpdaterModule()
)
