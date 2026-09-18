import SwiftUI
import AppKit

/// 弹出面板：重叠的日程堆成一叠卡包。
/// 单击展开收起，二段重按打开日历，右键出应用菜单。
/// 面板自身不画背景，卡片直接浮在桌面上。
struct CardStack: View {

    // 必须直接观察这三个对象。挂在 AppState 上没用：
    // 它只是个持有者，自身没有任何 @Published，
    // objectWillChange 永远不发，视图会停在第一帧。
    @ObservedObject var model: ScheduleModel
    @ObservedObject var tick: TickEngine
    @ObservedObject var calendarService: CalendarService
    @ObservedObject private var l10n = L10n.shared
    /// 出场退场与展开状态都由控制器持有：面板窗口复用，视图不重建，
    /// 放在 @State 里一旦漏掉一次事件就再也回不到正确的那一帧。
    @ObservedObject var presentation: PanelPresentation

    /// 二段重按的下沉反馈，只作用在被按的那一张上
    @State private var pressedIndex: Int? = nil

    private var expanded: Bool { presentation.expanded }

    private var now: Date { tick.now }

    var body: some View {
        // 不能用 GlassEffectContainer：同一个容器里的玻璃共享背景采样，
        // 于是它们互相不模糊，后面卡片的内容会直接透到最前面来。
        // 每张卡各自独立取景，前面那张才会把后面那张糊掉。
        Group {
            switch model.phase {
            case .needsAccess: AccessPanel(calendarService: calendarService)
            case .empty:       MessagePanel(head: L("panel.emptyHead"),
                                            message: L("panel.emptyBody"))
            case .upcoming(let e): singleCard(e, toStart: true)
            case .running(let list): deck(list)
            }
        }
        // 四周留给玻璃投影扩散的余量。
        // 投影 radius 14 加 y 偏移 10，四周至少要 24 才不会被切；
        // 留 14 的话左右正好卡在边界上，看着就是一条硬边。
        .padding(DS.panelInset)
        .fixedSize()
        // 出场退场：锚点取顶边中点，那正是菜单栏图标所在的位置，
        // 于是卡片看上去是从那个小图标里放大出来的，收回时原路缩回去。
        .scaleEffect(presentation.shown ? 1 : DS.appearScale, anchor: .top)
        .opacity(presentation.shown ? 1 : 0)
        .contextMenu { menuItems }
        .onAppear { postHeight() }
        .onChange(of: presentation.shown) { _, shown in
            if !shown { pressedIndex = nil }
        }
        .onChange(of: model.phase) { _, _ in
            // 日程数量变了，最大高度才需要重新报
            postHeight()
        }
    }

    private func postHeight() {
        NotificationCenter.default.post(
            name: .panelContentResized, object: nil,
            userInfo: ["height": panelHeight()])
    }

    // MARK: 菜单：应用级操作，挂在整叠上而不是某张卡上

    @ViewBuilder
    private var menuItems: some View {
        Button(L("menu.openCalendar")) { openCalendar() }
        Divider()
        Button(L("menu.settings")) {
            NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
        }
        Button(L("menu.about")) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        }
        Divider()
        Button(L("menu.quit")) { NSWorkspaceBridge.quit() }
    }

    // MARK: 交互：单击展开，二段重按开日历

    /// 跳去日历，随后把面板收回：手已经离开这块内容了，留着它挡在日历前面没有意义
    private func openCalendar() {
        NSWorkspaceBridge.openCalendarApp()
        // 让日历先起来，再收面板。同一帧里做完两件事，看上去就只剩“啪一下没了”
        DispatchQueue.main.asyncAfter(deadline: .now() + DS.dismissDelay) {
            NotificationCenter.default.post(name: .panelDismissRequested, object: nil)
        }
    }

    /// 每张卡各有一块交互区，重按的反馈才落在手指按住的那一张上
    private func interaction(_ index: Int) -> some View {
        InteractionArea(
            onClick: {
                withAnimation(DS.motion) { presentation.expanded.toggle() }
            },
            onForceClick: {
                // 三拍，顺序不能乱：先让手指感觉到卡片沉下去，
                // 再弹回并跳去日历，最后才收面板。
                // 把这三件事挤在同一帧，重按的反馈就等于没有。
                DispatchQueue.main.asyncAfter(deadline: .now() + DS.pressHold) {
                    withAnimation(DS.press) { pressedIndex = nil }
                    openCalendar()
                }
            },
            onPressing: { down in
                withAnimation(DS.press) { pressedIndex = down ? index : nil }
            }
        )
    }

    // MARK: 单张

    private func singleCard(_ e: ScheduleModel.EventSnapshot, toStart: Bool) -> some View {
        CountdownCard(
            event: e,
            progress: toStart ? 0 : model.progress(e, now: now),
            warning: toStart ? false : model.isWarning(e, now: now),
            countdown: TimeFormat.countdown(model.remaining(e, now: now, counting: toStart)),
            subtitle: toStart ? L("panel.toStart") : nil,
            fullness: 1
        )
        .scaleEffect(pressedIndex == 0 ? DS.pressScale : 1)
        .overlay { interaction(0) }
    }

    // MARK: 一叠

    private func deck(_ list: [ScheduleModel.EventSnapshot]) -> some View {
        let n = list.count

        return ZStack(alignment: .top) {
            ForEach(Array(list.enumerated()), id: \.element.id) { pair in
                let i = pair.offset
                let e = pair.element
                let full: Double = (expanded || i == 0) ? 1 : 0
                CountdownCard(
                    event: e,
                    progress: model.progress(e, now: now),
                    warning: model.isWarning(e, now: now),
                    countdown: TimeFormat.countdown(model.remaining(e, now: now)),
                    fullness: full
                )
                .overlay { interaction(i) }
                // 重按的缩放挂在这一层，和堆叠本身的缩放各管各的
                .scaleEffect(pressedIndex == i ? DS.pressScale : 1)
                // 主卡压在最上面完整显示，后面的往下露出底边
                .offset(y: expanded ? CGFloat(i) * (DS.cardH + DS.gap) : CGFloat(i) * DS.peek)
                // 锚点必须恒定。展开时 scale 回到 1，anchor 本来就不起作用，
                // 可一旦让它在 .bottom 和 .center 之间切换，SwiftUI 会把锚点也插值，
                // 最顶上那张明明 offset 和 scale 都没变，却跟着挪了一下。
                .scaleEffect(expanded ? 1 : 1 - DS.shrink * CGFloat(i), anchor: .bottom)
                .zIndex(Double(n - i))
            }
        }
        // 高度恒定取展开后的最大值，收起时下方是透明留白。
        // 窗口因此从头到尾不改尺寸，SwiftUI 的动画不会被布局打断。
        .frame(width: DS.cardW, height: stackHeight(expanded: true, count: n), alignment: .top)
    }

    private func stackHeight(expanded: Bool, count n: Int) -> CGFloat {
        expanded
            ? CGFloat(n) * DS.cardH + CGFloat(max(0, n - 1)) * DS.gap
            : DS.cardH + CGFloat(max(0, n - 1)) * DS.peek
    }

    /// 窗口高度：恒取展开后的最大值，加上四周那圈留白
    private func panelHeight() -> CGFloat {
        let inset = DS.panelInset * 2
        guard case .running(let list) = model.phase else { return DS.cardH + inset }
        return stackHeight(expanded: true, count: list.count) + inset
    }
}

// MARK: - 无日程与待授权

private struct MessagePanel: View {
    let head: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(head)
                .font(.system(size: 17, weight: DS.wBody))
                .foregroundStyle(DS.l1)
            Text(message)
                .font(.system(size: DS.fCaption, weight: DS.wCaption))
                .foregroundStyle(DS.l3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.padX)
        .padding(.vertical, DS.padY)
        .frame(width: DS.cardW, height: DS.cardH, alignment: .leading)
        .glassCard()
    }
}

private struct AccessPanel: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("panel.accessHead"))
                .font(.system(size: 17, weight: DS.wBody))
                .foregroundStyle(DS.l1)
            Text(L("panel.accessBody"))
                .font(.system(size: DS.fCaption, weight: DS.wCaption))
                .foregroundStyle(DS.l3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Button(L("panel.requestAccess")) { calendarService.requestAccess() }
                    .buttonStyle(.borderedProminent)
                Button(L("panel.systemSettings")) { NSWorkspaceBridge.openCalendarPrivacySettings() }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, DS.padX)
        .padding(.vertical, DS.padY)
        .frame(width: DS.cardW, height: DS.cardH, alignment: .leading)
        .glassCard()
    }
}
