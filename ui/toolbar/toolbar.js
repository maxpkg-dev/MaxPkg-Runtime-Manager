/*
 * Measures and scrolls package buttons in the docked toolbar.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

var scrollOffset = 0;
var scrollStep = 160;

function byId(elementId) {
    return document.getElementById(elementId);
}

function measureStrip() {
    var links = byId("strip").getElementsByTagName("a");
    var totalWidth = 0;
    var linkIndex;
    for (linkIndex = 0; linkIndex < links.length; linkIndex += 1) {
        totalWidth += links[linkIndex].offsetWidth + 15;
    }
    return totalWidth;
}

function layout() {
    var wrap = byId("wrap");
    var viewport = byId("viewport");
    var strip = byId("strip");
    var leftArrow = byId("leftArrow");
    var rightArrow = byId("rightArrow");
    var brand = byId("brand");
    var edge = 7;
    var gap = 5;
    var fullWidth = measureStrip();
    var cursor = edge;
    var rightEdge = wrap.clientWidth - edge;
    var availableWidth;
    var maximumOffset;

    brand.style.left = cursor + "px";
    cursor += brand.offsetWidth + gap;
    availableWidth = rightEdge - cursor;
    strip.style.width = (fullWidth > 0 ? fullWidth : 1) + "px";
    if (fullWidth > availableWidth) {
        leftArrow.style.display = "block";
        rightArrow.style.display = "block";
        leftArrow.style.left = cursor + "px";
        cursor += leftArrow.offsetWidth + gap;
        availableWidth = rightEdge - cursor - rightArrow.offsetWidth - gap;
        if (availableWidth < 20) {
            availableWidth = 20;
        }
        viewport.style.left = cursor + "px";
        viewport.style.width = availableWidth + "px";
        rightArrow.style.left = (cursor + availableWidth + gap) + "px";
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

function moveLeft() {
    scrollOffset -= scrollStep;
    layout();
}

function moveRight() {
    scrollOffset += scrollStep;
    layout();
}

window.onload = layout;
window.onresize = layout;
