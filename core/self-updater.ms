-- Updates MaxPkg Runtime and restarts the updated code.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg

    struct MaxPkgSelfUpdaterModule (
        owner,
        operations,
        installer,
        runtimeRoot,
        logger,

        fn reloadRuntime = (
            local startupFile = runtimeRoot + "startup.ms"
            if not (doesFileExist startupFile) do return false
            try (
                local isReloaded = fileIn startupFile
                return isReloaded == true and MaxPkg != undefined
            ) catch (
                logger.logError "self-updater" ("Reload failed: " + getCurrentException())
                return false
            )
        ),

        fn update = (
            if owner.settings.runtimeUpdateUrl == "" do (
                logger.logInfo "self-updater" "RuntimeUrl is not configured; staying offline"
                return false
            )
            if not (operations.begin "selfUpdate") do return false
            local isSuccess = false
            try (
                isSuccess = installer.installSource owner.settings.runtimeUpdateUrl
            ) catch (
                logger.logError "self-updater" ("Self-update operation failed: " + getCurrentException())
                isSuccess = false
            )
            operations.finish success:isSuccess
            if isSuccess do isSuccess = reloadRuntime()
            return isSuccess
        )
    )

    MaxPkgSelfUpdaterModule()
)
