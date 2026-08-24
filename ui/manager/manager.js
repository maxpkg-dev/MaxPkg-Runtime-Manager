/*
 * Controls Manager rendering, settings, and Runtime commands.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

(function (window, document) {
    "use strict";

    var Common = window.MaxPkgCommon;
    var currentState = {
        runtimeVersion: "",
        packages: [],
        updateCount: 0,
        connection: "offline",
        settings: {},
        collections: { loaded: false, available: false, featuredCount: 0, items: [] },
        categories: { loaded: false, available: false, items: [] },
        discover: { available: false, message: "Repository is unavailable.", packages: [] },
        remoteDetails: null
    };
    var activeTab = "discover";
    var activeFilter = "all";
    var toolbarVisibilityFilter = "all";
    var activeSort = "toolbar";
    var searchText = "";
    var observedSearchContent = "";
    var activeDiscoverKind = "";
    var activeCollectionSlug = "";
    var discoverCategory = "";
    var discoverSort = "popular";
    var detailsGuid = "";
    var detailsTab = "description";
    var activeScreenshotIndex = 0;
    var detailsListScrollTop = 0;
    var settingsSaveTimer = null;

    var draggedToolbarCard = null;
    var draggedToolbarGrid = null;
    var toolbarDropPlaceholder = null;
    var draggedToolbarOriginalNextSibling = null;

    function icon(iconName) {
        return "<img class='icon' src='../../data/themes/manager/icons/" + iconName + ".svg' alt=''>";
    }

    function boolText(isEnabled) {
        return isEnabled ? "true" : "false";
    }

    function safeCollectionAccent(accentColor) {
        var normalizedColor = String(accentColor || "").replace(/^\s+|\s+$/g, "");
        return /^#[0-9a-f]{6}$/i.test(normalizedColor) ? normalizedColor : "";
    }

    function safeCollectionIcon(iconName) {
        var normalizedIcon = String(iconName || "").toLowerCase().replace(/^\s+|\s+$/g, "");
        return /^[a-z0-9-]+$/.test(normalizedIcon) ? normalizedIcon : "package";
    }

    function collectionIcon(iconName) {
        var normalizedIcon = safeCollectionIcon(iconName);
        var iconPaths = {
            crown: "<path d='m3 5 4 4 5-6 5 6 4-4-2 14H5Z'></path><path d='M5 19h14'></path>",
            sparkles: "<path d='m12 3-1.1 4.1L7 8.2l3.9 1.1L12 13l1.1-3.7L17 8.2l-3.9-1.1Z'></path><path d='m19 13-.7 2.3L16 16l2.3.7L19 19l.7-2.3L22 16l-2.3-.7Z'></path><path d='m5 15-.6 1.7L3 17.3l1.4.5L5 19.5l.6-1.7 1.4-.5-1.4-.6Z'></path>",
            heart: "<path d='M19.5 12.6 12 20l-7.5-7.4a5 5 0 0 1 7.1-7.1l.4.4.4-.4a5 5 0 0 1 7.1 7.1Z'></path>",
            rocket: "<path d='M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09Z'></path><path d='m12 15-3-3a22 22 0 0 1 2-3.5A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6.5 11a22.41 22.41 0 0 1-3.5 2Z'></path><path d='M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0'></path><path d='M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5'></path>",
            medal: "<circle cx='12' cy='8' r='6'></circle><path d='M15.477 12.89 17 22l-5-3-5 3 1.523-9.11'></path>",
            tag: "<path d='M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42Z'></path><circle cx='7.5' cy='7.5' r='.5' fill='#ffffff' stroke='none'></circle>",
            package: "<path d='M16.5 9.4 7.5 4.2'></path><path d='M21 16V8a2 2 0 0 0-1-1.7l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.7l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z'></path><path d='m3.3 7 8.7 5 8.7-5'></path><path d='M12 22V12'></path>"
        };
        return "<svg class='collection-icon' viewBox='0 0 24 24' aria-hidden='true' fill='none' stroke='#ffffff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>" + (iconPaths[normalizedIcon] || iconPaths.package) + "</svg>";
    }

    function collectionAccentBackground(accentColor, opacityValue) {
        var safeAccent = safeCollectionAccent(accentColor);
        var redValue;
        var greenValue;
        var blueValue;
        if (!safeAccent) {
            return "";
        }
        redValue = parseInt(safeAccent.substring(1, 3), 16);
        greenValue = parseInt(safeAccent.substring(3, 5), 16);
        blueValue = parseInt(safeAccent.substring(5, 7), 16);
        return "rgba(" + redValue + "," + greenValue + "," + blueValue + "," + opacityValue + ")";
    }

    function readDiscoverSelection() {
        var discoverState = currentState.discover || {};
        activeDiscoverKind = discoverState.featured ? "featured" : (discoverState.collection ? "collection" : "");
        activeCollectionSlug = activeDiscoverKind === "collection" ? discoverState.collection : "";
        discoverCategory = activeDiscoverKind ? "" : (discoverState.category || "");
    }

    function resetDiscoverSelection() {
        activeDiscoverKind = "";
        activeCollectionSlug = "";
    }

    function collectionPillStyle(accentColor, isActive, hasActiveSelection) {
        var safeAccent = safeCollectionAccent(accentColor);
        var accentBackground = collectionAccentBackground(safeAccent, "0.30");
        if (!safeAccent || (hasActiveSelection && !isActive)) {
            return "";
        }
        return " style='border-color:" + safeAccent + ";background:" + accentBackground + ";color:#ffffff;" + (isActive ? "box-shadow:0 0 12px " + collectionAccentBackground(safeAccent, "0.42") + ";" : "") + "'";
    }

    function collectionsHtml() {
        var collectionsState = currentState.collections || {};
        var collectionItems = collectionsState.items || [];
        var hasActiveSelection = activeDiscoverKind !== "";
        var pills = [];
        var collectionIndex;
        var collectionInfo;
        var isActive;
        var accentStyle;
        if (!collectionsState.loaded) {
            return "";
        }
        pills.push("<button class='collection-pill collection-pill-all" + (!hasActiveSelection ? " is-active" : "") + "' type='button' data-action='discover-collection' data-kind='all' title='All packages'" + collectionPillStyle("#3280dd", !hasActiveSelection, hasActiveSelection) + ">" + collectionIcon("package") + "<span>All packages</span></button>");
        if (!collectionsState.available) {
            return "";
        }
        pills.push("<button class='collection-pill collection-pill-featured" + (activeDiscoverKind === "featured" ? " is-active" : "") + "' type='button' data-action='discover-collection' data-kind='featured' title='Featured packages'" + collectionPillStyle("#eb8ccd", activeDiscoverKind === "featured", hasActiveSelection) + ">" + collectionIcon("crown") + "<span>Featured</span><strong>" + (parseInt(collectionsState.featuredCount, 10) || 0) + "</strong></button>");
        for (collectionIndex = 0; collectionIndex < collectionItems.length; collectionIndex += 1) {
            collectionInfo = collectionItems[collectionIndex];
            isActive = activeDiscoverKind === "collection" && activeCollectionSlug === collectionInfo.slug;
            accentStyle = collectionPillStyle(collectionInfo.accentColor, isActive, hasActiveSelection);
            pills.push("<button class='collection-pill" + (isActive ? " is-active" : "") + "' type='button' data-action='discover-collection' data-kind='collection' data-slug='" + Common.escapeHtml(collectionInfo.slug) + "' title='" + Common.escapeHtml(collectionInfo.description || collectionInfo.name) + "'" + accentStyle + ">" + collectionIcon(collectionInfo.icon) + "<span>" + Common.escapeHtml(collectionInfo.name) + "</span><strong>" + (parseInt(collectionInfo.count, 10) || 0) + "</strong></button>");
        }
        if (!pills.length) {
            return "";
        }
        return "<div class='collections-bar'><div class='collection-pills'>" + pills.join("") + "</div></div>";
    }

    function populateDiscoverCategoryOptions() {
        var categoriesState = currentState.categories || {};
        var categoryItems = categoriesState.items || [];
        var categoryMenu = Common.byId("discoverCategoryMenu");
        var categoryOptions = ["<button type='button' data-dropdown-option=''>All Categories</button>"];
        var categoryIndex;
        var categoryInfo;
        var hasCategories = false;
        for (categoryIndex = 0; categoryIndex < categoryItems.length; categoryIndex += 1) {
            categoryInfo = categoryItems[categoryIndex];
            if ((parseInt(categoryInfo.count, 10) || 0) <= 0) {
                continue;
            }
            hasCategories = true;
            categoryOptions.push("<button type='button' data-dropdown-option='" + Common.escapeHtml(categoryInfo.slug) + "'>" + Common.escapeHtml(categoryInfo.name) + "</button>");
        }
        categoryMenu.innerHTML = categoryOptions.join("");
        if (!hasCategories) {
            discoverCategory = "";
        }
        Common.toggleClass(Common.byId("discoverCategoryControl"), "is-hidden", !categoriesState.loaded || !categoriesState.available || !hasCategories);
        Common.toggleClass(Common.byId("discoverTools"), "has-single-tool", !categoriesState.loaded || !categoriesState.available || !hasCategories);
        window.MaxPkgDropdown.setSelectValue(Common.byId("discoverCategorySelect"), discoverCategory);
    }

    function updateDiscoverToolsState() {
        var hasActiveCategory = discoverCategory !== "";
        var hasCustomSort = discoverSort !== "popular";
        populateDiscoverCategoryOptions();
        window.MaxPkgDropdown.setSelectValue(Common.byId("discoverSortSelect"), discoverSort);
        Common.toggleClass(Common.byId("discoverCategoryControl"), "has-active-filter", hasActiveCategory);
        Common.toggleClass(Common.byId("clearDiscoverCategoryButton"), "is-hidden", !hasActiveCategory);
        Common.toggleClass(Common.byId("discoverSortControl"), "has-custom-sort", hasCustomSort);
        Common.toggleClass(Common.byId("clearDiscoverSortButton"), "is-hidden", !hasCustomSort);
    }

    function categoriesSidebarHtml() {
        var categoriesState = currentState.categories || {};
        var categoryItems = categoriesState.items || [];
        var categoryButtons = [];
        var categoryIndex;
        var categoryInfo;
        var categoryCount;
        var isActive;
        if (!categoriesState.loaded || !categoriesState.available) {
            return "";
        }
        categoryButtons.push("<button class='discover-category-option" + (!discoverCategory ? " is-active" : "") + "' type='button' data-action='discover-sidebar-category' data-slug='' title='Show all categories'><span class='discover-category-marker'><img src='../../data/themes/manager/icons/check.svg' alt=''></span><span class='discover-category-label'>All Categories</span></button>");
        for (categoryIndex = 0; categoryIndex < categoryItems.length; categoryIndex += 1) {
            categoryInfo = categoryItems[categoryIndex];
            categoryCount = parseInt(categoryInfo.count, 10) || 0;
            if (categoryCount <= 0) {
                continue;
            }
            isActive = discoverCategory === categoryInfo.slug;
            categoryButtons.push("<button class='discover-category-option" + (isActive ? " is-active" : "") + "' type='button' data-action='discover-sidebar-category' data-slug='" + Common.escapeHtml(categoryInfo.slug) + "' title='" + Common.escapeHtml(categoryInfo.description || categoryInfo.name) + "'><span class='discover-category-marker'><img src='../../data/themes/manager/icons/check.svg' alt=''></span><span class='discover-category-count'>" + categoryCount + "</span><span class='discover-category-label'>" + Common.escapeHtml(categoryInfo.name) + "</span></button>");
        }
        if (categoryButtons.length <= 1) {
            return "";
        }
        return "<div class='discover-category-sidebar'><div class='discover-category-panel'><h3>Categories</h3><div class='discover-category-options'>" + categoryButtons.join("") + "</div></div></div>";
    }

    function discoverLayoutHtml(discoverContent) {
        var sidebarContent = categoriesSidebarHtml();
        if (!sidebarContent) {
            return discoverContent;
        }
        return "<div class='discover-layout'>" + sidebarContent + "<div class='discover-results'>" + discoverContent + "</div></div>";
    }

    function packageDescriptionPreview(descriptionText) {
        var maxLength = 280;
        var normalizedText = (descriptionText || "No description provided.").replace(/\s+/g, " ");
        var truncatedText;
        var lastSpaceIndex;
        if (normalizedText.length < maxLength) {
            return normalizedText;
        }
        truncatedText = normalizedText.substring(0, maxLength - 3).replace(/\s+$/g, "");
        lastSpaceIndex = truncatedText.lastIndexOf(" ");
        if (lastSpaceIndex > 0) {
            truncatedText = truncatedText.substring(0, lastSpaceIndex);
        }
        return truncatedText + "...";
    }

    function packageDescriptionHtml(descriptionText) {
        return "<p class='package-description'>" + Common.escapeHtml(packageDescriptionPreview(descriptionText)) + "</p>";
    }

    function safeHttpUrl(sourceUrl) {
        var normalizedUrl = String(sourceUrl || "").replace(/^\s+|\s+$/g, "");
        if (/^https?:\/\//i.test(normalizedUrl)) {
            return normalizedUrl;
        }
        return "";
    }

    function safeImageUrl(sourceUrl) {
        var normalizedUrl = String(sourceUrl || "").replace(/^\s+|\s+$/g, "");
        if (safeHttpUrl(normalizedUrl) || /^file:\/\/\//i.test(normalizedUrl)) {
            return normalizedUrl;
        }
        return "";
    }

    function safeThumbnailImageUrl(sourceUrl, fallbackUrl) {
        var normalizedUrl = safeImageUrl(sourceUrl);
        if (!normalizedUrl || /\.(webp|avif)(?:[?#]|$)/i.test(normalizedUrl)) {
            return fallbackUrl;
        }
        return normalizedUrl;
    }

    function discoverPackageForGuid(packageGuid) {
        var packageIndex;
        var remotePackages = currentState.discover && currentState.discover.packages ? currentState.discover.packages : [];
        var normalizedGuid = String(packageGuid || "").toLowerCase();
        if (!normalizedGuid) {
            return null;
        }
        for (packageIndex = 0; packageIndex < remotePackages.length; packageIndex += 1) {
            if (String(remotePackages[packageIndex].guid || "").toLowerCase() === normalizedGuid) {
                return remotePackages[packageIndex];
            }
        }
        return null;
    }

    function installedPackageForGuid(packageGuid) {
        var packageIndex;
        var normalizedGuid = String(packageGuid || "").toLowerCase();
        if (!normalizedGuid) {
            return null;
        }
        for (packageIndex = 0; packageIndex < currentState.packages.length; packageIndex += 1) {
            if (String(currentState.packages[packageIndex].guid || "").toLowerCase() === normalizedGuid) {
                return currentState.packages[packageIndex];
            }
        }
        return null;
    }

    function copyPackageFields(targetPackage, sourcePackage, keepEmptyValues) {
        var fieldName;
        var fieldValue;
        if (!sourcePackage) {
            return targetPackage;
        }
        for (fieldName in sourcePackage) {
            if (sourcePackage.hasOwnProperty(fieldName)) {
                fieldValue = sourcePackage[fieldName];
                if (keepEmptyValues || (fieldValue !== undefined && fieldValue !== null && fieldValue !== "")) {
                    targetPackage[fieldName] = fieldValue;
                }
            }
        }
        return targetPackage;
    }

    function mergedDetailsPackage(remotePackage) {
        var installedPackage = installedPackageForGuid(remotePackage.guid);
        var mergedPackage;
        if (!installedPackage) {
            return remotePackage;
        }
        mergedPackage = copyPackageFields({}, installedPackage, true);
        copyPackageFields(mergedPackage, remotePackage, false);
        mergedPackage.isRemote = false;
        mergedPackage.iconFile = installedPackage.iconFile;
        mergedPackage.installPath = installedPackage.installPath;
        mergedPackage.toolbarVisible = installedPackage.toolbarVisible;
        mergedPackage.toolbarOrder = installedPackage.toolbarOrder;
        mergedPackage.updateAvailable = installedPackage.updateAvailable;
        mergedPackage.latestVersion = installedPackage.latestVersion;
        return mergedPackage;
    }

    function safePackageImageUrl(packageInfo, includeCover) {
        var discoverPackage = discoverPackageForGuid(packageInfo.guid);
        var packageIconUrl = safeImageUrl(packageInfo.packageIconUrl);
        var iconUrl = safeImageUrl(packageInfo.iconUrl);
        var coverImageUrl = includeCover ? safeImageUrl(packageInfo.coverImageUrl) : "";
        if (!packageIconUrl && discoverPackage) {
            packageIconUrl = safeImageUrl(discoverPackage.packageIconUrl);
        }
        if (!iconUrl && discoverPackage) {
            iconUrl = safeImageUrl(discoverPackage.iconUrl);
        }
        if (!coverImageUrl && includeCover && discoverPackage) {
            coverImageUrl = safeImageUrl(discoverPackage.coverImageUrl);
        }
        if (packageIconUrl) {
            return packageIconUrl;
        }
        if (iconUrl) {
            return iconUrl;
        }
        if (coverImageUrl) {
            return coverImageUrl;
        }
        if (!packageInfo.isRemote && packageInfo.iconUrl) {
            return packageInfo.iconUrl;
        }
        return "";
    }

    function activeViewName() {
        if (activeTab === "discover") {
            return "discover";
        }
        if (activeFilter === "updates") {
            return "updates";
        }
        return "installed";
    }

    function updateSearchPlaceholder() {
        var searchInput = Common.byId("searchInput");
        var viewName = activeViewName();
        var placeholderText = "Search installed packages";
        if (viewName === "discover") {
            placeholderText = "Search Discover";
        } else if (viewName === "updates") {
            placeholderText = "Search updates";
        }
        searchInput.setAttribute("placeholder", placeholderText);
    }

    function readManagerFilter(filterContent) {
        var normalizedFilter = String(filterContent || "all").toLowerCase();
        activeFilter = normalizedFilter.indexOf("updates") === 0 ? "updates" : "all";
        if (normalizedFilter.indexOf("hidden") >= 0) {
            toolbarVisibilityFilter = "hidden";
        } else if (normalizedFilter.indexOf("toolbar") >= 0) {
            toolbarVisibilityFilter = "toolbar";
        } else {
            toolbarVisibilityFilter = "all";
        }
    }

    function managerFilterContent() {
        if (activeFilter === "updates" && toolbarVisibilityFilter !== "all") {
            return "updates-" + toolbarVisibilityFilter;
        }
        if (activeFilter === "updates") {
            return "updates";
        }
        return toolbarVisibilityFilter;
    }

    function saveManagerView() {
        window.location.href = "maxpkg://manager/view?tab=" + Common.encode(activeTab) + "&filter=" + Common.encode(managerFilterContent()) + "&sort=" + Common.encode(activeSort);
    }

    function findPackage(packageGuid) {
        var packageIndex;
        if (currentState.remoteDetails && currentState.remoteDetails.guid.toLowerCase() === packageGuid.toLowerCase()) {
            return mergedDetailsPackage(currentState.remoteDetails);
        }
        for (packageIndex = 0; packageIndex < currentState.packages.length; packageIndex += 1) {
            if (currentState.packages[packageIndex].guid.toLowerCase() === packageGuid.toLowerCase()) {
                return currentState.packages[packageIndex];
            }
        }
        if (currentState.discover && currentState.discover.packages) {
            for (packageIndex = 0; packageIndex < currentState.discover.packages.length; packageIndex += 1) {
                if (currentState.discover.packages[packageIndex].guid.toLowerCase() === packageGuid.toLowerCase()) {
                    return currentState.discover.packages[packageIndex];
                }
            }
        }
        return null;
    }

    function packageInitials(packageInfo) {
        var words = packageInfo.name.replace(/^\s+|\s+$/g, "").split(/\s+/);
        var initials = words.length ? words[0].charAt(0) : "P";
        if (words.length > 1) {
            initials += words[1].charAt(0);
        }
        return Common.escapeHtml(initials.toUpperCase());
    }

    function packageIcon(packageInfo, cssClass, includeCover) {
        var imageUrl = safePackageImageUrl(packageInfo, includeCover);
        if (imageUrl) {
            return "<img class='" + cssClass + "' src='" + Common.escapeHtml(imageUrl) + "' alt=''>";
        }
        return "<span class='" + cssClass + " package-icon-fallback'>" + packageInitials(packageInfo) + "</span>";
    }

    function comparePackages(leftPackage, rightPackage) {
        var leftText;
        var rightText;
        var leftToolbarIndex;
        var rightToolbarIndex;
        if (activeSort === "toolbar") {
            leftToolbarIndex = toolbarOrderIndex(leftPackage.guid);
            rightToolbarIndex = toolbarOrderIndex(rightPackage.guid);
            if (leftToolbarIndex < rightToolbarIndex) {
                return -1;
            }
            if (leftToolbarIndex > rightToolbarIndex) {
                return 1;
            }
        }
        leftText = leftPackage[activeSort] || leftPackage.name || "";
        rightText = rightPackage[activeSort] || rightPackage.name || "";
        leftText = String(leftText).toLowerCase();
        rightText = String(rightText).toLowerCase();
        if (leftText < rightText) {
            return -1;
        }
        if (leftText > rightText) {
            return 1;
        }
        return 0;
    }

    function packageGuidIndex(packageGuids, packageGuid) {
        var normalizedGuid = String(packageGuid || "").toLowerCase();
        var orderIndex;
        for (orderIndex = 0; orderIndex < packageGuids.length; orderIndex += 1) {
            if (String(packageGuids[orderIndex] || "").toLowerCase() === normalizedGuid) {
                return orderIndex;
            }
        }
        return -1;
    }

    function toolbarOrderIndex(packageGuid) {
        var toolbarOrder = currentState.settings.toolbarOrder || [];
        var orderIndex = packageGuidIndex(toolbarOrder, packageGuid);
        return orderIndex < 0 ? toolbarOrder.length : orderIndex;
    }

    function toolbarSortingEnabled() {
        return activeSort === "toolbar" && !searchText;
    }

    function toolbarHiddenIndicator(packageInfo) {
        if (!packageInfo || packageInfo.toolbarVisible !== false) {
            return "";
        }
        return "<span class='toolbar-hidden-indicator' title='Hidden from toolbar'>" + icon("eye-off") + "</span>";
    }

    function purchaseIndicator(packageInfo, includeLabel) {
        if (!packageInfo.purchaseUrl) {
            return "";
        }
        return "<span class='badge badge-purchase'>" + icon("shopping-cart") + (includeLabel ? Common.escapeHtml(purchaseActionLabel(packageInfo)) : "") + "</span>";
    }

    function purchaseActionLabel(packageInfo) {
        var buttonLabel = String(packageInfo.purchaseButtonLabel || "").replace(/^\s+|\s+$/g, "");
        return buttonLabel || "Buy";
    }

    function purchaseNoticeCopy(packageInfo) {
        var normalizedLabel = purchaseActionLabel(packageInfo).toLowerCase();
        if (normalizedLabel === "donate") {
            return "This package is free. If it helps your work, consider donating to support the author and continued development.";
        }
        if (normalizedLabel === "support") {
            return "This package is free. Support the author to help fund maintenance, improvements, and future releases.";
        }
        if (normalizedLabel === "sponsor") {
            return "This package is free. Sponsor the author to help turn new ideas into updates and new tools.";
        }
        if (normalizedLabel === "purchase") {
            return "Purchase this package directly from the author to unlock the tool and support its continued development.";
        }
        if (normalizedLabel === "get license" || normalizedLabel.indexOf("license") >= 0) {
            return "Get your license directly from the author and receive access according to the developer's terms.";
        }
        if (normalizedLabel === "buy") {
            return "Buy this package directly from the author and support its continued development.";
        }
        return "Support this package directly through the author. Your contribution helps fund maintenance and future updates.";
    }

    function purchaseActionIcon(packageInfo) {
        var normalizedLabel = purchaseActionLabel(packageInfo).toLowerCase();
        if (normalizedLabel === "donate" || normalizedLabel === "support" || normalizedLabel === "sponsor") {
            return "heart-success";
        }
        return "shopping-cart";
    }

    function purchaseNotice(packageInfo) {
        if (!packageInfo.purchaseUrl) {
            return "";
        }
        return "<div class='purchase-details-notice'>" +
            "<span class='purchase-notice-icon'>" + icon(purchaseActionIcon(packageInfo) === "heart-success" ? "heart" : "circle-dollar-sign") + "</span>" +
            "<p class='purchase-notice-copy'>" + Common.escapeHtml(purchaseNoticeCopy(packageInfo)) + "</p>" +
            "<div class='purchase-notice-action'><a class='button button-purchase purchase-notice-button' href='maxpkg://manager/package-link/" + Common.encode(packageInfo.guid) + "?kind=purchase'>" + icon(purchaseActionIcon(packageInfo)) + Common.escapeHtml(purchaseActionLabel(packageInfo)) + "</a></div>" +
        "</div>";
    }

    function compactStatNumber(sourceNumber) {
        var normalizedNumber = Math.max(0, parseInt(sourceNumber, 10) || 0);
        var compactNumber;
        if (normalizedNumber >= 1000000) {
            compactNumber = Math.round(normalizedNumber / 100000) / 10;
            return compactNumber + "M";
        }
        if (normalizedNumber >= 1000) {
            compactNumber = Math.round(normalizedNumber / 100) / 10;
            return compactNumber + "K";
        }
        return String(normalizedNumber);
    }

    function discoverPackageStats(packageInfo) {
        var downloadCount = Math.max(0, parseInt(packageInfo.downloadCount, 10) || 0);
        var reviewCount = Math.max(0, parseInt(packageInfo.reviewCount, 10) || 0);
        var rating = parseFloat(packageInfo.rating) || 0;
        var statsContent = "<span class='catalog-stat' title='" + downloadCount + " downloads'>" + icon("download") + compactStatNumber(downloadCount) + "</span>";
        statsContent += "<span class='catalog-stat' title='Rating " + rating.toFixed(1) + " from " + reviewCount + " review(s)'>" + icon("star") + rating.toFixed(1) + " <span class='catalog-stat-secondary'>(" + compactStatNumber(reviewCount) + ")</span></span>";
        return statsContent;
    }

    function visiblePackages() {
        var filteredPackages = [];
        var packageIndex;
        var packageInfo;
        var searchableText;
        for (packageIndex = 0; packageIndex < currentState.packages.length; packageIndex += 1) {
            packageInfo = currentState.packages[packageIndex];
            searchableText = (packageInfo.name + " " + packageInfo.developer + " " + packageInfo.description + " " + packageInfo.guid).toLowerCase();
            if (searchText && searchableText.indexOf(searchText) < 0) {
                continue;
            }
            if (activeFilter === "updates" && !packageInfo.updateAvailable) {
                continue;
            }
            if (toolbarVisibilityFilter === "toolbar" && !packageInfo.toolbarVisible) {
                continue;
            }
            if (toolbarVisibilityFilter === "hidden" && packageInfo.toolbarVisible) {
                continue;
            }
            filteredPackages.push(packageInfo);
        }
        filteredPackages.sort(comparePackages);
        return filteredPackages;
    }

    function packageCard(packageInfo) {
        var badges = "<span class='badge'>" + Common.escapeHtml(packageInfo.runtime) + "</span>";
        var isFullCard = !!currentState.settings.managerFullCards;
        var packageDetailsContent = "";
        var updateAction = "";
        var dragHandle = "";
        var cardClass = isFullCard ? "card card-full" : "card card-compact";
        if (toolbarSortingEnabled()) {
            cardClass += " toolbar-sort-card";
            dragHandle = "<span class='toolbar-drag-handle' role='button' draggable='true' data-toolbar-drag='true' title='Drag to change Toolbar order'>" +
                "<img src='../../data/themes/manager/icons/grip-vertical.svg' draggable='false' alt=''></span>";
        }
        if (packageInfo.toolbarVisible) {
            badges += "<span class='badge'>Toolbar</span>";
        }
        if (packageInfo.updateAvailable) {
            badges += "<span class='badge badge-warning'>v" + Common.escapeHtml(packageInfo.latestVersion) + " available</span>";
            updateAction = "<a class='button' href='maxpkg://manager/update/" + Common.encode(packageInfo.guid) + "' data-busy='Updating package...'>" + icon("download") + "Update</a> ";
        }
        badges += purchaseIndicator(packageInfo, false);
        if (isFullCard) {
            packageDetailsContent = packageDescriptionHtml(packageInfo.description) +
                "<div>" + badges + "</div>";
        }
        return "<div class='" + cardClass + "' data-package-guid='" + Common.escapeHtml(packageInfo.guid) + "'>" +
            dragHandle +
            "<div class='card-content clearfix'>" +
                "<button class='package-summary clearfix' type='button' data-action='details' data-guid='" + Common.escapeHtml(packageInfo.guid) + "' title='Open package details'>" +
                    packageIcon(packageInfo, "package-icon", true) +
                    "<span class='package-heading'><span class='package-title ellipsis'>" + Common.escapeHtml(packageInfo.name) + "</span>" +
                    "<span class='package-meta ellipsis'>" + toolbarHiddenIndicator(packageInfo) + "v" + Common.escapeHtml(packageInfo.version) + " &middot; " + Common.escapeHtml(packageInfo.developer || "Unknown developer") + "</span></span>" +
                "</button>" + packageDetailsContent +
            "</div>" +
            "<div class='card-actions'>" + updateAction +
                "<a class='button button-primary' href='maxpkg://manager/run/" + Common.encode(packageInfo.guid) + "' data-busy='Starting package...'>" + icon("play") + "Run</a>" +
                "<button class='icon-button more-button' type='button' title='More actions' data-action='menu' data-guid='" + Common.escapeHtml(packageInfo.guid) + "'>" + icon("ellipsis") + "</button>" +
            "</div>" +
        "</div>";
    }

    function emptyInstalledState() {
        var title = currentState.packages.length ? "No packages match" : "No packages installed";
        var message = currentState.packages.length ? "Try a different search or filter." : "Installed packages will appear here as soon as Runtime discovers their manifests.";
        return "<div class='state-panel'><img class='state-icon' src='../../data/themes/manager/icons/package.svg' alt=''><h2>" + title + "</h2><p>" + message + "</p>" +
            "<a class='button' href='maxpkg://manager/refresh' data-busy='Scanning packages...'>" + icon("refresh-cw") + "Refresh</a></div>";
    }

    function renderInstalled() {
        var packageCards = [];
        var packages = visiblePackages();
        var packageIndex;
        for (packageIndex = 0; packageIndex < packages.length; packageIndex += 1) {
            packageCards.push(packageCard(packages[packageIndex]));
        }
        Common.byId("installedPage").innerHTML = packageCards.length ? "<div class='card-grid'>" + packageCards.join("") + "</div>" : emptyInstalledState();

    }

    function ancestorWithClass(sourceElement, className) {
        var currentElement = sourceElement;
        while (currentElement && currentElement !== document.body) {
            if (Common.hasClass(currentElement, className)) {
                return currentElement;
            }
            currentElement = currentElement.parentNode;
        }
        return null;
    }

    function toolbarOrderFromGrid(cardGrid) {
        var orderedGuids = [];
        var visibleGuidLookup = {};
        var savedToolbarOrder = currentState.settings.toolbarOrder || [];
        var mergedGuids = [];
        var childElement = cardGrid.firstChild;
        var packageGuid;
        var normalizedGuid;
        var orderIndex;
        var visibleOrderIndex = 0;
        var packageIndex;
        while (childElement) {
            if (childElement.nodeType === 1 && childElement.getAttribute) {
                packageGuid = childElement.getAttribute("data-package-guid");
                if (packageGuid) {
                    orderedGuids.push(packageGuid);
                    visibleGuidLookup["guid:" + String(packageGuid).toLowerCase()] = true;
                }
            }
            childElement = childElement.nextSibling;
        }
        if (activeFilter === "all" && toolbarVisibilityFilter === "all") {
            return orderedGuids;
        }
        for (orderIndex = 0; orderIndex < savedToolbarOrder.length; orderIndex += 1) {
            packageGuid = savedToolbarOrder[orderIndex];
            normalizedGuid = "guid:" + String(packageGuid || "").toLowerCase();
            if (visibleGuidLookup[normalizedGuid]) {
                if (visibleOrderIndex < orderedGuids.length) {
                    mergedGuids.push(orderedGuids[visibleOrderIndex]);
                    visibleOrderIndex += 1;
                }
            } else {
                mergedGuids.push(packageGuid);
            }
        }
        while (visibleOrderIndex < orderedGuids.length) {
            mergedGuids.push(orderedGuids[visibleOrderIndex]);
            visibleOrderIndex += 1;
        }
        for (packageIndex = 0; packageIndex < currentState.packages.length; packageIndex += 1) {
            packageGuid = currentState.packages[packageIndex].guid;
            if (packageGuidIndex(mergedGuids, packageGuid) < 0) {
                mergedGuids.push(packageGuid);
            }
        }
        return mergedGuids;
    }

    function finishToolbarDrag(shouldSave) {
        var cardGrid = draggedToolbarGrid;
        var orderedGuids;
        var orderPayload;
        if (!draggedToolbarCard || !cardGrid) {
            return;
        }
        Common.removeClass(draggedToolbarCard, "is-toolbar-dragging");
        if (shouldSave && toolbarDropPlaceholder && toolbarDropPlaceholder.parentNode === cardGrid) {
            cardGrid.insertBefore(draggedToolbarCard, toolbarDropPlaceholder);
        } else if (draggedToolbarOriginalNextSibling && draggedToolbarOriginalNextSibling.parentNode === cardGrid) {
            cardGrid.insertBefore(draggedToolbarCard, draggedToolbarOriginalNextSibling);
        } else {
            cardGrid.appendChild(draggedToolbarCard);
        }
        if (toolbarDropPlaceholder && toolbarDropPlaceholder.parentNode) {
            toolbarDropPlaceholder.parentNode.removeChild(toolbarDropPlaceholder);
        }
        orderedGuids = shouldSave ? toolbarOrderFromGrid(cardGrid) : [];
        draggedToolbarCard = null;
        draggedToolbarGrid = null;
        toolbarDropPlaceholder = null;
        draggedToolbarOriginalNextSibling = null;
        if (shouldSave) {
            orderPayload = Common.byId("toolbarOrderPayload");
            orderPayload.innerHTML = orderedGuids.join("|");
            window.location.href = "maxpkg://manager/set-toolbar-order";
        }
    }

    function handleToolbarDragStart(eventObject) {
        var sourceElement = Common.eventTarget(eventObject);
        var dragHandle = Common.closestWithAttribute(sourceElement, "data-toolbar-drag");
        var packageCardElement;
        if (!dragHandle || !toolbarSortingEnabled()) {
            return;
        }
        packageCardElement = Common.closestWithAttribute(dragHandle, "data-package-guid");
        if (!packageCardElement) {
            return;
        }
        draggedToolbarCard = packageCardElement;
        draggedToolbarGrid = packageCardElement.parentNode;
        draggedToolbarOriginalNextSibling = packageCardElement.nextSibling;
        toolbarDropPlaceholder = document.createElement("div");
        toolbarDropPlaceholder.className = "card toolbar-drop-placeholder" + (Common.hasClass(packageCardElement, "card-compact") ? " card-compact" : "");
        toolbarDropPlaceholder.innerHTML = "<span>Drop here</span>";
        draggedToolbarGrid.insertBefore(toolbarDropPlaceholder, packageCardElement);
        if (eventObject.dataTransfer) {
            try {
                eventObject.dataTransfer.effectAllowed = "move";
                eventObject.dataTransfer.setData("Text", packageCardElement.getAttribute("data-package-guid"));
            } catch (dragError) {
            }
        }
        window.setTimeout(function () {
            if (draggedToolbarCard) {
                Common.addClass(draggedToolbarCard, "is-toolbar-dragging");
            }
        }, 0);
    }

    function handleToolbarDragOver(eventObject) {
        var sourceElement;
        var targetCard;
        var targetGrid;
        var targetBounds;
        var insertAfter;
        if (!draggedToolbarCard || !toolbarDropPlaceholder) {
            return;
        }
        sourceElement = Common.eventTarget(eventObject);
        targetGrid = ancestorWithClass(sourceElement, "card-grid");
        if (targetGrid !== draggedToolbarGrid) {
            return;
        }
        Common.preventDefault(eventObject);
        if (eventObject.dataTransfer) {
            try {
                eventObject.dataTransfer.dropEffect = "move";
            } catch (dragError) {
            }
        }
        targetCard = Common.closestWithAttribute(sourceElement, "data-package-guid");
        if (!targetCard || targetCard === draggedToolbarCard) {
            return;
        }
        targetBounds = targetCard.getBoundingClientRect();
        insertAfter = eventObject.clientX > targetBounds.left + ((targetBounds.right - targetBounds.left) / 2);
        if (insertAfter) {
            targetGrid.insertBefore(toolbarDropPlaceholder, targetCard.nextSibling);
        } else {
            targetGrid.insertBefore(toolbarDropPlaceholder, targetCard);
        }
    }

    function handleToolbarDrop(eventObject) {
        var targetGrid;
        if (!draggedToolbarCard) {
            return;
        }
        targetGrid = ancestorWithClass(Common.eventTarget(eventObject), "card-grid");
        if (targetGrid === draggedToolbarGrid) {
            Common.preventDefault(eventObject);
            finishToolbarDrag(true);
        } else {
            finishToolbarDrag(false);
        }
    }

    function handleToolbarDragEnd() {
        if (draggedToolbarCard) {
            finishToolbarDrag(false);
        }
    }

    function activeDiscoverFilterName() {
        var collectionsState = currentState.collections || {};
        var collectionItems = collectionsState.items || [];
        var categoriesState = currentState.categories || {};
        var categoryItems = categoriesState.items || [];
        var filterIndex;
        if (activeDiscoverKind === "featured") {
            return "Featured";
        }
        for (filterIndex = 0; filterIndex < collectionItems.length; filterIndex += 1) {
            if (collectionItems[filterIndex].slug === activeCollectionSlug) {
                return collectionItems[filterIndex].name;
            }
        }
        for (filterIndex = 0; filterIndex < categoryItems.length; filterIndex += 1) {
            if (categoryItems[filterIndex].slug === discoverCategory) {
                return categoryItems[filterIndex].name;
            }
        }
        return "";
    }

    function renderDiscover() {
        var discoverState = currentState.discover || {};
        var remotePackages = discoverState.packages || [];
        var packageCards = [];
        var packageIndex;
        var pagination = "";
        var filtersContent = collectionsHtml();
        var selectionName = activeDiscoverFilterName();
        var summarySuffix = selectionName ? " in " + Common.escapeHtml(selectionName) : "";
        var discoverContent;
        updateDiscoverToolsState();
        if (!discoverState.available) {
            discoverContent = filtersContent + "<div class='state-panel'><img class='state-icon' src='../../data/themes/manager/icons/cloud-off.svg' alt=''><h2>Catalog unavailable</h2>" +
                "<p>" + Common.escapeHtml(discoverState.message || "Load the catalog to browse packages.") + "</p><button class='button' type='button' data-action='catalog-retry'>" + icon("refresh-cw") + "Retry</button></div>";
            Common.byId("discoverPage").innerHTML = discoverLayoutHtml(discoverContent);
            return;
        }
        for (packageIndex = 0; packageIndex < remotePackages.length; packageIndex += 1) {
            packageCards.push(remotePackageCard(remotePackages[packageIndex]));
        }
        if (discoverState.totalPages > 1) {
            pagination = "<div class='catalog-pagination'>" +
                "<button class='button' type='button' data-action='discover-page' data-page='" + (discoverState.page - 1) + "'" + (discoverState.page <= 1 ? " disabled='disabled'" : "") + ">" + icon("arrow-left") + "Previous</button>" +
                "<span>Page " + discoverState.page + " of " + discoverState.totalPages + "</span>" +
                "<button class='button' type='button' data-action='discover-page' data-page='" + (discoverState.page + 1) + "'" + (discoverState.page >= discoverState.totalPages ? " disabled='disabled'" : "") + ">Next</button></div>";
        }
        discoverContent = filtersContent + (packageCards.length ? "<div class='catalog-summary'>" + discoverState.total + " packages" + summarySuffix + "</div><div class='card-grid'>" + packageCards.join("") + "</div>" + pagination :
            "<div class='state-panel'><img class='state-icon' src='../../data/themes/manager/icons/search.svg' alt=''><h2>No packages found</h2><p>" + (selectionName ? "This filter has no compatible packages." : "Try a different search phrase.") + "</p></div>");
        Common.byId("discoverPage").innerHTML = discoverLayoutHtml(discoverContent);
    }

    function remotePackageCard(packageInfo) {
        var purchaseBadge = purchaseIndicator(packageInfo, true);
        var resolvedPackage = findPackage(packageInfo.guid);
        var installAction = "<a class='button button-primary' href='maxpkg://manager/install/" + Common.encode(packageInfo.guid) + "' data-busy='Installing package...'>" + icon("download") + "Install</a>";
        var toolbarIndicator = "";
        if (resolvedPackage && !resolvedPackage.isRemote) {
            installAction = "<button class='button' type='button' disabled='disabled'>" + icon("check") + "Installed</button>";
            toolbarIndicator = toolbarHiddenIndicator(resolvedPackage);
        }
        return "<div class='card card-full' data-package-guid='" + Common.escapeHtml(packageInfo.guid) + "'>" +
            "<div class='card-content clearfix'>" +
                "<button class='package-summary clearfix' type='button' data-action='details' data-guid='" + Common.escapeHtml(packageInfo.guid) + "' title='Open package details'>" +
                    packageIcon(packageInfo, "package-icon", true) +
                    "<span class='package-heading'><span class='package-title ellipsis'>" + Common.escapeHtml(packageInfo.name) + "</span>" +
                    "<span class='package-meta ellipsis'>" + toolbarIndicator + "v" + Common.escapeHtml(packageInfo.version) + " &middot; " + Common.escapeHtml(packageInfo.developer || "Unknown developer") + "</span></span>" +
                "</button>" +
                packageDescriptionHtml(packageInfo.description) +
                "<div class='catalog-card-meta clearfix'><span class='catalog-card-stats'>" + discoverPackageStats(packageInfo) + "</span><span class='catalog-card-purchase'>" + purchaseBadge + "</span></div>" +
            "</div>" +
            "<div class='card-actions'>" + installAction + "</div>" +
        "</div>";
    }

    function requestDiscover() {
        resetDiscoverSelection();
        discoverCategory = "";
        discoverSort = "popular";
        Common.byId("busyMessage").innerHTML = "Loading Discover...";
        Common.removeClass(Common.byId("busyShade"), "is-hidden");
        window.location.href = "maxpkg://manager/discover?query=" + Common.encode(searchText);
    }


    function requestCatalog(pageNumber) {
        var normalizedPage = pageNumber > 0 ? pageNumber : 1;
        var selectionQuery = "";
        if (activeDiscoverKind === "featured") {
            selectionQuery = "&featured=true";
        } else if (activeDiscoverKind === "collection" && activeCollectionSlug) {
            selectionQuery = "&collection=" + Common.encode(activeCollectionSlug);
        }
        Common.byId("busyMessage").innerHTML = "Loading package catalog...";
        Common.removeClass(Common.byId("busyShade"), "is-hidden");
        window.location.href = "maxpkg://manager/catalog?query=" + Common.encode(searchText) + "&category=" + Common.encode(discoverCategory) + "&sort=" + Common.encode(discoverSort) + "&page=" + normalizedPage + "&pageSize=24" + selectionQuery;
    }

    function detailRow(rowLabel, fieldContent, cssClass) {
        if (!fieldContent) {
            return "";
        }
        return "<tr><th>" + Common.escapeHtml(rowLabel) + "</th><td" + (cssClass ? " class='" + cssClass + "'" : "") + ">" + Common.escapeHtml(fieldContent) + "</td></tr>";
    }

    function detailPackageIdRow(packageInfo) {
        var packageId = packageInfo.slug || packageInfo.guid || "";
        if (!packageId) {
            return "";
        }
        return "<tr><th>Package ID</th><td class='details-package-id-cell'>" +
            "<a class='icon-button details-package-id-copy' href='maxpkg://manager/copy-package-id/" + Common.encode(packageId) + "' title='Copy Package ID'>" + icon("copy") + "</a>" +
            "<span class='details-package-id-text' title='" + Common.escapeHtml(packageId) + "'>" + Common.escapeHtml(packageId) + "</span>" +
        "</td></tr>";
    }

    function compatibilityLabel(packageInfo) {
        if (packageInfo.minimumMaxVersion) {
            return packageInfo.minimumMaxVersion + " and newer";
        }
        return "Any version";
    }

    function packageLinkButton(packageInfo, linkKind, buttonLabel) {
        var packageUrl = linkKind === "maxpkg" ? packageInfo.packagePageUrl : packageInfo[linkKind + "Url"];
        if (!packageUrl) {
            return "";
        }
        return "<a class='button' href='maxpkg://manager/package-link/" + Common.encode(packageInfo.guid) + "?kind=" + Common.encode(linkKind) + "'>" + icon("external-link") + Common.escapeHtml(buttonLabel) + "</a>";
    }

    function packageCopyLinkButton(packageInfo) {
        if (!packageInfo.packagePageUrl) {
            return "";
        }
        return "<a class='icon-button' href='maxpkg://manager/copy-package-link/" + Common.encode(packageInfo.slug) + "' title='Copy MaxPkg link'>" + icon("copy") + "</a>";
    }

    function changelogBadgeClass(changeType) {
        var normalizedChangeType = String(changeType || "").toLowerCase();
        if (normalizedChangeType === "added" ||
                normalizedChangeType === "fixed" ||
                normalizedChangeType === "improved" ||
                normalizedChangeType === "changed" ||
                normalizedChangeType === "removed") {
            return "changelog-badge-" + normalizedChangeType;
        }
        return "changelog-badge-default";
    }

    function changelogHtml(packageInfo) {
        var changelogEntries = packageInfo.changelogEntries || [];
        var changelogGroups = [];
        var changelogIndex;
        var changelogEntry;
        var changeType;
        var versionContent;
        var releaseDateContent;
        var groupKey;
        var currentGroup;
        var groupIndex;
        var groupMarkup = [];
        var dateMarkup;
        for (changelogIndex = 0; changelogIndex < changelogEntries.length; changelogIndex += 1) {
            changelogEntry = changelogEntries[changelogIndex];
            changeType = changelogEntry.changeType || "Changed";
            versionContent = changelogEntry.versionContent || packageInfo.version || "Unknown";
            releaseDateContent = changelogEntry.releaseDateContent || packageInfo.releaseDate || "";
            groupKey = versionContent + "|" + releaseDateContent;
            currentGroup = changelogGroups.length ? changelogGroups[changelogGroups.length - 1] : null;
            if (!currentGroup || currentGroup.groupKey !== groupKey) {
                currentGroup = {
                    groupKey: groupKey,
                    versionContent: versionContent,
                    releaseDateContent: releaseDateContent,
                    items: []
                };
                changelogGroups.push(currentGroup);
            }
            currentGroup.items.push("<li><span class='badge changelog-badge " + changelogBadgeClass(changeType) + "'>" + Common.escapeHtml(changeType) + "</span><span>" + Common.escapeHtml(changelogEntry.messageContent) + "</span></li>");
        }
        if (!changelogGroups.length) {
            return "<div class='details-section'><h3>Full changelog</h3><p class='text-muted'>No changelog entries were provided with this package.</p></div>";
        }
        for (groupIndex = 0; groupIndex < changelogGroups.length; groupIndex += 1) {
            currentGroup = changelogGroups[groupIndex];
            dateMarkup = currentGroup.releaseDateContent ? "<span class='changelog-version-date'>" + Common.escapeHtml(currentGroup.releaseDateContent) + "</span>" : "";
            groupMarkup.push("<div class='changelog-version-group'>" +
                "<div class='changelog-version-header'><strong>" + Common.escapeHtml(currentGroup.versionContent) + "</strong>" + dateMarkup + "</div>" +
                "<ul class='changelog-list'>" + currentGroup.items.join("") + "</ul></div>");
        }
        return "<div class='details-section changelog-section'><h3>Full changelog</h3>" + groupMarkup.join("") + "</div>";
    }

    function normalizedFullDescription(sourceContent) {
        var normalizedContent = String(sourceContent || "");
        normalizedContent = normalizedContent.replace(/\\r\\n/g, "\n");
        normalizedContent = normalizedContent.replace(/\\n/g, "\n");
        normalizedContent = normalizedContent.replace(/\r\n/g, "\n");
        normalizedContent = normalizedContent.replace(/\r/g, "\n");
        return normalizedContent.replace(/^\s+|\s+$/g, "");
    }

    function markdownInlineTextHtml(sourceContent) {
        var escapedContent = Common.escapeHtml(sourceContent);
        escapedContent = escapedContent.replace(/`([^`]+)`/g, "<code>$1</code>");
        escapedContent = escapedContent.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
        escapedContent = escapedContent.replace(/__([^_]+)__/g, "<strong>$1</strong>");
        escapedContent = escapedContent.replace(/\*([^*]+)\*/g, "<em>$1</em>");
        escapedContent = escapedContent.replace(/_([^_]+)_/g, "<em>$1</em>");
        return escapedContent;
    }

    function markdownInlineHtml(sourceContent) {
        var rawContent = String(sourceContent || "");
        var linkExpression = /\[([^\]]+)\]\(([^)]+)\)/g;
        var outputParts = [];
        var lastIndex = 0;
        var linkMatch;
        var linkUrl;
        var linkLabel;

        while ((linkMatch = linkExpression.exec(rawContent)) !== null) {
            outputParts.push(markdownInlineTextHtml(rawContent.substring(lastIndex, linkMatch.index)));
            linkUrl = safeHttpUrl(linkMatch[2]);
            linkLabel = markdownInlineTextHtml(linkMatch[1]);
            if (linkUrl) {
                outputParts.push("<a href='" + Common.escapeHtml(linkUrl) + "' target='_blank'>" + linkLabel + "</a>");
            } else {
                outputParts.push(markdownInlineTextHtml(linkMatch[0]));
            }
            lastIndex = linkMatch.index + linkMatch[0].length;
        }

        outputParts.push(markdownInlineTextHtml(rawContent.substring(lastIndex)));
        return outputParts.join("");
    }

    function markdownListHtml(listLines, isOrderedList) {
        var listItems = [];
        var lineIndex;
        var lineContent;
        var tagName = isOrderedList ? "ol" : "ul";

        for (lineIndex = 0; lineIndex < listLines.length; lineIndex += 1) {
            lineContent = listLines[lineIndex].replace(/^\s*(?:[-*+]|\d+\.)\s+/, "");
            listItems.push("<li>" + markdownInlineHtml(lineContent) + "</li>");
        }
        return "<" + tagName + ">" + listItems.join("") + "</" + tagName + ">";
    }

    function markdownParagraphHtml(paragraphLines) {
        if (!paragraphLines.length) {
            return "";
        }
        return "<p>" + markdownInlineHtml(paragraphLines.join("\n")).replace(/\n/g, "<br>") + "</p>";
    }

    function fullDescriptionContentHtml(sourceContent) {
        var normalizedContent = normalizedFullDescription(sourceContent);
        var lines = normalizedContent ? normalizedContent.split("\n") : [];
        var outputItems = [];
        var paragraphLines = [];
        var lineIndex = 0;
        var lineContent;
        var trimmedLine;
        var headingMatch;
        var headingLevel;
        var listLines;
        var quoteLines;
        var codeLines;
        var isOrderedList;

        while (lineIndex < lines.length) {
            lineContent = lines[lineIndex];
            trimmedLine = lineContent.replace(/^\s+|\s+$/g, "");

            if (!trimmedLine) {
                outputItems.push(markdownParagraphHtml(paragraphLines));
                paragraphLines = [];
                lineIndex += 1;
                continue;
            }

            if (/^```/.test(trimmedLine)) {
                outputItems.push(markdownParagraphHtml(paragraphLines));
                paragraphLines = [];
                codeLines = [];
                lineIndex += 1;
                while (lineIndex < lines.length && !(/^```/.test(lines[lineIndex].replace(/^\s+|\s+$/g, "")))) {
                    codeLines.push(lines[lineIndex]);
                    lineIndex += 1;
                }
                if (lineIndex < lines.length) {
                    lineIndex += 1;
                }
                outputItems.push("<pre><code>" + Common.escapeHtml(codeLines.join("\n")) + "</code></pre>");
                continue;
            }

            headingMatch = /^(#{1,4})\s+(.+)$/.exec(trimmedLine);
            if (headingMatch) {
                outputItems.push(markdownParagraphHtml(paragraphLines));
                paragraphLines = [];
                headingLevel = headingMatch[1].length + 2;
                outputItems.push("<h" + headingLevel + ">" + markdownInlineHtml(headingMatch[2]) + "</h" + headingLevel + ">");
                lineIndex += 1;
                continue;
            }

            if (/^>\s*/.test(trimmedLine)) {
                outputItems.push(markdownParagraphHtml(paragraphLines));
                paragraphLines = [];
                quoteLines = [];
                while (lineIndex < lines.length && /^>\s*/.test(lines[lineIndex].replace(/^\s+|\s+$/g, ""))) {
                    quoteLines.push(lines[lineIndex].replace(/^\s*>\s*/, ""));
                    lineIndex += 1;
                }
                outputItems.push("<blockquote>" + markdownParagraphHtml(quoteLines) + "</blockquote>");
                continue;
            }

            if (/^\s*(?:[-*+]|\d+\.)\s+/.test(lineContent)) {
                outputItems.push(markdownParagraphHtml(paragraphLines));
                paragraphLines = [];
                isOrderedList = /^\s*\d+\.\s+/.test(lineContent);
                listLines = [];
                while (lineIndex < lines.length && (/^\s*(?:[-*+]|\d+\.)\s+/.test(lines[lineIndex])) && (/^\s*\d+\.\s+/.test(lines[lineIndex]) === isOrderedList)) {
                    listLines.push(lines[lineIndex]);
                    lineIndex += 1;
                }
                outputItems.push(markdownListHtml(listLines, isOrderedList));
                continue;
            }

            paragraphLines.push(lineContent);
            lineIndex += 1;
        }
        outputItems.push(markdownParagraphHtml(paragraphLines));
        return outputItems.join("");
    }

    function fullDescriptionHtml(packageInfo) {
        var fullDescriptionContent = packageInfo.fullDescription || "";
        var descriptionMarkup = fullDescriptionContentHtml(fullDescriptionContent);
        if (!descriptionMarkup) {
            descriptionMarkup = "<p>" + Common.escapeHtml(packageInfo.description || "No description provided.") + "</p>";
        }
        return "<div class='details-section full-description-section'><h3>Description</h3><div class='full-description-content'>" + descriptionMarkup + "</div></div>";
    }

    function validScreenshots(packageInfo) {
        var screenshots = packageInfo.screenshots || [];
        var validItems = [];
        var screenshotIndex;
        var screenshotInfo;
        var fullImageUrl;
        var thumbnailUrl;

        for (screenshotIndex = 0; screenshotIndex < screenshots.length; screenshotIndex += 1) {
            screenshotInfo = screenshots[screenshotIndex] || {};
            fullImageUrl = safeImageUrl(screenshotInfo.url);
            thumbnailUrl = safeThumbnailImageUrl(screenshotInfo.thumbnailUrl, fullImageUrl);
            if (fullImageUrl && thumbnailUrl) {
                validItems.push({
                    url: fullImageUrl,
                    thumbnailUrl: thumbnailUrl,
                    title: screenshotInfo.title || ("Screenshot " + (screenshotIndex + 1)),
                    caption: screenshotInfo.caption || ""
                });
            }
        }

        return validItems;
    }

    function screenshotGalleryHtml(packageInfo) {
        var screenshots = validScreenshots(packageInfo);
        var galleryItems = [];
        var screenshotIndex;
        var screenshotInfo;
        var activeScreenshot;
        var previousIndex;
        var nextIndex;

        for (screenshotIndex = 0; screenshotIndex < screenshots.length; screenshotIndex += 1) {
            screenshotInfo = screenshots[screenshotIndex];
            galleryItems.push("<button class='screenshot-thumb" + (screenshotIndex === activeScreenshotIndex ? " is-active" : "") + "' type='button' data-action='select-screenshot' data-screenshot-index='" + screenshotIndex + "'>" +
                "<img src='" + Common.escapeHtml(screenshotInfo.thumbnailUrl) + "' alt='" + Common.escapeHtml(screenshotInfo.title) + "'>" +
                "<span>" + Common.escapeHtml(screenshotInfo.title) + "</span>" +
            "</button>");
        }

        if (!galleryItems.length) {
            return "<div class='details-section'><h3>Screenshots</h3><p class='text-muted'>No screenshots available.</p></div>";
        }

        if (activeScreenshotIndex < 0 || activeScreenshotIndex >= screenshots.length) {
            activeScreenshotIndex = 0;
        }
        activeScreenshot = screenshots[activeScreenshotIndex];
        previousIndex = activeScreenshotIndex <= 0 ? screenshots.length - 1 : activeScreenshotIndex - 1;
        nextIndex = activeScreenshotIndex >= screenshots.length - 1 ? 0 : activeScreenshotIndex + 1;

        return "<div class='details-section screenshot-section'><h3>Screenshots</h3>" +
            "<div class='screenshot-viewer'>" +
                "<button class='screenshot-nav screenshot-nav-left' type='button' data-action='select-screenshot' data-screenshot-index='" + previousIndex + "' title='Previous screenshot'>" + icon("gallery-chevron-left") + "</button>" +
                "<button class='screenshot-main' type='button' data-action='screenshot-preview' data-image-url='" + Common.escapeHtml(activeScreenshot.url) + "' data-title='" + Common.escapeHtml(activeScreenshot.title) + "' data-caption='" + Common.escapeHtml(activeScreenshot.caption) + "'>" +
                    "<img src='" + Common.escapeHtml(activeScreenshot.url) + "' alt='" + Common.escapeHtml(activeScreenshot.title) + "'>" +
                "</button>" +
                "<button class='screenshot-nav screenshot-nav-right' type='button' data-action='select-screenshot' data-screenshot-index='" + nextIndex + "' title='Next screenshot'>" + icon("gallery-chevron-right") + "</button>" +
            "</div>" +
            "<div class='screenshot-viewer-copy'><h3>" + Common.escapeHtml(activeScreenshot.title) + "</h3>" +
            (activeScreenshot.caption ? "<p>" + Common.escapeHtml(activeScreenshot.caption) + "</p>" : "") + "</div>" +
            "<div class='screenshot-gallery'>" + galleryItems.join("") + "</div></div>";
    }

    function closeScreenshotPreview() {
        var previewElement = Common.byId("screenshotPreview");
        if (previewElement) {
            previewElement.parentNode.removeChild(previewElement);
        }
    }

    function showScreenshotPreview() {
        var packageInfo = findPackage(detailsGuid);
        var screenshots = packageInfo ? validScreenshots(packageInfo) : [];
        var activeScreenshot;
        var previousIndex;
        var nextIndex;
        if (!screenshots.length) {
            return false;
        }
        if (activeScreenshotIndex < 0 || activeScreenshotIndex >= screenshots.length) {
            activeScreenshotIndex = 0;
        }
        activeScreenshot = screenshots[activeScreenshotIndex];
        previousIndex = activeScreenshotIndex <= 0 ? screenshots.length - 1 : activeScreenshotIndex - 1;
        nextIndex = activeScreenshotIndex >= screenshots.length - 1 ? 0 : activeScreenshotIndex + 1;
        closeScreenshotPreview();
        document.body.insertAdjacentHTML("beforeend", "<div id='screenshotPreview' class='screenshot-preview'>" +
            "<div class='screenshot-preview-dialog'>" +
                "<button class='screenshot-preview-close' type='button' data-action='close-screenshot-preview' title='Close preview'>" + icon("x") + "</button>" +
                "<button class='screenshot-preview-nav screenshot-preview-nav-left' type='button' data-action='select-screenshot' data-screenshot-index='" + previousIndex + "' title='Previous screenshot'>" + icon("gallery-chevron-left") + "</button>" +
                "<div class='screenshot-preview-image-wrap'><img src='" + Common.escapeHtml(activeScreenshot.url) + "' alt='" + Common.escapeHtml(activeScreenshot.title) + "'></div>" +
                "<button class='screenshot-preview-nav screenshot-preview-nav-right' type='button' data-action='select-screenshot' data-screenshot-index='" + nextIndex + "' title='Next screenshot'>" + icon("gallery-chevron-right") + "</button>" +
                "<div class='screenshot-preview-copy'><h3>" + Common.escapeHtml(activeScreenshot.title) + "</h3>" +
                (activeScreenshot.caption ? "<p>" + Common.escapeHtml(activeScreenshot.caption) + "</p>" : "") + "</div>" +
            "</div>" +
        "</div>");
        return true;
    }

    function showDetailsTab(tabName) {
        var normalizedTabName = tabName === "screenshots" || tabName === "changelog" ? tabName : "description";
        var detailsPage = Common.byId("detailsPage");
        var tabButtons = detailsPage.getElementsByTagName("button");
        var tabPanels = detailsPage.getElementsByTagName("div");
        var elementIndex;
        detailsTab = normalizedTabName;
        for (elementIndex = 0; elementIndex < tabButtons.length; elementIndex += 1) {
            if (tabButtons[elementIndex].getAttribute("data-details-tab") !== null) {
                Common.toggleClass(tabButtons[elementIndex], "is-active", tabButtons[elementIndex].getAttribute("data-details-tab") === detailsTab);
            }
        }
        for (elementIndex = 0; elementIndex < tabPanels.length; elementIndex += 1) {
            if (tabPanels[elementIndex].getAttribute("data-details-panel") !== null) {
                Common.toggleClass(tabPanels[elementIndex], "is-hidden", tabPanels[elementIndex].getAttribute("data-details-panel") !== detailsTab);
            }
        }
    }

    function renderDetails() {
        var packageInfo = findPackage(detailsGuid);
        var compatibilityText;
        var packagerText;
        var sidebarRows;
        var linkButtons;
        var releaseBadges;
        var updateButton;
        var actionMarkup;
        var openFolderButton;
        var linksSection;
        var changelogCount;
        var screenshotCount;
        var integrationText;
        if (!packageInfo) {
            showTab(activeTab);
            return;
        }
        compatibilityText = compatibilityLabel(packageInfo);
        packagerText = packageInfo.packagerName ? packageInfo.packagerName + (packageInfo.packagerVersion ? " " + packageInfo.packagerVersion : "") : "";
        integrationText = packageInfo.toolbarVisible ? "Toolbar" : (packageInfo.isRemote ? "Package" : "Hidden");
        sidebarRows = detailPackageIdRow(packageInfo) +
            detailRow("Version", packageInfo.version, "details-mono-value") +
            detailRow("Release date", packageInfo.releaseDate, "details-mono-value") +
            detailRow("3ds Max", compatibilityText, "details-mono-value") +
            detailRow("Author", packageInfo.developer, "details-mono-value") +
            detailRow("Type", packageInfo.runtime, "details-mono-value") +
            detailRow("Channel", packageInfo.releaseChannel, "details-mono-value") +
            detailRow("License", packageInfo.licenseType, "details-mono-value") +
            detailRow("Integration", integrationText, "details-mono-value") +
            detailRow("Packager", packagerText, "details-mono-value");
        linkButtons = packageCopyLinkButton(packageInfo) +
            packageLinkButton(packageInfo, "maxpkg", "MaxPkg page") +
            packageLinkButton(packageInfo, "homepage", "Homepage") +
            packageLinkButton(packageInfo, "documentation", "Documentation") +
            packageLinkButton(packageInfo, "support", "Support") +
            packageLinkButton(packageInfo, "license", "License");
        releaseBadges = packageInfo.runtime ? "<span class='badge'>" + Common.escapeHtml(packageInfo.runtime) + "</span>" : "";
        if (packageInfo.releaseChannel) {
            releaseBadges += "<span class='badge'>" + Common.escapeHtml(packageInfo.releaseChannel) + "</span>";
        }
        if (packageInfo.licenseType) {
            releaseBadges += "<span class='badge badge-warning'>" + Common.escapeHtml(packageInfo.licenseType) + "</span>";
        }
        if (packageInfo.toolbarVisible) {
            releaseBadges += "<span class='badge'>Toolbar</span>";
        }
        if (packageInfo.detailsLoaded) {
            releaseBadges += "<span class='badge' title='Showing current package information from maxpkg.dev'>Online info</span>";
        } else if (!packageInfo.isRemote) {
            releaseBadges += "<span class='badge badge-warning' title='Showing package information from local manifest.ini'>Offline info</span>";
        }
        updateButton = packageInfo.updateAvailable ? "<a class='button details-action-button' href='maxpkg://manager/update/" + Common.encode(packageInfo.guid) + "' data-busy='Updating package...'>" + icon("download") + "Update to " + Common.escapeHtml(packageInfo.latestVersion) + "</a>" : "";
        actionMarkup = packageInfo.isRemote ?
            "<a class='button button-primary details-action-button' href='maxpkg://manager/install/" + Common.encode(packageInfo.guid) + "' data-busy='Installing package...'>" + icon("download") + "Install</a>" :
            "<a class='button button-primary details-action-button' href='maxpkg://manager/run/" + Common.encode(packageInfo.guid) + "' data-busy='Starting package...'>" + icon("play") + "Run</a>" +
            updateButton + "<a class='button button-danger details-action-button details-uninstall-button' href='maxpkg://manager/uninstall/" + Common.encode(packageInfo.guid) + "' data-busy='Uninstalling package...'>" + icon("trash-2") + "Uninstall</a>";
        openFolderButton = packageInfo.isRemote ? "" :
            "<a class='button' href='maxpkg://manager/open-folder/" + Common.encode(packageInfo.guid) + "'>" + icon("folder-open") + "Open Folder</a>";
        linksSection = linkButtons || openFolderButton ? "<div class='details-section details-links-section'><h3>Links</h3><div class='details-link-actions'>" + linkButtons + openFolderButton + "</div></div>" : "";
        changelogCount = (packageInfo.changelogEntries || []).length;
        screenshotCount = validScreenshots(packageInfo).length;
        if (screenshotCount < 1 && detailsTab === "screenshots") {
            detailsTab = "description";
        }
        Common.byId("detailsPathName").innerHTML = Common.escapeHtml(packageInfo.name);
        Common.byId("detailsPathRoot").innerHTML = packageInfo.isRemote ? "Discover" : "Installed";
        Common.byId("detailsPage").innerHTML = "<div class='details-layout'>" +
            "<div class='details-main'>" +
                "<div class='details-hero clearfix'>" + packageIcon(packageInfo, "details-icon", false) +
                    "<div class='details-copy'><h1>" + Common.escapeHtml(packageInfo.name) + "</h1><p>Version " + Common.escapeHtml(packageInfo.version) + " by " + Common.escapeHtml(packageInfo.developer || "Unknown developer") + "</p><div class='details-badges'>" + releaseBadges + "</div></div>" +
                    "<div class='details-hero-actions'>" + actionMarkup + "</div>" +
                "</div>" +
                purchaseNotice(packageInfo) +
                "<div class='details-tabs' role='tablist'><button class='details-tab' type='button' data-action='details-tab' data-details-tab='description'>Description</button>" +
                    (screenshotCount > 0 ? "<button class='details-tab' type='button' data-action='details-tab' data-details-tab='screenshots'>Screenshots<span class='details-tab-count'>" + screenshotCount + "</span></button>" : "") +
                    "<button class='details-tab' type='button' data-action='details-tab' data-details-tab='changelog'>Changelog<span class='details-tab-count'>" + changelogCount + "</span></button></div>" +
                "<div class='details-tab-panel is-hidden' data-details-panel='description'>" + fullDescriptionHtml(packageInfo) + linksSection + "</div>" +
                (screenshotCount > 0 ? "<div class='details-tab-panel is-hidden' data-details-panel='screenshots'>" + screenshotGalleryHtml(packageInfo) + "</div>" : "") +
                "<div class='details-tab-panel is-hidden' data-details-panel='changelog'>" + changelogHtml(packageInfo) + "</div>" +
            "</div>" +
            "<div class='details-sidebar'><div class='details-section details-package-info'><h3>Package information</h3><table class='table details-summary-table'>" + sidebarRows + "</table></div></div>" +
        "</div>";
        showDetailsTab(detailsTab);
    }

    function renderStatus() {
        var packageLabel = currentState.packages.length === 1 ? " package" : " packages";
        var updateLabel = currentState.updateCount === 1 ? " update" : " updates";
        Common.byId("runtimeVersion").innerHTML = "Runtime " + Common.escapeHtml(currentState.runtimeVersion);
        Common.byId("footerVersion").innerHTML = "Runtime " + Common.escapeHtml(currentState.runtimeVersion);
        Common.byId("aboutVersion").innerHTML = "MaxPkg Runtime " + Common.escapeHtml(currentState.runtimeVersion);
        Common.byId("installedTabCount").innerHTML = currentState.packages.length;
        Common.byId("updatesTabCount").innerHTML = currentState.updateCount;
        Common.byId("packageStatus").innerHTML = currentState.packages.length + packageLabel;
        Common.byId("updateStatus").innerHTML = currentState.updateCount + updateLabel;
        var connectionStatus = Common.byId("connectionStatus");
        var isCurlConnection = currentState.connection === "online-curl";
        connectionStatus.innerHTML = isCurlConnection ? "Online (CURL, slow)" : (currentState.connection === "online" ? "Online" : (currentState.connection === "configured" ? "Endpoint configured" : "Offline"));
        connectionStatus.className = "connection-status " + (currentState.connection === "online" || isCurlConnection ? "text-success" : "text-warning") + (isCurlConnection ? " connection-status-curl" : "");
        if (isCurlConnection) {
            connectionStatus.setAttribute("data-tooltip", "3ds Max could not connect through .NET, usually because its network access is blocked by a firewall. MaxPkg is using CURL as a workaround. CURL runs as a separate process, so network actions may be slower.");
            connectionStatus.setAttribute("tabindex", "0");
        } else {
            connectionStatus.removeAttribute("data-tooltip");
            connectionStatus.removeAttribute("tabindex");
        }
        Common.toggleClass(Common.byId("updateAllButton"), "is-hidden", currentState.updateCount < 1);
    }

    function updateInstalledToolsState() {
        var hasActiveFilter = toolbarVisibilityFilter !== "all";
        var hasCustomSort = activeSort !== "toolbar";
        window.MaxPkgDropdown.setSelectValue(Common.byId("toolbarFilterSelect"), toolbarVisibilityFilter);
        window.MaxPkgDropdown.setSelectValue(Common.byId("sortSelect"), activeSort);
        Common.toggleClass(Common.byId("toolbarFilterControl"), "has-active-filter", hasActiveFilter);
        Common.toggleClass(Common.byId("clearToolbarFilterButton"), "is-hidden", !hasActiveFilter);
        Common.toggleClass(Common.byId("sortControl"), "has-custom-sort", hasCustomSort);
        Common.toggleClass(Common.byId("clearSortButton"), "is-hidden", !hasCustomSort);
    }

    function showTab(tabName, filterName) {
        var viewName;
        activeTab = tabName === "discover" ? "discover" : "installed";
        if (activeTab === "installed" && filterName) {
            activeFilter = filterName === "updates" ? "updates" : "all";
        }
        if (activeFilter !== "updates") {
            activeFilter = "all";
        }
        viewName = activeViewName();
        detailsGuid = "";
        Common.toggleClass(Common.byId("discoverTab"), "is-active", viewName === "discover");
        Common.toggleClass(Common.byId("installedTab"), "is-active", viewName === "installed");
        Common.toggleClass(Common.byId("updatesTab"), "is-active", viewName === "updates");
        Common.toggleClass(Common.byId("installedPage"), "is-hidden", activeTab !== "installed");
        Common.toggleClass(Common.byId("discoverPage"), "is-hidden", activeTab !== "discover");
        Common.addClass(Common.byId("detailsPage"), "is-hidden");
        Common.toggleClass(Common.byId("discoverTools"), "is-hidden", activeTab !== "discover");
        Common.toggleClass(Common.byId("installedTools"), "is-hidden", activeTab !== "installed");
        Common.removeClass(Common.byId("pageToolbar"), "is-hidden");
        Common.addClass(Common.byId("detailsNavigation"), "is-hidden");
        updateInstalledToolsState();
        updateSearchPlaceholder();

    }

    function showDetails(packageGuid) {
        if (!detailsGuid) {
            detailsListScrollTop = Common.byId("pageHost").scrollTop;
        }
        if (detailsGuid !== packageGuid) {
            detailsTab = "description";
            activeScreenshotIndex = 0;
        }
        detailsGuid = packageGuid;
        Common.byId("busyMessage").innerHTML = "Loading package details...";
        Common.removeClass(Common.byId("busyShade"), "is-hidden");
        window.location.href = "maxpkg://manager/remote-details/" + Common.encode(packageGuid) + "?manifestFallback=" + boolText(activeTab === "installed");
        Common.addClass(Common.byId("installedPage"), "is-hidden");
        Common.addClass(Common.byId("discoverPage"), "is-hidden");
        Common.removeClass(Common.byId("detailsPage"), "is-hidden");
        Common.addClass(Common.byId("pageToolbar"), "is-hidden");
        Common.removeClass(Common.byId("detailsNavigation"), "is-hidden");
        renderDetails();
        Common.byId("pageHost").scrollTop = 0;
    }

    function hideDetails() {
        var restoredScrollTop = detailsListScrollTop;
        showTab(activeTab);
        Common.byId("pageHost").scrollTop = restoredScrollTop;
    }

    function renderAll() {
        renderInstalled();
        renderDiscover();
        renderStatus();
        if (detailsGuid) {
            renderDetails();
        } else {
            showTab(activeTab);
        }
        Common.addClass(Common.byId("busyShade"), "is-hidden");
    }

    function readRuntimeState() {
        var payloadElement = Common.byId("runtimePayload");
        var sourceText = payloadElement.innerText || payloadElement.textContent || "";
        try {
            currentState = JSON.parse(sourceText);
            readDiscoverSelection();
            activeTab = currentState.settings.managerLastTab || activeTab;
            readManagerFilter(currentState.settings.managerFilter || "all");
            activeSort = currentState.settings.managerSort || activeSort;
            window.MaxPkgDropdown.setSelectValue(Common.byId("sortSelect"), activeSort);
            renderAll();
            if (activeTab === "discover" && (!(currentState.collections || {}).loaded || !(currentState.categories || {}).loaded || (!currentState.discover.available && !currentState.discover.errorCode))) {
                requestDiscover();
            }
        } catch (parseError) {
            showNotification("Manager could not read Runtime state.", "error");
            Common.addClass(Common.byId("busyShade"), "is-hidden");
        }
    }

    function showNotification(messageText, notificationType) {
        var notificationElement = document.createElement("div");
        var normalizedNotificationType = notificationType;
        var notificationIcon = "i";
        if (normalizedNotificationType !== "success" && normalizedNotificationType !== "info" && normalizedNotificationType !== "warning" && normalizedNotificationType !== "error") {
            normalizedNotificationType = "info";
        }
        if (normalizedNotificationType === "success") {
            notificationIcon = "<img class='notification-icon-image' src='../../data/themes/manager/icons/circle-check.svg' alt=''>";
        } else if (normalizedNotificationType === "warning") {
            notificationIcon = "!";
        } else if (normalizedNotificationType === "error") {
            notificationIcon = "<img class='notification-icon-image' src='../../data/themes/manager/icons/circle-x.svg' alt=''>";
        }
        notificationElement.className = "notification notification-" + normalizedNotificationType;
        notificationElement.innerHTML = "<span class='notification-icon'>" + notificationIcon + "</span><span class='notification-message'>" + Common.escapeHtml(messageText) + "</span>";
        Common.byId("notificationHost").appendChild(notificationElement);
        window.setTimeout(function () {
            if (notificationElement.parentNode) {
                notificationElement.parentNode.removeChild(notificationElement);
            }
        }, 3500);
    }

    function readRuntimeNotification() {
        var payloadElement = Common.byId("notificationPayload");
        var sourceText = payloadElement.innerText || payloadElement.textContent || "";
        var separatorIndex = sourceText.indexOf("|");
        var notificationType = separatorIndex >= 0 ? sourceText.substring(0, separatorIndex) : "info";
        var messageText = separatorIndex >= 0 ? sourceText.substring(separatorIndex + 1) : sourceText;
        showNotification(messageText, notificationType);
    }

    function openPackageMenu(sourceButton, packageGuid) {
        var packageInfo = findPackage(packageGuid);
        var developerModeEnabled = !!currentState.settings.developerMode;
        var toolbarLabel;
        var menuHtml;
        if (!packageInfo) {
            return;
        }
        toolbarLabel = packageInfo.toolbarVisible ? "Hide from Toolbar" : "Show in Toolbar";
        menuHtml = "<a href='maxpkg://manager/run/" + Common.encode(packageInfo.guid) + "' data-busy='Starting package...'>Run</a>";
        if (packageInfo.updateAvailable) {
            menuHtml += "<a href='maxpkg://manager/update/" + Common.encode(packageInfo.guid) + "' data-busy='Updating package...'>Update</a>";
        }
        menuHtml += "<button type='button' data-action='details' data-guid='" + Common.escapeHtml(packageInfo.guid) + "'>Details</button>";
        if (developerModeEnabled) {
            menuHtml += "<a href='maxpkg://manager/open-folder/" + Common.encode(packageInfo.guid) + "'>Open Folder</a>";
        }
        if (packageInfo.helpUrl) {
            menuHtml += "<a href='maxpkg://manager/help/" + Common.encode(packageInfo.guid) + "'>Help</a>";
        }
        menuHtml += "<a href='maxpkg://manager/toggle-package-toolbar/" + Common.encode(packageInfo.guid) + "'>" + toolbarLabel + "</a>";
        if (developerModeEnabled) {
            menuHtml += "<div class='context-separator'></div>" +
                "<button type='button' data-action='copy' data-copy='" + Common.escapeHtml(packageInfo.guid) + "'>Copy GUID</button>" +
                "<button type='button' data-action='copy' data-copy='" + Common.escapeHtml(packageInfo.installPath) + "'>Copy Path</button>";
        }
        menuHtml += "<div class='context-separator'></div>" +
            "<a class='context-danger' href='maxpkg://manager/uninstall/" + Common.encode(packageInfo.guid) + "' data-busy='Uninstalling package...'>" + icon("trash-2") + "Uninstall</a>";
        Common.byId("contextMenu").innerHTML = menuHtml;
        window.MaxPkgDropdown.open(Common.byId("contextMenu"), sourceButton);
    }

    function updateEndpointSettingsVisibility() {
        var developerModeEnabled = Common.byId("developerModeCheck").checked;
        Common.toggleClass(Common.byId("endpointSettingsNavigation"), "is-hidden", !developerModeEnabled);
        if (!developerModeEnabled && !Common.hasClass(Common.byId("endpointSettingsPanel"), "is-hidden")) {
            changeSettingsPage("developer");
        }
    }

    function populateThemeSelect(selectId, themeOptions, selectedThemeId) {
        var selectElement = Common.byId(selectId);
        var menuElements = selectElement.getElementsByTagName("div");
        var menuElement = menuElements.length > 0 ? menuElements[0] : null;
        var optionIndex;
        var optionButton;
        if (!menuElement) {
            return;
        }
        while (menuElement.firstChild) {
            menuElement.removeChild(menuElement.firstChild);
        }
        themeOptions = themeOptions || [];
        for (optionIndex = 0; optionIndex < themeOptions.length; optionIndex += 1) {
            optionButton = document.createElement("button");
            optionButton.type = "button";
            optionButton.setAttribute("data-dropdown-option", themeOptions[optionIndex].id);
            optionButton.appendChild(document.createTextNode(themeOptions[optionIndex].name));
            menuElement.appendChild(optionButton);
        }
        window.MaxPkgDropdown.setSelectValue(selectElement, selectedThemeId || "default");
    }

    function populateSettings() {
        var settings = currentState.settings;
        window.MaxPkgDropdown.setSelectValue(Common.byId("languageSelect"), settings.language || "English");
        populateThemeSelect("managerThemeSelect", settings.managerThemes, settings.managerTheme);
        populateThemeSelect("toolbarThemeSelect", settings.toolbarThemes, settings.toolbarTheme);
        window.MaxPkgDropdown.setSelectValue(Common.byId("frequencySelect"), String(settings.updateFrequencyHours || 24));
        Common.byId("autoStartCheck").checked = !!settings.autoStart;
        Common.byId("openManagerCheck").checked = !!settings.openManagerOnStartup;
        Common.byId("notificationsCheck").checked = !!settings.notifications;
        Common.byId("managerFullCardsCheck").checked = !!settings.managerFullCards;
        Common.byId("autoCheckPackagesCheck").checked = !!settings.autoCheckPackages;
        Common.byId("autoCheckRuntimeCheck").checked = !!settings.autoCheckRuntime;
        Common.byId("autoDownloadCheck").checked = !!settings.downloadUpdatesAutomatically;
        Common.byId("apiEndpointInput").value = settings.apiEndpoint || settings.defaultApiEndpoint || "";
        Common.byId("toolbarVisibleCheck").checked = !!settings.toolbarVisible;
        window.MaxPkgDropdown.setSelectValue(Common.byId("toolbarDockPositionSelect"), settings.toolbarDockPosition || "top");
        window.MaxPkgDropdown.setSelectValue(Common.byId("toolbarTitleSelect"), settings.toolbarTitleMode || "packageName");
        window.MaxPkgDropdown.setSelectValue(Common.byId("toolbarButtonSizeSelect"), settings.toolbarButtonSize || "medium");
        window.MaxPkgDropdown.setSelectValue(Common.byId("toolbarSubtitleSelect"), settings.toolbarSubtitleMode || "version");
        Common.byId("developerModeCheck").checked = !!settings.developerMode;
        Common.byId("debugLoggingCheck").checked = !!settings.debugLogging;
        updateEndpointSettingsVisibility();
    }

    function saveSettings() {
        var queryParts = [];
        var endpointInput;
        var endpointOverride;
        var endpointFallback;
        if (settingsSaveTimer !== null) {
            window.clearTimeout(settingsSaveTimer);
            settingsSaveTimer = null;
        }
        queryParts.push("language=" + Common.encode(window.MaxPkgDropdown.getSelectValue(Common.byId("languageSelect"))));
        queryParts.push("managerTheme=" + Common.encode(window.MaxPkgDropdown.getSelectValue(Common.byId("managerThemeSelect"))));
        queryParts.push("autoStart=" + boolText(Common.byId("autoStartCheck").checked));
        queryParts.push("openManagerOnStartup=" + boolText(Common.byId("openManagerCheck").checked));
        queryParts.push("notifications=" + boolText(Common.byId("notificationsCheck").checked));
        queryParts.push("managerFullCards=" + boolText(Common.byId("managerFullCardsCheck").checked));
        queryParts.push("autoCheckPackages=" + boolText(Common.byId("autoCheckPackagesCheck").checked));
        queryParts.push("autoCheckRuntime=" + boolText(Common.byId("autoCheckRuntimeCheck").checked));
        queryParts.push("downloadUpdatesAutomatically=" + boolText(Common.byId("autoDownloadCheck").checked));
        queryParts.push("updateFrequencyHours=" + Common.encode(window.MaxPkgDropdown.getSelectValue(Common.byId("frequencySelect"))));
        endpointInput = Common.byId("apiEndpointInput").value;
        endpointOverride = endpointInput;
        endpointFallback = currentState.settings.defaultApiEndpoint || "";
        if (!currentState.settings.apiEndpoint && endpointInput === endpointFallback) {
            endpointOverride = "";
        }
        queryParts.push("apiEndpoint=" + Common.encode(endpointOverride));
        queryParts.push("toolbarVisible=" + boolText(Common.byId("toolbarVisibleCheck").checked));
        queryParts.push("toolbarDockPosition=" + Common.encode(window.MaxPkgDropdown.getSelectValue(Common.byId("toolbarDockPositionSelect"))));
        queryParts.push("toolbarTheme=" + Common.encode(window.MaxPkgDropdown.getSelectValue(Common.byId("toolbarThemeSelect"))));
        queryParts.push("toolbarTitleMode=" + Common.encode(window.MaxPkgDropdown.getSelectValue(Common.byId("toolbarTitleSelect"))));
        queryParts.push("toolbarButtonSize=" + Common.encode(window.MaxPkgDropdown.getSelectValue(Common.byId("toolbarButtonSizeSelect"))));
        queryParts.push("toolbarSubtitleMode=" + Common.encode(window.MaxPkgDropdown.getSelectValue(Common.byId("toolbarSubtitleSelect"))));
        queryParts.push("developerMode=" + boolText(Common.byId("developerModeCheck").checked));
        queryParts.push("debugLogging=" + boolText(Common.byId("debugLoggingCheck").checked));
        queryParts.push("silent=true");
        window.location.href = "maxpkg://manager/save-settings?" + queryParts.join("&");
    }

    function scheduleSettingsSave() {
        if (settingsSaveTimer !== null) {
            window.clearTimeout(settingsSaveTimer);
        }
        settingsSaveTimer = window.setTimeout(saveSettings, 450);
    }

    function hideSettingsDialog() {
        if (settingsSaveTimer !== null) {
            saveSettings();
        }
        window.MaxPkgDropdown.close();
        window.MaxPkgDialog.close(Common.byId("settingsShade"));
    }

    function bindImmediateSettingsSave(elementId) {
        Common.on(Common.byId(elementId), "change", saveSettings);
    }

    function bindTextSettingsSave(elementId) {
        Common.on(Common.byId(elementId), "input", scheduleSettingsSave);
        Common.on(Common.byId(elementId), "keyup", scheduleSettingsSave);
        Common.on(Common.byId(elementId), "change", saveSettings);
    }

    function changeSettingsPage(pageName) {
        var navigationButtons = Common.byId("settingsNavigation").getElementsByTagName("button");
        var settingsPanels = document.getElementsByTagName("div");
        var elementIndex;
        for (elementIndex = 0; elementIndex < navigationButtons.length; elementIndex += 1) {
            Common.toggleClass(navigationButtons[elementIndex], "is-active", navigationButtons[elementIndex].getAttribute("data-settings-page") === pageName);
        }
        for (elementIndex = 0; elementIndex < settingsPanels.length; elementIndex += 1) {
            if (settingsPanels[elementIndex].getAttribute("data-settings-panel") !== null) {
                Common.toggleClass(settingsPanels[elementIndex], "is-hidden", settingsPanels[elementIndex].getAttribute("data-settings-panel") !== pageName);
            }
        }
    }

    function showRuntimeUninstallConfirmation(isVisible) {
        Common.toggleClass(Common.byId("showRuntimeUninstallConfirmationButton"), "is-hidden", isVisible);
        Common.toggleClass(Common.byId("runtimeUninstallConfirmation"), "is-hidden", !isVisible);
    }

    function handleDocumentClick(eventObject) {
        var sourceElement = Common.eventTarget(eventObject);
        var actionElement = Common.closestWithAttribute(sourceElement, "data-action");
        var tabElement = Common.closestWithAttribute(sourceElement, "data-tab");
        var settingsPageElement = Common.closestWithAttribute(sourceElement, "data-settings-page");
        var busyElement = Common.closestWithAttribute(sourceElement, "data-busy");
        var actionName;
        if (busyElement) {
            Common.byId("busyMessage").innerHTML = Common.escapeHtml(busyElement.getAttribute("data-busy"));
            Common.removeClass(Common.byId("busyShade"), "is-hidden");
        }
        if (tabElement) {
            showTab(tabElement.getAttribute("data-tab"), tabElement.getAttribute("data-filter"));
            if (activeTab === "discover") {
                if (!(currentState.collections || {}).loaded || !(currentState.categories || {}).loaded) {
                    requestDiscover();
                } else {
                    requestCatalog(1);
                }
            } else {
                renderInstalled();
                saveManagerView();
            }
            return;
        }
        if (settingsPageElement) {
            changeSettingsPage(settingsPageElement.getAttribute("data-settings-page"));
            return;
        }
        if (!actionElement) {
            return;
        }
        actionName = actionElement.getAttribute("data-action");
        if (actionName === "menu") {
            Common.preventDefault(eventObject);
            openPackageMenu(actionElement, actionElement.getAttribute("data-guid"));
        } else if (actionName === "details") {
            Common.preventDefault(eventObject);
            window.MaxPkgDropdown.close();
            showDetails(actionElement.getAttribute("data-guid"));
        } else if (actionName === "details-back") {
            Common.preventDefault(eventObject);
            hideDetails();
        } else if (actionName === "details-tab") {
            Common.preventDefault(eventObject);
            showDetailsTab(actionElement.getAttribute("data-details-tab"));
        } else if (actionName === "discover-collection") {
            Common.preventDefault(eventObject);
            var requestedKind = actionElement.getAttribute("data-kind") || "";
            var requestedSlug = actionElement.getAttribute("data-slug") || "";
            var isRequestedSelectionActive = (requestedKind === "all" && !activeDiscoverKind) || (activeDiscoverKind === requestedKind && (requestedKind !== "collection" || activeCollectionSlug === requestedSlug));
            if (isRequestedSelectionActive) {
                return;
            }
            if (requestedKind === "all") {
                resetDiscoverSelection();
            } else {
                activeDiscoverKind = requestedKind === "featured" ? "featured" : "collection";
                activeCollectionSlug = activeDiscoverKind === "collection" ? requestedSlug : "";
            }
            discoverCategory = "";
            requestCatalog(1);
        } else if (actionName === "discover-sidebar-category") {
            Common.preventDefault(eventObject);
            var requestedCategory = actionElement.getAttribute("data-slug") || "";
            if (discoverCategory === requestedCategory && activeDiscoverKind === "") {
                return;
            }
            resetDiscoverSelection();
            discoverCategory = requestedCategory;
            updateDiscoverToolsState();
            requestCatalog(1);
        } else if (actionName === "clear-discover-category") {
            Common.preventDefault(eventObject);
            discoverCategory = "";
            window.MaxPkgDropdown.close();
            updateDiscoverToolsState();
            requestCatalog(1);
        } else if (actionName === "clear-discover-sort") {
            Common.preventDefault(eventObject);
            discoverSort = "popular";
            window.MaxPkgDropdown.close();
            updateDiscoverToolsState();
            requestCatalog(1);
        } else if (actionName === "catalog-retry") {
            Common.preventDefault(eventObject);
            if ((currentState.collections || {}).loaded && (currentState.categories || {}).loaded) {
                requestCatalog(parseInt((currentState.discover || {}).page, 10) || 1);
            } else {
                requestDiscover();
            }
        } else if (actionName === "discover-page") {
            Common.preventDefault(eventObject);
            requestCatalog(parseInt(actionElement.getAttribute("data-page"), 10) || 1);
        } else if (actionName === "screenshot-preview") {
            Common.preventDefault(eventObject);
            showScreenshotPreview();
        } else if (actionName === "select-screenshot") {
            Common.preventDefault(eventObject);
            activeScreenshotIndex = parseInt(actionElement.getAttribute("data-screenshot-index"), 10) || 0;
            if (Common.byId("screenshotPreview")) {
                showScreenshotPreview();
            } else {
                renderDetails();
            }
        } else if (actionName === "close-screenshot-preview") {
            Common.preventDefault(eventObject);
            closeScreenshotPreview();
        } else if (actionName === "copy") {
            Common.preventDefault(eventObject);
            if (Common.copyText(actionElement.getAttribute("data-copy"))) {
                showNotification("Copied to clipboard.", "info");
            } else {
                showNotification("Clipboard is unavailable.", "error");
            }
            window.MaxPkgDropdown.close();
        } else if (actionName === "clear-toolbar-filter") {
            Common.preventDefault(eventObject);
            toolbarVisibilityFilter = "all";
            window.MaxPkgDropdown.close();
            updateInstalledToolsState();
            renderInstalled();
            saveManagerView();
        } else if (actionName === "clear-sort") {
            Common.preventDefault(eventObject);
            activeSort = "toolbar";
            window.MaxPkgDropdown.close();
            updateInstalledToolsState();
            renderInstalled();
            saveManagerView();
        } else if (actionName === "request-runtime-uninstall") {
            Common.preventDefault(eventObject);
            showRuntimeUninstallConfirmation(true);
        } else if (actionName === "cancel-runtime-uninstall") {
            Common.preventDefault(eventObject);
            showRuntimeUninstallConfirmation(false);
        }
    }

    function initialize() {
        var searchInput = Common.byId("searchInput");
        observedSearchContent = searchInput.value;
        var debouncedSearch = window.MaxPkgSearch.debounce(function () {
            searchText = searchInput.value.toLowerCase().replace(/^\s+|\s+$/g, "");
            if (activeTab === "discover") {
                requestCatalog(1);
            } else {
                renderInstalled();
            }
        }, 300);
        var queueSearch = function () {
            var currentSearchContent = searchInput.value;
            if (currentSearchContent === observedSearchContent) {
                return;
            }
            observedSearchContent = currentSearchContent;
            debouncedSearch();
        };
        Common.on(document, "click", handleDocumentClick);
        Common.on(document, "dragstart", handleToolbarDragStart);
        Common.on(document, "dragenter", handleToolbarDragOver);
        Common.on(document, "dragover", handleToolbarDragOver);
        Common.on(document, "drop", handleToolbarDrop);
        Common.on(document, "dragend", handleToolbarDragEnd);
        Common.on(searchInput, "keyup", queueSearch);
        Common.on(searchInput, "input", queueSearch);
        Common.on(searchInput, "propertychange", queueSearch);
        Common.on(searchInput, "paste", queueSearch);
        Common.on(searchInput, "cut", queueSearch);
        window.setInterval(queueSearch, 200);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarFilterSelect"), function (selectedValue) {
            toolbarVisibilityFilter = selectedValue === "toolbar" || selectedValue === "hidden" ? selectedValue : "all";
            updateInstalledToolsState();
            renderInstalled();
            saveManagerView();
        });
        window.MaxPkgDropdown.bindSelect(Common.byId("sortSelect"), function (selectedValue) {
            activeSort = selectedValue;
            updateInstalledToolsState();
            renderInstalled();
            saveManagerView();
        });
        window.MaxPkgDropdown.bindSelect(Common.byId("discoverCategorySelect"), function (selectedValue) {
            resetDiscoverSelection();
            discoverCategory = selectedValue || "";
            updateDiscoverToolsState();
            requestCatalog(1);
        });
        window.MaxPkgDropdown.bindSelect(Common.byId("discoverSortSelect"), function (selectedValue) {
            discoverSort = selectedValue || "popular";
            updateDiscoverToolsState();
            requestCatalog(1);
        });
        window.MaxPkgDropdown.bindSelect(Common.byId("languageSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("managerThemeSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarThemeSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("frequencySelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarDockPositionSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarTitleSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarButtonSizeSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarSubtitleSelect"), saveSettings);
        bindImmediateSettingsSave("autoStartCheck");
        bindImmediateSettingsSave("openManagerCheck");
        bindImmediateSettingsSave("notificationsCheck");
        bindImmediateSettingsSave("managerFullCardsCheck");
        bindImmediateSettingsSave("autoCheckPackagesCheck");
        bindImmediateSettingsSave("autoCheckRuntimeCheck");
        bindImmediateSettingsSave("autoDownloadCheck");
        bindImmediateSettingsSave("toolbarVisibleCheck");
        bindImmediateSettingsSave("debugLoggingCheck");
        bindTextSettingsSave("apiEndpointInput");
        Common.on(Common.byId("developerModeCheck"), "change", function () {
            currentState.settings.developerMode = Common.byId("developerModeCheck").checked;
            updateEndpointSettingsVisibility();
            saveSettings();
        });
        Common.on(Common.byId("settingsButton"), "click", function () {
            populateSettings();
            showRuntimeUninstallConfirmation(false);
            changeSettingsPage("general");
            window.MaxPkgDialog.open(Common.byId("settingsShade"));
        });
        Common.on(Common.byId("closeSettingsButton"), "click", hideSettingsDialog);
        Common.on(Common.byId("copyRuntimeInfoButton"), "click", function () {
            if (Common.copyText("MaxPkg Runtime " + currentState.runtimeVersion)) {
                showNotification("Runtime info copied.", "info");
            }
        });

        window.location.href = "maxpkg://manager/ready";
    }

    window.setRuntimeState = readRuntimeState;
    window.showRuntimeNotification = readRuntimeNotification;

    if (document.readyState === "complete") {
        initialize();
    } else {
        Common.on(window, "load", initialize);
    }
}(window, document));
