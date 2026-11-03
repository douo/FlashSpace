//
//  NSRunningApplication+Actions.swift
//
//  Created by Wojciech Kulik on 16/02/2025.
//  Copyright © 2025 Wojciech Kulik. All rights reserved.
//

import AppKit

extension NSRunningApplication {
    func raise() {
        guard let mainWindow else {
            unhide()
            return
        }

        AXUIElementPerformAction(mainWindow, NSAccessibility.Action.raise as CFString)
    }

    func raiseSingleWindowIfNotVisible() {
        let windows = allWindows.filter {
            $0.window.subrole == kAXStandardWindowSubrole as String &&
                !$0.window.isMinimized && $0.frame.width > 10 && $0.frame.height > 10
        }
        guard windows.count == 1, let window = windows.first else { return }

        guard let onScreenWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return }

        let isVisible = onScreenWindows.contains { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }

            return abs(frame.minX - window.frame.minX) <= 1 &&
                abs(frame.minY - window.frame.minY) <= 1 &&
                abs(frame.width - window.frame.width) <= 1 &&
                abs(frame.height - window.frame.height) <= 1
        }
        guard !isVisible else { return }

        let result = AXUIElementPerformAction(window.window, NSAccessibility.Action.raise as CFString)
        if result != .success {
            Logger.log("Could not restore \(localizedName ?? "") window: \(result.rawValue)")
        }
    }

    /// Position is in window coordinates where (0,0) is top-left corner
    /// and it is relative to the main screen.
    func setPosition(_ position: CGPoint) {
        mainWindow?.setPosition(position)
    }

    func centerApp(display: DisplayName) {
        guard let appFrame = frame else {
            return Logger.log("Could not get frame for app: \(localizedName ?? "")")
        }

        guard let nsScreen = NSScreen.screen(display) else { return }
        guard appFrame.getDisplay() != nsScreen.localizedName else { return }

        let normalizedScreenFrame = nsScreen.normalizedFrame

        let origin = CGPoint(
            x: normalizedScreenFrame.midX - appFrame.width / 2.0,
            y: normalizedScreenFrame.midY - appFrame.height / 2.0
        )

        setPosition(origin)
    }

    func runWithoutAnimations(action: () -> ()) {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        let wasEnabled = appElement.enhancedUserInterface

        if wasEnabled { appElement.setAttribute(.enchancedUserInterface, value: false) }

        action()

        if wasEnabled { appElement.setAttribute(.enchancedUserInterface, value: true) }
    }
}
