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
        name = "",
        buttonName = "",
        version = "",
        developer = "",
        description = "",
        helpUrl = "",
        documentationUrl = "",
        homepageUrl = "",
        supportUrl = "",
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
        icon = "",
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
            local section = "package"
            local package = MaxPkgPackageData()
            package.manifestPath = manifestPath
            package.installPath = utils.ensureSlash (getFilenamePath manifestPath)
            package.guid = ini.readAny manifestPath section #("packageGuid", "Guid", "guid")
            package.name = ini.readAny manifestPath section #("name", "Name")
            package.slug = ini.readAny manifestPath section #("slug", "Slug") defaultValue:(slugFromName package.name)
            package.buttonName = ini.readAny manifestPath section #("buttonName", "ButtonName") defaultValue:package.name
            package.version = ini.readAny manifestPath section #("version", "Version")
            package.developer = ini.readAny manifestPath section #("developerName", "Developer", "developer")
            package.description = ini.readAny manifestPath section #("description", "Description")
            package.helpUrl = ini.readAny manifestPath section #("documentation", "Documentation", "documentationUrl", "help", "Help", "helpUrl") defaultValue: ""
            package.documentationUrl = package.helpUrl
            package.homepageUrl = ini.readAny manifestPath section #("homepage", "Homepage", "homepageUrl") defaultValue: ""
            package.supportUrl = ini.readAny manifestPath section #("support", "Support", "supportUrl") defaultValue: ""
            package.licenseType = ini.readAny manifestPath section #("license", "License") defaultValue: ""
            package.licenseUrl = ini.readAny manifestPath section #("licenseUrl", "LicenseUrl") defaultValue: ""
            package.releaseChannel = ini.readAny manifestPath section #("releaseChannel", "ReleaseChannel") defaultValue: "stable"
            package.releaseDate = ini.readAny manifestPath section #("releaseDate", "ReleaseDate") defaultValue: ""
            package.minimumMaxVersion = ini.readAny manifestPath section #("min3dsMax", "Min3dsMax", "minimum3dsMax") defaultValue: ""
            package.maximumMaxVersion = ini.readAny manifestPath section #("max3dsMax", "Max3dsMax", "maximum3dsMax") defaultValue: ""
            package.manifestVersion = ini.readAny manifestPath section #("manifestVersion", "ManifestVersion") defaultValue: ""
            package.packagerName = ini.readAny manifestPath section #("packager", "Packager") defaultValue: ""
            package.packagerVersion = ini.readAny manifestPath section #("packagerVersion", "PackagerVersion") defaultValue: ""
            package.changelogEntries = changelogFromManifest manifestPath
            package.entry = ini.readAny manifestPath section #("entry", "Entry")
            package.runtime = ini.readAny manifestPath section #("runtime", "Runtime")
            if package.runtime == "" do (
                local extension = toLower (getFilenameType package.entry)
                package.runtime = if extension == ".py" then "Python" else "MaxScript"
            )
            local iconRelative = ini.readAny manifestPath section #("icon", "Icon")
            if iconRelative != "" do package.icon = package.installPath + iconRelative
            package.toolbarVisible = utils.boolValue (ini.readAny manifestPath section #("showInToolbar", "ToolbarVisible") defaultValue:"true") defaultValue:true
            local toolbarOrderValue = ini.readAny manifestPath section #("toolbarOrder", "ToolbarOrder") defaultValue:"0"
            try (
                package.toolbarOrder = toolbarOrderValue as integer
            ) catch (
                package.toolbarOrder = 0
                logger.logWarning "scanner" ("Invalid ToolbarOrder in " + manifestPath + ": " + toolbarOrderValue)
            )
            package.uninstall = ini.readAny manifestPath section #("uninstallScript", "Uninstall") defaultValue:"uninstall.ms"
            return package
        ),

        fn validate package = (
            local missing = #()
            if package.guid == "" do append missing "Guid"
            if package.name == "" do append missing "Name"
            if package.version == "" do append missing "Version"
            if package.runtime == "" do append missing "Runtime"
            if package.entry == "" do append missing "Entry"
            if missing.count > 0 do (
                logger.logError "scanner" ("Skipped invalid manifest " + package.manifestPath + "; missing: " + (utils.join missing separator:", "))
                return false
            )
            return true
        ),

        fn manifestsInRoot rootPath = (
            local manifestPaths = #()
            local root = utils.ensureSlash rootPath
            if root == "" or not (doesDirectoryExist root) do return manifestPaths
            local direct = root + "manifest.ini"
            if doesFileExist direct do append manifestPaths direct
            for folder in (getDirectories (root + "*")) do (
                local manifest = (utils.ensureSlash folder) + "manifest.ini"
                if doesFileExist manifest do append manifestPaths manifest
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
                    if validate package do (
                        local duplicate = false
                        for current in packages while not duplicate where (toLower current.guid) == (toLower package.guid) do duplicate = true
                        if duplicate then logger.logWarning "scanner" ("Duplicate package GUID skipped: " + package.guid) else append packages package
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
