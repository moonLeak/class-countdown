import AppKit
import SwiftUI
import Combine

/// 自己管的弹出面板。
///
/// 不用 MenuBarExtra 的 window 样式：那个容器会自带一层毛玻璃背景，
/// 卡片本身已经是 Liquid Glass，再垫一层就成了一个灰框，
/// 而那层背景由系统在窗口里绘制，从视图层级里清不掉。
/// 自己开一个无边框透明面板，背景就彻底归自己管。
@MainActor
final class PanelController: NSObject {

    private var statusItem: NSStatusItem!
    private var panel: TransparentPanel!
    private var settingsWindow: NSWindow?
    private var outsideMonitor: Any?
    private var bag = Set<AnyCancellable>()
    /// 退场那一下的延时任务。中途又被打开就取消掉，
    /// 否则它迟到落地，会把刚开的面板关掉，看上去就是点了没反应。
    private var hideWork: DispatchWorkItem?
    /// 出场退场的状态源。放在这里而不是视图的 @State：
    /// 面板窗口是复用的，视图不会重新创建，@State 不会自己回到初值，
    /// 快速连点时一旦有一次通知没被处理，它就卡在“收起”这一帧上再也不出来。
    let presentation = PanelPresentation()
    /// 显式记状态：点菜单栏按钮时 isVisible 可能已经被别处改过，靠它判断会漏掉一次收回
    private var isOpen = false

    private let state = AppState.shared

    /// 编译时刻，由 build.sh 写进 CFBundleVersion
    static var buildStamp: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown"
    }

    func install() {
        state.start()
        buildStatusItem()
        buildPanel()

        // 菜单栏那行字跟着心跳和状态走
        state.tick.$now
            .combineLatest(state.model.$phase)
            .sink { [weak self] now, phase in self?.refreshTitle(now: now, phase: phase) }
            .store(in: &bag)

        // 分隔符和显示内容改完要当场看到，不然得等下一次心跳
        state.settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.refreshTitle(now: self.state.tick.now, phase: self.state.model.phase)
                }
            }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: .panelDismissRequested)
            .sink { [weak self] _ in Task { @MainActor in self?.hide() } }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: .openSettingsRequested)
            .sink { [weak self] _ in Task { @MainActor in self?.openSettings() } }
            .store(in: &bag)

        // 展开收起会改变内容高度，面板得跟着变
        NotificationCenter.default.publisher(for: .panelContentResized)
            .sink { [weak self] note in
                guard let h = note.userInfo?["height"] as? CGFloat else { return }
                Task { @MainActor in self?.setPanelHeight(h) }
            }
            .store(in: &bag)
    }

    // MARK: 菜单栏

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        // 悬停能看到这一份是什么时候编译的，用来确认跑的是哪次产物
        button.toolTip = "ClassCountdown  build \(Self.buildStamp)"
        button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        refreshTitle(now: state.tick.now, phase: state.model.phase)
    }

    /// now 和 phase 一定由调用方传进来。
    /// @Published 在 willSet 时发布，订阅回调里读属性拿到的还是上一拍的值，
    /// 菜单栏就会比卡片慢整整一秒。
    private func refreshTitle(now: Date, phase: ScheduleModel.Phase) {
        guard let button = statusItem?.button else { return }
        let model = state.model
        switch phase {
        case .needsAccess:
            button.title = ""
            button.image = NSImage(systemSymbolName: "calendar.badge.exclamationmark",
                                   accessibilityDescription: L("a11y.needsAccess"))
        case .empty:
            button.title = ""
            button.image = NSImage(systemSymbolName: "calendar",
                                   accessibilityDescription: L("a11y.noEvents"))
        case .running(let list):
            guard let e = list.first else { return }
            button.image = nil
            button.title = TimeFormat.menuBar(
                title: e.title,
                time: TimeFormat.countdown(model.remaining(e, now: now)),
                showTitle: state.settings.showsTitleInMenuBar,
                separator: state.settings.separator)
        case .upcoming(let e):
            button.image = nil
            button.title = TimeFormat.menuBar(
                title: e.title,
                time: "↑" + TimeFormat.countdown(model.remaining(e, now: now, counting: true)),
                showTitle: state.settings.showsTitleInMenuBar,
                separator: state.settings.separator)
        }
    }

    // MARK: 设置窗口

    /// 自己建这个窗口。
    /// openSettings 环境值和 showSettingsWindow: 都要求调用方在 SwiftUI 的
    /// Settings 场景的响应链里，而面板是独立的 NSHostingView，够不着，
    /// 所以点了没反应。
    private func openSettings() {
        // 不关面板：设置窗口和卡片是两件独立的事，
        // 开着设置的同时该能继续看倒计时。
        if settingsWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            w.contentView = NSHostingView(
                rootView: SettingsView(settings: state.settings,
                                       calendarService: state.calendar))
            w.isReleasedWhenClosed = false   // 关掉之后还要能再打开
            w.center()
            settingsWindow = w
        }
        // 语言可能已经变过，每次打开都重取一次标题
        settingsWindow?.title = L("settings.title")

        // LSUIElement 的应用不在 Dock 里，不激活就会被压在别的窗口后面
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }

    // MARK: 面板

    private func buildPanel() {
        let p = TransparentPanel(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false                 // 阴影由卡片自己的玻璃给
        p.level = .popUpMenu
        p.isMovableByWindowBackground = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.animationBehavior = .utilityWindow

        let host = NSHostingView(rootView: CardStack(
            model: state.model,
            tick: state.tick,
            calendarService: state.calendar,
            presentation: presentation
        ))
        // 不碰 host 的尺寸策略，也不碰它的 layer。
        // Liquid Glass 靠 SwiftUI 自己的合成层渲染，外部一干预就退化成普通模糊。
        // 动画不会再被布局打断，因为卡片容器的高度本来就是恒定的。
        p.contentView = host
        panel = p
    }

    @objc private func togglePanel() {
        isOpen ? hide() : show()
    }

    private func show() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        panel.layoutIfNeeded()
        let size = panel.contentView?.fittingSize ?? .zero
        panel.setContentSize(size)

        let onScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var x = onScreen.midX - size.width / 2
        let y = onScreen.minY - size.height

        // 贴着屏幕边缘时往里收，别让面板掉出可见区域
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let limit = screen.visibleFrame
            x = min(max(x, limit.minX + 8), limit.maxX - size.width - 8)
        }

        // 上一次的退场还没落地就取消，否则它会把这次刚开的面板 orderOut 掉
        hideWork?.cancel()
        hideWork = nil

        // 先把起始帧摆好：窗口一露面就是动画的第一帧，
        // 反过来会先闪一下完整尺寸再缩回去。每次打开都归位成收起的一叠。
        presentation.expanded = false
        presentation.shown = false

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        // makeKey 而不是 orderFrontRegardless：
        // 不成为 key window，glassEffect 会退回非激活态的材质，
        // 而且第一次点击会被拿去抢 key，于是要点两下才展开。
        panel.makeKeyAndOrderFront(nil)
        panel.killShadow()
        isOpen = true
        statusItem.button?.highlight(true)
        installOutsideMonitor()

        // 隔一拍再起，同一帧里赋两次值 SwiftUI 只会看到最后那个，动画就没了
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isOpen else { return }
            withAnimation(DS.appear) { self.presentation.shown = true }
        }
    }

    /// 先让内容层缩回菜单栏，窗口等动画跑完再下线。
    /// 直接 orderOut 的话窗口一瞬间消失，动画根本来不及显示。
    private func hide() {
        guard isOpen else { return }
        isOpen = false
        statusItem.button?.highlight(false)
        removeOutsideMonitor()
        withAnimation(DS.appear) { presentation.shown = false }

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isOpen else { return }
            self.panel.orderOut(nil)
            self.hideWork = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + DS.appearDuration + 0.02, execute: work)
    }

    /// 点面板以外的任何地方就关掉，和系统弹出面板的行为一致
    private func installOutsideMonitor() {
        removeOutsideMonitor()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // 点在菜单栏按钮上就交给按钮自己处理成收回，
                // 这里放手，否则先关再开，看上去就是点了没反应
                if let button = self.statusItem.button, let win = button.window {
                    let onScreen = win.convertToScreen(button.convert(button.bounds, to: nil))
                    if onScreen.contains(NSEvent.mouseLocation) { return }
                }
                self.hide()
            }
        }
    }

    private func removeOutsideMonitor() {
        if let m = outsideMonitor { NSEvent.removeMonitor(m) }
        outsideMonitor = nil
    }

    /// 窗口高度只在日程数量变化时调整。
    /// 展开收起不再动窗口：一旦在动画途中 setFrame，NSHostingView 会重新布局，
    /// SwiftUI 正在跑的动画就被打断，那正是一跳一跳的来源。
    private func setPanelHeight(_ height: CGFloat) {
        guard panel != nil else { return }
        let f = panel.frame
        guard abs(f.height - height) > 0.5 else { return }
        // 面板挂在菜单栏下方往下长，所以顶边固定
        panel.setFrame(
            NSRect(x: f.minX, y: f.maxY - height, width: f.width, height: height),
            display: true, animate: false)
    }
}

/// 面板出场退场的状态源
@MainActor
final class PanelPresentation: ObservableObject {
    /// true 是完整尺寸，false 是缩在菜单栏图标那一点上
    @Published var shown = false
    /// 卡叠是否展开
    @Published var expanded = false
}

/// borderless 的面板默认当不了 key window，右键菜单和按钮就没法交互
final class TransparentPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 面板被激活时系统会把窗口阴影加回来。
    /// 同一拍里按掉按不住，系统在这之后还会再设一次，所以下一拍补一刀。
    func killShadow() {
        hasShadow = false
        invalidateShadow()
        DispatchQueue.main.async { [weak self] in
            self?.hasShadow = false
            self?.invalidateShadow()
        }
    }

    override func becomeKey() {
        super.becomeKey()
        killShadow()
    }

    override func resignKey() {
        super.resignKey()
        killShadow()
    }
}
