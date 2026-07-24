/*
 * Measures and scrolls package buttons in the docked toolbar.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

var scrollOffset = 0;
var scrollStep = 160;
var controlGap = 4;
var lastLayoutWidth = -1;
var layoutMonitor = null;

function byId(elementId) {
    return document.getElementById(elementId);
}

function measureStrip() {
    var links = byId("strip").getElementsByTagName("a");
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

function layout() {
    var wrap = byId("wrap");
    if (!wrap) {
        return;
    }
    var viewport = byId("viewport");
    var strip = byId("strip");
    var leftArrow = byId("leftArrow");
    var rightArrow = byId("rightArrow");
    var brand = byId("brand");
    var edge = 7;
    var fullWidth = measureStrip();
    var cursor = edge;
    var rightEdge = wrap.clientWidth - edge;
    var availableWidth;
    var maximumOffset;

    lastLayoutWidth = wrap.clientWidth;
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
    if (scrollOffset > maximumOffset) {
        scrollOffset = maximumOffset;
    }
    if (scrollOffset < 0) {
        scrollOffset = 0;
    }
    strip.style.left = (-scrollOffset) + "px";
}

function monitorLayout() {
    var wrap = byId("wrap");
    if (wrap && wrap.clientWidth !== lastLayoutWidth) {
        layout();
    }
}

function initializeLayout() {
    layout();
    window.setTimeout(layout, 50);
    window.setTimeout(layout, 250);
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
