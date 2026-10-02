import AppKit
import SwiftUI

/// 统计窗口：标准窗口，可缩放，与设置窗口共用激活策略逻辑。
@MainActor
final class StatsWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let focus: FocusController

    init(focus: FocusController) {
        self.focus = focus
        super.init()
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: DS.statsW, height: DS.statsH),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.hidesOnDeactivate = false
            w.delegate = self
            let host = NSHostingView(rootView: StatsView(focus: focus))
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
