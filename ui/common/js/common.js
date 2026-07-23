/*
 * Shared IE9-compatible DOM and encoding helpers.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

(function (window, document) {
    "use strict";

    var Common = {};

    Common.byId = function (elementId) {
        return document.getElementById(elementId);
    };

    Common.on = function (element, eventName, handler) {
        if (!element) {
            return;
        }
        if (element.addEventListener) {
            element.addEventListener(eventName, handler, false);
        } else if (element.attachEvent) {
            element.attachEvent("on" + eventName, handler);
        }
    };

    Common.eventTarget = function (eventObject) {
        return eventObject.target || eventObject.srcElement;
    };

    Common.preventDefault = function (eventObject) {
        if (eventObject.preventDefault) {
            eventObject.preventDefault();
        }
        eventObject.returnValue = false;
    };

    Common.stopPropagation = function (eventObject) {
        if (eventObject.stopPropagation) {
            eventObject.stopPropagation();
        }
        eventObject.cancelBubble = true;
    };

    Common.hasClass = function (element, className) {
        if (!element) {
            return false;
        }
        return (" " + element.className + " ").indexOf(" " + className + " ") >= 0;
    };

    Common.addClass = function (element, className) {
        if (element && !Common.hasClass(element, className)) {
            element.className = element.className ? element.className + " " + className : className;
        }
    };

    Common.removeClass = function (element, className) {
        var expression;
        if (!element) {
            return;
        }
        expression = new RegExp("(^|\\s)" + className + "(?=\\s|$)", "g");
        element.className = element.className.replace(expression, " ").replace(/^\s+|\s+$/g, "");
    };

    Common.toggleClass = function (element, className, isEnabled) {
        if (isEnabled) {
            Common.addClass(element, className);
        } else {
            Common.removeClass(element, className);
        }
    };

    Common.closestWithAttribute = function (element, attributeName) {
        while (element && element !== document.body) {
            if (element.getAttribute && element.getAttribute(attributeName) !== null) {
                return element;
            }
            element = element.parentNode;
        }
        return null;
    };

    Common.escapeHtml = function (sourceText) {
        var text = sourceText === null || sourceText === undefined ? "" : String(sourceText);
        return text.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;");
    };

    Common.encode = function (sourceText) {
        return encodeURIComponent(sourceText === null || sourceText === undefined ? "" : String(sourceText));
    };

    Common.copyText = function (sourceText) {
        if (window.clipboardData && window.clipboardData.setData) {
            return window.clipboardData.setData("Text", sourceText);
        }
        return false;
    };

    window.MaxPkgCommon = Common;
}(window, document));
