/*
 * Shared IE9-compatible search and debounce helpers.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */

(function (window) {
    "use strict";

    window.MaxPkgSearch = {
        debounce: function (callback, delayMilliseconds) {
            var timeoutId = null;
            return function () {
                var callbackContext = this;
                var callbackArguments = arguments;
                window.clearTimeout(timeoutId);
                timeoutId = window.setTimeout(function () {
                    callback.apply(callbackContext, callbackArguments);
                }, delayMilliseconds);
            };
        }
    };
}(window));
