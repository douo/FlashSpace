//
//  Workspace.swift
//
//  Created by Wojciech Kulik on 19/01/2025.
//  Copyright © 2025 Wojciech Kulik. All rights reserved.
//

import AppKit
import Foundation

typealias WorkspaceID = UUID

struct Workspace: Identifiable, Codable, Hashable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case display
        case activateShortcut = "shortcut"
        case assignAppShortcut
        case apps
        case appToFocus
        case symbolIconName
        case openAppsOnActivation
    }

    var id: WorkspaceID
    var name: String
    var display: DisplayName
    var activateShortcut: AppHotKey?
    var assignAppShortcut: AppHotKey?
    var apps: [MacApp]
    var appToFocus: MacApp?
    var symbolIconName: String?
    var openAppsOnActivation: Bool?
}

extension Workspace {
    var displays: Set<DisplayName> {
        if NSScreen.screens.count == 1 {
            Logger.log("[Workspace] \(name): using Single Screen strategy")
            return [NSScreen.main?.localizedName ?? ""]
        } else if isDynamic {
            // TODO: After disconnecting a display, the detection may not work correctly.
            // The app will have the old coordinates until it is shown again, which
            // prevents from detecting the correct display.
            //
            // The workaround is to activate the app manually to update its frame.

            // 首先尝试使用 Accessibility API（最准确，但无法获取全屏空间的窗口）
            let axDisplays = NSWorkspace.shared.runningRegularApps
                .filter { apps.containsApp($0) }
                .flatMap(\.allDisplays)
                .asSet

            // 如果 Accessibility API 返回空（可能是全屏应用），使用 CoreGraphics API 作为 fallback
            // CoreGraphics 可以获取所有空间的窗口信息，包括全屏空间
            if axDisplays.isEmpty {
                Logger.log("[Workspace] \(name): using Dynamic (CoreGraphics) strategy")
                return displayManager.resolveDisplaysForApps(apps)
            }

            Logger.log("[Workspace] \(name): using Dynamic (Accessibility) strategy")
            return axDisplays
        } else {
            Logger.log("[Workspace] \(name): using Static (Config) strategy")
            return [displayManager.resolveDisplay(display)]
        }
    }

    var displayForPrint: DisplayName {
        if isDynamic,
           let mainDisplay = NSScreen.main?.localizedName,
           displays.contains(mainDisplay) {
            return mainDisplay
        }

        return isDynamic
            ? displayManager.lastActiveDisplay(from: displays)
            : displayManager.resolveDisplay(display)
    }

    var isOnTheCurrentScreen: Bool {
        guard let currentScreen = NSScreen.main?.localizedName else { return false }
        return displays.contains(currentScreen)
    }

    var isDynamic: Bool {
        AppDependencies.shared.workspaceSettings.displayMode == .dynamic
    }

    /// 检查工作区的应用是否有任何一个在运行
    var hasRunningApps: Bool {
        let runningBundleIds = NSWorkspace.shared.runningRegularApps
            .compactMap(\.bundleIdentifier)
            .asSet
        return apps.contains { runningBundleIds.contains($0.bundleIdentifier) }
    }

    /// 检查工作区是否可以激活
    /// 对于动态工作区：如果显示器为空，且没有应用在运行，且不自动打开应用，则不能激活
    var canActivate: Bool {
        if isDynamic, displays.isEmpty,
           !hasRunningApps,
           openAppsOnActivation != true {
            return false
        }
        return true
    }

    private var displayManager: DisplayManager {
        AppDependencies.shared.displayManager
    }
}

extension [Workspace] {
    func skipWithoutRunningApps() -> [Workspace] {
        let runningBundleIds = NSWorkspace.shared.runningRegularApps
            .compactMap(\.bundleIdentifier)
            .asSet

        return filter {
            $0.apps.contains { runningBundleIds.contains($0.bundleIdentifier) }
        }
    }
}
