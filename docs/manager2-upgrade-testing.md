# Manager 2.0 upgrade: manual test plan (Runtime 1.2.1)

Run on a machine or 3ds Max profile that has no Manager 2.0 installed
(no `temp\MaxPkg-Runtime-Manager-Qt` folder, no `maxpkg-runtime-qt-startup.ms`).
Never run these in a 3ds Max instance that is in use.

## Test setup

1. Make a test copy of the 1.2.1 sources and point `latestVersionUrl` and `runtimeArchiveUrl` in
   `core/self-updater.ms` at a test branch of the old repository instead of `main`.
2. On that branch, set `[manager2]` in `version.ini` to the published 2.0 release:
   `Enabled=true`, `Version`, `Url`, `Sha256` (from the release `.sha256` file), `MinMaxVersion=24000`.
3. Install the 1.x Runtime (1.2.0 for the full path, or the test copy) with `install.ms`.
4. State and logs: `temp\MaxPkg-Runtime-Manager\data\manager2-upgrade.ini` and `logs\maxpkg.log` (area `manager2`).
   Reset between runs by deleting `manager2-upgrade.ini`.

## Cases

| # | Case | Steps | Expected |
|---|------|-------|----------|
| 1 | 1.2.0 -> 1.2.1 | Install 1.2.0, set the test branch to 1.2.1, start Max | Runtime updates and reloads without a restart; no prompt while `Enabled=false` |
| 2 | Max 2022 or newer, upgrade | `Enabled=true`, restart Max, choose Upgrade now | 2.0 installed, 1.x files, startup script and macros removed, packages in `data\packages` and settings carried over, Max restarts cleanly with only 2.0 |
| 3 | Max older than 2022 | Run on Max 2021 or older | No prompt, no download, no log entry; 1.x keeps working and updating |
| 4 | Remind me later | Choose Remind me later | No prompt for 7 days (`NextPromptAt` in the state file) |
| 5 | Do not ask again | Choose Do not ask again | `DeclinedVersion` saved; no prompt until `Version` changes |
| 6 | Kill switch | Set `Enabled=false` (or remove `[manager2]`) | No prompt, nothing downloaded |
| 7 | Failed download | Point `Url` at a missing asset (same prefix) | 1.x untouched, `LastError` saved, no retry for 24 h, stops after 3 failures |
| 8 | Wrong SHA-256 | Change one character of `Sha256` | Rejected before anything changes; same retry limits |
| 9 | 2.0 fails to start | Make the 2.0 installer fail after it removes 1.x (for example break its `python\startup.py` in a test mzp) | 1.x is restored and restarts in the same session; the failure is logged |
| 10 | Max killed mid-upgrade | Start the upgrade and kill the 3ds Max process while the 2.0 installer runs | Next launch: `maxpkg-runtime-recovery.ms` either finishes the upgrade (2.0 files complete) or restores 1.x, then removes itself and the backup |
| 11 | Operation running | Start a package install, then trigger the check | Upgrade waits; no prompt |
| 12 | Shared folders | Point two 3ds Max versions at one shared startup/macros/temp folder, upgrade from the newer one | Documented limitation: the 2.0 installer deletes the shared 1.x startup script and macros, so the older Max loses 1.x until the 2.0 installer is changed |
| 13 | Older Runtime | Install 1.1.0 and 1.0.x, point them at the test branch | They self-update to 1.2.1, then follow case 2 (1.1.0 and older use the renamed `maxpkg-dev/runtime` URL; confirm the redirect works) |

## Release order

1. Publish 2.0 at its public release URL.
2. Run the cases above against the test branch.
3. Push 1.2.1 to `main` with `Enabled=false` and confirm clients update and stay stable.
4. Set `Enabled=true` only after the maintainer approves.

Pushing a higher `Version` in `[Runtime]` to `main` is a live release to every 1.2.0 client and cannot be recalled.
