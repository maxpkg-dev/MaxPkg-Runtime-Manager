-- Verifies Manager 2.0 offer parsing, gating, retry limits, and hashing without touching 3ds Max startup folders.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local testRoot = getFilenamePath (getSourceFileName())
    local runtimeRoot = getFilenamePath (substring testRoot 1 (testRoot.count - 1))
    local utilsModule = fileIn (runtimeRoot + @"core\utils.ms")
    local iniModule = fileIn (runtimeRoot + @"core\ini.ms")
    local upgradeModule = fileIn (runtimeRoot + @"core\manager2-upgrade.ms")
    local testStatus = "MAXPKG_MANAGER2_NOT_RUN"
    local guidClass = dotNetClass "System.Guid"
    local fixtureRoot = (utilsModule.ensureSlash (getDir #temp)) + "maxpkg-manager2-test-" + ((guidClass.NewGuid()).ToString()) + @"\"
    makeDir fixtureRoot all: true

    struct Manager2LoggerFixtureData (
        fn logInfo area content = (return true),
        fn logWarning area content = (return true),
        fn logError area content = (return true)
    )
    struct Manager2OperationsFixtureData (
        busy = false,
        fn isBusy = (return busy)
    )

    upgradeModule.utils = utilsModule
    upgradeModule.ini = iniModule
    upgradeModule.logger = Manager2LoggerFixtureData()
    upgradeModule.operations = Manager2OperationsFixtureData()
    upgradeModule.runtimeRoot = fixtureRoot

    local goodHash = "fc29fd860e30da02898ed10bc7d31839d1f4b826140016257949f085e63300a1"
    local goodUrl = "https://github.com/maxpkg-dev/MaxPkg-Runtime-Manager-Qt/releases/download/v2.0.2/MaxPkg-Runtime-Manager-Qt.mzp"
    fn manifestWith enabledText versionText urlText hashText = (
        return "[Runtime]\r\nVersion=1.2.1\r\n\r\n[manager2]\r\nEnabled=" + enabledText + "\r\nVersion=" + versionText + "\r\nUrl=" + urlText + "\r\nSha256=" + hashText + "\r\nMinMaxVersion=24000\r\n"
    )

    try (
        local validOffer = upgradeModule.parseOffer (manifestWith "true" "2.0.2" goodUrl goodHash)
        if (not (validOffer.isValid and validOffer.isEnabled and validOffer.version == "2.0.2")) do throw "A valid offer was rejected."
        local disabledOffer = upgradeModule.parseOffer (manifestWith "false" "2.0.2" goodUrl goodHash)
        if (not disabledOffer.isValid or disabledOffer.isEnabled) do throw "Enabled=false must stay disabled."
        if ((upgradeModule.parseOffer "[Runtime]\r\nVersion=1.2.1\r\n").hasSection) do throw "A missing section must be reported as missing."
        if ((upgradeModule.parseOffer (manifestWith "true" "2.0" goodUrl goodHash)).isValid) do throw "A short version must be invalid."
        if ((upgradeModule.parseOffer (manifestWith "true" "2.0.2" "https://example.com/a.mzp" goodHash)).isValid) do throw "A foreign host must be invalid."
        if ((upgradeModule.parseOffer (manifestWith "true" "2.0.2" goodUrl "abc")).isValid) do throw "A short hash must be invalid."
        if ((upgradeModule.parseOffer (manifestWith "true" "2.0.2" (goodUrl + ".exe") goodHash)).isValid) do throw "A non-mzp URL must be invalid."

        if ((upgradeModule.compareVersions "2.0.2" "2.0.10") != -1) do throw "Version comparison is wrong."
        if ((upgradeModule.compareVersions "2.1.0" "2.0.9") != 1) do throw "Version comparison is wrong."

        local testHashFile = fixtureRoot + "hash.bin"
        utilsModule.writeText testHashFile "abc"
        if ((upgradeModule.fileSha256 testHashFile) != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") do throw "SHA-256 is wrong."

        -- Gating by saved state.
        if ((upgradeModule.currentMaxVersion()) >= 24000 and (upgradeModule.installedManagerVersion()) == "") do (
            if (not (upgradeModule.shouldOffer validOffer)) do throw "A fresh offer should be allowed."
            upgradeModule.writeState "DeclinedVersion" "2.0.2"
            if (upgradeModule.shouldOffer validOffer) do throw "A declined version must not be offered again."
            upgradeModule.writeState "DeclinedVersion" ""
            upgradeModule.writeState "NextPromptAt" ((upgradeModule.nowSeconds()) + 3600)
            if (upgradeModule.shouldOffer validOffer) do throw "A postponed offer must wait."
            upgradeModule.writeState "NextPromptAt" "0"
            upgradeModule.recordAttempt validOffer
            if (upgradeModule.shouldOffer validOffer) do throw "A recent attempt must not repeat immediately."
            upgradeModule.writeState "LastAttemptAt" "0"
            upgradeModule.writeState "Failures" "3"
            if (upgradeModule.shouldOffer validOffer) do throw "The failure limit must stop retries."
        )

        -- Below 3ds Max 2022 nothing is offered, whatever the manifest says.
        local oldMaxOffer = upgradeModule.parseOffer (manifestWith "true" "2.0.2" goodUrl goodHash)
        oldMaxOffer.minMaxVersion = 99999
        if (upgradeModule.shouldOffer oldMaxOffer) do throw "MinMaxVersion above the running 3ds Max must block the offer."
        testStatus = "MAXPKG_MANAGER2_OK"
    ) catch (
        testStatus = "MAXPKG_MANAGER2_FAILED: " + (getCurrentException())
    )
    utilsModule.forceDeleteFolder fixtureRoot
    testStatus
)
