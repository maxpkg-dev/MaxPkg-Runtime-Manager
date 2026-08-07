-- Discovers packages and normalizes their manifests.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgChangelogEntryData (
        changeType = "",
        messageContent = ""
    )

    struct MaxPkgPackageData (
        guid = "",
        slug = "",
        packageName = "",
        buttonName = "",
        version = "",
        developer = "",
        description = "",
        helpUrl = "",
        documentationUrl = "",
        homepageUrl = "",
        supportUrl = "",
        purchaseUrl = "",
        purchaseButtonLabel = "Buy",
        licenseType = "",
        licenseUrl = "",
        releaseChannel = "",
        releaseDate = "",
        minimumMaxVersion = "",
        maximumMaxVersion = "",
        manifestVersion = "",
        packagerName = "",
        packagerVersion = "",
        changelogEntries = #(),
        runtime = "",
        entry = "",
        iconFile = "",
        installPath = "",
        toolbarVisible = true,
        toolbarOrder = 0,
        manifestPath = "",
        uninstall = "",
        updateAvailable = false,
        latestVersion = "",
        downloadUrl = ""
    )

    struct MaxPkgScannerModule (
        utils,
        ini,
        logger,

        fn slugFromName packageName = (
            local packageSlug = toLower (utils.trim packageName)
            packageSlug = substituteString packageSlug " " "-"
            packageSlug = substituteString packageSlug "_" "-"
            return packageSlug
        ),

        fn changelogFromManifest manifestPath = (
            local changelogEntries = #()
            for changelogIndex in 1 to 100 do (
                local keyPrefix = changelogIndex as string
                local messageContent = ini.read manifestPath "changelog" (keyPrefix + "_text")
                if (messageContent == "") do exit
                local changeType = ini.read manifestPath "changelog" (keyPrefix + "_type") defaultValue: "Changed"
                append changelogEntries (MaxPkgChangelogEntryData changeType: changeType messageContent: messageContent)
            )
            return changelogEntries
        ),

        fn packageFromManifest manifestPath = (
            local iniSection = "package"
            local package = MaxPkgPackageData()
            package.manifestPath = manifestPath
            package.installPath = utils.ensureSlash (getFilenamePath manifestPath)
            package.guid = ini.readAny manifestPath iniSection #("packageGuid", "Guid", "guid")
            package.packageName = ini.readAny manifestPath iniSection #("name", "Name")
            package.slug = ini.readAny manifestPath iniSection #("slug", "Slug") defaultValue: (slugFromName package.packageName)
            package.buttonName = ini.readAny manifestPath iniSection #("buttonName", "ButtonName") defaultValue: package.packageName
            package.version = ini.readAny manifestPath iniSection #("version", "Version")
            package.developer = ini.readAny manifestPath iniSection #("developerName", "Developer", "developer")
            package.description = ini.readAny manifestPath iniSection #("description", "Description")
            package.helpUrl = ini.readAny manifestPath iniSection #("documentation", "Documentation", "documentationUrl", "help", "Help", "helpUrl") defaultValue: ""
            package.documentationUrl = package.helpUrl
            package.homepageUrl = ini.readAny manifestPath iniSection #("homepage", "Homepage", "homepageUrl") defaultValue: ""
            package.supportUrl = ini.readAny manifestPath iniSection #("support", "Support", "supportUrl") defaultValue: ""
            package.purchaseUrl = ini.readAny manifestPath iniSection #("purchase", "Purchase", "purchaseUrl", "PurchaseUrl") defaultValue: ""
            package.purchaseButtonLabel = ini.readAny manifestPath iniSection #("purchaseButtonLabel", "PurchaseButtonLabel") defaultValue: "Buy"
            package.licenseType = ini.readAny manifestPath iniSection #("license", "License") defaultValue: ""
            package.licenseUrl = ini.readAny manifestPath iniSection #("licenseUrl", "LicenseUrl") defaultValue: ""
            package.releaseChannel = ini.readAny manifestPath iniSection #("releaseChannel", "ReleaseChannel") defaultValue: "stable"
            package.releaseDate = ini.readAny manifestPath iniSection #("releaseDate", "ReleaseDate") defaultValue: ""
            package.minimumMaxVersion = ini.readAny manifestPath iniSection #("min3dsMax", "Min3dsMax", "minimum3dsMax") defaultValue: ""
            package.maximumMaxVersion = ini.readAny manifestPath iniSection #("max3dsMax", "Max3dsMax", "maximum3dsMax") defaultValue: ""
            package.manifestVersion = ini.readAny manifestPath iniSection #("manifestVersion", "ManifestVersion") defaultValue: ""
            package.packagerName = ini.readAny manifestPath iniSection #("packager", "Packager") defaultValue: ""
            package.packagerVersion = ini.readAny manifestPath iniSection #("packagerVersion", "PackagerVersion") defaultValue: ""
            package.changelogEntries = changelogFromManifest manifestPath
            package.entry = ini.readAny manifestPath iniSection #("entry", "Entry")
            package.runtime = ini.readAny manifestPath iniSection #("runtime", "Runtime")
            if (package.runtime == "") do (
                local extension = toLower (getFilenameType package.entry)
                package.runtime = if (extension == ".py") then "Python" else "MaxScript"
            )
            local relativeIconPath = ini.readAny manifestPath iniSection #("icon", "Icon")
            if (relativeIconPath != "") do package.iconFile = package.installPath + relativeIconPath
            package.toolbarVisible = utils.boolValue (ini.readAny manifestPath iniSection #("showInToolbar", "ToolbarVisible") defaultValue: "true") defaultValue: true
            local toolbarOrderValue = ini.readAny manifestPath iniSection #("toolbarOrder", "ToolbarOrder") defaultValue: "0"
            try (
                package.toolbarOrder = toolbarOrderValue as integer
            ) catch (
                package.toolbarOrder = 0
                logger.logWarning "scanner" ("Invalid ToolbarOrder in " + manifestPath + ": " + toolbarOrderValue)
            )
            package.uninstall = ini.readAny manifestPath iniSection #("uninstallScript", "Uninstall") defaultValue: "uninstall.ms"
            return package
        ),

        fn validate package = (
            local missingFields = #()
            if (package.guid == "") do append missingFields "Guid"
            if (package.packageName == "") do append missingFields "Name"
            if (package.version == "") do append missingFields "Version"
            if (package.runtime == "") do append missingFields "Runtime"
            if (package.entry == "") do append missingFields "Entry"
            if (missingFields.count > 0) do (
                logger.logError "scanner" ("Skipped invalid manifest " + package.manifestPath + "; missing: " + (utils.join missingFields separator: ", "))
                return false
            )
            return true
        ),

        fn manifestsInRoot rootPath = (
            local manifestPaths = #()
            local normalizedRootPath = utils.ensureSlash rootPath
            if (normalizedRootPath == "" or not (doesDirectoryExist normalizedRootPath)) do return manifestPaths
            local directManifestPath = normalizedRootPath + "manifest.ini"
            if (doesFileExist directManifestPath) do append manifestPaths directManifestPath
            for packageFolder in (getDirectories (normalizedRootPath + "*")) do (
                local manifestPath = (utils.ensureSlash packageFolder) + "manifest.ini"
                if (doesFileExist manifestPath) do append manifestPaths manifestPath
            )
            return manifestPaths
        ),

        fn scan roots = (
            local packages = #()
            local manifests = #()
            for root in (utils.uniqueStrings roots) do join manifests (manifestsInRoot root)
            manifests = utils.uniqueStrings manifests

            for manifestPath in manifests do (
                try (
                    local package = packageFromManifest manifestPath
                    if (validate package) do (
                        local isDuplicate = false
                        for existingPackage in packages while not isDuplicate where (toLower existingPackage.guid) == (toLower package.guid) do isDuplicate = true
                        if (isDuplicate) then logger.logWarning "scanner" ("Duplicate package GUID skipped: " + package.guid) else append packages package
                    )
                ) catch (
                    logger.logError "scanner" (manifestPath + ": " + getCurrentException())
                )
            )
            logger.logInfo "scanner" ("Discovered " + (packages.count as string) + " package(s)")
            return packages
        )
    )

    MaxPkgScannerModule()
)
