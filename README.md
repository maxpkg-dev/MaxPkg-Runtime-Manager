# MaxPkg Runtime 1.0

Offline-first package runtime for 3ds Max 2012 and newer. It is compatible with
the real package output produced by the neighboring `max-dev-tool` project and
also accepts the field names from the Runtime technical specification.

## Install

Run `install.ms` once from 3ds Max. It copies the Runtime to the current user
scripts directory, creates a small startup shim in `#userStartupScripts`, loads
the Runtime, scans installed packages, and opens the docked toolbar.
Installation also registers a `MaxPkg Manager` action in the `MaxPkg` category.
The user can place this action on any 3ds Max toolbar through Customize User
Interface without enabling the docked Runtime toolbar.

Run the installed `uninstall.ms` to remove Runtime, its startup shim, and its
Manager MacroScript. Runtime and package uninstallers clear read-only file
attributes before deletion. Package uninstall also removes the generated
`maxpkg-<GUID>.mcr` file and copied package icon from the current 3ds Max
profile.

For development, run `startup.ms` directly from this folder. It can be run
repeatedly: the previous Runtime closes Manager, unregisters and destroys its
toolbar, and then a new Runtime instance is loaded and started.

## Package discovery

The scanner checks:

- `getDir #temp` for packages extracted by current MaxPkg MZP installers;
- `data/packages` for persistent packages;
- extra roots configured in `settings.ini`.

The packager's actual keys are supported: `packageGuid`, `name`, `version`,
`entry`, `developerName`, `icon`, `documentation`, `showInToolbar`, and
`uninstallScript`.
Aliases such as `Guid`, `Runtime`, `ToolbarVisible`, and `ToolbarOrder` are also
accepted. Runtime type is inferred from `.ms`, `.mse`, or `.py` when omitted.

## Public API

The Runtime exposes one global facade named `MaxPkg`. MaxScript identifiers are
case-insensitive, so `MaxPkg` and `maxpkg` resolve to that same global object.
Both spellings are supported in Listener and script code:

```maxscript
maxpkg.install "prune scene"
MaxPkg.install "prune scene"
```

The facade provides:

```maxscript
MaxPkg.start()
MaxPkg.shutdown()
MaxPkg.isStarted()
MaxPkg.scan()
MaxPkg.openManager()
MaxPkg.getPackages()
MaxPkg.getPackage "package-guid-or-slug"
MaxPkg.getSettings()
MaxPkg.saveSettings()
MaxPkg.getStatus()
MaxPkg.run "package-guid-or-slug"
MaxPkg.install "C:\\Downloads\\package.mzp"
MaxPkg.uninstall "package-guid-or-slug"
MaxPkg.checkUpdates()
MaxPkg.updateAll()
MaxPkg.updatePackage "package-guid-or-slug"
MaxPkg.selfUpdate()
MaxPkg.setToolbarVisible "package-guid-or-slug" true
MaxPkg.resetToolbarOrder()
MaxPkg.openPackageFolder "package-guid-or-slug"
MaxPkg.openPackageLink "package-guid-or-slug" "homepage"
MaxPkg.openPackageHelp "package-guid-or-slug"
MaxPkg.packageInstalled "package-guid"
MaxPkg.packageRemoved "package-guid"
MaxPkg.rebuildToolbar()
MaxPkg.isBusy()
```

State is exposed as `MaxPkg.version`, `MaxPkg.packages`, `MaxPkg.settings`, and
`MaxPkg.operation`.

## Toolbar state

The dockable WebBrowser toolbar is built only from `MaxPkg.packages`. User state
is stored separately in `settings.ini`:

```ini
[Toolbar]
Visible=true
Hidden=guid-one|guid-two
Order=guid-two|guid-one
SubtitleMode=version
ButtonSize=medium

[Packages]
Roots=D:\\MaxPkg Packages|E:\\Studio Tools
```

Package manifests are never modified for toolbar preferences.
`Toolbar.SubtitleMode` accepts `none`, `version`, or `developer`.
`Toolbar.ButtonSize` accepts `large`, `medium`, `small`, or `icon`.

## Manager UI

The Manager is an IE9-compatible HTML application hosted by the 3ds Max
WebBrowser control. It opens at 900x650 by default, is resizable, and remembers
its size and position. Its minimum size is 720x520, and restored bounds are
kept inside the working area of the selected monitor. Installed packages,
search, filtering, details, toolbar visibility, update actions, and Settings
operate through the Runtime facade.

Package Details expose normalized manifest metadata including release channel
and date, license, supported 3ds Max versions, entry file, packager, changelog,
homepage, documentation, support, and license links when provided.

The Manager loads its design system from `ui/common` and uses local SVG icons.
It intentionally uses ES5 JavaScript and float/inline-block/absolute CSS rather
than Flexbox, Grid, CSS custom properties, or network-hosted assets.

Discover shows an explicit offline/unconfigured state until a catalog response
contract is added to Runtime. The configured API endpoint is used for Runtime
and installed-package update requests; it is not treated as a package store.

## Runtime API endpoint

Runtime uses one base endpoint and appends the required API action. The
production fallback is hardcoded as `https://maxpkg.dev/api/runtime/v1/`, so a
new installation does not need to store an endpoint in `settings.ini`.

`settings.ini` contains this section only when an installer or developer
provides an override:

```ini
[Endpoint]
BaseUrl=http://192.168.1.4:3000/api/runtime/v1/

[Updates]
FrequencyHours=24
Notifications=true
```

Without an override, the resulting update URLs are
`https://maxpkg.dev/api/runtime/v1/updates` and
`https://maxpkg.dev/api/runtime/v1/runtime`. The base endpoint is hidden from
regular users. Enable Developer mode in Manager settings to expose the Endpoint
section.

The `updates` action receives one form field named `packages`, containing
comma-separated `guid@version` pairs. Its response is INI so it remains
parseable on 3ds Max 2012 without a JSON dependency:

```ini
[package-guid]
Version=1.2.0
DownloadUrl=https://example.test/downloads/package.mzp
```

The exact production API was not present in the supplied specification. This
contract is deliberately isolated in `core/updater.ms` and can be adapted
without changing scanning, toolbar, launch, or installation code.

## Logs

Errors and lifecycle events are appended to `logs/maxpkg.log`. A malformed
package is logged and skipped without aborting the remaining scan.
