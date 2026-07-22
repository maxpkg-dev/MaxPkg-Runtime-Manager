# MaxPkg Runtime Coding Rules

These rules describe how we write and maintain the MaxPkg Runtime. They apply
to `startup.ms`, `install.ms`, everything under `core/` and `ui/`, and the
MaxScript tests.

## Project Priorities

- Keep startup, package discovery, toolbar creation, package launch, and
  uninstall fully usable without Internet access.
- Treat a damaged package as an isolated failure. Log it, skip it, and continue
  processing the remaining packages.
- Keep modules small and focused on one responsibility.
- Use 3ds Max 2027 for active development and runtime smoke tests.
- Preserve the documented 3ds Max 2012+ compatibility unless a newer API is
  intentionally adopted and the compatibility requirement is updated.

## Global Scope

- `MaxPkg` is the only project global object.
- Declaring `global MaxPkg` in a loader or test is allowed; it refers to the
  same object and must not create another global value.
- Do not add global module managers, package caches, temporary variables, or UI
  rollout references.
- Wrap every module file in a top-level `(...)` scope. Define its structs,
  functions, and rollouts inside that scope and return one module instance.
- Keep rollout/controller bridges lexical, as done by `toolbarOwner` and
  `managerOwner`.
- Expose new behavior through the existing `MaxPkg` facade only when it is part
  of the intended public API. Implementation details stay inside modules.

## Module Architecture

- `core/runtime.ms` is the composition root. It loads modules, connects their
  dependencies, creates `MaxPkg`, and contains no feature-specific business
  logic beyond orchestration.
- A module must not load another module directly. Dependencies are assigned by
  `runtime.ms`.
- Do not duplicate path handling, INI access, HTTP, logging, package resolution,
  or operation-locking logic. Use the existing module that owns it.
- `startup.ms` must remain a small idempotent loader. Do not scan packages or
  construct UI directly inside it.
- Avoid circular module ownership. When callbacks need the Runtime, pass the
  facade or a narrow module dependency explicitly.

## Functions

- Use an explicit `return` whenever a function produces a value.
- Functions reporting success or failure return `true` or `false` explicitly.
- Use early returns for invalid input and failed preconditions.
- Keep keyword parameters for optional behavior and give them safe defaults.
- Do not rely on a lone expression at the end of a function as its result.

```maxscript
fn isValidManifest manifestPath = (
    if manifestPath == undefined or manifestPath == "" do return false
    if not (doesFileExist manifestPath) do return false
    return true
)
```

## Braces And Layout

- Keep the opening parenthesis on the same line as the construct that owns it.
- Apply this consistently to functions, conditions, loops, `try/catch`,
  structures, rollouts, event handlers, and anonymous code blocks.
- Do not place the opening parenthesis on the following line.
- Keep the closing parenthesis on its own line and aligned with the beginning
  of the construct.

```maxscript
fn testFunc argument = (
    if argument != undefined do (
        for index in 1 to 3 do (
            format "%\n" argument
        )
    )
    return true
)

struct MaxPkgTestData (
    packageGuid = "",
    isValid = false
)

try (
    testFunc "MaxPkg"
) catch (
    format "Test failed: %\n" (getCurrentException())
)
```

Avoid:

```maxscript
fn testFunc argument =
(
    if argument != undefined do
    (
        return true
    )
)
```

## Variables And Naming

- Declare internal function variables with `local`.
- Use descriptive names such as `isSuccess`, `isValid`, `manifestPath`,
  `packageGuid`, and `responseBody`.
- Never use MaxScript reserved words, predefined names, literals, or ambiguous
  generic identifiers as variable, parameter, struct-field, or function names.
- In particular, do not use names such as `value`, `ok`, `true`, `false`,
  `undefined`, `on`, `off`, `do`, `then`, `else`, `try`, `catch`, `local`,
  `global`, `function`, `fn`, `struct`, or `rollout`.
- Avoid generic names such as `data`, `item`, `tmp`, `object`, or `result` when
  a domain-specific name is available.
- Prefer names such as `sourceContent`, `packageInfo`, `isInstalled`,
  `manifestEntry`, and `operationResult`.
- Boolean names should read as conditions: `isBusy`, `isHidden`,
  `toolbarVisible`, `updateAvailable`.
- Keep package identity comparisons case-insensitive.
- Use `for index in 1 to count do (...)`; do not use `for index = 1 to count`.

## Structs And Runtime Data

- Use a focused data struct when several values describe one object.
- Package records belong in `MaxPkgPackageData`. Add normalized fields there
  rather than passing parallel arrays or positional tuples.
- Keep data structs free of unrelated manager behavior.
- Use named constructor arguments or explicit field assignment where it makes
  a call easier to read.
- Keep struct definitions within their module's top-level local scope.

## Package Manifest Contract

- `manifest.ini` is the only package source of truth. Runtime code must never
  require `manifest.json`.
- Read manifests only in `core/scanner.ms`. Toolbar, Manager, launcher, updater,
  and uninstaller consume normalized objects from `MaxPkg.packages`.
- Maintain compatibility with the actual `max-dev-tool` keys, including
  `packageGuid`, `developerName`, `showInToolbar`, and `uninstallScript`.
- Keep documented aliases such as `Guid`, `Runtime`, `ToolbarVisible`, and
  `ToolbarOrder` when changing manifest parsing.
- Validate `Guid`, `Name`, `Version`, `Runtime`, and `Entry`. Log missing fields
  and skip the package instead of stopping the scan.
- Never write toolbar preferences or downloaded informational metadata over
  developer-owned manifest fields.

## Settings And Persistent State

- Store user state in `data/settings.ini`, never in package manifests.
- Provide a safe default for every new setting and load it through
  `core/settings.ms`.
- Save toolbar visibility, hidden packages, and package order through the
  settings module immediately after a Manager action changes them.
- Keep `data/settings.ini`, update-response files, logs, and other generated
  state out of Git.

## Offline And Network Behavior

- `MaxPkg.start()` and `MaxPkg.scan()` must not make network requests.
- Network endpoints are optional settings. Missing endpoints mean offline mode,
  not startup failure.
- Update checks use one batch request for all installed packages. Do not add one
  request per package.
- Keep request/response parsing isolated in `core/http.ms` and
  `core/updater.ms`.
- Check downloaded files before executing them and log actionable failures.

## Critical Operations

- Install, uninstall, update, update-all, and self-update must use
  `core/operations.ms`.
- Only one critical operation may run at a time. Package launching remains
  independent.
- Always release the operation lock on both success and failure paths.
- After a package-changing operation, rescan packages, rebuild the toolbar, and
  refresh Manager state.
- Do not report success only because an installer script executed. Verify the
  resulting package state where possible.

## Error Handling And Logging

- Catch failures at module boundaries: filesystem, package entry scripts,
  network, external hooks, and UI integration.
- Do not use empty `catch()` around important processing. Log the exception and
  return a clear failure result.
- Empty catches are acceptable only for best-effort cleanup, optional UI
  refresh, or unregister/destroy calls where failure is harmless.
- Use `core/logger.ms` for startup, scan, launch, install, uninstall, update,
  toolbar, and self-update events.
- Include the operation area and useful identity or path in errors.
- Avoid placeholder debug output and silent failure.

```maxscript
catch (
    logger.error "launcher" (package.guid + ": " + getCurrentException())
    return false
)
```

## Filesystem Safety

- Normalize directory paths through `utils.ensureSlash`.
- Check files and directories before reading, executing, copying, or deleting.
- Resolve entry, icon, and hook paths relative to the normalized package
  installation directory.
- Before recursive deletion, verify that the target is the resolved package
  folder and does not contain or overlap the Runtime folder.
- Never delete a root, user scripts directory, temp root, or an unresolved path.
- Clean up test downloads and generated logs after smoke tests.

## Toolbar And Manager UI

- Build toolbar content only from `MaxPkg.packages`.
- Keep UI state separate from package/runtime state.
- Escape all package text before inserting it into HTML.
- Route browser actions only through the controlled `maxpkg://run/` and
  `maxpkg://ui/` schemes. Cancel their browser navigation before dispatching.
- Restore 3ds Max accelerators after browser interaction and when the toolbar
  closes.
- Always call `cui.UnRegisterDialogBar` before destroying or recreating a
  registered toolbar rollout.
- UI refresh failure must not break scanning, package callbacks, or startup.
- User-facing errors must say what failed and identify the relevant package or
  file.

## Public API Stability

- Preserve the public members documented in `README.md` and the technical
  specification.
- `MaxPkg.run`, `uninstall`, `packageInstalled`, and `packageRemoved` accept a
  GUID or slug where documented.
- Do not expose module structs or internal helper functions as additional
  globals.
- When changing a public method, update `README.md` and `tests/smoke.ms` in the
  same change.

## Verification In 3ds Max 2027

- Run `tests/smoke.ms` through the installed 3ds Max 2027 batch executable.
- The listener log must contain `MAXPKG_SMOKE_OK`.
- Inspect the listener log for Runtime parse errors and exceptions; do not rely
  only on the process exit code because unrelated user startup scripts may fail.
- Test docked toolbar creation, resize, navigation, Manager controls, and
  accelerator restoration interactively when toolbar code changes.
- Exercise install/uninstall only with a disposable test package.

## Git And Release Hygiene

- Do not commit credentials, downloaded packages, local settings, generated
  logs, update responses, or 3ds Max batch output.
- Preserve unrelated user changes in a dirty worktree.
- Before handing off a change, run:

```powershell
git -c safe.directory=C:/Projects/Scripts/runtime diff --check
rg -n "\bglobal\b" -g "*.ms" .
rg -n "TODO|FIXME|HACK" core ui startup.ms install.ms tests
git -c safe.directory=C:/Projects/Scripts/runtime status --short
```

- Confirm that every global declaration refers only to `MaxPkg`.
- Update `version.ini` and the README when behavior or the public contract
  changes for a release.
