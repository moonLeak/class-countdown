import AppKit
import SwiftUI

/// 统计窗口。阶段 6 之前先放占位，窗口与激活策略的行为已经是最终的。
@MainActor
final class StatsWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: DS.statsW, height: DS.statsH),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.hidesOnDeactivate = false
            w.delegate = self
            let host = NSHostingView(rootView: Text(L("stats.placeholder"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity))
            host.sizingOptions = []
            w.contentView = host
            if !w.setFrameAutosaveName("StatsWindow") { w.center() }
            window = w
        }
        guard let window else { return }
        window.title = L("stats.title")
        AppWindowTracker.windowOpened(window)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        AppWindowTracker.windowClosed(w)
    }
}
