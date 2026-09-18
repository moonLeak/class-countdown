import Foundation
import AppKit

/// 休眠唤醒通知的小包装，避免在 CalendarService 里直接引 AppKit。
enum NSWorkspaceNotificationBridge {
    private static var tokens: [NSObjectProtocol] = []

    static func onWake(_ handler: @escaping () -> Void) {
        let center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in handler() })

        // 时区变更（FR：跨时区仍正确）。内部计算本来就是绝对时间，这里只是逼一次重绘。
        tokens.append(NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
        ) { _ in handler() })
    }
}

enum NSWorkspaceBridge {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func openCalendarPrivacySettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    /// 打开系统日历。先按 bundle id 找应用，找不到再退回 ical:// 协议。
    static func openCalendarApp() {
        let ws = NSWorkspace.shared
        if let app = ws.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            ws.openApplication(at: app, configuration: cfg, completionHandler: nil)
            return
        }
        if let url = URL(string: "ical://") { ws.open(url) }
    }

    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
