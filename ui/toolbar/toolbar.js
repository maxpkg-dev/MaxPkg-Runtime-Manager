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

function byId(elementId) {
    return document.getElementById(elementId);
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
