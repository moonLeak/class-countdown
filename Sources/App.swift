import SwiftUI
import AppKit

@main
@MainActor
struct ClassCountdownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // 菜单栏、弹出面板、设置窗口都归 PanelController 管。
        // 这里只是占位：SwiftUI 的 App 至少要有一个 Scene，
        // 而 Settings 场景不会自己冒出来。
        Settings { EmptyView() }
    }
}

/// NSApplicationDelegate 的回调本来就在主线程，
/// 整个类标到主 actor 上，PanelController 才能作为存储属性直接建
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panelController = PanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController.install()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

extension Notification.Name {
    /// 面板尺寸要跟着内容变，靠这个通知从 SwiftUI 那侧推过来
    static let panelContentResized = Notification.Name("panelContentResized")
    /// 右键菜单里点了设置
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    /// 内容层请求收回面板（例如跳去日历之后）
    static let panelDismissRequested = Notification.Name("panelDismissRequested")
}
