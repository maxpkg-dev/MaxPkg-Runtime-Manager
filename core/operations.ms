-- Coordinates mutually exclusive package operations.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgOperationData (
        kind = "",
        packageGuid = "",
        startedAt = undefined
    )

    struct MaxPkgOperationsModule (
        owner,
        logger,
        current,

        fn isBusy = (
            return current != undefined
        ),

        fn begin kind packageGuid: "" = (
            if (current != undefined) do (
                logger.logWarning "operations" ("Rejected " + kind + "; " + current.kind + " is active")
                return false
            )
            current = MaxPkgOperationData kind: kind packageGuid: packageGuid startedAt: localTime
            if (owner != undefined) do owner.operation = current
            logger.logInfo "operations" ("Started " + kind)
            return true
        ),

        fn finish success: true = (
            local completedKind = if (current != undefined) then current.kind else "unknown"
            current = undefined
            if (owner != undefined) do owner.operation = undefined
            logger.logInfo "operations" ("Finished " + completedKind + "; success=" + (success as string))
            return success
        )
    )

    MaxPkgOperationsModule()
)
