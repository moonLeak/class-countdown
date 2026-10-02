import AppKit

/// 管理应用的激活策略。
///
/// TimeTool 平时是 .accessory：没有 Dock 图标，也没有菜单栏。
/// 设置和统计这类标准窗口打开时要切到 .regular，窗口才能正常激活，
/// 也才有 Dock 图标和 Command+Tab 入口。最后一个窗口关掉后回到 .accessory。
@MainActor
enum AppWindowTracker {

    private static var openWindows = Set<ObjectIdentifier>()

    static func windowOpened(_ window: NSWindow) {
        openWindows.insert(ObjectIdentifier(window))
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    static func windowClosed(_ window: NSWindow) {
        openWindows.remove(ObjectIdentifier(window))
        if openWindows.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
