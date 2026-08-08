# MaxPkg Runtime Release Rules

These rules define how Codex prepares a MaxPkg Runtime release. A release is
prepared only when the user explicitly asks to make or prepare a release.

## Release Ownership

- Codex prepares the release files but does not commit, tag, or push the
  release.
- After Codex updates the version and changelog, the user reviews the changes
  and performs the commit and push.
- Do not change the project version during ordinary implementation work unless
  the user explicitly asks to prepare a release.

## Version Update

- Update the Runtime version in the root `version.ini` first.
- Use the `major.minor.patch` version format.
- Keep the minor and patch components within `0` to `9`. Never create versions
  such as `1.0.10`, `1.0.11`, or `1.10.0`.
- For a large feature release or a substantial update, increment the minor
  version and reset the patch version to zero.
- For fixes, small features, UI improvements, maintenance, and all other
  regular releases, increment only the patch version.
- Treat version increments like carrying digits. If patch `9` must be
  incremented, reset it to `0` and increment minor. If minor `9` must be
  incremented, reset both minor and patch to `0` and increment major.
- Keep the major version unchanged except when the user explicitly requests a
  major release or the minor component overflows from `9` to `0`.
- Change only the version required for the current release. Preserve the
  release channel and unrelated INI values.

Examples:

- Large update: `1.0.4` becomes `1.1.0`.
- Regular update: `1.0.4` becomes `1.0.5`.
- Regular update after `1.0.9`: `1.0.9` becomes `1.1.0`.
- Next release after `2.9.9`: `2.9.9` becomes `3.0.0`.
- Large update after `2.9.4`: `2.9.4` becomes `3.0.0`.

## Changelog

- Maintain the release history in the root `CHANGELOG.md`.
- Add the newest version at the top of the file, immediately below the main
  `# Changelog` heading.
- Do not invent changes. Describe only behavior actually implemented for the
  release.
- Keep entries short, clear, and understandable to 3D artists. Avoid internal
  implementation details unless users need to know about them.
- Use one entry per meaningful user-facing change.
- Write the change type at the beginning of every entry.
- Group and order entries by type. Always place `Added` first, `Fixed` second,
  and `Changed` third. Place any remaining types after them in a logical order.
- Within one type, keep related changes together and put the most important
  user-facing changes first.
- Older versions always remain below newer versions. Never reorder or rewrite
  historical releases unless the user explicitly asks for a correction.

Preferred type order:

1. `Added`
2. `Fixed`
3. `Changed`
4. `Improved`
5. `Removed`
6. `Deleted`
7. Other necessary types

Use this format:

```markdown
## 1.0.2

- Added: New feature with clear user-facing information.
- Fixed: Package search now returns the expected results.
- Changed: Installed package cards now use a compact layout by default.
- Removed: Obsolete setting that is no longer used.
```

## Release Preparation Sequence

When the user asks to prepare a release:

1. Review the completed changes since the previous release and determine
   whether the release is a large update or a regular update.
2. Update `version.ini` using the version rules above.
3. Add the new version and its grouped changes to the top of `CHANGELOG.md`.
4. Verify that the changelog version exactly matches `version.ini`.
5. Run the project checks required by `coding-rules.md` and report their
   results.
6. Show the prepared version and changelog summary to the user for review.
7. Stop without committing, tagging, or pushing.

## Publishing The Prepared Release

- The user reviews, commits, and pushes the prepared release to `main`.
- The user starts publication by running the root `publish-release.bat` file.
- Do not run `publish-release.bat` unless the user explicitly asks to publish
  the already reviewed release.
- The batch file must read the version from `version.ini`, require Y/N
  confirmation, reject dirty or unpushed repositories, and reject an existing
  GitHub Release or tag with the same version.
- Publication is performed by the manual GitHub Actions workflow. It builds
  `MaxPkg-Runtime-Manager.mzp` from `.github/mzp-files.txt`, validates the
  archive, creates the version tag and GitHub Release, and uploads the MZP and
  SHA-256 checksum.
- `publish-release.bat`, repository settings, tests, logs, internal rules, and
  GitHub workflow files must never be included in the MZP archive.

### First-Time Setup

GitHub CLI is required to start the release workflow from
`publish-release.bat`.

1. Install GitHub CLI:

   ```bat
   winget install --id GitHub.cli
   ```

2. Sign in to GitHub once:

   ```bat
   gh auth login
   ```

### Publishing A Release

After Codex has prepared the version and changelog, and the user has reviewed
the changes:

1. Commit all prepared release changes.
2. Push the commit to the `main` branch.
3. Run `publish-release.bat` from the repository root.
4. Review the version and release information shown by the script.
5. Press `Y` to confirm publication.
6. Follow the GitHub Actions page opened by the script until the workflow
   finishes successfully.

The batch file will stop without publishing if the working tree is dirty, the
local commit has not been pushed to `main`, or the same version already has a
GitHub tag or Release.
