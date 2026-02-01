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
        let screens = NSScreen.screens
        
        // Quartz 坐标系: (0,0) 在**主屏幕**左上角，Y 向下增加
        // Cocoa 坐标系: (0,0) 在**主屏幕**左下角，Y 向上增加
        // 注意：NSScreen.screens[0] 是主屏幕（Quartz 坐标系的基准屏幕）
        // 这与 NSScreen.normalizedFrame 的实现保持一致
        guard let mainScreen = screens.first else { return [] }
        let mainScreenHeight = mainScreen.frame.height

        return list.compactMap { info -> WindowInfo? in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pidsSet.contains(pid),
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width > 10, bounds.height > 10
            else { return nil }

            // 将 Quartz 坐标（Y-down）转换为 Cocoa 坐标（Y-up）
            // cocoaY = mainScreenHeight - (quartzY + windowHeight)
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

