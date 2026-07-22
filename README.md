# MaxPkg Runtime 1.0

Offline-first package runtime for 3ds Max 2012 and newer. It is compatible with
the real package output produced by the neighboring `max-dev-tool` project and
also accepts the field names from the Runtime technical specification.

## Install

Run `install.ms` once from 3ds Max. It copies the Runtime to the current user
scripts directory, creates a small startup shim in `#userStartupScripts`, loads
the Runtime, scans installed packages, and opens the docked toolbar.

For development, run `startup.ms` directly from this folder. It can be run
repeatedly: the previous Runtime closes Manager, unregisters and destroys its
toolbar, and then a new Runtime instance is loaded and started.

## Package discovery

The scanner checks:

- `getDir #temp` for packages extracted by current MaxPkg MZP installers;
- `data/packages` for persistent packages;
- extra roots configured in `data/settings.ini`.

The packager's actual keys are supported: `packageGuid`, `name`, `version`,
`entry`, `developerName`, `icon`, `showInToolbar`, and `uninstallScript`.
Aliases such as `Guid`, `Runtime`, `ToolbarVisible`, and `ToolbarOrder` are also
accepted. Runtime type is inferred from `.ms`, `.mse`, or `.py` when omitted.

## Public API

The only explicitly global value is `MaxPkg`:

```maxscript
MaxPkg.start()
MaxPkg.shutdown()
MaxPkg.isStarted()
MaxPkg.scan()
MaxPkg.openManager()
MaxPkg.run "package-guid-or-slug"
MaxPkg.install "C:\\Downloads\\package.mzp"
MaxPkg.uninstall "package-guid-or-slug"
MaxPkg.checkUpdates()
MaxPkg.updateAll()
MaxPkg.selfUpdate()
MaxPkg.packageInstalled "package-guid"
MaxPkg.packageRemoved "package-guid"
MaxPkg.rebuildToolbar()
MaxPkg.isBusy()
```

State is exposed as `MaxPkg.version`, `MaxPkg.packages`, `MaxPkg.settings`, and
`MaxPkg.operation`.

## Toolbar state

The dockable WebBrowser toolbar is built only from `MaxPkg.packages`. User state
is stored separately in `data/settings.ini`:

```ini
[Toolbar]
Visible=true
Hidden=guid-one|guid-two
Order=guid-two|guid-one

[Packages]
Roots=D:\\MaxPkg Packages|E:\\Studio Tools
```

Package manifests are never modified for toolbar preferences.

## Batch update contract

Update networking is disabled until URLs are configured, so startup and all
local features remain fully offline. Configure endpoints as follows:

```ini
[Updates]
BatchUrl=https://example.test/api/runtime/updates
RuntimeUrl=https://example.test/downloads/maxpkg-runtime.mzp
FrequencyHours=24
Notifications=true
```

`BatchUrl` receives one form field named `packages`, containing comma-separated
`guid@version` pairs. Its response is INI so it remains parseable on 3ds Max
2012 without a JSON dependency:

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
