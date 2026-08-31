-- Applies Windows DPI scaling to embedded WebBrowser interfaces.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgUiScaleModule (
        logger,
        baseDpi = 96.0,
        minimumScalePercentage = 100,
        maximumScalePercentage = 300,

        fn scalePercentageFromDpi screenDpi = (
            if (screenDpi == undefined or screenDpi <= 0) do return minimumScalePercentage
            local scalePercentage = floor (((screenDpi as float) / baseDpi * 100.0) + 0.5)
            return amax minimumScalePercentage (amin maximumScalePercentage scalePercentage)
        ),

        fn browserScalePercentage browserControl = (
            if (browserControl == undefined) do return minimumScalePercentage
            local graphicsContext = undefined
            try (
                local graphicsClass = dotNetClass "System.Drawing.Graphics"
                graphicsContext = graphicsClass.FromHwnd browserControl.Handle
                local scalePercentage = scalePercentageFromDpi graphicsContext.DpiX
                graphicsContext.Dispose()
                return scalePercentage
            ) catch (
                try (
                    if (graphicsContext != undefined) do graphicsContext.Dispose()
                ) catch (
                )
                if (logger != undefined) do logger.logWarning "ui-scale" ("Could not detect browser DPI: " + getCurrentException())
                return minimumScalePercentage
            )
        ),

        fn applyBrowserScale browserControl constrainViewport: false = (
            if (browserControl == undefined or browserControl.Document == undefined) do return false
            try (
                local scalePercentage = browserScalePercentage browserControl
                local documentBody = browserControl.Document.Body
                if (documentBody == undefined) do return false
                if (scalePercentage == minimumScalePercentage) then (
                    documentBody.Style = ""
                    if (constrainViewport) do documentBody.SetAttribute "className" ""
                ) else (
                    local browserStyle = "zoom: " + (scalePercentage as string) + "%;"
                    if (constrainViewport) do (
                        local inverseScalePercentage = 10000.0 / scalePercentage
                        local effectiveBrowserWidth = floor ((((browserControl.ClientSize.Width as float) * 100.0) / scalePercentage) + 0.5)
                        local responsiveClassNames = ""
                        if (effectiveBrowserWidth < 1200) do responsiveClassNames += " maxpkg-viewport-under-1200"
                        if (effectiveBrowserWidth < 900) do responsiveClassNames += " maxpkg-viewport-under-900"
                        if (effectiveBrowserWidth < 760) do responsiveClassNames += " maxpkg-viewport-under-760"
                        if (effectiveBrowserWidth < 740) do responsiveClassNames += " maxpkg-viewport-under-740"
                        if (effectiveBrowserWidth < 720) do responsiveClassNames += " maxpkg-viewport-under-720"
                        if (effectiveBrowserWidth < 540) do responsiveClassNames += " maxpkg-viewport-under-540"
                        browserStyle += " width: " + (inverseScalePercentage as string) + "%; height: " + (inverseScalePercentage as string) + "%;"
                        documentBody.SetAttribute "className" responsiveClassNames
                    )
                    documentBody.Style = browserStyle
                )
                return true
            ) catch (
                if (logger != undefined) do logger.logWarning "ui-scale" ("Could not apply browser DPI scale: " + getCurrentException())
                return false
            )
        )
    )

    MaxPkgUiScaleModule()
)
