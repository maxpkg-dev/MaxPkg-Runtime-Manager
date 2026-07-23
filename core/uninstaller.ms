-- Runs package uninstall hooks and removes package files.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgUninstallerModule (
        owner,
        operations,
        api,
        manager,
        runtimeRoot,
        utils,
        logger,

        fn runHook package = (
            local hookPath = package.installPath + package.uninstall
            if (package.uninstall == "" or not (doesFileExist hookPath)) do return true
            try (
                fileIn hookPath
                return true
            ) catch (
                logger.logError "uninstaller" ("Hook failed: " + getCurrentException())
                return false
            )
        ),

        fn isSafePackageFolder package = (
            if (package.installPath == "" or package.manifestPath == "" or not (doesFileExist package.manifestPath)) do (
                logger.logError "uninstaller" ("Refused unresolved package path for " + package.guid)
                return false
            )
            if (not (utils.pathInside package.manifestPath package.installPath)) do (
                logger.logError "uninstaller" ("Manifest is outside package folder: " + package.manifestPath)
                return false
            )
            if ((utils.pathInside runtimeRoot package.installPath) or (utils.pathInside package.installPath runtimeRoot)) do (
                logger.logError "uninstaller" ("Refused unsafe path: " + package.installPath)
                return false
            )
            local protectedRoots = #((getDir #temp), (getDir #userScripts), (getDir #userStartupScripts))
            for protectedRoot in protectedRoots where (toLower (utils.ensureSlash protectedRoot)) == (toLower (utils.ensureSlash package.installPath)) do (
                logger.logError "uninstaller" ("Refused protected root: " + package.installPath)
                return false
            )
            return true
        ),

        fn removeFolder package = (
            if (not (doesDirectoryExist package.installPath)) do return true
            if (not (isSafePackageFolder package)) do return false
            if (not (utils.forceDeleteFolder package.installPath)) do (
                logger.logError "uninstaller" ("Could not remove package folder: " + package.installPath)
                return false
            )
            return true
        ),

        fn removePackageMacro package = (
            local userMacrosRoot = utils.ensureSlash (getDir #userMacros)
            local userIconsRoot = utils.ensureSlash (getDir #userIcons)
            local macroName = "MaxPkg_" + (substituteString package.guid "-" "")
            local macroFilePaths = #(
                userMacrosRoot + "maxpkg-" + package.guid + ".mcr",
                userMacrosRoot + "MaxPkg-" + macroName + ".mcr"
            )
            local iconFilePath = userIconsRoot + package.guid + ".svg"
            local isRemoved = true
            for macroFilePath in macroFilePaths do (
                if (not (utils.forceDeleteFile macroFilePath)) do (
                    logger.logError "uninstaller" ("Could not remove package MacroScript: " + macroFilePath)
                    isRemoved = false
                )
            )
            if (not (utils.forceDeleteFile iconFilePath)) do (
                logger.logWarning "uninstaller" ("Could not remove package icon: " + iconFilePath)
            )
            return isRemoved
        ),

        fn uninstall package = (
            if (package == undefined) do return false
            if (not (operations.begin "uninstall" packageGuid: package.guid)) do return false
            local isSuccess = false
            try (
                isSuccess = isSafePackageFolder package
                if (isSuccess) do isSuccess = runHook package
                if (isSuccess) do (
                    local isMacroRemoved = removePackageMacro package
                    local isFolderRemoved = removeFolder package
                    isSuccess = isMacroRemoved and isFolderRemoved
                )
                owner.scan()
                if (api.contains owner.packages package.guid) do isSuccess = false
                owner.rebuildToolbar()
                try (
                    manager.refresh()
                ) catch (
                    logger.logWarning "uninstaller" ("Manager refresh failed: " + getCurrentException())
                )
            ) catch (
                logger.logError "uninstaller" ("Uninstall operation failed for " + package.guid + ": " + getCurrentException())
                isSuccess = false
            )
            return operations.finish success: isSuccess
        )
    )

    MaxPkgUninstallerModule()
)
