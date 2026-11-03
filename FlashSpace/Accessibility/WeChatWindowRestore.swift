//
//  WeChatWindowRestore.swift
//

import AppKit

enum WeChatWindowRestore {
    @discardableResult
    static func reopenIfNeeded(_ app: NSRunningApplication) -> Bool {
        guard let url = app.bundleURL,
              let windows = CGWindowListCopyWindowInfo(
                  [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
              ) as? [[String: Any]],
              !hasVisibleWindow(windows, for: app.processIdentifier) else { return false }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                DispatchQueue.main.async { Logger.log("Could not reopen WeChat: \(error)") }
            }
        }
        return true
    }

    static func hasVisibleWindow(_ windows: [[String: Any]], for pid: pid_t) -> Bool {
        windows.contains { info in
            guard let owner = info[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }

            // Ignore the menu bar and small auxiliary surfaces owned by WeChat.
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            return alpha > 0 && frame.width > 100 && frame.height > 100
        }
    }
}
