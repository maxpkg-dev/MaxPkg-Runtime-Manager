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
        discover: { available: false, message: "Repository is unavailable.", packages: [] },
        remoteDetails: null
    };
    var activeTab = "discover";
    var activeFilter = "all";
    var activeSort = "toolbar";
    var searchText = "";
    var detailsGuid = "";
    var detailsTab = "information";
    var activeScreenshotIndex = 0;
    var detailsListScrollTop = 0;
    var settingsSaveTimer = null;
    var draggedToolbarCard = null;
    var draggedToolbarGrid = null;
    var toolbarDropPlaceholder = null;
    var draggedToolbarOriginalNextSibling = null;

    function icon(iconName) {
        return "<img class='icon' src='../common/icons/" + iconName + ".svg' alt=''>";
    }

    function boolText(isEnabled) {
        return isEnabled ? "true" : "false";
    }

    function packageDescriptionPreview(descriptionText) {
        var maxLength = 118;
        var normalizedText = (descriptionText || "No description provided.").replace(/\s+/g, " ");
        if (normalizedText.length <= maxLength) {
            return normalizedText;
        }
        return normalizedText.substring(0, maxLength - 3).replace(/\s+$/g, "") + "...";
    }

    function safeHttpImageUrl(sourceUrl) {
        var normalizedUrl = String(sourceUrl || "").replace(/^\s+|\s+$/g, "");
        if (/^https?:\/\//i.test(normalizedUrl)) {
            return normalizedUrl;
        }
        return "";
    }

    function safeThumbnailImageUrl(sourceUrl, fallbackUrl) {
        var normalizedUrl = safeHttpImageUrl(sourceUrl);
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

    function discoverDetailsPackage(remotePackage) {
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
        var packageIconUrl = safeHttpImageUrl(packageInfo.packageIconUrl);
        var iconUrl = safeHttpImageUrl(packageInfo.iconUrl);
        var coverImageUrl = includeCover ? safeHttpImageUrl(packageInfo.coverImageUrl) : "";
        if (!packageIconUrl && discoverPackage) {
            packageIconUrl = safeHttpImageUrl(discoverPackage.packageIconUrl);
        }
        if (!iconUrl && discoverPackage) {
            iconUrl = safeHttpImageUrl(discoverPackage.iconUrl);
        }
        if (!coverImageUrl && includeCover && discoverPackage) {
            coverImageUrl = safeHttpImageUrl(discoverPackage.coverImageUrl);
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

    function layoutHeader() {
        var headerActions = Common.byId("headerActions");
        var searchCell = Common.byId("searchCell");
        var actionElements;
        var actionIndex;
        var actionStyle;
        var actionWidth = 0;
        if (!headerActions || !searchCell) {
            return false;
        }
        actionElements = headerActions.children;
        for (actionIndex = 0; actionIndex < actionElements.length; actionIndex += 1) {
            if (actionElements[actionIndex].offsetWidth > 0) {
                actionStyle = actionElements[actionIndex].currentStyle;
                actionWidth += actionElements[actionIndex].offsetWidth;
                actionWidth += actionStyle ? parseInt(actionStyle.marginLeft, 10) || 0 : 0;
                actionWidth += actionStyle ? parseInt(actionStyle.marginRight, 10) || 0 : 0;
            }
        }
        headerActions.style.width = actionWidth + "px";
        searchCell.style.right = actionWidth + "px";
        return true;
    }

    function findPackage(packageGuid) {
        var packageIndex;
        if (activeTab === "discover" && currentState.remoteDetails && currentState.remoteDetails.guid.toLowerCase() === packageGuid.toLowerCase()) {
            return discoverDetailsPackage(currentState.remoteDetails);
        }
        for (packageIndex = 0; packageIndex < currentState.packages.length; packageIndex += 1) {
            if (currentState.packages[packageIndex].guid.toLowerCase() === packageGuid.toLowerCase()) {
                return currentState.packages[packageIndex];
            }
        }
        if (currentState.remoteDetails && currentState.remoteDetails.guid.toLowerCase() === packageGuid.toLowerCase()) {
            return discoverDetailsPackage(currentState.remoteDetails);
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

    function toolbarOrderIndex(packageGuid) {
        var toolbarOrder = currentState.settings.toolbarOrder || [];
        var normalizedGuid = String(packageGuid || "").toLowerCase();
        var orderIndex;
        for (orderIndex = 0; orderIndex < toolbarOrder.length; orderIndex += 1) {
            if (String(toolbarOrder[orderIndex] || "").toLowerCase() === normalizedGuid) {
                return orderIndex;
            }
        }
        return toolbarOrder.length;
    }

    function toolbarSortingEnabled() {
        return activeSort === "toolbar" && activeFilter === "all" && !searchText;
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
            if (activeFilter === "toolbar" && !packageInfo.toolbarVisible) {
                continue;
            }
            filteredPackages.push(packageInfo);
        }
        filteredPackages.sort(comparePackages);
        return filteredPackages;
    }

    function packageCard(packageInfo) {
        var badges = "<span class='badge'>" + Common.escapeHtml(packageInfo.runtime) + "</span>";
        var updateAction = "";
        var dragHandle = "";
        var cardClass = "card";
        if (toolbarSortingEnabled()) {
            cardClass += " toolbar-sort-card";
            dragHandle = "<span class='toolbar-drag-handle' role='button' draggable='true' data-toolbar-drag='true' title='Drag to change Toolbar order'>" +
                "<img src='../common/icons/grip-vertical.svg' draggable='false' alt=''></span>";
        }
        if (packageInfo.toolbarVisible) {
            badges += "<span class='badge badge-success'>Toolbar</span>";
        }
        if (packageInfo.updateAvailable) {
            badges += "<span class='badge badge-warning'>v" + Common.escapeHtml(packageInfo.latestVersion) + " available</span>";
            updateAction = "<a class='button' href='maxpkg://manager/update/" + Common.encode(packageInfo.guid) + "' data-busy='Updating package...'>" + icon("download") + "Update</a> ";
        }
        return "<div class='" + cardClass + "' data-package-guid='" + Common.escapeHtml(packageInfo.guid) + "'>" +
            dragHandle +
            "<div class='card-content clearfix'>" +
                "<button class='package-summary clearfix' type='button' data-action='details' data-guid='" + Common.escapeHtml(packageInfo.guid) + "' title='Open package details'>" +
                    packageIcon(packageInfo, "package-icon", true) +
                    "<span class='package-heading'><span class='package-title ellipsis'>" + Common.escapeHtml(packageInfo.name) + "</span>" +
                    "<span class='package-meta ellipsis'>v" + Common.escapeHtml(packageInfo.version) + " &middot; " + Common.escapeHtml(packageInfo.developer || "Unknown developer") + "</span></span>" +
                "</button>" +
                "<p class='package-description'>" + Common.escapeHtml(packageDescriptionPreview(packageInfo.description)) + "</p>" +
                "<div>" + badges + "</div>" +
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
        return "<div class='state-panel'><img class='state-icon' src='../common/icons/package.svg' alt=''><h2>" + title + "</h2><p>" + message + "</p>" +
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
        var childElement = cardGrid.firstChild;
        var packageGuid;
        while (childElement) {
            if (childElement.nodeType === 1 && childElement.getAttribute) {
                packageGuid = childElement.getAttribute("data-package-guid");
                if (packageGuid) {
                    orderedGuids.push(packageGuid);
                }
            }
            childElement = childElement.nextSibling;
        }
        return orderedGuids;
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
        toolbarDropPlaceholder.className = "card toolbar-drop-placeholder";
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

    function renderDiscover() {
        var discoverState = currentState.discover || {};
        var remotePackages = discoverState.packages || [];
        var packageCards = [];
        var packageIndex;
        var pagination = "";
        if (!discoverState.available) {
            Common.byId("discoverPage").innerHTML = "<div class='state-panel'><img class='state-icon' src='../common/icons/cloud-off.svg' alt=''><h2>Catalog unavailable</h2>" +
                "<p>" + Common.escapeHtml(discoverState.message || "Load the catalog to browse packages.") + "</p><button class='button' type='button' data-action='catalog-retry'>" + icon("refresh-cw") + "Retry</button></div>";
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
        Common.byId("discoverPage").innerHTML = packageCards.length ? "<div class='catalog-summary'>" + discoverState.total + " packages</div><div class='card-grid'>" + packageCards.join("") + "</div>" + pagination :
            "<div class='state-panel'><img class='state-icon' src='../common/icons/search.svg' alt=''><h2>No packages found</h2><p>Try a different search phrase.</p></div>";
    }

    function remotePackageCard(packageInfo) {
        var badges = "";
        var resolvedPackage = findPackage(packageInfo.guid);
        var installAction = "<a class='button button-primary' href='maxpkg://manager/install/" + Common.encode(packageInfo.guid) + "' data-busy='Installing package...'>" + icon("download") + "Install</a>";
        if (resolvedPackage && !resolvedPackage.isRemote) {
            installAction = "<button class='button' type='button' disabled='disabled'>" + icon("check") + "Installed</button>";
        }
        if (packageInfo.runtime) {
            badges += "<span class='badge'>" + Common.escapeHtml(packageInfo.runtime) + "</span>";
        }
        if (packageInfo.category) {
            badges += "<span class='badge'>" + Common.escapeHtml(packageInfo.category) + "</span>";
        }
        return "<div class='card' data-package-guid='" + Common.escapeHtml(packageInfo.guid) + "'>" +
            "<div class='card-content clearfix'>" +
                "<button class='package-summary clearfix' type='button' data-action='details' data-guid='" + Common.escapeHtml(packageInfo.guid) + "' title='Open package details'>" +
                    packageIcon(packageInfo, "package-icon", true) +
                    "<span class='package-heading'><span class='package-title ellipsis'>" + Common.escapeHtml(packageInfo.name) + "</span>" +
                    "<span class='package-meta ellipsis'>v" + Common.escapeHtml(packageInfo.version) + " &middot; " + Common.escapeHtml(packageInfo.developer || "Unknown developer") + "</span></span>" +
                "</button>" +
                "<p class='package-description'>" + Common.escapeHtml(packageDescriptionPreview(packageInfo.description)) + "</p>" +
                "<div>" + badges + "</div>" +
            "</div>" +
            "<div class='card-actions'>" + installAction + "</div>" +
        "</div>";
    }

    function requestCatalog(pageNumber) {
        var normalizedPage = pageNumber > 0 ? pageNumber : 1;
        Common.byId("busyMessage").innerHTML = "Loading package catalog...";
        Common.removeClass(Common.byId("busyShade"), "is-hidden");
        window.location.href = "maxpkg://manager/catalog?query=" + Common.encode(searchText) + "&category=&sort=popular&page=" + normalizedPage + "&pageSize=24";
    }

    function detailRow(rowLabel, fieldContent, cssClass) {
        if (!fieldContent) {
            return "";
        }
        return "<tr><th>" + Common.escapeHtml(rowLabel) + "</th><td" + (cssClass ? " class='" + cssClass + "'" : "") + ">" + Common.escapeHtml(fieldContent) + "</td></tr>";
    }

    function detailPackageLinkRow(packageInfo) {
        if (!packageInfo.packagePageUrl) {
            return "";
        }
        return "<tr><th>MaxPkg page</th><td class='path-value'><a class='icon-button details-copy-link-button' href='maxpkg://manager/copy-package-link/" +
            Common.encode(packageInfo.slug) + "' title='Copy link'>" + icon("copy") + "</a><a class='details-table-link' href='maxpkg://manager/package-link/" +
            Common.encode(packageInfo.guid) + "?kind=maxpkg'>" + Common.escapeHtml(packageInfo.packagePageUrl) + "</a></td></tr>";
    }

    function compatibilityLabel(packageInfo) {
        if (packageInfo.minimumMaxVersion) {
            return packageInfo.minimumMaxVersion + " and newer";
        }
        return "Any version";
    }

    function packageLinkButton(packageInfo, linkKind, buttonLabel) {
        var packageUrl = packageInfo[linkKind + "Url"] || "";
        if (!packageUrl) {
            return "";
        }
        return "<a class='button' href='maxpkg://manager/package-link/" + Common.encode(packageInfo.guid) + "?kind=" + Common.encode(linkKind) + "'>" + icon("external-link") + Common.escapeHtml(buttonLabel) + "</a>";
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
        var changelogItems = [];
        var changelogIndex;
        var changeType;
        for (changelogIndex = 0; changelogIndex < changelogEntries.length; changelogIndex += 1) {
            changeType = changelogEntries[changelogIndex].changeType || "Changed";
            changelogItems.push("<li><span class='badge changelog-badge " + changelogBadgeClass(changeType) + "'>" + Common.escapeHtml(changeType) + "</span><span>" + Common.escapeHtml(changelogEntries[changelogIndex].messageContent) + "</span></li>");
        }
        if (!changelogItems.length) {
            return "<div class='details-section'><h3>Full changelog</h3><p class='text-muted'>No changelog entries were provided with this package.</p></div>";
        }
        return "<div class='details-section'><h3>Full changelog</h3><ul class='changelog-list'>" + changelogItems.join("") + "</ul></div>";
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
            linkUrl = safeHttpImageUrl(linkMatch[2]);
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
            return "<div class='details-section'><h3>Full description</h3><p class='text-muted'>No full description was provided with this package.</p></div>";
        }
        return "<div class='details-section full-description-section'><h3>Full description</h3><div class='full-description-content'>" + descriptionMarkup + "</div></div>";
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
            fullImageUrl = safeHttpImageUrl(screenshotInfo.url);
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
        var normalizedTabName = tabName === "description" || tabName === "screenshots" || tabName === "changelog" ? tabName : "information";
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
        var packageRows;
        var linkButtons;
        var releaseBadges;
        var updateButton;
        var actionMarkup;
        var bottomActionButton;
        var changelogCount;
        var screenshotCount;
        var hasFullDescription;
        if (!packageInfo) {
            showTab(activeTab);
            return;
        }
        compatibilityText = compatibilityLabel(packageInfo);
        packageRows = detailRow("Version", packageInfo.version) +
            detailRow("Release channel", packageInfo.releaseChannel) +
            detailPackageLinkRow(packageInfo) +
            detailRow("Release date", packageInfo.releaseDate) +
            detailRow("Developer", packageInfo.developer) +
            detailRow("Runtime", packageInfo.runtime) +
            detailRow("3ds Max", compatibilityText) +
            detailRow("License", packageInfo.licenseType) +
            detailRow("Entry file", packageInfo.entry, "path-value") +
            detailRow("Install path", packageInfo.installPath, "path-value") +
            detailRow("Manifest version", packageInfo.manifestVersion) +
            detailRow("Packager", packageInfo.packagerName ? packageInfo.packagerName + (packageInfo.packagerVersion ? " " + packageInfo.packagerVersion : "") : "") +           
            detailRow("GUID", packageInfo.guid, "path-value");
        linkButtons = packageLinkButton(packageInfo, "homepage", "Homepage") +
            packageLinkButton(packageInfo, "documentation", "Documentation") +
            packageLinkButton(packageInfo, "support", "Support") +
            packageLinkButton(packageInfo, "license", "License");
        releaseBadges = packageInfo.runtime ? "<span class='badge'>" + Common.escapeHtml(packageInfo.runtime) + "</span>" : "";
        if (packageInfo.releaseChannel) {
            releaseBadges += "<span class='badge'>" + Common.escapeHtml(packageInfo.releaseChannel) + "</span>";
        }
        if (packageInfo.licenseType) {
            releaseBadges += "<span class='badge'>" + Common.escapeHtml(packageInfo.licenseType) + "</span>";
        }
        if (packageInfo.toolbarVisible) {
            releaseBadges += "<span class='badge badge-success'>Toolbar</span>";
        }
        updateButton = packageInfo.updateAvailable ? "<a class='button details-action-button' href='maxpkg://manager/update/" + Common.encode(packageInfo.guid) + "' data-busy='Updating package...'>" + icon("download") + "Update to " + Common.escapeHtml(packageInfo.latestVersion) + "</a>" : "";
        actionMarkup = packageInfo.isRemote ?
            "<a class='button button-primary details-action-button' href='maxpkg://manager/install/" + Common.encode(packageInfo.guid) + "' data-busy='Installing package...'>" + icon("download") + "Install</a>" :
            "<a class='button button-primary details-action-button' href='maxpkg://manager/run/" + Common.encode(packageInfo.guid) + "' data-busy='Starting package...'>" + icon("play") + "Run</a>" +
            updateButton + "<a class='button button-danger details-action-button details-uninstall-button' href='maxpkg://manager/uninstall/" + Common.encode(packageInfo.guid) + "' data-busy='Uninstalling package...'>" + icon("trash-2") + "Uninstall</a>";
        bottomActionButton = packageInfo.isRemote ? "" :
            "<div class='details-bottom-actions'><a class='button details-bottom-button' href='maxpkg://manager/open-folder/" + Common.encode(packageInfo.guid) + "'>" + icon("folder-open") + "Open Folder</a></div>";
        changelogCount = (packageInfo.changelogEntries || []).length;
        screenshotCount = validScreenshots(packageInfo).length;
        hasFullDescription = fullDescriptionContentHtml(packageInfo.fullDescription || "") !== "";
        if (!hasFullDescription && detailsTab === "description") {
            detailsTab = "information";
        }
        if (screenshotCount < 1 && detailsTab === "screenshots") {
            detailsTab = "information";
        }
        Common.byId("detailsPathName").innerHTML = Common.escapeHtml(packageInfo.name);
        Common.byId("detailsPathRoot").innerHTML = packageInfo.isRemote ? "Discover" : "Installed";
        Common.byId("detailsPage").innerHTML = "<div class='details-hero clearfix'>" + packageIcon(packageInfo, "details-icon", false) +
            "<div class='details-hero-actions'>" + actionMarkup + "</div>" +
            "<div class='details-copy'><h1>" + Common.escapeHtml(packageInfo.name) + "</h1><p>Version " + Common.escapeHtml(packageInfo.version) + " by " + Common.escapeHtml(packageInfo.developer || "Unknown developer") + "</p><div class='details-badges'>" + releaseBadges + "</div></div></div>" +
            "<div class='details-section'><h3>Description</h3><p>" + Common.escapeHtml(packageInfo.description || "No description provided.") + "</p></div>" +
            "<div class='details-tabs' role='tablist'><button class='details-tab' type='button' data-action='details-tab' data-details-tab='information'>Information</button>" +
            (hasFullDescription ? "<button class='details-tab' type='button' data-action='details-tab' data-details-tab='description'>Description</button>" : "") +
            (screenshotCount > 0 ? "<button class='details-tab' type='button' data-action='details-tab' data-details-tab='screenshots'>Screenshots<span class='details-tab-count'>" + screenshotCount + "</span></button>" : "") +
            "<button class='details-tab' type='button' data-action='details-tab' data-details-tab='changelog'>Changelog<span class='details-tab-count'>" + changelogCount + "</span></button></div>" +
            "<div class='details-tab-panel' data-details-panel='information'><div class='details-section'><h3>Package information</h3><table class='table details-table'>" + packageRows + "</table></div>" +
            (linkButtons ? "<div class='details-section'><h3>Links</h3><div class='details-link-actions'>" + linkButtons + "</div></div>" : "") + bottomActionButton + "</div>" +
            (hasFullDescription ? "<div class='details-tab-panel is-hidden' data-details-panel='description'>" + fullDescriptionHtml(packageInfo) + "</div>" : "") +
            (screenshotCount > 0 ? "<div class='details-tab-panel is-hidden' data-details-panel='screenshots'>" + screenshotGalleryHtml(packageInfo) + "</div>" : "") +
            "<div class='details-tab-panel is-hidden' data-details-panel='changelog'>" + changelogHtml(packageInfo) + "</div>";
        showDetailsTab(detailsTab);
    }

    function renderStatus() {
        var packageLabel = currentState.packages.length === 1 ? " package" : " packages";
        var updateLabel = currentState.updateCount === 1 ? " update" : " updates";
        Common.byId("runtimeVersion").innerHTML = "Runtime " + Common.escapeHtml(currentState.runtimeVersion);
        Common.byId("footerVersion").innerHTML = "Runtime " + Common.escapeHtml(currentState.runtimeVersion);
        Common.byId("aboutVersion").innerHTML = "MaxPkg Runtime " + Common.escapeHtml(currentState.runtimeVersion);
        Common.byId("installedTabCount").innerHTML = currentState.packages.length;
        Common.byId("packageStatus").innerHTML = currentState.packages.length + packageLabel;
        Common.byId("updateStatus").innerHTML = currentState.updateCount + updateLabel;
        Common.byId("connectionStatus").innerHTML = currentState.connection === "online" ? "Online" : (currentState.connection === "configured" ? "Endpoint configured" : "Offline");
        Common.byId("connectionStatus").className = "connection-status " + (currentState.connection === "online" ? "text-success" : "text-warning");
        Common.toggleClass(Common.byId("updateAllButton"), "is-hidden", currentState.updateCount < 1);
    }

    function showTab(tabName) {
        activeTab = tabName === "discover" ? "discover" : "installed";
        detailsGuid = "";
        Common.toggleClass(Common.byId("installedTab"), "is-active", activeTab === "installed");
        Common.toggleClass(Common.byId("discoverTab"), "is-active", activeTab === "discover");
        Common.toggleClass(Common.byId("installedPage"), "is-hidden", activeTab !== "installed");
        Common.toggleClass(Common.byId("discoverPage"), "is-hidden", activeTab !== "discover");
        Common.addClass(Common.byId("detailsPage"), "is-hidden");
        Common.toggleClass(Common.byId("installedTools"), "is-hidden", activeTab !== "installed");
        Common.toggleClass(Common.byId("discoverTools"), "is-hidden", activeTab !== "discover");
        Common.removeClass(Common.byId("pageToolbar"), "is-hidden");
        Common.addClass(Common.byId("detailsNavigation"), "is-hidden");
    }

    function showDetails(packageGuid) {
        if (!detailsGuid) {
            detailsListScrollTop = Common.byId("pageHost").scrollTop;
        }
        if (detailsGuid !== packageGuid) {
            detailsTab = "information";
            activeScreenshotIndex = 0;
        }
        detailsGuid = packageGuid;
        if (activeTab === "discover") {
            Common.byId("busyMessage").innerHTML = "Loading package details...";
            Common.removeClass(Common.byId("busyShade"), "is-hidden");
            window.location.href = "maxpkg://manager/remote-details/" + Common.encode(packageGuid);
        }
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
        layoutHeader();
        Common.addClass(Common.byId("busyShade"), "is-hidden");
    }

    function readRuntimeState() {
        var payloadElement = Common.byId("runtimePayload");
        var sourceText = payloadElement.innerText || payloadElement.textContent || "";
        try {
            currentState = JSON.parse(sourceText);
            activeTab = currentState.settings.managerLastTab || activeTab;
            activeFilter = currentState.settings.managerFilter || activeFilter;
            activeSort = currentState.settings.managerSort || activeSort;
            window.MaxPkgDropdown.setSelectValue(Common.byId("sortSelect"), activeSort);
            renderAll();
            if (activeTab === "discover" && !currentState.discover.available && !currentState.discover.errorCode) {
                requestCatalog(1);
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
            notificationIcon = "<img class='notification-icon-image' src='../common/icons/circle-check.svg' alt=''>";
        } else if (normalizedNotificationType === "warning") {
            notificationIcon = "!";
        } else if (normalizedNotificationType === "error") {
            notificationIcon = "<img class='notification-icon-image' src='../common/icons/circle-x.svg' alt=''>";
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
        menuHtml += "<button type='button' data-action='details' data-guid='" + Common.escapeHtml(packageInfo.guid) + "'>Details</button>" +
            "<a href='maxpkg://manager/open-folder/" + Common.encode(packageInfo.guid) + "'>Open Folder</a>";
        if (packageInfo.helpUrl) {
            menuHtml += "<a href='maxpkg://manager/help/" + Common.encode(packageInfo.guid) + "'>Help</a>";
        }
        menuHtml += "<a href='maxpkg://manager/toggle-package-toolbar/" + Common.encode(packageInfo.guid) + "'>" + toolbarLabel + "</a>" +
            "<div class='context-separator'></div>" +
            "<button type='button' data-action='copy' data-copy='" + Common.escapeHtml(packageInfo.guid) + "'>Copy GUID</button>" +
            "<button type='button' data-action='copy' data-copy='" + Common.escapeHtml(packageInfo.installPath) + "'>Copy Path</button>" +
            "<div class='context-separator'></div>" +
            "<a class='context-danger' href='maxpkg://manager/uninstall/" + Common.encode(packageInfo.guid) + "' data-busy='Uninstalling package...'>" + icon("trash-2") + "Uninstall</a>";
        Common.byId("contextMenu").innerHTML = menuHtml;
        window.MaxPkgDropdown.open(Common.byId("contextMenu"), sourceButton);
    }

    function setFilter(filterName) {
        var filterButtons = document.getElementsByTagName("button");
        var buttonIndex;
        activeFilter = filterName;
        for (buttonIndex = 0; buttonIndex < filterButtons.length; buttonIndex += 1) {
            if (filterButtons[buttonIndex].getAttribute("data-filter") !== null) {
                Common.toggleClass(filterButtons[buttonIndex], "is-active", filterButtons[buttonIndex].getAttribute("data-filter") === activeFilter);
            }
        }
        renderInstalled();
        window.location.href = "maxpkg://manager/view?tab=" + Common.encode(activeTab) + "&filter=" + Common.encode(activeFilter) + "&sort=" + Common.encode(activeSort);
    }

    function updateEndpointSettingsVisibility() {
        var developerModeEnabled = Common.byId("developerModeCheck").checked;
        Common.toggleClass(Common.byId("endpointSettingsNavigation"), "is-hidden", !developerModeEnabled);
        if (!developerModeEnabled && !Common.hasClass(Common.byId("endpointSettingsPanel"), "is-hidden")) {
            changeSettingsPage("developer");
        }
    }

    function populateSettings() {
        var settings = currentState.settings;
        window.MaxPkgDropdown.setSelectValue(Common.byId("languageSelect"), settings.language || "English");
        window.MaxPkgDropdown.setSelectValue(Common.byId("frequencySelect"), String(settings.updateFrequencyHours || 24));
        Common.byId("autoStartCheck").checked = !!settings.autoStart;
        Common.byId("openManagerCheck").checked = !!settings.openManagerOnStartup;
        Common.byId("notificationsCheck").checked = !!settings.notifications;
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
        queryParts.push("autoStart=" + boolText(Common.byId("autoStartCheck").checked));
        queryParts.push("openManagerOnStartup=" + boolText(Common.byId("openManagerCheck").checked));
        queryParts.push("notifications=" + boolText(Common.byId("notificationsCheck").checked));
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
        var filterElement = Common.closestWithAttribute(sourceElement, "data-filter");
        var settingsPageElement = Common.closestWithAttribute(sourceElement, "data-settings-page");
        var busyElement = Common.closestWithAttribute(sourceElement, "data-busy");
        var actionName;
        if (busyElement) {
            Common.byId("busyMessage").innerHTML = Common.escapeHtml(busyElement.getAttribute("data-busy"));
            Common.removeClass(Common.byId("busyShade"), "is-hidden");
        }
        if (tabElement) {
            showTab(tabElement.getAttribute("data-tab"));
            if (activeTab === "discover") {
                requestCatalog(1);
            } else {
                window.location.href = "maxpkg://manager/view?tab=" + Common.encode(activeTab) + "&filter=" + Common.encode(activeFilter) + "&sort=" + Common.encode(activeSort);
            }
            return;
        }
        if (filterElement) {
            setFilter(filterElement.getAttribute("data-filter"));
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
        } else if (actionName === "catalog-retry") {
            Common.preventDefault(eventObject);
            requestCatalog(1);
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
        var observedSearchContent = searchInput.value;
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
        Common.on(window, "resize", layoutHeader);
        Common.on(searchInput, "keyup", queueSearch);
        Common.on(searchInput, "input", queueSearch);
        Common.on(searchInput, "propertychange", queueSearch);
        Common.on(searchInput, "paste", queueSearch);
        Common.on(searchInput, "cut", queueSearch);
        window.setInterval(queueSearch, 200);
        window.MaxPkgDropdown.bindSelect(Common.byId("sortSelect"), function (selectedValue) {
            activeSort = selectedValue;
            renderInstalled();
            window.location.href = "maxpkg://manager/view?tab=" + Common.encode(activeTab) + "&filter=" + Common.encode(activeFilter) + "&sort=" + Common.encode(activeSort);
        });
        window.MaxPkgDropdown.bindSelect(Common.byId("languageSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("frequencySelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarDockPositionSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarTitleSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarButtonSizeSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("toolbarSubtitleSelect"), saveSettings);
        bindImmediateSettingsSave("autoStartCheck");
        bindImmediateSettingsSave("openManagerCheck");
        bindImmediateSettingsSave("notificationsCheck");
        bindImmediateSettingsSave("autoCheckPackagesCheck");
        bindImmediateSettingsSave("autoCheckRuntimeCheck");
        bindImmediateSettingsSave("autoDownloadCheck");
        bindImmediateSettingsSave("toolbarVisibleCheck");
        bindImmediateSettingsSave("debugLoggingCheck");
        bindTextSettingsSave("apiEndpointInput");
        Common.on(Common.byId("developerModeCheck"), "change", function () {
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
        layoutHeader();
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
