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

## Source File Headers

- Every project MaxScript and JavaScript source file must begin with a short
  comment describing that file's responsibility.
- Follow the description with the copyright owner, project website, and
  developer attribution shown below.
- Keep the header before all executable code, global declarations, wrappers,
  and immediately invoked functions.

MaxScript header:

```maxscript
-- Short description of this script.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)
```

JavaScript header:

```javascript
/*
 * Short description of this script.
 * Copyright (c) 2026 Lukianenko Vasyl
 * https://maxpkg.dev
 * Developed by https://3dground.net (3DGROUND)
 */
```

## Global Scope

- `MaxPkg` is the only project global object. MaxScript identifiers are
  case-insensitive, so Listener and script calls may spell the same facade as
  either `MaxPkg` or `maxpkg`; do not create a second alias object.
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
- Define a struct helper method before every method that calls it. MaxScript
  can resolve an unqualified forward call to `undefined` instead of the method
  declared later in the same struct.
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
- Always wrap the complete expression tested by `if` in parentheses.
- Use `do` when the condition has no `else` or `else if` branch.
- Use `then` when the condition is followed by `else` or `else if`.
- Every condition in an `else if` chain must also be wrapped in parentheses
  and followed by `then`.

```maxscript
fn testFunc argument = (
    if (argument != undefined) do (
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

Condition without an alternative branch:

```maxscript
if (packageCount == 1) do (
    format "One package\n"
)
```

Condition with `else` and `else if` branches:

```maxscript
if (packageCount == 0) then (
    format "No packages\n"
) else if (packageCount == 1) then (
    format "One package\n"
) else (
    format "% packages\n" packageCount
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

## Variables

- Declare internal function variables with `local`.
- Do not leak temporary variables into global scope.
- Use descriptive names such as `isSuccess`, `isValid`, `manifestPath`,
  `packageGuid`, and `responseBody`.
- Never use MaxScript reserved words, predefined names, literals, or ambiguous
  generic identifiers as variable, parameter, struct-field, or function names.
- Never declare custom functions, struct members, parameters, or variables
  named `open` or `close`. They conflict with MaxScript generic functions and
  can make a zero-argument call resolve to a built-in instead of the intended
  struct method.
- Use descriptive names such as `showManager`, `destroyManagerDialog`,
  `openPackageFolder`, or `closeFileStream`. Actual built-ins such as
  `openFile` and `close stream` remain valid.
- In particular, do not use names such as `value`, `ok`, `true`, `false`,
  `undefined`, `on`, `off`, `do`, `then`, `else`, `try`, `catch`, `local`,
  `global`, `function`, `fn`, `struct`, or `rollout`.
- Do not use reserved, generic, or ambiguous standalone names such as `path`,
  `text`, `name`, `section`, `icon`, `data`, `item`, `tmp`, `object`, or
  `result`. They can conflict with MaxScript built-ins or hide the variable's
  intent.
- Prefer names such as `sourceContent`, `packageInfo`, `isInstalled`,
  `manifestEntry`, `operationResult`, `filePath`, `content`, `packageName`,
  `iniSection`, `iconFile`, `isSuccess`, `isValid`, `hasError`,
  `uploadResult`, `errorMessage`, and `responseBody`.
- Boolean names should read as conditions: `isBusy`, `isHidden`,
  `toolbarVisible`, `updateAvailable`.
- Keep package identity comparisons case-insensitive.

Example:

```maxscript
local isUploaded = awsUploaderMgr.upload sourceFile
if (isUploaded) then (
    return true
) else (
    return false
)
```

## Loops

- Use `for packageIndex in 1 to packageCount do (...)` style for numeric
  ranges.
- Do not use `for packageIndex = 1 to packageCount do (...)` in project
  MaxScript code.
- Use descriptive iterator and collection names instead of generic names such
  as `i` or `items`.

Example:

```maxscript
for packageIndex in 1 to packages.count do (
    format "%\n" packages[packageIndex]
)
```

## Arrays

- Do not use the mapped MaxScript `copy` function to clone an array. For an
  empty array it can return `OK` instead of another array.
- Clone arrays explicitly by creating `#()` and appending each source entry.
- Validate persisted collection values before iterating them and recover with
  an empty array when their type is invalid.

## Strings

- Never use `format` for string concatenation.
- Use `+` to build strings from parts, especially for file paths, generated
  code, command text, and messages.
- Use MaxScript verbatim string literals (`@"..."`) for static paths and other
  ordinary strings that contain backslashes. Inside a verbatim string, write
  each backslash once instead of escaping it as `\\`.
- This applies when MaxScript consumes the string directly, for example in
  `fileIn`, filesystem calls, module paths, icon paths, and asset paths.
- Do not automatically use verbatim literals inside dynamically generated
  MaxScript source that will be parsed again through `execute`, or inside
  generated MacroScript definitions. Generated code has another parsing layer,
  so keep the escaping required by that generated source and verify the final
  emitted code.
- Use `format` only when writing formatted output to a stream or Listener and
  the `%` placeholder behavior is intentional and easy to verify.
- When generating code as strings, prefer explicit concatenation inside the
  generated code instead of embedding `%` placeholders inside quoted path
  fragments.

Example:

```maxscript
local managerModule = fileIn (runtimeRoot + @"ui\manager\manager.ms")
local packageDir = (getDir #temp) + @"\" + packageGuid + @"\"
```

Avoid:

```maxscript
local managerModule = fileIn (runtimeRoot + "ui\\manager\\manager.ms")
format "local packageDir = (getDir #temp) + \"\\%\\\"\n" packageGuid to:ss
```

## Named Arguments

- For MaxScript named arguments, UI control parameters, rollout options, and
  function keyword arguments, write exactly one space after `:` and no space
  before it.
- Use `key: value`, not `key:value`, `key :value`, or `key : value`.

Example:

```maxscript
dotNetControl dncTabs "System.Windows.Forms.TabControl" width: 260 height: 20 align: #left across: 2 offset: [-10, 0]
local versionParts = parseVersionParts (settingsGetEscaped "version" defaultContent: "1.0.0")
```

## Data Bundles And Structs

- When several values describe one logical runtime object, pass them as a small
  named `struct` instead of passing many separate arguments.
- Prefer a structure for grouped information such as file metadata, processing
  options, operation results, or validation details.
- Name fields by meaning, for example `fileName`, `processingOptions`,
  `initialContent`, `errors`, `warnings`, and `isSuccess`.
- Keep data structs focused on data. Do not turn a temporary data bundle into a
  manager unless it genuinely owns behavior.
- Use named struct arguments or explicit field assignment so call sites remain
  readable.
- Keep temporary data structs close to the module, wrapper, or factory that owns
  them. If a struct is used only by one lexical wrapper, define it inside that
  wrapper instead of adding another global type.
- Prefer passing one readable data struct through several functions over
  passing parallel arrays or relying on indexes such as `packageEntry[1]`,
  `packageEntry[2]`, and `packageEntry[3]`.
- The project-wide variable rules remain stricter than generic MaxScript
  examples: do not use `tmp`, `item`, `result`, `val`, or similarly ambiguous
  names even for short-lived bundle variables or fields.
- Do not let a struct type name differ from a function, local, rollout, or
  control only by letter case or a close camelCase/PascalCase variant.
  MaxScript name resolution can be case-insensitive. Use explicit type suffixes
  such as `SampleDataSourcesData`.
- Package records belong in `MaxPkgPackageData`. Add normalized fields there
  rather than passing parallel arrays or positional tuples.
- Keep struct definitions inside the owning module's lexical scope.

Example:

```maxscript
struct FileProcessData (
    fileName,
    processingOptions,
    initialContent,
    errors = #(),
    warnings = #(),
    isSuccess = false
)

local processInfo = FileProcessData fileName: sourceFileName processingOptions: processOptions initialContent: sourceContent
local processingResult = processFile processInfo
```

Avoid:

```maxscript
local processingResult = processFile sourceFileName processOptions sourceContent
```

## Package Manifest Contract

- `manifest.ini` is the only package source of truth. Runtime code must never
  require `manifest.json`.
- Read manifests only in `core/scanner.ms`. Toolbar, Manager, launcher, updater,
  and uninstaller consume normalized objects from `MaxPkg.packages`.
- Maintain compatibility with the actual `max-dev-tool` keys, including
  `packageGuid`, `developerName`, `documentation`, `purchase`,
  `purchaseButtonLabel`, `showInToolbar`, and `uninstallScript`.
- Normalize the release channel and date, license and license URL, supported
  3ds Max range, homepage, documentation, support, packager metadata, and
  changelog entries for Manager Details. Manager UI must consume these
  normalized fields rather than reading `manifest.ini` directly.
- Keep documented aliases such as `Guid`, `Runtime`, `ToolbarVisible`, and
  `ToolbarOrder` when changing manifest parsing.
- Validate `Guid`, `Name`, `Version`, `Runtime`, and `Entry`. Log missing fields
  and skip the package instead of stopping the scan.
- Never write toolbar preferences or downloaded informational metadata over
  developer-owned manifest fields.

## Settings And Persistent State

- Store user state in the Runtime root `settings.ini`, never in package
  manifests.
- Provide a safe default for every new setting and load it through
  `core/settings.ms`.
- Save Settings dialog controls immediately when their values change. Keep the
  dialog free of manual Save and Cancel actions and preserve one close action.
- Debounce editable text settings briefly, flush pending edits when the dialog
  closes, and keep successful automatic saves silent. Always report failures.
- Save toolbar visibility, hidden packages, and package order through the
  settings module immediately after a Manager action changes them.
- Keep `settings.ini`, legacy `data/settings.ini`, update-response files, logs,
  and other generated state out of Git.

## Offline And Network Behavior

- `MaxPkg.start()` and `MaxPkg.scan()` must not make network requests.
- Use one optional base API endpoint override and derive action URLs from it.
  Keep `https://maxpkg.dev/api/runtime/v1/` as a hardcoded fallback instead of
  writing it into `settings.ini` by default. Expose the effective endpoint in
  Manager only while Developer mode is enabled.
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
- Clear the read-only attribute on every file before deleting package or
  Runtime content.
- Package uninstall must remove the generated `maxpkg-<GUID>.mcr` from
  `#userMacros` and its copied icon from `#userIcons`.
- Runtime installation must register a `MaxPkg Manager` MacroScript action in
  `#userMacros`. Do not place the action on a toolbar automatically; let the
  user choose its location through Customize User Interface.
- Never delete a root, user scripts directory, temp root, or an unresolved path.
- Clean up test downloads and generated logs after smoke tests.

## Toolbar And Manager UI

- Build toolbar content only from `MaxPkg.packages`.
- Keep UI state separate from package/runtime state.
- Treat the Manager and Toolbar as IE9 hosts: use ES5 JavaScript and simple CSS
  layout based on floats, inline blocks, tables, or absolute positioning.
- Keep the Manager window at or above 720x520 and constrain restored window
  bounds to the available monitor working area.
- Dock the Manager WebBrowser to its rollout host and synchronize its dimensions
  from `getDialogSize` both when the dialog opens and when the HTML document
  completes loading. Do not assume the control's declared 900x650 size matches
  a window that Windows reduced to fit the monitor.
- Keep the header search field fluid between the fixed logo and action cells.
  Measure the visible action area after Runtime state changes and on window
  resize, then update the search boundary explicitly. Do not rely on IE9 to
  reflow a table correctly after a header action is hidden.
- Do not use Flexbox, Grid, CSS custom properties, `fetch`, promises, modules,
  arrow functions, `let`, `const`, `async`, or `await` in embedded UI code.
- Keep shared colors, typography, controls, dialog styles, and local SVG icons
  under `ui/common`. Do not load fonts, scripts, styles, or icons from a CDN.
- Use official Lucide SVG geometry for standard action and status icons. Store
  the SVG locally and do not imitate an available Lucide icon with a Unicode
  glyph, CSS shape, or hand-drawn substitute.
- Disable text selection on interactive controls through the shared layout
  styles. Apply `user-select: none` and its browser-prefixed variants to
  buttons, action links, checkbox/radio labels, HTML dropdowns, context menus,
  and elements with `role="button"`, but keep text inputs and ordinary content
  selectable.
- Keep at least 12px between adjacent action buttons. Header and toolbar
  controls may use 15px, and compact filter groups use at least 9px; do not
  rely on the browser's small whitespace gap between inline elements.
- Distinguish destructive context-menu actions with a red treatment and a
  local action-specific icon, such as the trash icon for Uninstall.
- Keep changelog type badges consistent with the maxpkg.dev semantic palette:
  green Added, yellow Fixed, blue Improved, purple Changed, and red Removed.
  Render unknown types with the neutral badge treatment.
- Use the shared HTML dropdown component for themed Manager selections instead
  of native `<select>` controls whose popup cannot be styled consistently in
  IE9.
- Keep reusable dropdown state, positioning, outside-click handling, keyboard
  navigation, and value selection in `ui/common/js/dropdown.js`. Feature pages
  only register a dropdown and react to its change callback.
- Escape all package text before inserting it into HTML.
- Limit package-card descriptions to three visible lines with an
  IE9-compatible fixed line height and hidden overflow. Keep the full
  description on the Details page.
- Route browser actions only through the controlled `maxpkg://run/`,
  `maxpkg://ui/`, and `maxpkg://manager/` schemes. Cancel their browser
  navigation before dispatching.
- UI code never reads manifests or settings INI files directly. It receives
  normalized state from Runtime and sends commands back to Runtime.
- Set `enableAccelerators = false` while a browser control that accepts keyboard
  input has focus.
- Restore `enableAccelerators = true` when that browser loses focus and whenever
  its rollout closes or the Runtime shuts down.
- A toolbar browser without text input may restore accelerators immediately
  after dispatching its navigation command.
- Always call `cui.UnRegisterDialogBar` before destroying or recreating a
  registered toolbar rollout.
- UI refresh failure must not break scanning, package callbacks, or startup.
- User-facing errors must say what failed and identify the relevant package or
  file.
- Keep visible bottom spacing inside every scrollable Manager page. When the
  user scrolls to the end, the final card, details section, or action row must
  not touch or disappear behind the fixed status bar.
- Put this spacing on the content page inside the scroll container rather than
  relying only on the scroll container's bottom padding, because the IE9 host
  may omit container padding from the effective scroll extent.
- Keep Back navigation outside the scroll container in a fixed page toolbar.
  Render Back as a link, include the current pathway or breadcrumb beside it,
  and never place a Back button inside scrolling page content.

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
