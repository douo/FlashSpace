# FlashSpace Local Behavior Reference

Preserve these behaviors when merging upstream changes.

## Current Screen Semantics

Keep the original `NSScreen.main` / `DisplayName.current` semantics for general workspace logic.

Only use mouse screen semantics where the feature explicitly needs it:

- `focusNextScreen`
- `focusPreviousScreen`
- existing `switchWorkspaceOnCursorScreen`

Do not globally redefine `DisplayName.current` to cursor screen.

## Minimized Windows

Minimized windows must not count as active display/focus candidates.

Expected preserved checks:

- `NSRunningApplication.allDisplays` filters `!$0.window.isMinimized`.
- Directional focus filters `!$0.window.isMinimized`.
- Cross-screen focus filters `!windowInfo.window.isMinimized`.

This prevents minimized windows from creating ghost workspace/display activity.

## Dynamic Workspace Activation

Preserve `Workspace.canActivate` semantics:

- Dynamic workspace with no running apps and no auto-open should show “No Running Apps To Show”.
- Dynamic workspace with no running apps but `openAppsOnActivation == true` should still activate and launch apps.

When upstream adds recent-workspace behavior, run the recent-workspace branch first, then apply local `canActivate`.

## Dynamic Workspace Display Resolution

Preserve CoreGraphics fallback:

- Try Accessibility-derived displays first.
- If empty, use `DisplayManager.resolveDisplaysForApps`.
- If still empty during activation and the workspace has apps, fallback to cursor screen or `.current`.

## Chromium Focus Workaround

Preserve `BrowserFocusHelper`:

- After unhide/show of Chromium-family browser, attempt to focus AXWebArea.
- Keep fallback `Esc` behavior because the user explicitly chose to retain it.

## Hotkey Migration

When upstream uses `KeyboardShortcuts`, local screen-focus hotkeys must be represented as:

- `HotKeyName.focusNextScreen`
- `HotKeyName.focusPreviousScreen`
- `RecordedHotKey(name: .focusNextScreen, hotKey: ..., action: focusNextScreen)`
- `RecordedHotKey(name: .focusPreviousScreen, hotKey: ..., action: focusPreviousScreen)`
