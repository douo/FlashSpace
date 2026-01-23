//
//  BrowserFocusHelper.swift
//
//  Created on 2026/01/22.
//  Copyright © 2026 Wojciech Kulik. All rights reserved.
//

import AppKit

/// 浏览器 bundle identifiers，这些浏览器可能需要特殊的焦点处理
/// 来确保 web content 获得键盘焦点
enum BrowserBundleID: String, CaseIterable {
    case chrome = "com.google.Chrome"
    case chromeBeta = "com.google.Chrome.beta"
    case chromeCanary = "com.google.Chrome.canary"
    case chromium = "org.chromium.Chromium"
    case edge = "com.microsoft.edgemac"
    case brave = "com.brave.Browser"
    case arc = "company.thebrowser.Browser"
    case vivaldi = "com.vivaldi.Vivaldi"
    case opera = "com.operasoftware.Opera"
}

/// 辅助类，用于处理浏览器（特别是 Chromium 系）的 web content 焦点问题
/// 当使用 hide/unhide 切换工作区时，浏览器窗口可能获得焦点，但 web content 不会
/// 这会导致浏览器扩展（如 Vimium C）无法接收键盘事件
final class BrowserFocusHelper {
    
    /// 检查指定应用是否是需要特殊焦点处理的浏览器
    static func isBrowser(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }
        return BrowserBundleID.allCases.contains { $0.rawValue == bundleId }
    }
    
    /// 尝试将焦点设置到浏览器的 web content 区域
    /// 这通过查找 AXWebArea 元素并设置 AXFocused 属性来实现
    static func focusWebContent(for app: NSRunningApplication) {
        guard isBrowser(app) else { return }
        
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // 首先尝试获取当前聚焦的窗口
        guard let focusedWindow: AXUIElement = appElement.getAttribute(.focusedWindow) else {
            Logger.log("[BrowserFocusHelper] Could not get focused window for \(app.localizedName ?? "unknown")")
            return
        }
        
        // 递归查找 AXWebArea 元素
        if let webArea = findWebArea(in: focusedWindow) {
            let success = webArea.setAttribute(.focused, value: true)
            if success {
                Logger.log("[BrowserFocusHelper] Successfully set focus to AXWebArea")
            } else {
                Logger.log("[BrowserFocusHelper] Failed to set focus to AXWebArea (AXError), trying fallback...")
                simulateEscapeKey()
            }
        } else {
            Logger.log("[BrowserFocusHelper] Could not find AXWebArea in \(app.localizedName ?? "unknown"), trying fallback...")
            simulateEscapeKey()
        }
    }
    
    /// 递归查找 AXWebArea 元素
    private static func findWebArea(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        // 限制递归深度，避免性能问题
        guard depth < 10 else { return nil }
        
        // 检查当前元素的 role
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        
        if let role = roleValue as? String, role == "AXWebArea" {
            return element
        }
        
        // 获取子元素
        var childrenValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        
        guard let children = childrenValue as? [AXUIElement] else { return nil }
        
        // 递归搜索子元素
        for child in children {
            if let webArea = findWebArea(in: child, depth: depth + 1) {
                return webArea
            }
        }
        
        return nil
    }

    /// 备选方案：通过发送无修饰符的 ESC 键来尝试重置焦点
    /// 这通常能把焦点从地址栏或其他 UI 元素归还给网页内容
    /// 使用 explicit flags = [] 避免受用户当前按下的修饰键（如 Ctrl）影响
    private static func simulateEscapeKey() {
        Logger.log("[BrowserFocusHelper] Simulating modifier-free ESC key press")
        
        let validFlags = CGEventFlags(rawValue: 0) // 清除所有修饰符
        
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: true), // 0x35 is Esc
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: false)
        else { return }
        
        keyDown.flags = validFlags
        keyUp.flags = validFlags
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
