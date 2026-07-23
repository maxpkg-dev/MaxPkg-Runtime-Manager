# MaxPkg Runtime

MaxPkg is a package manager for Autodesk 3ds Max. It provides one place to
discover, install, launch, update, and remove scripts without managing separate
installers and script folders manually.

MaxPkg Runtime connects 3ds Max to the package catalog on
[maxpkg.dev](https://maxpkg.dev) and keeps installed tools available from the
Manager and the optional MaxPkg toolbar.

## Requirements

- Autodesk 3ds Max 2027
- Internet access for discovering, installing, and updating packages

Already installed packages remain available when the service is offline.

## Features

- Browse and search the MaxPkg package catalog
- Install compatible packages directly from 3ds Max
- Launch installed scripts from one Manager
- Check for package updates
- View package descriptions, versions, changelogs, licenses, and Help links
- Add package buttons to the dockable MaxPkg toolbar
- Configure toolbar button size and secondary text
- Hide individual packages from the toolbar
- Open an installed package folder
- Remove packages and their generated MacroScript actions
- Use a MaxPkg Manager action on any standard 3ds Max toolbar

## Installation

1. Download and extract the MaxPkg Runtime archive.
2. In 3ds Max, open `Scripting > Run Script`.
3. Select `install.ms`.
4. Wait for the installation confirmation.

Runtime is installed into the current 3ds Max user scripts directory and starts
automatically with 3ds Max.

The installer also registers a `MaxPkg Manager` action in the `MaxPkg`
category. You can place this action on any toolbar through
`Customize > Customize User Interface`.

## Opening MaxPkg Manager

Open the Manager using one of these methods:

- Click the MaxPkg button on the dockable MaxPkg toolbar.
- Use the `MaxPkg Manager` action added through Customize User Interface.
- Run this command in MAXScript Listener:

```maxscript
maxpkg.openManager()
```

## Discovering and installing packages

1. Open MaxPkg Manager.
2. Select the `Discover` tab.
3. Enter a package name in the search field.
4. Open package Details to review its description, version, compatibility,
   changelog, license, and available links.
5. Click `Install`.

The package becomes available in the `Installed` tab after installation.

Packages can also provide a small `maxpkg-install` script on the MaxPkg website.
Drag that script into a 3ds Max viewport to install the required package.

## Working with installed packages

The `Installed` tab lets you:

- Run a package
- Open its Details
- Check its version and developer
- Open its installation folder
- Show or hide it on the MaxPkg toolbar
- Open its Help, homepage, support, or license link when provided
- Update it when a newer compatible version is available
- Uninstall it

Click a package icon, name, version, or developer to open its Details.

## Toolbar settings

Open `Settings > Toolbar` to:

- Enable or disable the dockable MaxPkg toolbar
- Select what appears below a package name: nothing, version, or developer
- Select a button size: large, medium, small, or icon only
- Reset the package button order

Disabling the dockable toolbar does not remove the `MaxPkg Manager` action from
3ds Max. You can keep that action on any toolbar of your choice.

## Updates

Use `Check Updates` in the Manager header to check installed packages.

Automatic package and Runtime update checks can be configured in
`Settings > Updates`.

## Advanced installation command

A package can be installed by GUID, slug, or supported package reference from
MAXScript Listener:

```maxscript
maxpkg.install "prune-scene"
```

The command returns a status object containing `success`, `errorCode`, and
`errorMessage`.

## Uninstalling MaxPkg Runtime

Run `uninstall.ms` from the installed `MaxPkg Runtime` directory inside the
current 3ds Max user scripts folder.

The uninstaller removes:

- Runtime files
- The automatic startup script
- The MaxPkg Manager MacroScript action
- The dockable MaxPkg toolbar and open Manager window

Installed package data is handled separately by each package uninstaller.

## Troubleshooting

If the Manager or toolbar does not open:

1. Close and restart 3ds Max.
2. Run `install.ms` again to repair the Runtime installation.
3. Check `logs/maxpkg.log` inside the installed MaxPkg Runtime directory.

When reporting a problem, include:

- Your 3ds Max version
- The Runtime version shown in Manager
- The steps that reproduce the problem
- The relevant lines from `maxpkg.log`

## Links

- Website and package catalog: [maxpkg.dev](https://maxpkg.dev)
- Developed by [3DGROUND](https://3dground.net)

Copyright (c) 2026 Lukianenko Vasyl.
