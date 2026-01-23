//
//  WindowInfoUtils.swift
//
//  Created by Wojciech Kulik on 24/01/2026.
//  Copyright © 2026 Wojciech Kulik. All rights reserved.
//

import AppKit

struct WindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let frame: CGRect
}

enum WindowInfoUtils {
    static func getWindows(for pids: [pid_t]) -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let pidsSet = Set(pids)
        // Global visual coordinate system has (0,0) at top-left of the primary screen for Quartz (CGWindowList).
        // Cocoa uses (0,0) at bottom-left of the primary screen.
        // We need to flip the Y coordinate.
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0

        return list.compactMap { info -> WindowInfo? in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pidsSet.contains(pid),
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width > 10, bounds.height > 10
            else { return nil }

            // Convert raw Quartz bounds (Y-down) to Cocoa bounds (Y-up)
            var cocoaFrame = bounds
            cocoaFrame.origin.y = mainScreenHeight - bounds.maxY

            return WindowInfo(
                id: info[kCGWindowNumber as String] as? CGWindowID ?? 0,
                pid: pid,
                frame: cocoaFrame
            )
        }
    }
}
