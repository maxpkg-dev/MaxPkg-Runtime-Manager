-- Shows reusable Windows notifications for Runtime operations.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    struct MaxPkgNotifierModule (
        logger,
        notificationIcon,
        notificationTimer,

        fn handleTimerTick timerSender eventArgs = (
            if (notificationTimer != undefined) do notificationTimer.Stop()
            if (notificationIcon != undefined) do notificationIcon.Visible = false
            return true
        ),

        fn initialize = (
            if (notificationIcon != undefined and notificationTimer != undefined) do return true
            try (
                local systemIconsClass = dotNetClass "System.Drawing.SystemIcons"
                notificationIcon = dotNetObject "System.Windows.Forms.NotifyIcon"
                notificationIcon.Icon = systemIconsClass.Information
                notificationIcon.Text = "MaxPkg"
                notificationTimer = dotNetObject "System.Windows.Forms.Timer"
                notificationTimer.Interval = 6500
                dotNet.addEventHandler notificationTimer "Tick" handleTimerTick
                return true
            ) catch (
                if (logger != undefined) do logger.logWarning "notification" ("Could not initialize NotifyIcon: " + getCurrentException())
                notificationIcon = undefined
                notificationTimer = undefined
                return false
            )
        ),

        fn showNotification notificationContent notificationTitle: "MaxPkg" isError: false = (
            if (not (initialize())) do return false
            local displayContent = notificationContent as string
            if (displayContent.count > 240) do displayContent = (substring displayContent 1 237) + "..."
            try (
                local systemIconsClass = dotNetClass "System.Drawing.SystemIcons"
                local tooltipIconClass = dotNetClass "System.Windows.Forms.ToolTipIcon"
                notificationTimer.Stop()
                notificationIcon.Icon = if (isError) then systemIconsClass.Error else systemIconsClass.Information
                notificationIcon.BalloonTipTitle = notificationTitle
                notificationIcon.BalloonTipText = displayContent
                notificationIcon.BalloonTipIcon = if (isError) then tooltipIconClass.Error else tooltipIconClass.Info
                notificationIcon.Visible = true
                notificationIcon.ShowBalloonTip 5000
                notificationTimer.Start()
                return true
            ) catch (
                if (logger != undefined) do logger.logWarning "notification" ("Could not show NotifyIcon message: " + getCurrentException())
                return false
            )
        ),

        fn shutdown = (
            try (
                if (notificationTimer != undefined) do (
                    notificationTimer.Stop()
                    notificationTimer.Dispose()
                    notificationTimer = undefined
                )
                if (notificationIcon != undefined) do (
                    notificationIcon.Visible = false
                    notificationIcon.Dispose()
                    notificationIcon = undefined
                )
                return true
            ) catch (
                notificationTimer = undefined
                notificationIcon = undefined
                return false
            )
        )
    )

    MaxPkgNotifierModule()
)
