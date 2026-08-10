-- Calls the MaxPkg Runtime API and parses its INI metadata responses.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgApiChangelogEntryData (
        changeType = "",
        messageContent = ""
    )

    struct MaxPkgApiScreenshotData (
        imageUrl = "",
        thumbnailUrl = "",
        titleContent = "",
        captionContent = "",
        sortOrder = 0
    )

    struct MaxPkgApiPackageData (
        guid = "",
        slug = "",
        packageName = "",
        buttonName = "",
        version = "",
        developer = "",
        description = "",
        fullDescription = "",
        category = "",
        helpUrl = "",
        documentationUrl = "",
        homepageUrl = "",
        supportUrl = "",
        purchaseUrl = "",
        purchaseButtonLabel = "",
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
        iconUrl = "",
        packageIconUrl = "",
        coverImageUrl = "",
        screenshotEntries = #(),
        downloadUrl = "",
        rating = 0.0,
        reviewCount = 0,
        downloadCount = 0,
        latestVersion = "",
        installPath = "",
        toolbarVisible = false,
        updateAvailable = false,
        isRemote = true,
        detailsLoaded = false
    )

    struct MaxPkgApiResponseData (
        success = false,
        errorCode = "",
        errorMessage = "",
        requestId = "",
        packages = #(),
        packageInfo = undefined,
        page = 1,
        pageSize = 24,
        total = 0,
        totalPages = 0
    )

    struct MaxPkgRepositoryModule (
        owner,
        runtimeRoot,
        http,
        ini,
        utils,
        logger,

        fn integerValue sourceContent fallbackNumber = (
            try (
                return sourceContent as integer
            ) catch (
                return fallbackNumber
            )
        ),

        fn floatValue sourceContent fallbackNumber = (
            try (
                return sourceContent as float
            ) catch (
                return fallbackNumber
            )
        ),

        fn findSection responseSections sectionName = (
            for responseSection in responseSections where (toLower responseSection) == (toLower sectionName) do return responseSection
            return ""
        ),

        fn commonFormFields channelName = (
            return #(
                utils.formField "runtimeVersion" owner.version,
                utils.formField "channel" channelName
            )
        ),

        fn compatibleWithCurrent3dsMax packageInfo = (
            if (packageInfo.minimumMaxVersion == "") do return true
            local minimum3dsMaxVersion = integerValue packageInfo.minimumMaxVersion 0
            return minimum3dsMaxVersion == 0 or (utils.current3dsMaxYear()) >= minimum3dsMaxVersion
        ),

        fn enforceMinimum3dsMax responseInfo requireCompatiblePackage: false = (
            if (not responseInfo.success) do return responseInfo
            local compatiblePackages = #()
            for packageInfo in responseInfo.packages where (compatibleWithCurrent3dsMax packageInfo) do append compatiblePackages packageInfo
            local removedCount = responseInfo.packages.count - compatiblePackages.count
            responseInfo.packages = compatiblePackages
            responseInfo.packageInfo = if (compatiblePackages.count > 0) then compatiblePackages[1] else undefined
            if (removedCount > 0) do responseInfo.total = amax 0 (responseInfo.total - removedCount)
            if (requireCompatiblePackage and compatiblePackages.count == 0) do (
                responseInfo.success = false
                responseInfo.errorCode = "INCOMPATIBLE_3DS_MAX"
                responseInfo.errorMessage = "This package requires a newer version of 3ds Max."
            )
            return responseInfo
        ),

        fn responseFilePath = (
            return runtimeRoot + @"data\api-response.ini"
        ),

        fn request actionName formFields = (
            local endpointUrl = utils.apiEndpointUrl owner.settings.apiEndpoint actionName
            local responseBody = http.post endpointUrl (utils.join formFields separator: "&")
            if (responseBody == undefined or responseBody == "") do return ""
            local apiResponseFilePath = responseFilePath()
            if (not (utils.writeText apiResponseFilePath responseBody)) do (
                logger.logError "repository" ("Could not persist API response: " + apiResponseFilePath)
                return ""
            )
            return apiResponseFilePath
        ),

        fn readChangelog apiResponseFilePath iniSection = (
            local changelogEntries = #()
            for changelogIndex in 1 to 200 do (
                local entryPrefix = changelogIndex as string
                local messageContent = ini.read apiResponseFilePath iniSection (entryPrefix + "_text")
                if (messageContent == "") do exit
                local changeType = ini.read apiResponseFilePath iniSection (entryPrefix + "_type") defaultValue: "Changed"
                append changelogEntries (MaxPkgApiChangelogEntryData changeType: changeType messageContent: messageContent)
            )
            return changelogEntries
        ),

        fn readChangelogItem apiResponseFilePath itemSectionName = (
            local messageContent = ini.readAny apiResponseFilePath itemSectionName #("Text", "text", "Message", "message", "MessageContent", "messageContent")
            if (messageContent == "") do return undefined

            local changeType = ini.readAny apiResponseFilePath itemSectionName #("Type", "type", "ChangeType", "changeType") defaultValue: "Changed"
            return MaxPkgApiChangelogEntryData changeType: changeType messageContent: messageContent
        ),

        fn readVersionedChangelog apiResponseFilePath = (
            local changelogEntries = #()
            local changelogCount = integerValue (ini.read apiResponseFilePath "changelog" "Count" defaultValue: "0") 0

            for changelogIndex in 1 to changelogCount do (
                local changelogSectionName = "changelog_" + (changelogIndex as string)
                local changelogItemCount = integerValue (ini.read apiResponseFilePath changelogSectionName "Count" defaultValue: "0") 0

                for changelogItemIndex in 1 to changelogItemCount do (
                    local changelogItemSectionName = changelogSectionName + "_item_" + (changelogItemIndex as string)
                    local changelogEntry = readChangelogItem apiResponseFilePath changelogItemSectionName

                    if (changelogEntry != undefined) do append changelogEntries changelogEntry
                )
            )

            return changelogEntries
        ),

        fn readScreenshotItem apiResponseFilePath screenshotSectionName = (
            local imageUrl = ini.readAny apiResponseFilePath screenshotSectionName #("Url", "url", "ImageUrl", "imageUrl")
            if (imageUrl == "") do return undefined

            local thumbnailUrl = ini.readAny apiResponseFilePath screenshotSectionName #("ThumbnailUrl", "thumbnailUrl", "Thumbnail", "thumbnail")
            local titleContent = ini.readAny apiResponseFilePath screenshotSectionName #("Title", "title")
            local captionContent = ini.readAny apiResponseFilePath screenshotSectionName #("Caption", "caption")
            local sortOrder = integerValue (ini.readAny apiResponseFilePath screenshotSectionName #("SortOrder", "sortOrder") defaultValue: "0") 0

            return MaxPkgApiScreenshotData imageUrl: imageUrl thumbnailUrl: thumbnailUrl titleContent: titleContent captionContent: captionContent sortOrder: sortOrder
        ),

        fn sortScreenshotsByOrder screenshotEntries = (
            local sortedEntries = #()

            for screenshotEntry in screenshotEntries do (
                local insertIndex = sortedEntries.count + 1

                for sortedIndex in 1 to sortedEntries.count do (
                    if (screenshotEntry.sortOrder < sortedEntries[sortedIndex].sortOrder) do (
                        insertIndex = sortedIndex
                        exit
                    )
                )

                insertItem screenshotEntry sortedEntries insertIndex
            )

            return sortedEntries
        ),

        fn readScreenshots apiResponseFilePath = (
            local screenshotEntries = #()
            local screenshotCount = integerValue (ini.read apiResponseFilePath "screenshots" "Count" defaultValue: "0") 0

            for screenshotIndex in 1 to screenshotCount do (
                local screenshotSectionName = "screenshot_" + (screenshotIndex as string)
                local screenshotEntry = readScreenshotItem apiResponseFilePath screenshotSectionName

                if (screenshotEntry != undefined) do append screenshotEntries screenshotEntry
            )

            return sortScreenshotsByOrder screenshotEntries
        ),

        fn packageFromSection apiResponseFilePath iniSection detailsLoaded: false = (
            local packageInfo = MaxPkgApiPackageData()
            packageInfo.guid = ini.readAny apiResponseFilePath iniSection #("Guid", "PackageGuid", "packageGuid", "guid")
            if (packageInfo.guid == "" and iniSection != "package" and iniSection != "details") do packageInfo.guid = iniSection
            packageInfo.slug = ini.readAny apiResponseFilePath iniSection #("Slug", "PackageSlug", "slug")
            packageInfo.packageName = ini.readAny apiResponseFilePath iniSection #("Name", "PackageName", "name")
            packageInfo.buttonName = ini.readAny apiResponseFilePath iniSection #("ButtonName", "buttonName") defaultValue: packageInfo.packageName
            packageInfo.version = ini.readAny apiResponseFilePath iniSection #("Version", "LatestVersion", "version")
            packageInfo.latestVersion = packageInfo.version
            packageInfo.developer = ini.readAny apiResponseFilePath iniSection #("Developer", "DeveloperName", "developerName", "developer")
            packageInfo.description = ini.readAny apiResponseFilePath iniSection #("Description", "description")
            packageInfo.fullDescription = ini.readAny apiResponseFilePath iniSection #("FullDescription", "fullDescription", "FullText", "fullText")
            packageInfo.category = ini.readAny apiResponseFilePath iniSection #("Category", "category")
            packageInfo.documentationUrl = ini.readAny apiResponseFilePath iniSection #("Documentation", "DocumentationUrl", "documentation", "documentationUrl", "HelpUrl")
            packageInfo.helpUrl = packageInfo.documentationUrl
            packageInfo.homepageUrl = ini.readAny apiResponseFilePath iniSection #("Homepage", "HomepageUrl", "homepage", "homepageUrl")
            packageInfo.supportUrl = ini.readAny apiResponseFilePath iniSection #("Support", "SupportUrl", "support", "supportUrl")
            packageInfo.purchaseUrl = ini.readAny apiResponseFilePath iniSection #("PurchaseUrl", "purchaseUrl", "Purchase", "purchase")
            packageInfo.purchaseButtonLabel = ini.readAny apiResponseFilePath iniSection #("PurchaseButtonLabel", "purchaseButtonLabel")
            packageInfo.licenseType = ini.readAny apiResponseFilePath iniSection #("License", "LicenseType", "license")
            packageInfo.licenseUrl = ini.readAny apiResponseFilePath iniSection #("LicenseUrl", "licenseUrl")
            packageInfo.releaseChannel = ini.readAny apiResponseFilePath iniSection #("Channel", "ReleaseChannel", "releaseChannel") defaultValue: "stable"
            packageInfo.releaseDate = ini.readAny apiResponseFilePath iniSection #("ReleaseDate", "releaseDate")
            packageInfo.minimumMaxVersion = ini.readAny apiResponseFilePath iniSection #("Min3dsMax", "Minimum3dsMax", "min3dsMax")
            packageInfo.maximumMaxVersion = ini.readAny apiResponseFilePath iniSection #("Max3dsMax", "Maximum3dsMax", "max3dsMax")
            packageInfo.manifestVersion = ini.readAny apiResponseFilePath iniSection #("ManifestVersion", "manifestVersion")
            packageInfo.packagerName = ini.readAny apiResponseFilePath iniSection #("Packager", "packager")
            packageInfo.packagerVersion = ini.readAny apiResponseFilePath iniSection #("PackagerVersion", "packagerVersion")
            packageInfo.runtime = ini.readAny apiResponseFilePath iniSection #("Runtime", "runtime")
            packageInfo.entry = ini.readAny apiResponseFilePath iniSection #("Entry", "entry")
            packageInfo.iconUrl = ini.readAny apiResponseFilePath iniSection #("IconUrl", "iconUrl", "Icon")
            packageInfo.packageIconUrl = ini.readAny apiResponseFilePath iniSection #("PackageIconUrl", "packageIconUrl")
            packageInfo.coverImageUrl = ini.readAny apiResponseFilePath iniSection #("CoverImageUrl", "coverImageUrl")
            packageInfo.downloadUrl = ini.readAny apiResponseFilePath iniSection #("DownloadUrl", "downloadUrl")
            packageInfo.rating = floatValue (ini.readAny apiResponseFilePath iniSection #("Rating", "rating") defaultValue: "0") 0.0
            packageInfo.reviewCount = integerValue (ini.readAny apiResponseFilePath iniSection #("ReviewCount", "reviewCount") defaultValue: "0") 0
            packageInfo.downloadCount = integerValue (ini.readAny apiResponseFilePath iniSection #("DownloadCount", "downloadCount") defaultValue: "0") 0
            packageInfo.detailsLoaded = detailsLoaded
            packageInfo.changelogEntries = readChangelog apiResponseFilePath (iniSection + ".changelog")
            if (packageInfo.changelogEntries.count == 0 and detailsLoaded) do packageInfo.changelogEntries = readChangelog apiResponseFilePath "changelog"
            if (packageInfo.changelogEntries.count == 0 and detailsLoaded) do packageInfo.changelogEntries = readVersionedChangelog apiResponseFilePath
            if (detailsLoaded) do packageInfo.screenshotEntries = readScreenshots apiResponseFilePath
            return packageInfo
        ),

        fn errorFromResponse apiResponseFilePath responseInfo = (
            responseInfo.errorCode = ini.read apiResponseFilePath "error" "Code"
            responseInfo.errorMessage = ini.read apiResponseFilePath "error" "Message"
            responseInfo.requestId = ini.read apiResponseFilePath "error" "RequestId"
            if (responseInfo.errorCode != "" or responseInfo.errorMessage != "") do (
                responseInfo.success = false
                return true
            )
            return false
        ),

        fn parsePackages apiResponseFilePath detailsLoaded: false requirePackageName: true = (
            local responseInfo = MaxPkgApiResponseData()
            if (apiResponseFilePath == "") do (
                responseInfo.errorCode = "NETWORK_ERROR"
                responseInfo.errorMessage = "The Runtime API could not be reached."
                return responseInfo
            )
            if (errorFromResponse apiResponseFilePath responseInfo) do return responseInfo
            local responseSections = ini.sections apiResponseFilePath
            for iniSection in responseSections do (
                local normalizedSection = toLower iniSection
                if (normalizedSection != "error" and normalizedSection != "meta" and normalizedSection != "catalog" and normalizedSection != "response" and normalizedSection != "changelog") do (
                    local packageInfo = packageFromSection apiResponseFilePath iniSection detailsLoaded: detailsLoaded
                    if (packageInfo.guid != "" and (not requirePackageName or packageInfo.packageName != "")) do append responseInfo.packages packageInfo
                )
            )
            local metadataSection = findSection responseSections "catalog"
            if (metadataSection == "") do metadataSection = findSection responseSections "meta"
            if (metadataSection == "") do metadataSection = "catalog"
            responseInfo.page = integerValue (ini.read apiResponseFilePath metadataSection "Page" defaultValue: "1") 1
            responseInfo.pageSize = integerValue (ini.read apiResponseFilePath metadataSection "PageSize" defaultValue: "24") 24
            responseInfo.total = integerValue (ini.read apiResponseFilePath metadataSection "Total" defaultValue: (responseInfo.packages.count as string)) responseInfo.packages.count
            responseInfo.totalPages = integerValue (ini.read apiResponseFilePath metadataSection "TotalPages" defaultValue: "0") 0
            if (responseInfo.packages.count > 0) do responseInfo.packageInfo = responseInfo.packages[1]
            responseInfo.success = true
            return responseInfo
        ),

        fn catalog queryText: "" categoryFilter: "" sortMode: "popular" pageNumber: 1 pageSize: 24 channelName: "stable" = (
            local formFields = #(
                utils.formField "query" queryText,
                utils.formField "category" categoryFilter,
                utils.formField "sort" sortMode,
                utils.formField "page" (pageNumber as string),
                utils.formField "pageSize" (pageSize as string)
            )
            join formFields (commonFormFields channelName)
            return enforceMinimum3dsMax (parsePackages (request "catalog" formFields))
        ),

        fn packageDetails packageReference channelName: "stable" = (
            local formFields = #(utils.formField "package" packageReference)
            join formFields (commonFormFields channelName)
            return enforceMinimum3dsMax (parsePackages (request "packages/details" formFields) detailsLoaded: true) requireCompatiblePackage: true
        ),

        fn resolvePackage packageReference channelName: "stable" = (
            local formFields = #(utils.formField "package" packageReference)
            join formFields (commonFormFields channelName)
            return enforceMinimum3dsMax (parsePackages (request "packages/resolve" formFields) detailsLoaded: true) requireCompatiblePackage: true
        ),

        fn updates packageVersions channelName: "stable" = (
            local formFields = #(utils.formField "packages" (utils.join packageVersions separator: ","))
            join formFields (commonFormFields channelName)
            return enforceMinimum3dsMax (parsePackages (request "updates" formFields) requirePackageName: false)
        )
    )

    MaxPkgRepositoryModule()
)
