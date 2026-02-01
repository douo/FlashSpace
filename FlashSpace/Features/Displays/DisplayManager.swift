//
//  DisplayManager.swift
//
//  Created by Moritz Brödel on 19/06/2025.
//  Copyright © 2025 Wojciech Kulik. All rights reserved.
//

import AppKit
import Combine

final class DisplayManager: ObservableObject {
    struct Focus {
        let display: DisplayName
        let app: MacApp
    }

    private var focusHistory: [Focus] = []
    private let workspaceSettings: WorkspaceSettings

    init(settingsRepository: SettingsRepository) {
        self.workspaceSettings = settingsRepository.workspaceSettings
    }

    func lastFocusedDisplay(where condition: (Focus) -> Bool) -> Focus? {
        focusHistory.last(where: condition)
    }

    func trackDisplayFocus(on display: DisplayName, for application: NSRunningApplication) {
        guard !application.isFinder || application.allWindows.isNotEmpty else { return }

        focusHistory.removeAll { $0.display == display }
        focusHistory.append(.init(display: display, app: application.toMacApp))
    }

    func getCursorScreen() -> DisplayName? {
        let cursorLocation = NSEvent.mouseLocation
        return NSScreen.screens
            .first { NSMouseInRect(cursorLocation, $0.frame, false) }?
            .localizedName
    }

    func resolveDisplay(_ display: DisplayName) -> DisplayName {
        guard !NSScreen.isConnected(display) else { return display }

        let alternativeDisplays = workspaceSettings.alternativeDisplays
            .split(separator: ";")
            .map { $0.split(separator: "=") }
            .compactMap { pair -> (source: String, target: String)? in
                guard pair.count == 2 else { return nil }
                return (String(pair[0]).trimmed, String(pair[1]).trimmed)
            }

        let alternative = alternativeDisplays
            .filter { $0.source == display }
            .map(\.target)
            .first(where: NSScreen.isConnected)

        if let alternative {
            Logger.log("[Display] Resolved alternative for '\(display)' -> '\(alternative)'")
            return alternative
        }

        let main = NSScreen.main?.localizedName ?? ""
        Logger.log("[Display] Fallback for '\(display)' -> '\(main)'")
        return main
    }

    func lastActiveDisplay(from candidates: Set<DisplayName>) -> DisplayName {
        if let recentDisplay = lastFocusedDisplay(where: { candidates.contains($0.display) })?.display {
            return recentDisplay
        }

        if let cursorDisplay = getCursorScreen(), candidates.contains(cursorDisplay) {
            return cursorDisplay
        }

        return candidates.first ?? NSScreen.main?.localizedName ?? ""
    }

    // MARK: - CoreGraphics-based Display Resolution

    /// 使用 CoreGraphics API 快速解析应用的显示器位置
    /// - 优点：可以获取所有空间的窗口，包括 macOS 原生全屏空间
    /// - 用途：解决 Dynamic Workspace 中隐藏或全屏应用无法通过 Accessibility API 获取位置的问题
    /// - Parameter apps: 要查询的应用列表
    /// - Returns: 应用所在的显示器集合，如果无法解析则返回空集合
    func resolveDisplaysForApps(_ apps: [MacApp]) -> Set<DisplayName> {
        let runningApps = apps.compactMap { NSWorkspace.shared.runningApplications.find($0) }
        guard runningApps.isNotEmpty else { return [] }

        let pids = runningApps.map(\.processIdentifier)
        let windows = WindowInfoUtils.getWindows(for: pids)
        
        // 调试日志：显示找到的窗口和屏幕信息
        Logger.log("[CG] Looking for PIDs: \(pids), found \(windows.count) windows")
        for window in windows {
            let display = window.frame.getDisplay()
            Logger.log("[CG] Window pid:\(window.pid) frame:\(window.frame) -> display: \(display ?? "nil")")
        }
        Logger.log("[CG] Available screens: \(NSScreen.screens.map { "\($0.localizedName ?? ""): \($0.normalizedFrame)" })")

        let displays = runningApps
            .compactMap { $0.getDisplay(using: windows) }
            .asSet

        if displays.isNotEmpty {
            Logger.log("[Display] Resolved via CoreGraphics: \(displays)")
        } else {
            Logger.log("[Display] CoreGraphics failed to resolve any display")
        }

        return displays
    }
}
