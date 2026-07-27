/*
 * Controls expandable Quick Guide sections in the Runtime result rollout.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

(function () {
    "use strict";

    function setExpanded(toggleButton, isExpanded) {
        var panelId = toggleButton.getAttribute("data-guide-toggle");
        var panelElement = document.getElementById(panelId);
        var entryElement = toggleButton.parentNode;

        toggleButton.setAttribute("aria-expanded", isExpanded ? "true" : "false");
        toggleButton.className = isExpanded ? "quick-guide-toggle is-active" : "quick-guide-toggle";
        entryElement.className = isExpanded ? "quick-guide-entry is-expanded" : "quick-guide-entry";
        panelElement.className = isExpanded ? "quick-guide-panel" : "quick-guide-panel is-hidden";
    }

    function handleGuideToggle() {
        var toggleButtons = document.querySelectorAll("[data-guide-toggle]");
        var selectedButton = this;
        var shouldExpand = selectedButton.getAttribute("aria-expanded") !== "true";
        var buttonIndex;

        for (buttonIndex = 0; buttonIndex < toggleButtons.length; buttonIndex += 1) {
            setExpanded(toggleButtons[buttonIndex], toggleButtons[buttonIndex] === selectedButton && shouldExpand);
        }
    }

    function initializeQuickGuide() {
        var toggleButtons = document.querySelectorAll("[data-guide-toggle]");
        var buttonIndex;

        for (buttonIndex = 0; buttonIndex < toggleButtons.length; buttonIndex += 1) {
            toggleButtons[buttonIndex].onclick = handleGuideToggle;
        }
    }

    initializeQuickGuide();
}());
