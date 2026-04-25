---
name: flashspace-local-release
description: Project-local workflow for /Users/tiou/playground/FlashSpace. Use when working on this FlashSpace fork to merge upstream, preserve local workspace/focus/display behavior, build a personal macOS Release app, ad-hoc sign the app and bundled CLI, package a zip, install to /Applications, or explain release impacts.
---

# FlashSpace Local Release

## Scope

Use this skill only for `/Users/tiou/playground/FlashSpace`.

Do not apply this workflow to other projects. This is intentionally project-local because it encodes this fork's local behavior decisions and personal-use packaging assumptions.

## Non-Negotiable Rules

- Preserve local behavior unless the user explicitly asks to change it:
  - Dynamic Workspace `canActivate` behavior.
  - CoreGraphics fallback for dynamic workspace display resolution.
  - Chromium `BrowserFocusHelper` web-content focus workaround, including fallback `Esc`.
  - Ignoring minimized windows for display/focus decisions.
  - Original current-screen semantics; do not globally replace with mouse-screen semantics.
- Do not add the CLI codesign patch back into `project.yml`.
- Keep CLI signing as a packaging step, documented in `docs/upstream-v4.16.74-merge-impact.md`.
- Do not run `fastlane release` for personal builds unless the user explicitly wants Developer ID notarization and has credentials available.
- Before destructive or history-rewriting operations, create a backup branch.

## Important Project State

- Main repo path: `/Users/tiou/playground/FlashSpace`.
- Current integrated branch created during this work: `integration/upstream-v4.16.74-local`.
- Current upstream release integrated: `v4.16.74`.
- Backup branch from before the merge: `backup/pre-upstream-merge-20260426-015550`.
- Merge-impact document: `docs/upstream-v4.16.74-merge-impact.md`.
- Personal release artifact convention: `.build/PersonalRelease/FlashSpace-<version>-local.zip`.

## Personal Release Workflow

Use `scripts/package-personal-release.sh` from this skill when the user asks to "打包", "打正式版", "personal release", or similar.

From the repo root:

```bash
bash .codex/skills/flashspace-local-release/scripts/package-personal-release.sh
```

The script:

1. Runs `xcodegen generate`.
2. Builds `Release` with local/ad-hoc signing.
3. Signs `FlashSpace.app/Contents/Resources/flashspace` ad-hoc with hardened runtime.
4. Re-signs the whole `.app` ad-hoc with hardened runtime.
5. Verifies the app with `codesign --verify --deep --strict`.
6. Writes a zip to `.build/PersonalRelease/FlashSpace-<version>-local.zip`.
7. Prints the zip SHA256.

Expected output app:

```text
.build/DerivedData/Build/Products/Release/FlashSpace.app
```

Expected output zip:

```text
.build/PersonalRelease/FlashSpace-<version>-local.zip
```

## Install Workflow

For personal install, prefer installing the built `.app` directly after quitting running copies:

```bash
osascript -e 'tell application id "pl.wojciechkulik.FlashSpace.dev" to quit' || true
osascript -e 'tell application id "pl.wojciechkulik.FlashSpace" to quit' || true
ditto ".build/DerivedData/Build/Products/Release/FlashSpace.app" "/Applications/FlashSpace.app"
```

After replacing `/Applications/FlashSpace.app`, the user may need to re-allow Accessibility or automation permissions because the local ad-hoc signature can differ from previous builds.

## Upstream Merge Workflow

When the user asks to update from upstream:

1. Ensure worktree status is understood:
   ```bash
   git status --short --branch
   ```
2. Create a rollback branch:
   ```bash
   git branch "backup/pre-upstream-merge-$(date +%Y%m%d-%H%M%S)"
   ```
3. Stash uncommitted work if present:
   ```bash
   git stash push -u -m "pre-upstream-merge-$(date +%Y%m%d-%H%M%S)"
   ```
4. Fetch upstream:
   ```bash
   git fetch upstream --prune
   git fetch origin --prune
   ```
5. Create an integration branch, never merge directly into the user's stable branch unless asked.
6. Merge upstream and resolve conflicts by preserving local behavior listed in Non-Negotiable Rules.
7. Run:
   ```bash
   xcodegen generate
   xcodebuild -project FlashSpace.xcodeproj -scheme FlashSpace -configuration Debug -destination 'platform=macOS' build
   ```
8. Update `docs/upstream-v4.16.74-merge-impact.md` with user-facing behavior changes.

## Known Conflict Hotspots

Pay special attention to:

- `FlashSpace/Features/FocusManager/FocusManager.swift`
- `FlashSpace/Features/Workspaces/WorkspaceManager.swift`
- `FlashSpace/Features/Workspaces/WorkspaceHotKeys.swift`
- `FlashSpace/Features/Workspaces/Models/Workspace.swift`
- `FlashSpace/Features/Displays/DisplayManager.swift`
- `FlashSpace/Accessibility/NSRunningApplication+Properties.swift`
- `FlashSpace/Accessibility/BrowserFocusHelper.swift`
- `FlashSpace/Features/HotKeys/Models/KeyboardShortcuts.swift`
- `FlashSpace/Features/Settings/FocusManager/FocusSettingsView.swift`
- `FlashSpace/Features/Settings/_Models/AppSettings.swift`

## Validation Checklist

After merge or package:

- `git status --short --branch` is clean unless intentionally packaging only.
- `rg -n "Sign the CLI tool|Signing FlashSpace CLI|codesign --force --sign" project.yml FlashSpace.xcodeproj/project.pbxproj` returns nothing.
- `xcodebuild ... Debug build` passes after code changes.
- Personal Release script completes successfully.
- `codesign --verify --deep --strict --verbose=2 .build/DerivedData/Build/Products/Release/FlashSpace.app` passes.
- The bundled CLI reports ad-hoc runtime signing:
  ```bash
  codesign -dv --verbose=4 .build/DerivedData/Build/Products/Release/FlashSpace.app/Contents/Resources/flashspace
  ```

## Reference Files

- Read `references/local-behavior.md` before resolving upstream merge conflicts.
- Read `references/release-notes.md` when writing or updating user-facing merge-impact documentation.
