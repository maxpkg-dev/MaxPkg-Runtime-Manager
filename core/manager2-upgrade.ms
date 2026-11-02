-- Offers and installs the MaxPkg Manager 2.0 upgrade for 3ds Max 2022 and newer.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    global MaxPkg

    local upgradeDialogChoice = "later"
    local upgradeDialogVersion = ""

    rollout MaxPkgManager2UpgradeRollout "MaxPkg Manager 2.0" width: 460 height: 205 (
        label headingLabel "MaxPkg Manager 2.0 is available" align: #left offset: [0, 8]
        label detailsLabel "" align: #left width: 430 height: 78 offset: [0, 4]
        button upgradeButton "Upgrade now" width: 130 height: 28 across: 3 align: #left offset: [0, 10]
        button laterButton "Remind me later" width: 130 height: 28 offset: [0, 10]
        button neverButton "Do not ask again" width: 130 height: 28 align: #right offset: [0, 10]

        on MaxPkgManager2UpgradeRollout open do (
            detailsLabel.text = "Version " + upgradeDialogVersion + " has a new interface and runs on 3ds Max 2022 and newer. Your installed scripts, toolbar layout and settings are kept. The current Runtime is backed up first and restored automatically if the upgrade fails."
        )
        on upgradeButton pressed do (
            upgradeDialogChoice = "upgrade"
            destroyDialog MaxPkgManager2UpgradeRollout
        )
        on laterButton pressed do (
            upgradeDialogChoice = "later"
            destroyDialog MaxPkgManager2UpgradeRollout
        )
        on neverButton pressed do (
            upgradeDialogChoice = "never"
            destroyDialog MaxPkgManager2UpgradeRollout
        )
    )

    struct MaxPkgManager2OfferData (
        hasSection = false,
        isEnabled = false,
        version = "",
        url = "",
        sha256 = "",
        minMaxVersion = 24000,
        isValid = false,
        problem = ""
    )

    struct MaxPkgManager2UpgradeModule (
        operations,
        logger,
        utils,
        ini,
        http,
        runtimeRoot,
        minimumMaxVersion = 24000,
        downloadUrlPrefix = "https://github.com/maxpkg-dev/MaxPkg-Runtime-Manager-Qt/releases/download/",
        maximumFailures = 3,
        retryDelayHours = 24,
        postponeDays = 7,

        fn currentMaxVersion = (
            return (maxVersion())[1]
        ),

        fn nowSeconds = (
            local offsetClass = dotNetClass "System.DateTimeOffset"
            return offsetClass.UtcNow.ToUnixTimeSeconds() as integer
        ),

        fn stateFilePath = (
            return runtimeRoot + @"data\manager2-upgrade.ini"
        ),

        fn readState stateKey defaultValue: "" = (
            return ini.read (stateFilePath()) "Upgrade" stateKey defaultValue: defaultValue
        ),

        fn readStateNumber stateKey = (
            local stateContent = readState stateKey
            if (stateContent == "") do return 0
            try (
                local stateNumber = stateContent as integer
                if (stateNumber == undefined) do return 0
                return stateNumber
            ) catch (
                return 0
            )
        ),

        fn writeState stateKey stateContent = (
            return ini.write (stateFilePath()) "Upgrade" stateKey (stateContent as string)
        ),

        fn versionNumberAt versionContent partIndex = (
            local versionParts = filterString (versionContent as string) "."
            if (versionParts.count < partIndex) do return 0
            try (
                local partNumber = versionParts[partIndex] as integer
                if (partNumber == undefined) do return 0
                return partNumber
            ) catch (
                return 0
            )
        ),

        fn compareVersions leftVersion rightVersion = (
            for partIndex in 1 to 3 do (
                local leftNumber = versionNumberAt leftVersion partIndex
                local rightNumber = versionNumberAt rightVersion partIndex
                if (leftNumber > rightNumber) do return 1
                if (leftNumber < rightNumber) do return -1
            )
            return 0
        ),

        fn isVersionText versionContent = (
            local versionParts = filterString (versionContent as string) "."
            if (versionParts.count != 3) do return false
            for versionPart in versionParts do (
                if (versionPart.count == 0 or versionPart.count > 4) do return false
                for characterIndex in 1 to versionPart.count do (
                    if ((findString "0123456789" (substring versionPart characterIndex 1)) == undefined) do return false
                )
            )
            return true
        ),

        fn isSha256Text hashContent = (
            if (hashContent.count != 64) do return false
            for characterIndex in 1 to 64 do (
                if ((findString "0123456789abcdef" (toLower (substring hashContent characterIndex 1))) == undefined) do return false
            )
            return true
        ),

        fn isAllowedUrl sourceUrl = (
            local normalizedUrl = toLower sourceUrl
            if ((findString normalizedUrl " ") != undefined) do return false
            if (not (matchPattern normalizedUrl pattern: ((toLower downloadUrlPrefix) + "*.mzp"))) do return false
            return true
        ),

        -- Reads the [manager2] section. A missing or invalid section never starts an upgrade.
        fn parseOffer manifestContent = (
            local offerInfo = MaxPkgManager2OfferData()
            local isOfferSection = false
            local normalizedContent = substituteString (substituteString (manifestContent as string) "\r\n" "\n") "\r" "\n"
            local contentLines = filterString normalizedContent "\n"
            local enabledText = ""
            local minMaxText = ""
            for lineContent in contentLines do (
                local trimmedLine = utils.trim lineContent
                if (trimmedLine != "") do (
                    if ((substring trimmedLine 1 1) == "[") then (
                        isOfferSection = (toLower trimmedLine) == "[manager2]"
                        if (isOfferSection) do offerInfo.hasSection = true
                    ) else if (isOfferSection) do (
                        local equalsIndex = findString trimmedLine "="
                        if (equalsIndex != undefined and equalsIndex > 1) do (
                            local keyContent = toLower (utils.trim (substring trimmedLine 1 (equalsIndex - 1)))
                            local settingContent = if (equalsIndex < trimmedLine.count) then utils.trim (substring trimmedLine (equalsIndex + 1) (trimmedLine.count - equalsIndex)) else ""
                            if (keyContent == "enabled") do enabledText = settingContent
                            if (keyContent == "version") do offerInfo.version = settingContent
                            if (keyContent == "url") do offerInfo.url = settingContent
                            if (keyContent == "sha256") do offerInfo.sha256 = toLower settingContent
                            if (keyContent == "minmaxversion") do minMaxText = settingContent
                        )
                    )
                )
            )
            if (not offerInfo.hasSection) do return offerInfo
            offerInfo.isEnabled = utils.boolValue enabledText defaultValue: false
            if (minMaxText != "") do (
                local parsedMinMax = undefined
                try (
                    parsedMinMax = minMaxText as integer
                ) catch (
                    parsedMinMax = undefined
                )
                if (parsedMinMax != undefined and parsedMinMax > minimumMaxVersion) do offerInfo.minMaxVersion = parsedMinMax
            )
            if (not (isVersionText offerInfo.version)) then (
                offerInfo.problem = "Version is missing or invalid."
            ) else if (not (isAllowedUrl offerInfo.url)) then (
                offerInfo.problem = "Url is missing or outside the Manager 2.0 releases."
            ) else if (not (isSha256Text offerInfo.sha256)) then (
                offerInfo.problem = "Sha256 is missing or invalid."
            ) else (
                offerInfo.isValid = true
            )
            return offerInfo
        ),

        fn qtRoot = (
            return (utils.ensureSlash (getDir #temp)) + @"MaxPkg-Runtime-Manager-Qt\"
        ),

        fn qtShimPath = (
            return (utils.ensureSlash (getDir #userStartupScripts)) + "maxpkg-runtime-qt-startup.ms"
        ),

        fn backupRoot = (
            return (utils.ensureSlash (getDir #temp)) + @"MaxPkg-Runtime-Manager-Backup\"
        ),

        fn recoveryShimPath = (
            return (utils.ensureSlash (getDir #userStartupScripts)) + "maxpkg-runtime-recovery.ms"
        ),

        fn installedManagerVersion = (
            return ini.read ((qtRoot()) + "version.ini") "Runtime" "Version" defaultValue: ""
        ),

        -- True when this offer may start now. Every refusal is silent, so nothing repeats on each launch.
        fn shouldOffer offerInfo = (
            if (currentMaxVersion() < offerInfo.minMaxVersion) do return false
            local installedVersion = installedManagerVersion()
            if (installedVersion != "" and (compareVersions installedVersion offerInfo.version) >= 0) do return false
            if ((readState "DeclinedVersion") == offerInfo.version) do return false
            if ((nowSeconds()) < (readStateNumber "NextPromptAt")) do return false
            if ((readState "TargetVersion") == offerInfo.version) do (
                if ((readStateNumber "Failures") >= maximumFailures) do return false
                local secondsSinceAttempt = (nowSeconds()) - (readStateNumber "LastAttemptAt")
                if (secondsSinceAttempt < retryDelayHours * 3600) do return false
            )
            return true
        ),

        fn fileSha256 filePath = (
            try (
                local fileClass = dotNetClass "System.IO.File"
                local hashClass = dotNetClass "System.Security.Cryptography.SHA256"
                local bitConverterClass = dotNetClass "System.BitConverter"
                local hashAlgorithm = hashClass.Create()
                local fileBytes = fileClass.ReadAllBytes filePath
                local hashBytes = hashAlgorithm.ComputeHash fileBytes
                local hashContent = toLower (substituteString (bitConverterClass.ToString hashBytes) "-" "")
                hashAlgorithm.Dispose()
                return hashContent
            ) catch (
                logger.logError "manager2" ("Could not hash " + filePath + ": " + getCurrentException())
                return ""
            )
        ),

        fn copyRuntimeTree sourceRoot targetRoot = (
            local normalizedSourceRoot = utils.ensureSlash sourceRoot
            local normalizedTargetRoot = utils.ensureSlash targetRoot
            try (
                local directoryClass = dotNetClass "System.IO.Directory"
                local searchOptionClass = dotNetClass "System.IO.SearchOption"
                local fileClass = dotNetClass "System.IO.File"
                local sourceFiles = directoryClass.GetFiles normalizedSourceRoot "*" searchOptionClass.AllDirectories
                for sourceFilePath in sourceFiles do (
                    local relativeFilePath = toLower (substring sourceFilePath (normalizedSourceRoot.count + 1) (sourceFilePath.count - normalizedSourceRoot.count))
                    local isExcluded = false
                    if (matchPattern relativeFilePath pattern: @"data\packages\*") do isExcluded = true
                    if (matchPattern relativeFilePath pattern: @"logs\*") do isExcluded = true
                    if (matchPattern relativeFilePath pattern: @".git\*") do isExcluded = true
                    if (matchPattern relativeFilePath pattern: @"dist\*") do isExcluded = true
                    if (not isExcluded) do (
                        local targetFilePath = normalizedTargetRoot + (substring sourceFilePath (normalizedSourceRoot.count + 1) (sourceFilePath.count - normalizedSourceRoot.count))
                        makeDir (getFilenamePath targetFilePath) all: true
                        utils.makeFileWritable targetFilePath
                        fileClass.Copy sourceFilePath targetFilePath true
                    )
                )
                return true
            ) catch (
                logger.logError "manager2" ("Could not back up the Runtime: " + getCurrentException())
                return false
            )
        ),

        -- Copies everything the Manager 2.0 installer removes (program files, startup script, MacroScripts)
        -- and arms a recovery startup script. A restart in the middle of the upgrade restores 1.x on next launch.
        fn createBackup offerInfo = (
            local backupFolder = backupRoot()
            try (
                if (not (utils.forceDeleteFolder backupFolder)) do throw "The previous backup could not be removed."
                makeDir (backupFolder + @"files\") all: true
                if (not (copyRuntimeTree runtimeRoot (backupFolder + @"runtime\"))) do throw "The Runtime files could not be copied."
                if (not (doesFileExist (backupFolder + @"runtime\core\manager2-recovery.ms"))) do throw "The recovery script is missing."

                local startupFolder = utils.ensureSlash (getDir #userStartupScripts)
                local macroFolder = utils.ensureSlash (getDir #userMacros)
                local legacyFiles = #(
                    startupFolder + "maxpkg-runtime-startup.ms",
                    macroFolder + "maxpkg-runtime-manager.mcr",
                    macroFolder + "MaxPkg-MaxPkg_Manager.mcr"
                )
                local planFile = backupFolder + "upgrade.ini"
                local backedUpCount = 0
                local fileClass = dotNetClass "System.IO.File"
                for legacyFile in legacyFiles do (
                    if (doesFileExist legacyFile) do (
                        backedUpCount += 1
                        fileClass.Copy legacyFile (backupFolder + @"files\" + (backedUpCount as string) + ".bak") true
                        if (not (ini.write planFile "Plan" ("File" + (backedUpCount as string)) legacyFile)) do throw "The backup plan could not be written."
                    )
                )
                local isPlanWritten = true
                if (not (ini.write planFile "Plan" "FileCount" (backedUpCount as string))) do isPlanWritten = false
                if (not (ini.write planFile "Plan" "RuntimeRoot" runtimeRoot)) do isPlanWritten = false
                if (not (ini.write planFile "Plan" "RecoveryShim" (recoveryShimPath()))) do isPlanWritten = false
                if (not (ini.write planFile "Plan" "QtRoot" (qtRoot()))) do isPlanWritten = false
                if (not (ini.write planFile "Plan" "QtShim" (qtShimPath()))) do isPlanWritten = false
                if (not (ini.write planFile "Plan" "QtMacro" (macroFolder + "maxpkg-runtime-qt.mcr"))) do isPlanWritten = false
                if (not (ini.write planFile "Plan" "ExpectedVersion" offerInfo.version)) do isPlanWritten = false
                if (not (ini.write planFile "Plan" "ForceRestore" "false")) do isPlanWritten = false
                if (not isPlanWritten) do throw "The backup plan could not be written."
                if (not (utils.writeText (backupFolder + "in-progress.flag") "in progress")) do throw "The upgrade marker could not be written."

                local recoveryScript = backupFolder + @"runtime\core\manager2-recovery.ms"
                local shimContent = "-- Restores MaxPkg Runtime 1.x if a Manager 2.0 upgrade was interrupted. Removes itself when done.\n"
                shimContent += "(\n"
                shimContent += "    local recoveryFile = \"" + (substituteString recoveryScript @"\" "/") + "\"\n"
                shimContent += "    if (doesFileExist recoveryFile) do fileIn recoveryFile\n"
                shimContent += ")\n"
                if (not (utils.writeText (recoveryShimPath()) shimContent)) do throw "The recovery startup script could not be written."
                return true
            ) catch (
                logger.logError "manager2" ("Backup failed: " + getCurrentException())
                utils.forceDeleteFile (recoveryShimPath())
                utils.forceDeleteFolder backupFolder
                return false
            )
        ),

        fn discardBackup = (
            utils.forceDeleteFile (recoveryShimPath())
            utils.forceDeleteFolder (backupRoot())
            return true
        ),

        -- Restores 1.x through the same script the recovery startup script uses, then 1.x restarts itself.
        fn rollback = (
            local recoveryScript = (backupRoot()) + @"runtime\core\manager2-recovery.ms"
            if (not (doesFileExist recoveryScript)) do return false
            ini.write ((backupRoot()) + "upgrade.ini") "Plan" "ForceRestore" "true"
            try (
                return (fileIn recoveryScript) == true
            ) catch (
                logger.logError "manager2" ("Rollback failed: " + getCurrentException())
                return false
            )
        ),

        fn isManagerLoaded = (
            return MaxPkg != undefined and isProperty MaxPkg #isPackageManager
        ),

        -- Manager 2.0 counts as installed only when its files match the offer and it really starts.
        fn verifyInstalled offerInfo = (
            local qtFolder = qtRoot()
            if (not (doesFileExist (qtFolder + @"python\startup.py"))) do return false
            if (not (doesFileExist (qtShimPath()))) do return false
            if ((compareVersions (installedManagerVersion()) offerInfo.version) != 0) do return false
            if (isManagerLoaded()) do return true
            try (
                fileIn (qtShimPath())
            ) catch (
                logger.logError "manager2" ("Manager 2.0 did not start: " + getCurrentException())
            )
            return isManagerLoaded()
        ),

        fn recordAttempt offerInfo = (
            local failureCount = 0
            if ((readState "TargetVersion") == offerInfo.version) do failureCount = readStateNumber "Failures"
            writeState "TargetVersion" offerInfo.version
            writeState "Failures" (failureCount + 1)
            writeState "LastAttemptAt" (nowSeconds())
            return true
        ),

        fn performUpgrade offerInfo = (
            if (not (operations.begin "manager2Upgrade")) do return false
            local isInstalled = false
            local installerStarted = false
            local failureReason = ""
            local guidClass = dotNetClass "System.Guid"
            local downloadRoot = (utils.ensureSlash (getDir #temp)) + "maxpkg-manager2-upgrade-" + ((guidClass.NewGuid()).ToString()) + @"\"
            local archiveFile = downloadRoot + "MaxPkg-Runtime-Manager-Qt.mzp"
            try (
                makeDir downloadRoot all: true
                logger.logInfo "manager2" ("Downloading Manager " + offerInfo.version)
                if (not (http.download offerInfo.url archiveFile)) do throw "The Manager 2.0 download failed."
                local actualHash = fileSha256 archiveFile
                if (actualHash != offerInfo.sha256) do throw ("The SHA-256 of the download does not match. Expected " + offerInfo.sha256 + ", got " + actualHash + ".")
                recordAttempt offerInfo
                if (not (createBackup offerInfo)) do throw "The current Runtime could not be backed up."
                installerStarted = true
                logger.logInfo "manager2" "Running the Manager 2.0 installer"
                fileIn archiveFile
                isInstalled = verifyInstalled offerInfo
                if (not isInstalled) do throw "Manager 2.0 was installed but did not start."
            ) catch (
                failureReason = getCurrentException()
            )
            utils.forceDeleteFolder downloadRoot
            if (isInstalled) then (
                discardBackup()
                try (
                    logger.logInfo "manager2" ("Upgraded to Manager " + offerInfo.version)
                ) catch (
                )
                operations.finish success: true
                return true
            )
            if (installerStarted) then (
                local isRestored = rollback()
                logger.logError "manager2" ("Upgrade failed and was rolled back (restored=" + (isRestored as string) + "): " + failureReason)
            ) else (
                discardBackup()
                logger.logError "manager2" ("Upgrade failed before changing anything: " + failureReason)
            )
            writeState "LastError" failureReason
            operations.finish success: false
            return false
        ),

        fn showUpgradePrompt offerInfo = (
            upgradeDialogChoice = "later"
            upgradeDialogVersion = offerInfo.version
            try (
                createDialog MaxPkgManager2UpgradeRollout modal: true style: #(#style_titlebar, #style_sysmenu)
            ) catch (
                logger.logWarning "manager2" ("The upgrade prompt could not be shown: " + getCurrentException())
                return "later"
            )
            return upgradeDialogChoice
        ),

        -- Entry point called with the downloaded version.ini after a successful Runtime update check.
        fn consider manifestContent = (
            if (currentMaxVersion() < minimumMaxVersion) do return false
            local offerInfo = parseOffer manifestContent
            if (not offerInfo.hasSection or not offerInfo.isEnabled) do return false
            if (not offerInfo.isValid) do (
                logger.logWarning "manager2" ("Ignoring the Manager 2.0 offer: " + offerInfo.problem)
                return false
            )
            if (not (shouldOffer offerInfo)) do return false
            if (operations == undefined or operations.isBusy()) do (
                logger.logInfo "manager2" "Manager 2.0 upgrade is waiting for the active operation to finish."
                return false
            )
            local dialogChoice = showUpgradePrompt offerInfo
            if (dialogChoice == "never") do (
                writeState "DeclinedVersion" offerInfo.version
                return false
            )
            if (dialogChoice != "upgrade") do (
                writeState "NextPromptAt" ((nowSeconds()) + postponeDays * 86400)
                return false
            )
            return performUpgrade offerInfo
        )
    )

    MaxPkgManager2UpgradeModule()
)
