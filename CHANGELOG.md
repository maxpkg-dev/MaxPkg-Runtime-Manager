# Changelog

## 1.1.8

- Added: Compact Top, Bottom, Left, and Right toolbar modes use space-saving icon-only buttons.
- Added: Floating Horizontal and Floating Vertical toolbars can be moved freely and restore their saved positions.
- Added: Setup Toolbar opens toolbar settings directly, while Reset Toolbar safely restores a lost or modified toolbar.
- Fixed: Floating toolbars open in a visible centered position after reset and stay above 3ds Max without covering other applications.
- Fixed: Vertical toolbar content now follows the docked panel size without being clipped.
- Changed: The MaxPkg Manager button is always the first toolbar button, including every compact mode.

## 1.1.7

- Fixed: Manager and toolbar now remain correctly sized and readable when Windows interface scaling is enabled.
- Fixed: Manager content stays centered, fills the resized window, and keeps package cards separated at responsive widths.
- Changed: Settings checkboxes now use clear green toggle switches across all Manager themes.

## 1.1.6

- Added: Discover now shows package categories in a dedicated sidebar on wide Manager windows and automatically switches to a compact dropdown on smaller windows.
- Changed: Discover package sorting now offers Popular, Newest, Rating, Downloads, and Name beside search, with active category and sorting choices highlighted and easy to reset.

## 1.1.5

- Fixed: Accidentally switch to CURL method on script start.

## 1.1.4

- Added: Featured packages and curated collections now appear as quick filters in Discover.
- Added: Discover categories can filter compatible packages and show current package counts.
- Fixed: Release builds can read `version.ini` in both supported text encodings.
- Changed: Discover hides collection and category controls when their data is unavailable, while the package catalog remains usable.

## 1.1.3

- Added: The MaxPkg toolbar button now shows how many installed packages have updates available.
- Added: Package updates are checked in the background without requiring the Manager to be opened, and the last known count is restored between 3ds Max sessions.
- Changed: Manual package update checks now run in the background and refresh the Manager and toolbar when complete.
- Changed: Manager themes now use a simpler linear background gradient for more consistent rendering in older 3ds Max versions.

## 1.1.2

- Added: Package changelogs are now grouped by version with release dates shown beside each group.
- Fixed: Package cards keep a consistent height and shortened descriptions end with three dots.
- Fixed: Details headers, pathways, action buttons, and link rows remain readable at smaller Manager widths.
- Changed: Manager pages now use a cleaner translucent design with updated theme colors and background gradients.
- Changed: Package Details now uses a clearer two-column layout with package information, purchase guidance, and related links organized into dedicated sections.

## 1.1.1

- Fixed: Runtime self-updates and release links now use the renamed MaxPkg Runtime Manager GitHub repository.

## 1.1.0

- Added: Manager and toolbar themes can now be selected independently from the new Themes settings section.
- Added: Five ready-to-use theme sets: 3ds Max Dark, Midnight Blue, Forest Green, Light Studio, and Violet Night.
- Added: Additional theme INI files are discovered automatically and safely fall back to Default when incomplete or unavailable.
- Fixed: Changelog badges now use clear colors for Added, Fixed, Improved, Changed, and Removed entries.
- Fixed: Light Studio buttons and MaxPkg logos now remain easy to read on light backgrounds.
- Changed: Installation and removal windows now follow the selected Manager theme.
- Changed: Runtime installation and updates include built-in themes while preserving additional user themes.

## 1.0.9

- Added: Automatic CURL fallback keeps online features working when 3ds Max network access through .NET is blocked by a firewall.
- Added: Discover cards now show download counts, ratings, review counts, and the purchase action selected by the package developer.
- Added: Manager footer now includes a direct link to maxpkg.dev.
- Fixed: Image cache cleanup no longer reports DateTime comparison errors and keeps its disk usage bounded.
- Fixed: Discover cards now keep equal spacing along the left and right sides of the catalog.
- Changed: Catalog images now download through a small background CURL queue so the Manager remains responsive.
- Changed: CURL mode remains active for the current 3ds Max session and is clearly identified as a slower fallback in the status bar.
- Changed: Runtime logs are cleaned between 3ds Max sessions and limited in size.

## 1.0.8

- Fixed: Removing a package now also cleans up its generated actions, Quad Menu commands, and Quad Menu startup file.
- Fixed: Package card descriptions now end with three dots when all five lines do not fit.
- Changed: Windows notifications now use matching Information and Error icons.

## 1.0.7

- Added: MaxPkg Runtime Manager can now be downloaded and installed as a single MZP package.
- Changed: Manual installation now starts by dragging the downloaded MZP into a 3ds Max viewport.
- Changed: Runtime files are now kept in the 3ds Max temporary MaxPkg-Runtime-Manager folder instead of the user scripts folder.

## 1.0.6

- Added: Installed packages can now be filtered by toolbar visibility using All, In toolbar, and Hidden options.
- Added: Hidden packages now display a crossed-out eye indicator on their cards.
- Fixed: Toolbar order and visibility settings no longer fail when their saved lists are empty.
- Changed: Active filters and custom sorting are highlighted and can be reset with a single click.
- Changed: Drag-and-drop toolbar ordering now works in Installed, Updates, and filtered package views while preserving the position of other packages.
- Changed: Open Folder, Copy GUID, and Copy Path actions are now shown only in Developer mode.

## 1.0.5

- Added: Purchase buttons now use the action label selected by the package developer.

## 1.0.4

- Fixed: Automatic Runtime updates can now replace existing and read-only Runtime files.

## 1.0.3

- Fixed: Drag-and-drop placeholder now matches the size of compact Installed cards.

## 1.0.2

- Added: Setting to switch Installed package views between compact and full cards.
- Changed: Discover, Installed, Updates, and In toolbar now use one clear navigation level.
- Changed: Search now appears below the navigation and follows the currently selected section.
- Changed: Installed, Updates, and In toolbar use compact cards without descriptions and badges by default.

## 1.0.1

- Added: Discover catalog for finding and installing packages directly inside 3ds Max.
- Added: Online package details with descriptions, screenshots, changelogs, license, Help, support, purchase, and developer links.
- Added: Offline package information fallback from the installed manifest when the Runtime API is unavailable.
- Added: Windows notifications after package installation and removal.
- Added: Drag-and-drop package ordering for the MaxPkg toolbar.
- Added: Toolbar position, button size, primary text, and secondary text settings.
- Added: Friendly Runtime installation and removal windows with a quick start guide.
- Added: Runtime uninstall section in Manager Settings.
- Added: Package purchase indicators and a clear Buy action when the developer provides a purchase link.
- Fixed: Package search accepts natural names with spaces and different word order.
- Fixed: Runtime and package removal clear read-only file attributes and clean generated 3ds Max actions.
- Fixed: Manager and toolbar compatibility issues affecting older supported 3ds Max versions.
- Changed: Runtime API configuration now uses one base endpoint with the official service as its built-in fallback.
- Changed: Package details prefer current online information while preserving installed manifest data for offline use.
- Changed: Settings save immediately without separate Save or Cancel buttons.
- Improved: Manager layout, dropdowns, notifications, gallery, buttons, icons, spacing, and small-window behavior.
- Improved: README now explains installation and everyday use in simpler language for 3D artists.

## 1.0.0

- Added: First public MaxPkg Runtime release for Autodesk 3ds Max 2012 and newer.
- Added: Package scanning, installation, launching, updating, and removal through one `MaxPkg` interface.
- Added: Manager for viewing installed packages, searching, opening details, running tools, and managing updates.
- Added: Dockable MaxPkg toolbar with package buttons and per-package visibility controls.
- Added: Automatic Runtime startup and safe repeated Runtime restarts during development.
- Added: MaxPkg Manager action for Customize User Interface and generated actions for installed packages.
- Added: Offline-first package operation with local manifests, persistent settings, and Runtime logs.
- Added: Safe package and Runtime uninstallers that remove startup files, generated actions, and copied icons.
- Added: Initial smoke tests and compatibility rules for supported 3ds Max versions.
