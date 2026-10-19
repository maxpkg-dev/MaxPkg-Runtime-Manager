/*
 * Applies onboarding state and sends explicit user actions to Runtime.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */
(function (window, document) {
    "use strict";
    var Common = window.MaxPkgCommon;
    function readPayload(elementId) {
        var element = Common.byId(elementId);
        return element.innerText || element.textContent || "";
    }
    function selectChoice(elementId, isSelected) {
        var element = Common.byId(elementId);
        Common.toggleClass(element, "is-selected", isSelected);
        element.setAttribute("aria-checked", isSelected ? "true" : "false");
    }
    window.setOnboardingState = function () {
        var state = JSON.parse(readPayload("onboardingPayload"));
        selectChoice("automaticUpdates", state.mode === "automatic");
        selectChoice("manualUpdates", state.mode === "manual");
        Common.byId("onboardingError").innerText = state.error || "";
        Common.toggleClass(Common.byId("onboardingError"), "is-hidden", !state.error);
        if (state.error) {
            Common.byId("onboardingError").scrollIntoView(false);
        }
    };
    window.setOnboardingTheme = function () {
        var styleElement = Common.byId("onboardingTheme");
        var cssContent = readPayload("themePayload");
        var images = document.getElementsByTagName("img");
        var iconRoot = Common.byId("themePayload").getAttribute("data-icon-root");
        var imageIndex;
        if (styleElement.styleSheet) {
            styleElement.styleSheet.cssText = cssContent;
        } else {
            styleElement.textContent = cssContent;
        }
        for (imageIndex = 0; imageIndex < images.length; imageIndex += 1) {
            if (images[imageIndex].getAttribute("data-icon")) {
                images[imageIndex].src = iconRoot + images[imageIndex].getAttribute("data-icon") + ".svg";
            }
        }
    };
    function chooseMode(modeName) {
        window.location.href = "maxpkg://onboarding/updates/" + modeName;
    }
    Common.on(Common.byId("automaticUpdates"), "click", function () { chooseMode("automatic"); });
    Common.on(Common.byId("manualUpdates"), "click", function () { chooseMode("manual"); });
    Common.on(document, "keydown", function (eventObject) {
        var keyCode = eventObject.keyCode || eventObject.which;
        var target = eventObject.target || eventObject.srcElement;
        if (keyCode === 27) {
            Common.preventDefault(eventObject);
            eventObject.cancelBubble = true;
        } else if (target && (target.id === "automaticUpdates" || target.id === "manualUpdates") && (keyCode === 37 || keyCode === 39 || keyCode === 38 || keyCode === 40)) {
            Common.preventDefault(eventObject);
            var useAutomatic = keyCode === 37 || keyCode === 38;
            Common.byId(useAutomatic ? "automaticUpdates" : "manualUpdates").focus();
            chooseMode(useAutomatic ? "automatic" : "manual");
        }
    });
}(window, document));
