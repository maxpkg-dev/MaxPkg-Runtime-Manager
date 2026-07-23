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
        discover: { available: false, message: "Repository is unavailable." }
    };
    var activeTab = "installed";
    var activeFilter = "all";
    var activeSort = "name";
    var searchText = "";
    var detailsGuid = "";
    var detailsTab = "information";
    var detailsListScrollTop = 0;
    var settingsSaveTimer = null;

    function icon(iconName) {
        return "<img class='icon' src='../common/icons/" + iconName + ".svg' alt=''>";
    }

    function boolText(isEnabled) {
        return isEnabled ? "true" : "false";
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
        for (packageIndex = 0; packageIndex < currentState.packages.length; packageIndex += 1) {
            if (currentState.packages[packageIndex].guid.toLowerCase() === packageGuid.toLowerCase()) {
                return currentState.packages[packageIndex];
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

    function packageIcon(packageInfo, cssClass) {
        if (packageInfo.iconUrl) {
            return "<img class='" + cssClass + "' src='" + Common.escapeHtml(packageInfo.iconUrl) + "' alt=''>";
        }
        return "<span class='" + cssClass + " package-icon-fallback'>" + packageInitials(packageInfo) + "</span>";
    }

    function comparePackages(leftPackage, rightPackage) {
        var leftText = leftPackage[activeSort] || "";
        var rightText = rightPackage[activeSort] || "";
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
        if (packageInfo.toolbarVisible) {
            badges += "<span class='badge badge-success'>Toolbar</span>";
        }
        if (packageInfo.updateAvailable) {
            badges += "<span class='badge badge-warning'>v" + Common.escapeHtml(packageInfo.latestVersion) + " available</span>";
            updateAction = "<a class='button' href='maxpkg://manager/update/" + Common.encode(packageInfo.guid) + "' data-busy='Updating package...'>" + icon("download") + "Update</a> ";
        }
        return "<div class='card' data-package-guid='" + Common.escapeHtml(packageInfo.guid) + "'>" +
            "<div class='card-content clearfix'>" +
                "<button class='package-summary clearfix' type='button' data-action='details' data-guid='" + Common.escapeHtml(packageInfo.guid) + "' title='Open package details'>" +
                    packageIcon(packageInfo, "package-icon") +
                    "<span class='package-heading'><span class='package-title ellipsis'>" + Common.escapeHtml(packageInfo.name) + "</span>" +
                    "<span class='package-meta ellipsis'>v" + Common.escapeHtml(packageInfo.version) + " &middot; " + Common.escapeHtml(packageInfo.developer || "Unknown developer") + "</span></span>" +
                "</button>" +
                "<p class='package-description'>" + Common.escapeHtml(packageInfo.description || "No description provided.") + "</p>" +
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

    function renderDiscover() {
        var discoverState = currentState.discover || {};
        var message = discoverState.message || "Runtime did not provide repository data.";
        Common.byId("discoverPage").innerHTML = "<div class='state-panel'><img class='state-icon' src='../common/icons/cloud-off.svg' alt=''><h2>Discover is offline</h2>" +
            "<p>" + Common.escapeHtml(message) + "</p><a class='button' href='maxpkg://manager/check-updates' data-busy='Checking connection...'>" + icon("refresh-cw") + "Retry</a></div>";
    }

    function detailRow(rowLabel, fieldContent, cssClass) {
        if (!fieldContent) {
            return "";
        }
        return "<tr><th>" + Common.escapeHtml(rowLabel) + "</th><td" + (cssClass ? " class='" + cssClass + "'" : "") + ">" + Common.escapeHtml(fieldContent) + "</td></tr>";
    }

    function compatibilityLabel(packageInfo) {
        if (packageInfo.minimumMaxVersion && packageInfo.maximumMaxVersion) {
            return packageInfo.minimumMaxVersion + "–" + packageInfo.maximumMaxVersion;
        }
        if (packageInfo.minimumMaxVersion) {
            return packageInfo.minimumMaxVersion + " and newer";
        }
        return packageInfo.maximumMaxVersion || "";
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

    function showDetailsTab(tabName) {
        var normalizedTabName = tabName === "changelog" ? "changelog" : "information";
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
        var changelogCount;
        if (!packageInfo) {
            showTab(activeTab);
            return;
        }
        compatibilityText = compatibilityLabel(packageInfo);
        packageRows = detailRow("GUID", packageInfo.guid, "path-value") +
            detailRow("Version", packageInfo.version) +
            detailRow("Release channel", packageInfo.releaseChannel) +
            detailRow("Release date", packageInfo.releaseDate) +
            detailRow("Developer", packageInfo.developer) +
            detailRow("Runtime", packageInfo.runtime) +
            detailRow("3ds Max", compatibilityText) +
            detailRow("License", packageInfo.licenseType) +
            detailRow("Entry file", packageInfo.entry, "path-value") +
            detailRow("Install path", packageInfo.installPath, "path-value") +
            detailRow("Manifest version", packageInfo.manifestVersion) +
            detailRow("Packager", packageInfo.packagerName ? packageInfo.packagerName + (packageInfo.packagerVersion ? " " + packageInfo.packagerVersion : "") : "");
        linkButtons = packageLinkButton(packageInfo, "homepage", "Homepage") +
            packageLinkButton(packageInfo, "documentation", "Documentation") +
            packageLinkButton(packageInfo, "support", "Support") +
            packageLinkButton(packageInfo, "license", "License");
        releaseBadges = "<span class='badge'>" + Common.escapeHtml(packageInfo.runtime) + "</span>";
        if (packageInfo.releaseChannel) {
            releaseBadges += "<span class='badge'>" + Common.escapeHtml(packageInfo.releaseChannel) + "</span>";
        }
        if (packageInfo.licenseType) {
            releaseBadges += "<span class='badge'>" + Common.escapeHtml(packageInfo.licenseType) + "</span>";
        }
        if (packageInfo.toolbarVisible) {
            releaseBadges += "<span class='badge badge-success'>Toolbar</span>";
        }
        updateButton = packageInfo.updateAvailable ? "<a class='button' href='maxpkg://manager/update/" + Common.encode(packageInfo.guid) + "' data-busy='Updating package...'>" + icon("download") + "Update to " + Common.escapeHtml(packageInfo.latestVersion) + "</a>" : "";
        changelogCount = (packageInfo.changelogEntries || []).length;
        Common.byId("detailsPathName").innerHTML = Common.escapeHtml(packageInfo.name);
        Common.byId("detailsPage").innerHTML = "<div class='details-hero clearfix'>" + packageIcon(packageInfo, "details-icon") +
            "<div class='details-copy'><h1>" + Common.escapeHtml(packageInfo.name) + "</h1><p>Version " + Common.escapeHtml(packageInfo.version) + " by " + Common.escapeHtml(packageInfo.developer || "Unknown developer") + "</p><div class='details-badges'>" + releaseBadges + "</div></div></div>" +
            "<div class='details-primary-actions'><a class='button button-primary' href='maxpkg://manager/run/" + Common.encode(packageInfo.guid) + "' data-busy='Starting package...'>" + icon("play") + "Run</a>" +
            updateButton + "<a class='button' href='maxpkg://manager/open-folder/" + Common.encode(packageInfo.guid) + "'>" + icon("folder-open") + "Open Folder</a></div>" +
            "<div class='details-section'><h3>Description</h3><p>" + Common.escapeHtml(packageInfo.description || "No description provided.") + "</p></div>" +
            "<div class='details-tabs' role='tablist'><button class='details-tab' type='button' data-action='details-tab' data-details-tab='information'>Information</button>" +
            "<button class='details-tab' type='button' data-action='details-tab' data-details-tab='changelog'>Changelog<span class='details-tab-count'>" + changelogCount + "</span></button></div>" +
            "<div class='details-tab-panel' data-details-panel='information'><div class='details-section'><h3>Package information</h3><table class='table details-table'>" + packageRows + "</table></div>" +
            (linkButtons ? "<div class='details-section'><h3>Links</h3><div class='details-link-actions'>" + linkButtons + "</div></div>" : "") + "</div>" +
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
        }
        detailsGuid = packageGuid;
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
            notificationIcon = "&#215;";
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
            window.location.href = "maxpkg://manager/view?tab=" + Common.encode(activeTab) + "&filter=" + Common.encode(activeFilter) + "&sort=" + Common.encode(activeSort);
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
        } else if (actionName === "copy") {
            Common.preventDefault(eventObject);
            if (Common.copyText(actionElement.getAttribute("data-copy"))) {
                showNotification("Copied to clipboard.", "info");
            } else {
                showNotification("Clipboard is unavailable.", "error");
            }
            window.MaxPkgDropdown.close();
        }
    }

    function initialize() {
        var debouncedSearch = window.MaxPkgSearch.debounce(function () {
            searchText = Common.byId("searchInput").value.toLowerCase().replace(/^\s+|\s+$/g, "");
            Common.toggleClass(Common.byId("clearSearchButton"), "is-hidden", !searchText);
            renderInstalled();
        }, 300);
        Common.on(document, "click", handleDocumentClick);
        Common.on(window, "resize", layoutHeader);
        Common.on(Common.byId("searchInput"), "keyup", debouncedSearch);
        Common.on(Common.byId("clearSearchButton"), "click", function () {
            Common.byId("searchInput").value = "";
            searchText = "";
            Common.addClass(Common.byId("clearSearchButton"), "is-hidden");
            renderInstalled();
        });
        window.MaxPkgDropdown.bindSelect(Common.byId("sortSelect"), function (selectedValue) {
            activeSort = selectedValue;
            renderInstalled();
            window.location.href = "maxpkg://manager/view?tab=" + Common.encode(activeTab) + "&filter=" + Common.encode(activeFilter) + "&sort=" + Common.encode(activeSort);
        });
        window.MaxPkgDropdown.bindSelect(Common.byId("languageSelect"), saveSettings);
        window.MaxPkgDropdown.bindSelect(Common.byId("frequencySelect"), saveSettings);
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
