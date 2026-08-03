# Changelog

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
