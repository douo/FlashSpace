//
//  FocusManager.swift
//
//  Created by Wojciech Kulik on 23/01/2025.
//  Copyright © 2025 Wojciech Kulik. All rights reserved.
//

import AppKit
import Foundation

final class FocusManager {
    var visibleApps: [NSRunningApplication] {
        NSWorkspace.shared.runningRegularApps.filter { !$0.isHidden }
    }

    var focusedApp: NSRunningApplication? { NSWorkspace.shared.frontmostApplication }
    var focusedAppFrame: CGRect? { focusedApp?.frame }

    private let workspaceRepository: WorkspaceRepository
    private let workspaceManager: WorkspaceManager
    private let settings: FocusManagerSettings
    private let floatingAppsSettings: FloatingAppsSettings
    private let displayManager: DisplayManager

    init(
        workspaceRepository: WorkspaceRepository,
        workspaceManager: WorkspaceManager,
        focusManagerSettings: FocusManagerSettings,
        floatingAppsSettings: FloatingAppsSettings,
        displayManager: DisplayManager
    ) {
        self.workspaceRepository = workspaceRepository
        self.workspaceManager = workspaceManager
        self.settings = focusManagerSettings
        self.floatingAppsSettings = floatingAppsSettings
        self.displayManager = displayManager
    }

    func getHotKeys() -> [(AppHotKey, () -> ())] {
        guard settings.enableFocusManagement else { return [] }

        return [
            settings.focusLeft.flatMap { ($0, focusLeft) },
            settings.focusRight.flatMap { ($0, focusRight) },
            settings.focusUp.flatMap { ($0, focusUp) },
            settings.focusDown.flatMap { ($0, focusDown) },
            settings.focusNextWorkspaceApp.flatMap { ($0, nextWorkspaceApp) },
            settings.focusPreviousWorkspaceApp.flatMap { ($0, previousWorkspaceApp) },
            settings.focusNextWorkspaceWindow.flatMap { ($0, nextWorkspaceWindow) },
            settings.focusPreviousWorkspaceWindow.flatMap { ($0, previousWorkspaceWindow) },
            settings.focusNextScreen.flatMap { ($0, focusNextScreen) },
            settings.focusPreviousScreen.flatMap { ($0, focusPreviousScreen) }
        ].compactMap { $0 }
    }

    func nextWorkspaceWindow() {
        guard let focusedApp else { return nextWorkspaceApp() }
        guard let (_, apps) = getFocusedAppIndex() else { return }

        let runningWorkspaceApps = getRunningAppsWithSortedWindows(apps: apps)
        let focusedAppWindows = runningWorkspaceApps
            .first { $0.bundleIdentifier == focusedApp.bundleIdentifier }?
            .windows ?? []
        let isLastWindowFocused = focusedAppWindows.last?.axWindow.isMain == true

        if isLastWindowFocused {
            let nextApps = runningWorkspaceApps.drop(while: { $0.bundleIdentifier != focusedApp.bundleIdentifier }).dropFirst() +
                runningWorkspaceApps.prefix(while: { $0.bundleIdentifier != focusedApp.bundleIdentifier })
            let nextApp = nextApps.first ?? MacAppWithWindows(app: focusedApp)

            nextApp.app.activate()
            nextApp
                .windows
                .first?
                .axWindow
                .focus()
        } else {
            focusedAppWindows
                .drop(while: { !$0.axWindow.isMain })
                .dropFirst()
                .first?
                .axWindow
                .focus()
        }
    }

    func previousWorkspaceWindow() {
        guard let focusedApp else { return previousWorkspaceApp() }
        guard let (_, apps) = getFocusedAppIndex() else { return }

        let runningWorkspaceApps = getRunningAppsWithSortedWindows(apps: apps)
        let focusedAppWindows = runningWorkspaceApps
            .first { $0.bundleIdentifier == focusedApp.bundleIdentifier }?
            .windows ?? []
        let isFirstWindowFocused = focusedAppWindows.first?.axWindow.isMain == true

        if isFirstWindowFocused {
            let prevApps = runningWorkspaceApps.drop(while: { $0.bundleIdentifier != focusedApp.bundleIdentifier }).dropFirst() +
                runningWorkspaceApps.prefix(while: { $0.bundleIdentifier != focusedApp.bundleIdentifier })
            let prevApp = prevApps.last ?? MacAppWithWindows(app: focusedApp)

            prevApp.app.activate()
            prevApp
                .windows
                .last?
                .axWindow
                .focus()
        } else {
            focusedAppWindows
                .prefix(while: { !$0.axWindow.isMain })
                .last?
                .axWindow
                .focus()
        }
    }

    func nextWorkspaceApp() {
        guard let (index, apps) = getFocusedAppIndex() else { return }

        let appsQueue = apps.dropFirst(index + 1) + apps.prefix(index)
        let runningApps = NSWorkspace.shared.runningApplications
            .excludeFloatingAppsOnDifferentScreen()
            .compactMap(\.bundleIdentifier)
            .asSet
        let nextApp = appsQueue.first { app in runningApps.contains(app.bundleIdentifier) }

        NSWorkspace.shared.runningApplications
            .find(nextApp)?
            .activate()
    }

    func previousWorkspaceApp() {
        guard let (index, apps) = getFocusedAppIndex() else { return }

        let runningApps = NSWorkspace.shared.runningApplications
            .excludeFloatingAppsOnDifferentScreen()
            .compactMap(\.bundleIdentifier)
            .asSet
        let prefixApps = apps.prefix(index).reversed()
        let suffixApps = apps.suffix(apps.count - index - 1).reversed()
        let appsQueue = prefixApps + Array(suffixApps)
        let previousApp = appsQueue.first { app in runningApps.contains(app.bundleIdentifier) }

        NSWorkspace.shared.runningApplications
            .find(previousApp)?
            .activate()
    }

    func focusRight() {
        focus { focusedAppFrame, other in
            other.maxX > focusedAppFrame.maxX &&
                other.verticalIntersect(with: focusedAppFrame)
        }
    }

    func focusLeft() {
        focus { focusedAppFrame, other in
            other.minX < focusedAppFrame.minX &&
                other.verticalIntersect(with: focusedAppFrame)
        }
    }

    func focusDown() {
        focus { focusedAppFrame, other in
            other.maxY > focusedAppFrame.maxY &&
                other.horizontalIntersect(with: focusedAppFrame)
        }
    }

    func focusUp() {
        focus { focusedAppFrame, other in
            other.minY < focusedAppFrame.minY &&
                other.horizontalIntersect(with: focusedAppFrame)
        }
    }

    func focusNextScreen() {
        focusScreen(offset: 1)
    }

    func focusPreviousScreen() {
        focusScreen(offset: -1)
    }

    private func focusScreen(offset: Int) {
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        guard !screens.isEmpty else { return }

        let mouseLocation = NSEvent.mouseLocation
        let currentScreenIndex = screens.firstIndex { NSMouseInRect(mouseLocation, $0.frame, false) } ??
            screens.firstIndex { $0 == NSScreen.main } ?? 0

        let targetIndex = (currentScreenIndex + offset + screens.count) % screens.count
        let targetScreen = screens[targetIndex]

        activateScreen(targetScreen)
    }

    private func activateScreen(_ screen: NSScreen) {
        let displayName = screen.localizedName
        let screenFrameCG = cocoaToCGRect(screen.frame)

        // 收集目标屏幕上所有可见窗口
        let visibleWindowsOnScreen = visibleApps
            .flatMap { app in
                app.allWindows.map { (app: app, window: $0.window, frame: $0.frame) }
            }
            .filter { windowInfo in
                // 窗口坐标是 CG 坐标系
                screenFrameCG.contains(
                    CGPoint(x: windowInfo.frame.midX, y: windowInfo.frame.midY)
                ) && !windowInfo.window.isMinimized
            }

        // 优先查找最近获得焦点的 App 的窗口
        if let lastFocused = displayManager.lastFocusedDisplay(where: { $0.display == displayName }) {
            if let targetWindow = visibleWindowsOnScreen
                .first(where: { $0.app.bundleIdentifier == lastFocused.app.bundleIdentifier })
            {
                targetWindow.window.focus()
                targetWindow.app.activate()
                let windowCenter = CGPoint(x: targetWindow.frame.midX, y: targetWindow.frame.midY)
                CGWarpMouseCursorPosition(windowCenter)
                return
            }
        }

        // 回退：选择目标屏幕上最上层的可见窗口（按 Y 坐标排序，Y 小的在上）
        if let topWindow = visibleWindowsOnScreen.sorted(by: { $0.frame.minY < $1.frame.minY }).first {
            topWindow.window.focus()
            topWindow.app.activate()
            let windowCenter = CGPoint(x: topWindow.frame.midX, y: topWindow.frame.midY)
            CGWarpMouseCursorPosition(windowCenter)
        } else {
            // 没有窗口，只移动鼠标到屏幕中心
            let screenCenterCG = cocoaToCGPoint(CGPoint(x: screen.frame.midX, y: screen.frame.midY))
            CGWarpMouseCursorPosition(screenCenterCG)
        }
    }

    /// 将 Cocoa 坐标系的点转换为 CG 坐标系的点
    private func cocoaToCGPoint(_ point: CGPoint) -> CGPoint {
        guard let mainScreen = NSScreen.screens.first else { return point }
        return CGPoint(x: point.x, y: mainScreen.frame.height - point.y)
    }

    /// 将 Cocoa 坐标系的矩形转换为 CG 坐标系的矩形
    private func cocoaToCGRect(_ rect: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return rect }
        let cgY = mainScreen.frame.height - rect.maxY
        return CGRect(x: rect.minX, y: cgY, width: rect.width, height: rect.height)
    }

    /// Predicate compares two frames using window coordinates.
    /// (0,0) is top-left corner relative to the main screen.
    /// Y-axis is pointing down.
    private func focus(predicate: (CGRect, CGRect) -> Bool) {
        guard let focusedAppFrame else { return }

        let appsToCheck = visibleApps
            .flatMap { app in
                app.allWindows.map {
                    (app: app, window: $0.window, frame: $0.frame)
                }
            }

        let toFocus = appsToCheck
            .filter { predicate(focusedAppFrame, $0.frame) && !$0.window.isMinimized }
            .sorted { $0.frame.distance(to: focusedAppFrame) < $1.frame.distance(to: focusedAppFrame) }
            .first { app in
                guard settings.focusFrontmostWindow else { return true }

                let otherWindows = appsToCheck
                    .filter { $0.app != app.app && $0.app != focusedApp }
                    .map(\.window)
                return !app.window.isBelowAnyOf(otherWindows)
            }

        toFocus?.window.focus()
        toFocus?.app.activate()
        centerCursorIfNeeded(in: toFocus?.frame)
    }

    private func centerCursorIfNeeded(in frame: CGRect?) {
        guard settings.centerCursorOnFocusChange, let frame else { return }

        CGWarpMouseCursorPosition(CGPoint(x: frame.midX, y: frame.midY))
    }

    private func getFocusedAppIndex() -> (Int, [MacApp])? {
        guard let focusedApp else { return nil }

        let workspace = workspaceManager.activeWorkspace[NSScreen.main?.localizedName ?? ""]
            ?? workspaceRepository.workspaces.first { $0.apps.containsApp(focusedApp) }

        guard let workspace else { return nil }

        let apps = workspace.apps + floatingAppsSettings.floatingApps
            .filter { !$0.isFinder }

        let index = apps.firstIndex(of: focusedApp) ?? 0

        return (index, apps)
    }

    private func getRunningAppsWithSortedWindows(apps: [MacApp]) -> [MacAppWithWindows] {
        let order = apps
            .enumerated()
            .reduce(into: [String: Int]()) {
                $0[$1.element.bundleIdentifier] = $1.offset
            }

        return NSWorkspace.shared.runningApplications
            .filter { !$0.isHidden && apps.containsApp($0) }
            .excludeFloatingAppsOnDifferentScreen()
            .map { MacAppWithWindows(app: $0) }
            .sorted { order[$0.bundleIdentifier] ?? 0 < order[$1.bundleIdentifier] ?? 0 }
    }
}
