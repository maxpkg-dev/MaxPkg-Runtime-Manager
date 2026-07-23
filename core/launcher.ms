-- Launches installed package entry scripts.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgLauncherModule (
        logger,

        fn run package = (
            if package == undefined do return false
            local entryPath = package.installPath + package.entry
            if not (doesFileExist entryPath) do (
                logger.logError "launcher" ("Entry file not found: " + entryPath)
                return false
            )
            try (
                local runtime = toLower package.runtime
                local extension = toLower (getFilenameType entryPath)
                if runtime == "python" or extension == ".py" then
                    python.ExecuteFile entryPath
                else if runtime == "maxscript" or extension == ".ms" or extension == ".mse" then
                    fileIn entryPath
                else (
                    logger.logError "launcher" ("Unsupported runtime: " + package.runtime)
                    return false
                )
                logger.logInfo "launcher" ("Ran " + package.guid)
                return true
            ) catch (
                logger.logError "launcher" (package.guid + ": " + getCurrentException())
                return false
            )
        )
    )

    MaxPkgLauncherModule()
)
