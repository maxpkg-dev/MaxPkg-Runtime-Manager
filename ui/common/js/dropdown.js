/*
 * Reusable IE9-compatible HTML dropdown component.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

(function (window, document) {
    "use strict";

    var Common = window.MaxPkgCommon;
    var activeMenu = null;
    var activeSource = null;
    var activeSelect = null;

    function sourceWidth(sourceRect) {
        return sourceRect.right - sourceRect.left;
    }

    function optionButtons(menuElement) {
        var buttons = menuElement.getElementsByTagName("button");
        var options = [];
        var buttonIndex;
        for (buttonIndex = 0; buttonIndex < buttons.length; buttonIndex += 1) {
            if (buttons[buttonIndex].getAttribute("data-dropdown-option") !== null) {
                options.push(buttons[buttonIndex]);
            }
        }
        return options;
    }

    function selectedOption(menuElement) {
        var options = optionButtons(menuElement);
        var optionIndex;
        for (optionIndex = 0; optionIndex < options.length; optionIndex += 1) {
            if (Common.hasClass(options[optionIndex], "is-selected")) {
                return options[optionIndex];
            }
        }
        return options.length ? options[0] : null;
    }

    function close() {
        if (activeMenu) {
            Common.addClass(activeMenu, "is-hidden");
        }
        if (activeSource) {
            activeSource.setAttribute("aria-expanded", "false");
        }
        if (activeSelect) {
            Common.removeClass(activeSelect, "is-open");
        }
        activeMenu = null;
        activeSource = null;
        activeSelect = null;
    }

    function open(menuElement, sourceElement, selectElement) {
        var sourceRect;
        var requestedWidth;
        var menuWidth;
        var leftPosition;
        var topPosition;
        var menuHeight;
        var focusOption;

        close();
        sourceRect = sourceElement.getBoundingClientRect();
        requestedWidth = menuElement.getAttribute("data-dropdown-width");
        menuWidth = requestedWidth === "source" ? sourceWidth(sourceRect) : parseInt(requestedWidth, 10);
        if (!menuWidth || menuWidth < 1) {
            menuWidth = 190;
        }
        leftPosition = requestedWidth === "source" ? sourceRect.left : sourceRect.right - menuWidth;
        if (leftPosition < 6) {
            leftPosition = 6;
        }
        if (leftPosition + menuWidth > document.documentElement.clientWidth - 6) {
            leftPosition = document.documentElement.clientWidth - menuWidth - 6;
        }
        topPosition = sourceRect.bottom + 4;
        menuElement.style.width = menuWidth + "px";
        menuElement.style.left = leftPosition + "px";
        menuElement.style.top = topPosition + "px";
        Common.removeClass(menuElement, "is-hidden");
        menuHeight = menuElement.offsetHeight;
        if (topPosition + menuHeight > document.documentElement.clientHeight - 6 && sourceRect.top > menuHeight + 6) {
            menuElement.style.top = (sourceRect.top - menuHeight - 4) + "px";
        }
        sourceElement.setAttribute("aria-expanded", "true");
        if (selectElement) {
            Common.addClass(selectElement, "is-open");
        }
        activeMenu = menuElement;
        activeSource = sourceElement;
        activeSelect = selectElement || null;
        focusOption = selectedOption(menuElement);
        if (focusOption) {
            focusOption.focus();
        }
    }

    function toggle(menuElement, sourceElement, selectElement) {
        if (activeMenu === menuElement) {
            close();
        } else {
            open(menuElement, sourceElement, selectElement);
        }
    }

    function selectParts(selectElement) {
        var buttons = selectElement.getElementsByTagName("button");
        var spans = selectElement.getElementsByTagName("span");
        var parts = {
            trigger: null,
            menu: null,
            label: null,
            options: []
        };
        var buttonIndex;
        var spanIndex;
        var divs;
        var divIndex;

        for (buttonIndex = 0; buttonIndex < buttons.length; buttonIndex += 1) {
            if (buttons[buttonIndex].getAttribute("data-dropdown-trigger") !== null) {
                parts.trigger = buttons[buttonIndex];
            }
            if (buttons[buttonIndex].getAttribute("data-dropdown-option") !== null) {
                parts.options.push(buttons[buttonIndex]);
            }
        }
        for (spanIndex = 0; spanIndex < spans.length; spanIndex += 1) {
            if (spans[spanIndex].getAttribute("data-select-label") !== null) {
                parts.label = spans[spanIndex];
                break;
            }
        }
        divs = selectElement.getElementsByTagName("div");
        for (divIndex = 0; divIndex < divs.length; divIndex += 1) {
            if (Common.hasClass(divs[divIndex], "html-select-menu")) {
                parts.menu = divs[divIndex];
                break;
            }
        }
        return parts;
    }

    function optionText(optionElement) {
        return optionElement.innerText || optionElement.textContent || "";
    }

    function setSelectValue(selectElement, selectedValue) {
        var parts = selectParts(selectElement);
        var optionIndex;
        var optionValue;
        var selectedLabel = selectedValue;

        selectElement.setAttribute("data-value", selectedValue);
        for (optionIndex = 0; optionIndex < parts.options.length; optionIndex += 1) {
            optionValue = parts.options[optionIndex].getAttribute("data-dropdown-option");
            Common.toggleClass(parts.options[optionIndex], "is-selected", optionValue === selectedValue);
            if (optionValue === selectedValue) {
                selectedLabel = optionText(parts.options[optionIndex]);
            }
        }
        if (parts.label) {
            parts.label.innerHTML = Common.escapeHtml(selectedLabel);
        }
        return true;
    }

    function getSelectValue(selectElement) {
        return selectElement.getAttribute("data-value") || "";
    }

    function focusRelativeOption(parts, currentOption, direction) {
        var optionIndex;
        var targetIndex = 0;
        for (optionIndex = 0; optionIndex < parts.options.length; optionIndex += 1) {
            if (parts.options[optionIndex] === currentOption) {
                targetIndex = optionIndex + direction;
                break;
            }
        }
        if (targetIndex < 0) {
            targetIndex = parts.options.length - 1;
        }
        if (targetIndex >= parts.options.length) {
            targetIndex = 0;
        }
        if (parts.options[targetIndex]) {
            parts.options[targetIndex].focus();
        }
    }

    function bindSelect(selectElement, changeHandler) {
        var parts = selectParts(selectElement);

        if (!parts.trigger || !parts.menu) {
            return false;
        }
        Common.on(parts.trigger, "click", function (eventObject) {
            Common.preventDefault(eventObject);
            Common.stopPropagation(eventObject);
            toggle(parts.menu, parts.trigger, selectElement);
        });
        Common.on(parts.trigger, "keydown", function (eventObject) {
            var keyCode = eventObject.keyCode || eventObject.which;
            if (keyCode === 13 || keyCode === 32 || keyCode === 40) {
                Common.preventDefault(eventObject);
                Common.stopPropagation(eventObject);
                open(parts.menu, parts.trigger, selectElement);
            } else if (keyCode === 27) {
                close();
            }
        });
        Common.on(parts.menu, "click", function (eventObject) {
            var optionElement = Common.closestWithAttribute(Common.eventTarget(eventObject), "data-dropdown-option");
            var selectedValue;
            if (!optionElement) {
                return;
            }
            selectedValue = optionElement.getAttribute("data-dropdown-option");
            Common.preventDefault(eventObject);
            Common.stopPropagation(eventObject);
            setSelectValue(selectElement, selectedValue);
            close();
            parts.trigger.focus();
            if (changeHandler) {
                changeHandler(selectedValue, selectElement);
            }
        });
        Common.on(parts.menu, "keydown", function (eventObject) {
            var optionElement = Common.closestWithAttribute(Common.eventTarget(eventObject), "data-dropdown-option");
            var keyCode = eventObject.keyCode || eventObject.which;
            var currentParts;
            if (!optionElement) {
                return;
            }
            if (keyCode === 38 || keyCode === 40) {
                Common.preventDefault(eventObject);
                currentParts = selectParts(selectElement);
                focusRelativeOption(currentParts, optionElement, keyCode === 38 ? -1 : 1);
            } else if (keyCode === 27) {
                Common.preventDefault(eventObject);
                close();
                parts.trigger.focus();
            } else if (keyCode === 13 || keyCode === 32) {
                Common.preventDefault(eventObject);
                optionElement.click();
            }
        });
        setSelectValue(selectElement, getSelectValue(selectElement));
        return true;
    }

    Common.on(document, "click", function () {
        close();
    });
    Common.on(window, "blur", function () {
        close();
    });
    Common.on(window, "resize", function () {
        close();
    });

    window.MaxPkgDropdown = {
        open: open,
        close: close,
        toggle: toggle,
        bindSelect: bindSelect,
        setSelectValue: setSelectValue,
        getSelectValue: getSelectValue
    };
}(window, document));
