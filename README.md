# MaxPkg Runtime Manager

## Your 3ds Max scripts, all in one place

MaxPkg makes working with scripts feel simple. Find the tool you need, install
it, and start using it without copying files by hand or figuring out where
each script belongs.

Everything is available inside 3ds Max:

- Find scripts in the MaxPkg catalog
- See what is already installed
- Install, update, or remove a script in a few clicks
- Read descriptions, view screenshots, and check changelogs
- Keep your favorite tools close on the MaxPkg toolbar

MaxPkg stays out of your way. Most actions happen quietly, with a small
notification when they are done.

## The easiest way to install

1. Visit [maxpkg.dev](https://maxpkg.dev) and find a script you like.
2. Click `Install`.
3. Drag the installer block from the website into a 3ds Max viewport.

That is all. MaxPkg installs the selected script for you. If MaxPkg Runtime is
not installed yet, it is installed automatically at the same time.

## Install MaxPkg Runtime manually

If you prefer to install MaxPkg before choosing a script:

1. Download `MaxPkg-Runtime-Manager.mzp` from the
   [latest release](https://github.com/maxpkg-dev/MaxPkg-Runtime-Manager/releases/latest).
2. Drag the downloaded file into a 3ds Max viewport.

MaxPkg will start automatically the next time you open 3ds Max.

## Meet the Manager

The Manager shows all your scripts in one clean window.

Use `Discover` to search the catalog and add new tools. Use `Installed` to see
everything you already have, run a script, open its information, update it, or
remove it.

Discover also helps you browse Featured scripts and curated collections, narrow
the catalog by category, and sort the results. Categories stay in a handy side
panel when there is enough room and move beside search in smaller windows.

Installed tools use clean compact cards by default. If you prefer to see their
descriptions and badges in the list, enable full package cards in Settings.

Each package can include:

- A clear description
- Version and developer information
- Screenshots
- A full changelog
- License, Help, homepage, and support links

## Open the Manager

Choose whichever way feels most comfortable:

- Click the MaxPkg button on the MaxPkg toolbar
- Press `X` in 3ds Max and search for `MaxPkg Manager`
- Add the `MaxPkg Manager` action to any 3ds Max toolbar from the `MaxPkg`
  category

Advanced users can also open it from MAXScript Listener:

```maxscript
maxpkg.openManager()
```

## Make the toolbar yours

MaxPkg can create a toolbar with buttons for your installed scripts. You can:

- Choose large, medium, small, or icon-only buttons
- Show a version, developer name, or no extra text
- Hide buttons you do not need
- Change the button order from Installed or directly on any toolbar by holding `Alt` and dragging
- Turn the MaxPkg toolbar off completely
- Choose separate themes for the Manager and the toolbar

Prefer regular 3ds Max toolbars? Script actions are available in the `MaxPkg`
category, so you can place them where you already keep your favorite tools.

## Updates without the busywork

Use `Check Updates` whenever you want to look for new versions. MaxPkg shows
which tools can be updated and keeps the process in one place.

Automatic update checks can be adjusted in `Settings > Updates`.

Already installed scripts remain available when you are offline.

## Install from MAXScript Listener

You can type a package name naturally. Capitalization and word order do not
matter:

```maxscript
maxpkg.install "prune scene"
maxpkg.install "scene prune"
```

MaxPkg shows a small Windows notification when the installation finishes.
Scripts with their own interface can keep this message hidden:

```maxscript
local installStatus = maxpkg.install "prune scene" showNotification: false
```

## Remove scripts

Remove any installed script from its menu in the Manager. MaxPkg cleans up the
package and its 3ds Max buttons for you.

When you install or remove a script from MAXScript Listener, MaxPkg shows a
small Windows notification instead of interrupting your work with another
dialog.

To remove MaxPkg Runtime itself, open `Settings > Uninstall` in the Manager.

## Requirements

- Autodesk 3ds Max 2012 or newer
- Internet access when discovering, installing, or updating scripts

## Need help?

If the Manager does not open, restart 3ds Max and run `install.ms` again.

When asking for help, include your 3ds Max version, the Runtime version shown in
the Manager, and a short description of what happened.

## License

MaxPkg Runtime and its installer bridge are provided only for use with the
official [MaxPkg service](https://maxpkg.dev). Unauthorized copying,
modification, redistribution, reverse engineering, or use with third-party
installer endpoints is prohibited.

## Links

- Browse scripts: [maxpkg.dev](https://maxpkg.dev)
- Developed by [3DGROUND](https://3dground.net)

Copyright (c) 2026 Lukianenko Vasyl.
