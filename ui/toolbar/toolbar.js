/*
 * Measures and scrolls horizontal, vertical, and floating MaxPkg toolbars.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

var scrollOffset = 0;
var scrollStep = 160;
var controlGap = 4;
var lastLayoutWidth = -1;
var lastLayoutHeight = -1;
var layoutMonitor = null;
var toolbarReorderInitialized = false;
var toolbarDragThreshold = 4;
var toolbarAutoScrollInset = 12;
var toolbarAutoScrollStep = 8;
var toolbarAutoScrollInterval = 30;
var toolbarDragSource = null;
var toolbarDragOriginalButtons = null;
var toolbarDragOriginalHref = "";
var toolbarDragGhost = null;
var toolbarDragCaptureElement = null;
var toolbarDragStartX = 0;
var toolbarDragStartY = 0;
var toolbarDragPointerOffsetX = 0;
var toolbarDragPointerOffsetY = 0;
var toolbarLastPointerX = 0;
var toolbarLastPointerY = 0;
var toolbarDragActive = false;
var toolbarDragEnding = false;
var toolbarAutoScrollDirection = 0;
var toolbarAutoScrollTimer = null;
var toolbarSuppressNextClick = false;
var toolbarSuppressClickTimer = null;
var toolbarOrderSavePending = false;
var toolbarOrderSaveTimer = null;
var toolbarPendingOriginalButtons = null;

function byId(elementId) {
    return document.getElementById(elementId);
}

function bindEvent(element, eventName, eventHandler) {
    if (!element) {
        return;
    }
    if (element.addEventListener) {
        element.addEventListener(eventName, eventHandler, false);
    } else if (element.attachEvent) {
        element.attachEvent("on" + eventName, eventHandler);
    }
}

function eventTarget(eventObject) {
    var resolvedEvent = eventObject || window.event;
    return resolvedEvent ? (resolvedEvent.target || resolvedEvent.srcElement) : null;
}

function hasClass(element, className) {
    return !!element && (" " + element.className + " ").indexOf(" " + className + " ") >= 0;
}

function addClass(element, className) {
    if (element && !hasClass(element, className)) {
        element.className = element.className ? element.className + " " + className : className;
    }
}

function removeClass(element, className) {
    if (element) {
        element.className = (" " + element.className + " ").replace(" " + className + " ", " ").replace(/^\s+|\s+$/g, "");
    }
}

function cancelEvent(eventObject) {
    var resolvedEvent = eventObject || window.event;
    if (!resolvedEvent) {
        return false;
    }
    if (resolvedEvent.preventDefault) {
        resolvedEvent.preventDefault();
    }
    if (resolvedEvent.stopPropagation) {
        resolvedEvent.stopPropagation();
    }
    resolvedEvent.returnValue = false;
    resolvedEvent.cancelBubble = true;
    return false;
}

function sortablePackageButton(sourceElement) {
    var currentElement = sourceElement;
    while (currentElement && currentElement !== document.body) {
        if (currentElement.getAttribute && currentElement.getAttribute("data-toolbar-sortable") === "true") {
            return currentElement;
        }
        currentElement = currentElement.parentNode;
    }
    return null;
}

function sortablePackageButtons() {
    var strip = byId("strip");
    var stripLinks = strip ? strip.getElementsByTagName("a") : [];
    var packageButtons = [];
    var linkIndex;
    for (linkIndex = 0; linkIndex < stripLinks.length; linkIndex += 1) {
        if (stripLinks[linkIndex].getAttribute("data-toolbar-sortable") === "true") {
            packageButtons.push(stripLinks[linkIndex]);
        }
    }
    return packageButtons;
}

function packageGuidOrder(packageButtons) {
    var packageGuids = [];
    var buttonIndex;
    for (buttonIndex = 0; buttonIndex < packageButtons.length; buttonIndex += 1) {
        packageGuids.push(packageButtons[buttonIndex].getAttribute("data-package-guid") || "");
    }
    return packageGuids;
}

function packageOrdersMatch(firstOrder, secondOrder) {
    var orderIndex;
    if (!firstOrder || !secondOrder || firstOrder.length !== secondOrder.length) {
        return false;
    }
    for (orderIndex = 0; orderIndex < firstOrder.length; orderIndex += 1) {
        if (String(firstOrder[orderIndex]).toLowerCase() !== String(secondOrder[orderIndex]).toLowerCase()) {
            return false;
        }
    }
    return true;
}

function restorePackageButtonOrder(packageButtons) {
    var strip = byId("strip");
    var buttonIndex;
    if (!strip || !packageButtons) {
        return;
    }
    for (buttonIndex = 0; buttonIndex < packageButtons.length; buttonIndex += 1) {
        if (packageButtons[buttonIndex] && packageButtons[buttonIndex].parentNode === strip) {
            strip.appendChild(packageButtons[buttonIndex]);
        }
    }
}

function setToolbarAltReady(isReady) {
    if (isReady && !toolbarOrderSavePending && sortablePackageButtons().length > 1) {
        addClass(document.body, "toolbar-alt-ready");
    } else {
        removeClass(document.body, "toolbar-alt-ready");
    }
}

function isLeftMouseButton(eventObject) {
    var resolvedEvent = eventObject || window.event;
    if (!resolvedEvent) {
        return false;
    }
    return resolvedEvent.which === 1 || resolvedEvent.button === 0 || resolvedEvent.button === 1;
}

function pointInsideElement(clientX, clientY, targetElement) {
    if (!targetElement) {
        return false;
    }
    var elementBounds = targetElement.getBoundingClientRect();
    return clientX >= elementBounds.left && clientX <= elementBounds.right && clientY >= elementBounds.top && clientY <= elementBounds.bottom;
}

function stopToolbarAutoScroll() {
    toolbarAutoScrollDirection = 0;
    if (toolbarAutoScrollTimer !== null) {
        window.clearInterval(toolbarAutoScrollTimer);
        toolbarAutoScrollTimer = null;
    }
}

function moveToolbarPlaceholder(clientX, clientY) {
    var strip = byId("strip");
    var packageButtons = sortablePackageButtons();
    var pointerPosition = isVerticalMode() ? clientY : clientX;
    var buttonIndex;
    var targetButton;
    var targetBounds;
    var targetMidpoint;
    if (!strip || !toolbarDragSource) {
        return;
    }
    targetButton = null;
    for (buttonIndex = 0; buttonIndex < packageButtons.length; buttonIndex += 1) {
        if (packageButtons[buttonIndex] === toolbarDragSource) {
            continue;
        }
        targetBounds = packageButtons[buttonIndex].getBoundingClientRect();
        targetMidpoint = isVerticalMode() ? targetBounds.top + ((targetBounds.bottom - targetBounds.top) / 2) : targetBounds.left + ((targetBounds.right - targetBounds.left) / 2);
        if (pointerPosition < targetMidpoint) {
            targetButton = packageButtons[buttonIndex];
            break;
        }
    }
    if (targetButton) {
        if (toolbarDragSource.nextSibling !== targetButton) {
            strip.insertBefore(toolbarDragSource, targetButton);
        }
    } else if (strip.lastChild !== toolbarDragSource) {
        strip.appendChild(toolbarDragSource);
    }
    layout();
}

function toolbarAutoScrollTick() {
    if (!toolbarDragActive || toolbarAutoScrollDirection === 0) {
        stopToolbarAutoScroll();
        return;
    }
    scrollOffset += toolbarAutoScrollDirection * toolbarAutoScrollStep;
    layout();
    moveToolbarPlaceholder(toolbarLastPointerX, toolbarLastPointerY);
}

function updateToolbarAutoScroll(clientX, clientY) {
    var viewport = byId("viewport");
    var viewportBounds;
    var pointerPosition;
    var leadingEdge;
    var trailingEdge;
    var requestedDirection = 0;
    if (!viewport || !toolbarDragActive) {
        stopToolbarAutoScroll();
        return;
    }
    viewportBounds = viewport.getBoundingClientRect();
    pointerPosition = isVerticalMode() ? clientY : clientX;
    leadingEdge = isVerticalMode() ? viewportBounds.top : viewportBounds.left;
    trailingEdge = isVerticalMode() ? viewportBounds.bottom : viewportBounds.right;
    if (pointerPosition >= leadingEdge - toolbarAutoScrollInset && pointerPosition <= leadingEdge + toolbarAutoScrollInset) {
        requestedDirection = -1;
    } else if (pointerPosition >= trailingEdge - toolbarAutoScrollInset && pointerPosition <= trailingEdge + toolbarAutoScrollInset) {
        requestedDirection = 1;
    }
    if (requestedDirection === toolbarAutoScrollDirection) {
        return;
    }
    stopToolbarAutoScroll();
    toolbarAutoScrollDirection = requestedDirection;
    if (toolbarAutoScrollDirection !== 0) {
        toolbarAutoScrollTimer = window.setInterval(toolbarAutoScrollTick, toolbarAutoScrollInterval);
    }
}

function positionToolbarDragGhost(clientX, clientY) {
    var wrap = byId("wrap");
    var wrapBounds;
    if (!wrap || !toolbarDragGhost) {
        return;
    }
    wrapBounds = wrap.getBoundingClientRect();
    toolbarDragGhost.style.left = Math.round(clientX - wrapBounds.left - toolbarDragPointerOffsetX) + "px";
    toolbarDragGhost.style.top = Math.round(clientY - wrapBounds.top - toolbarDragPointerOffsetY) + "px";
}

function startToolbarDrag(clientX, clientY) {
    var wrap = byId("wrap");
    var sourceBounds;
    var ghostButton;
    if (!toolbarDragSource || !wrap || toolbarDragActive) {
        return;
    }
    sourceBounds = toolbarDragSource.getBoundingClientRect();
    toolbarDragPointerOffsetX = toolbarDragStartX - sourceBounds.left;
    toolbarDragPointerOffsetY = toolbarDragStartY - sourceBounds.top;
    toolbarDragGhost = document.createElement("span");
    toolbarDragGhost.className = "toolbar-sort-ghost";
    toolbarDragGhost.style.width = toolbarDragSource.offsetWidth + "px";
    toolbarDragGhost.style.height = toolbarDragSource.offsetHeight + "px";
    toolbarDragGhost.setAttribute("unselectable", "on");
    ghostButton = toolbarDragSource.cloneNode(true);
    ghostButton.removeAttribute("href");
    ghostButton.removeAttribute("id");
    ghostButton.removeAttribute("title");
    ghostButton.removeAttribute("data-package-guid");
    ghostButton.removeAttribute("data-toolbar-sortable");
    ghostButton.setAttribute("unselectable", "on");
    toolbarDragGhost.appendChild(ghostButton);
    wrap.appendChild(toolbarDragGhost);
    addClass(toolbarDragSource, "toolbar-sort-placeholder");
    addClass(document.body, "toolbar-reorder-active");
    toolbarDragActive = true;
    positionToolbarDragGhost(clientX, clientY);
}

function releaseToolbarMouseCapture() {
    var captureElement = toolbarDragCaptureElement;
    toolbarDragCaptureElement = null;
    if (captureElement && captureElement.releaseCapture) {
        try {
            captureElement.releaseCapture();
        } catch (captureError) {
        }
    }
}

function clearToolbarDragState() {
    toolbarDragSource = null;
    toolbarDragOriginalButtons = null;
    toolbarDragOriginalHref = "";
    toolbarDragGhost = null;
    toolbarDragCaptureElement = null;
    toolbarDragActive = false;
    toolbarAutoScrollDirection = 0;
}

function armToolbarClickSuppression() {
    toolbarSuppressNextClick = true;
    if (toolbarSuppressClickTimer !== null) {
        window.clearTimeout(toolbarSuppressClickTimer);
    }
    toolbarSuppressClickTimer = window.setTimeout(function () {
        toolbarSuppressNextClick = false;
        toolbarSuppressClickTimer = null;
    }, 400);
}

function finishToolbarDrag(shouldSave) {
    var sourceButton = toolbarDragSource;
    var originalButtons = toolbarDragOriginalButtons;
    var originalOrder = packageGuidOrder(originalButtons || []);
    var updatedOrder;
    var orderPayload;
    var wasDragging = toolbarDragActive;
    if (!sourceButton || toolbarDragEnding) {
        return;
    }
    toolbarDragEnding = true;
    stopToolbarAutoScroll();
    if (toolbarDragGhost && toolbarDragGhost.parentNode) {
        toolbarDragGhost.parentNode.removeChild(toolbarDragGhost);
    }
    removeClass(sourceButton, "toolbar-sort-placeholder");
    if (toolbarDragOriginalHref) {
        sourceButton.setAttribute("href", toolbarDragOriginalHref);
    }
    removeClass(document.body, "toolbar-reorder-candidate");
    removeClass(document.body, "toolbar-reorder-active");
    releaseToolbarMouseCapture();
    if (!wasDragging || !shouldSave) {
        restorePackageButtonOrder(originalButtons);
    }
    updatedOrder = packageGuidOrder(sortablePackageButtons());
    if (wasDragging && shouldSave && !packageOrdersMatch(originalOrder, updatedOrder)) {
        toolbarPendingOriginalButtons = originalButtons;
        toolbarOrderSavePending = true;
        orderPayload = byId("toolbarOrderPayload");
        if (orderPayload) {
            orderPayload.innerText = updatedOrder.join("|");
        }
    }
    clearToolbarDragState();
    toolbarDragEnding = false;
    layout();
    setToolbarAltReady(false);
    armToolbarClickSuppression();
    if (toolbarOrderSavePending) {
        if (toolbarOrderSaveTimer !== null) {
            window.clearTimeout(toolbarOrderSaveTimer);
        }
        toolbarOrderSaveTimer = window.setTimeout(toolbarOrderSaved, 2000);
        window.location.href = "maxpkg://ui/set-toolbar-order";
    }
}

function toolbarOrderSaved() {
    if (toolbarOrderSaveTimer !== null) {
        window.clearTimeout(toolbarOrderSaveTimer);
        toolbarOrderSaveTimer = null;
    }
    toolbarPendingOriginalButtons = null;
    toolbarOrderSavePending = false;
    removeClass(document.body, "toolbar-order-save-failed");
}

function toolbarOrderSaveFailed() {
    if (toolbarOrderSaveTimer !== null) {
        window.clearTimeout(toolbarOrderSaveTimer);
        toolbarOrderSaveTimer = null;
    }
    restorePackageButtonOrder(toolbarPendingOriginalButtons);
    toolbarPendingOriginalButtons = null;
    toolbarOrderSavePending = false;
    addClass(document.body, "toolbar-order-save-failed");
    layout();
    window.setTimeout(function () {
        removeClass(document.body, "toolbar-order-save-failed");
    }, 1200);
}

function handleToolbarMouseDown(eventObject) {
    var resolvedEvent = eventObject || window.event;
    var sourceButton = sortablePackageButton(eventTarget(resolvedEvent));
    var sourceBounds;
    if (!sourceButton || toolbarOrderSavePending || !resolvedEvent.altKey || !isLeftMouseButton(resolvedEvent) || sortablePackageButtons().length < 2) {
        return true;
    }
    toolbarDragSource = sourceButton;
    toolbarDragOriginalButtons = sortablePackageButtons();
    toolbarDragOriginalHref = sourceButton.getAttribute("href") || "";
    toolbarDragStartX = resolvedEvent.clientX;
    toolbarDragStartY = resolvedEvent.clientY;
    toolbarLastPointerX = toolbarDragStartX;
    toolbarLastPointerY = toolbarDragStartY;
    sourceBounds = sourceButton.getBoundingClientRect();
    toolbarDragPointerOffsetX = toolbarDragStartX - sourceBounds.left;
    toolbarDragPointerOffsetY = toolbarDragStartY - sourceBounds.top;
    sourceButton.removeAttribute("href");
    toolbarDragCaptureElement = byId("wrap");
    if (toolbarDragCaptureElement && toolbarDragCaptureElement.setCapture) {
        try {
            toolbarDragCaptureElement.setCapture(true);
        } catch (captureError) {
        }
    }
    addClass(document.body, "toolbar-reorder-candidate");
    armToolbarClickSuppression();
    return cancelEvent(resolvedEvent);
}

function handleToolbarMouseMove(eventObject) {
    var resolvedEvent = eventObject || window.event;
    var deltaX;
    var deltaY;
    if (!toolbarDragSource) {
        setToolbarAltReady(!!resolvedEvent.altKey);
        return true;
    }
    toolbarLastPointerX = resolvedEvent.clientX;
    toolbarLastPointerY = resolvedEvent.clientY;
    deltaX = toolbarLastPointerX - toolbarDragStartX;
    deltaY = toolbarLastPointerY - toolbarDragStartY;
    if (!toolbarDragActive && ((deltaX * deltaX) + (deltaY * deltaY)) >= (toolbarDragThreshold * toolbarDragThreshold)) {
        startToolbarDrag(toolbarLastPointerX, toolbarLastPointerY);
    }
    if (toolbarDragActive) {
        positionToolbarDragGhost(toolbarLastPointerX, toolbarLastPointerY);
        moveToolbarPlaceholder(toolbarLastPointerX, toolbarLastPointerY);
        updateToolbarAutoScroll(toolbarLastPointerX, toolbarLastPointerY);
    }
    return cancelEvent(resolvedEvent);
}

function handleToolbarMouseUp(eventObject) {
    var resolvedEvent = eventObject || window.event;
    var shouldSave;
    if (!toolbarDragSource) {
        return true;
    }
    shouldSave = toolbarDragActive && pointInsideElement(resolvedEvent.clientX, resolvedEvent.clientY, byId("wrap"));
    finishToolbarDrag(shouldSave);
    return cancelEvent(resolvedEvent);
}

function handleToolbarClick(eventObject) {
    var resolvedEvent = eventObject || window.event;
    if (toolbarSuppressNextClick && sortablePackageButton(eventTarget(resolvedEvent))) {
        toolbarSuppressNextClick = false;
        if (toolbarSuppressClickTimer !== null) {
            window.clearTimeout(toolbarSuppressClickTimer);
            toolbarSuppressClickTimer = null;
        }
        return cancelEvent(resolvedEvent);
    }
    return true;
}

function handleToolbarKeyDown(eventObject) {
    var resolvedEvent = eventObject || window.event;
    if (resolvedEvent.keyCode === 27 && toolbarDragSource) {
        finishToolbarDrag(false);
        return cancelEvent(resolvedEvent);
    }
    if (resolvedEvent.keyCode === 18) {
        setToolbarAltReady(true);
    }
    return true;
}

function handleToolbarKeyUp(eventObject) {
    var resolvedEvent = eventObject || window.event;
    if (resolvedEvent.keyCode === 18 && !toolbarDragActive) {
        setToolbarAltReady(false);
    }
    return true;
}

function handleToolbarBlur() {
    if (toolbarDragSource) {
        finishToolbarDrag(false);
    }
    setToolbarAltReady(false);
}

function handleToolbarLostCapture() {
    if (!toolbarDragEnding && toolbarDragSource) {
        finishToolbarDrag(false);
    }
}

function handleToolbarSelectStart(eventObject) {
    if (toolbarDragSource) {
        return cancelEvent(eventObject);
    }
    return true;
}

function handleToolbarNativeDragStart(eventObject) {
    if (sortablePackageButton(eventTarget(eventObject))) {
        return cancelEvent(eventObject);
    }
    return true;
}

function initializeToolbarReorder() {
    var wrap = byId("wrap");
    if (toolbarReorderInitialized) {
        return;
    }
    toolbarReorderInitialized = true;
    bindEvent(document, "mousedown", handleToolbarMouseDown);
    bindEvent(document, "mousemove", handleToolbarMouseMove);
    bindEvent(document, "mouseup", handleToolbarMouseUp);
    bindEvent(document, "click", handleToolbarClick);
    bindEvent(document, "keydown", handleToolbarKeyDown);
    bindEvent(document, "keyup", handleToolbarKeyUp);
    bindEvent(document, "selectstart", handleToolbarSelectStart);
    bindEvent(document, "dragstart", handleToolbarNativeDragStart);
    bindEvent(window, "blur", handleToolbarBlur);
    if (wrap && wrap.attachEvent) {
        wrap.attachEvent("onlosecapture", handleToolbarLostCapture);
    } else {
        bindEvent(wrap, "losecapture", handleToolbarLostCapture);
    }
}

function toolbarMode() {
    return document.body.getAttribute("data-toolbar-mode") || "top";
}

function toolbarDensity() {
    return document.body.className.indexOf("toolbar-density-compact") >= 0 ? "compact" : "regular";
}

function isCompactMode() {
    var wrap = byId("wrap");
    return wrap && wrap.className.indexOf("wrap-compact") >= 0;
}

function isVerticalMode() {
    return toolbarMode() === "left" || toolbarMode() === "right" || toolbarMode() === "floatingvertical";
}

function stripLinks() {
    return byId("strip").getElementsByTagName("a");
}

function measureHorizontalStrip() {
    var links = stripLinks();
    var totalWidth = 0;
    var linkIndex;
    for (linkIndex = 0; linkIndex < links.length; linkIndex += 1) {
        if (linkIndex > 0) {
            totalWidth += controlGap;
        }
        totalWidth += links[linkIndex].offsetWidth;
    }
    return totalWidth;
}

function measureVerticalStrip() {
    var links = stripLinks();
    var totalHeight = 0;
    var linkIndex;
    for (linkIndex = 0; linkIndex < links.length; linkIndex += 1) {
        if (linkIndex > 0) {
            totalHeight += controlGap;
        }
        totalHeight += links[linkIndex].offsetHeight;
    }
    return totalHeight;
}

function normalizeScrollOffset(maximumOffset) {
    if (scrollOffset > maximumOffset) {
        scrollOffset = maximumOffset;
    }
    if (scrollOffset < 0) {
        scrollOffset = 0;
    }
}

function layoutCompact() {
    var wrap = byId("wrap");
    var viewport = byId("viewport");
    var strip = byId("strip");
    var vertical = isVerticalMode();
    var outerInset = toolbarDensity() === "compact" ? 1 : 5;
    var fullLength = vertical ? measureVerticalStrip() : measureHorizontalStrip();
    var availableLength = (vertical ? wrap.clientHeight : wrap.clientWidth) - (outerInset * 2);
    var maximumOffset;

    if (availableLength < 1) {
        availableLength = 1;
    }
    maximumOffset = Math.max(0, fullLength - availableLength);
    viewport.style.left = outerInset + "px";
    viewport.style.top = outerInset + "px";
    viewport.style.width = Math.max(1, wrap.clientWidth - (outerInset * 2)) + "px";
    viewport.style.height = Math.max(1, wrap.clientHeight - (outerInset * 2)) + "px";
    if (vertical) {
        strip.style.width = wrap.clientWidth + "px";
        strip.style.height = (fullLength > 0 ? fullLength : 1) + "px";
    } else {
        strip.style.width = (fullLength > 0 ? fullLength : 1) + "px";
        strip.style.height = wrap.clientHeight + "px";
    }
    normalizeScrollOffset(maximumOffset);
    strip.style.left = vertical ? "0px" : (-scrollOffset) + "px";
    strip.style.top = vertical ? (-scrollOffset) + "px" : "0px";
}

function layoutDockedHorizontal() {
    var wrap = byId("wrap");
    var viewport = byId("viewport");
    var strip = byId("strip");
    var leftArrow = byId("leftArrow");
    var rightArrow = byId("rightArrow");
    var brand = byId("brand");
    var edge = toolbarDensity() === "compact" ? 2 : 7;
    var fullWidth = measureHorizontalStrip();
    var cursor = edge;
    var rightEdge = wrap.clientWidth - edge;
    var availableWidth;
    var maximumOffset;

    brand.style.left = cursor + "px";
    cursor += brand.offsetWidth + controlGap;
    availableWidth = rightEdge - cursor;
    strip.style.width = (fullWidth > 0 ? fullWidth : 1) + "px";
    if (fullWidth > availableWidth) {
        leftArrow.style.display = "block";
        rightArrow.style.display = "block";
        leftArrow.style.left = cursor + "px";
        cursor += leftArrow.offsetWidth + controlGap;
        availableWidth = rightEdge - cursor - rightArrow.offsetWidth - controlGap;
        if (availableWidth < 20) {
            availableWidth = 20;
        }
        viewport.style.left = cursor + "px";
        viewport.style.width = availableWidth + "px";
        rightArrow.style.left = (cursor + availableWidth + controlGap) + "px";
    } else {
        leftArrow.style.display = "none";
        rightArrow.style.display = "none";
        scrollOffset = 0;
        viewport.style.left = cursor + "px";
        viewport.style.width = (availableWidth > 0 ? availableWidth : 1) + "px";
    }
    maximumOffset = Math.max(0, fullWidth - availableWidth);
    normalizeScrollOffset(maximumOffset);
    strip.style.left = (-scrollOffset) + "px";
}

function layout() {
    var wrap = byId("wrap");
    if (!wrap) {
        return;
    }
    lastLayoutWidth = wrap.clientWidth;
    lastLayoutHeight = wrap.clientHeight;
    if (isCompactMode()) {
        layoutCompact();
    } else {
        layoutDockedHorizontal();
    }
}

function monitorLayout() {
    var wrap = byId("wrap");
    if (wrap && (wrap.clientWidth !== lastLayoutWidth || wrap.clientHeight !== lastLayoutHeight)) {
        layout();
    }
}

function handleMouseWheel(eventObject) {
    var wheelEvent = eventObject || window.event;
    var wheelDelta;
    if (!isCompactMode()) {
        return true;
    }
    wheelDelta = wheelEvent.wheelDelta || (-wheelEvent.detail * 40);
    scrollOffset += wheelDelta < 0 ? 42 : -42;
    layout();
    if (wheelEvent.preventDefault) {
        wheelEvent.preventDefault();
    }
    wheelEvent.returnValue = false;
    return false;
}

function initializeLayout() {
    var wrap = byId("wrap");
    controlGap = toolbarDensity() === "compact" ? 2 : 4;
    layout();
    window.setTimeout(layout, 50);
    window.setTimeout(layout, 250);
    if (wrap) {
        wrap.onmousewheel = handleMouseWheel;
        if (wrap.addEventListener) {
            wrap.addEventListener("DOMMouseScroll", handleMouseWheel, false);
        }
    }
    if (layoutMonitor === null) {
        layoutMonitor = window.setInterval(monitorLayout, 250);
    }
    initializeToolbarReorder();
}

function moveLeft() {
    scrollOffset -= scrollStep;
    layout();
}

function moveRight() {
    scrollOffset += scrollStep;
    layout();
}

window.onload = initializeLayout;
window.onresize = layout;
