import AppKit
import SwiftUI
import Combine

/// 设置窗口的四个标签
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, calendars, focus, about

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general:   return "gearshape"
        case .calendars: return "calendar"
        case .focus:     return "scope"
        case .about:     return "info.circle"
        }
    }

    @MainActor var label: String { L("tab.\(rawValue)") }
}

/// 当前选中的标签，工具栏和内容区共用
@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab = .general
}

/// 标准设置窗口。
///
/// 不再用临时面板：点窗口外不会消失，可拖动缩放，位置与大小会记住。
/// 工具栏用 NSToolbar 的 preference 样式，标签切换时窗口标题跟着变。
@MainActor
final class SettingsWindowController: NSObject, NSToolbarDelegate, NSWindowDelegate {

    private let settings: SettingsStore
    private let calendarService: CalendarService
    private let navigation = SettingsNavigation()
    private var window: NSWindow?
    private var toolbar: NSToolbar?
    private var bag = Set<AnyCancellable>()

    init(settings: SettingsStore, calendarService: CalendarService) {
        self.settings = settings
        self.calendarService = calendarService
        super.init()
        // 语言一改，工具栏标签和窗口标题当场换
        L10n.shared.$code
            .dropFirst()
            .sink { [weak self] _ in Task { @MainActor in self?.refreshLabels() } }
            .store(in: &bag)
    }

    func show() {
        if window == nil { buildWindow() }
        guard let window else { return }
        refreshLabels()
        AppWindowTracker.windowOpened(window)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: 构建

    private func buildWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: DS.settingsW, height: DS.settingsH),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        w.isReleasedWhenClosed = false          // 关掉之后还要能再打开
        w.hidesOnDeactivate = false
        w.contentMinSize = NSSize(width: DS.settingsMinW, height: DS.settingsMinH)
        w.delegate = self

        // 用系统标准的窗口背景。做成透明窗口去透出桌面材质试过，
        // 缩放时标题栏和工具栏会重绘不全，所以不这么做。
        let host = NSHostingView(rootView: SettingsRoot(
            navigation: navigation, settings: settings, calendarService: calendarService))
        // 窗口大小由用户决定，内容的理想尺寸不参与
        host.sizingOptions = []
        w.contentView = host

        let tb = NSToolbar(identifier: "SettingsToolbar")
        tb.delegate = self
        tb.allowsUserCustomization = false
        tb.selectedItemIdentifier = NSToolbarItem.Identifier(navigation.tab.rawValue)
        w.toolbar = tb
        w.toolbarStyle = .preference
        toolbar = tb

        // 记住位置与大小；第一次打开没有记录，居中
        if !w.setFrameAutosaveName("SettingsWindow") { w.center() }
        window = w
    }

    private func refreshLabels() {
        window?.title = navigation.tab.label
        for item in toolbar?.items ?? [] {
            if let tab = SettingsTab(rawValue: item.itemIdentifier.rawValue) {
                item.label = tab.label
            }
        }
    }

    @objc private func selectTab(_ sender: NSToolbarItem) {
        guard let tab = SettingsTab(rawValue: sender.itemIdentifier.rawValue) else { return }
        navigation.tab = tab
        window?.title = tab.label
    }

    // MARK: NSToolbarDelegate

    private var identifiers: [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { identifiers }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { identifiers }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { identifiers }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab(rawValue: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.label
        item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.label)
        item.target = self
        item.action = #selector(selectTab(_:))
        return item
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        AppWindowTracker.windowClosed(w)
    }
}
