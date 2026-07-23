/*
 * Shared IE9-compatible dialog visibility helpers.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

(function (window) {
    "use strict";

    window.MaxPkgDialog = {
        open: function (element) {
            window.MaxPkgCommon.removeClass(element, "is-hidden");
        },

        close: function (element) {
            window.MaxPkgCommon.addClass(element, "is-hidden");
        }
    };
}(window));
