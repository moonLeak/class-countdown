import SwiftUI
import AppKit

/// 卡叠里的一张卡
private enum StackItem: Identifiable {
    case event(ScheduleModel.EventSnapshot, toStart: Bool)
    case access
    case empty
    case flow

    var id: String {
        switch self {
        case .event(let e, _): return e.id
        case .access: return "access"
        case .empty:  return "empty"
        case .flow:   return "flow"
        }
    }

    var isFlow: Bool { if case .flow = self { return true } else { return false } }
}

/// 弹出面板：日程卡和 Flow 卡堆成一叠卡包。
/// 单击展开收起，二段重按打开日历，右键出应用菜单。
/// Flow 卡默认在最底层，展开后可以拖动换位置，位置会记住。
/// 面板自身不画背景，卡片直接浮在桌面上。
struct CardStack: View {

    // 必须直接观察这几个对象。挂在 AppState 上没用：
    // 它只是个持有者，自身没有任何 @Published，
    // objectWillChange 永远不发，视图会停在第一帧。
    @ObservedObject var model: ScheduleModel
    @ObservedObject var tick: TickEngine
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var focus: FocusController
    @ObservedObject var settings: SettingsStore
    @ObservedObject private var l10n = L10n.shared
    /// 出场退场与展开状态都由控制器持有：面板窗口复用，视图不重建，
    /// 放在 @State 里一旦漏掉一次事件就再也回不到正确的那一帧。
    @ObservedObject var presentation: PanelPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 系统开了“减弱动态效果”时，位移动画缩短成一个很快的淡入淡出
    private var motion: Animation { reduceMotion ? .easeInOut(duration: 0.12) : DS.motion }

    /// 二段重按的下沉反馈，只作用在被按的那一张上
    @State private var pressedIndex: Int? = nil
    /// 正在被拖动的卡：它的 id、按下时所在的位置、垂直位移
    @State private var drag: (id: String, startIndex: Int, dy: CGFloat)? = nil
    /// 浮窗定位图标点过之后，Flow 卡边框亮一下
    @State private var flowHighlight = false

    private var expanded: Bool { presentation.expanded }

    private var now: Date { tick.now }

    // MARK: 卡片顺序

    /// 默认顺序：日程在前，Flow 在最底
    private var baseItems: [StackItem] {
        var list: [StackItem]
        switch model.phase {
        case .needsAccess:       list = [.access]
        case .empty:             list = [.empty]
        // 和菜单栏同一个开关：关掉“空闲时显示下一个日程”，卡叠里也不放下一个日程，
        // 只剩 Flow 卡。这里不用“没有日程”的提示卡，因为日程其实是有的
        case .upcoming(let e):   list = settings.showNextWhenIdle ? [.event(e, toStart: true)] : []
        case .running(let evs):  list = evs.map { .event($0, toStart: false) }
        }
        list.append(.flow)
        return list
    }

    /// 按记住的顺序排。记得的卡按记住的先后；
    /// 新出现的日程排在最前（它往往正是刚开始的那件事），新出现的 Flow 卡排在最后
    private func ordered(_ base: [StackItem]) -> [StackItem] {
        let saved = settings.cardOrder
        let rank = Dictionary(saved.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let known = base.filter { rank[$0.id] != nil }.sorted { rank[$0.id]! < rank[$1.id]! }
        let fresh = base.filter { rank[$0.id] == nil }
        return fresh.filter { !$0.isFlow } + known + fresh.filter { $0.isFlow }
    }

    /// 当前该显示的顺序。拖动中，被拖的卡按位移插到它该去的位置，其他卡顺次让位
    private var items: [StackItem] {
        guard let d = drag else { return ordered(baseItems) }
        return arranged(moving: d.id, from: d.startIndex, by: d.dy)
    }

    private func arranged(moving id: String, from start: Int, by dy: CGFloat) -> [StackItem] {
        var out = ordered(baseItems)
        guard let from = out.firstIndex(where: { $0.id == id }) else { return out }
        let to = liveSlot(startIndex: start, dy: dy, count: out.count)
        let item = out.remove(at: from)
        out.insert(item, at: to)
        return out
    }

    /// 拖动中按位移算出被拖的卡现在该在第几位
    private func liveSlot(startIndex: Int, dy: CGFloat, count: Int) -> Int {
        let step = DS.cardH + DS.gap
        let raw = (CGFloat(startIndex) + dy / step).rounded()
        return min(max(Int(raw), 0), count - 1)
    }

    var body: some View {
        // 不能用 GlassEffectContainer：同一个容器里的玻璃共享背景采样，
        // 于是它们互相不模糊，后面卡片的内容会直接透到最前面来。
        // 每张卡各自独立取景，前面那张才会把后面那张糊掉。
        stackWithPill(items)
            // 四周留给玻璃投影扩散的余量。
            // 投影 radius 14 加 y 偏移 10，四周至少要 24 才不会被切；
            // 留 14 的话左右正好卡在边界上，看着就是一条硬边。
            .padding(DS.panelInset)
            .fixedSize()
            // 出场退场：锚点取顶边中点，那正是菜单栏图标所在的位置，
            // 于是卡片看上去是从那个小图标里放大出来的，收回时原路缩回去。
            .environment(\.cardClarity, settings.cardClarity)
            .scaleEffect(presentation.shown ? 1 : DS.appearScale, anchor: .top)
            .opacity(presentation.shown ? 1 : 0)
            .contextMenu { menuItems }
            .onAppear { postHeight() }
            .onChange(of: presentation.shown) { _, shown in
                if !shown { pressedIndex = nil; drag = nil }
            }
            .onChange(of: baseItems.map(\.id)) { _, _ in
                // 卡的数量变了，最大高度才需要重新报
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

    /// 每张卡各有一块交互区，重按的反馈才落在手指按住的那一张上。
    /// 展开后每张卡都能拖动换位置，松手后整叠顺序记下来。
    private func interaction(_ index: Int, count: Int, id: String) -> some View {
        InteractionArea(
            onClick: {
                withAnimation(motion) { presentation.expanded.toggle() }
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
            },
            onDrag: expanded ? { dy, finished in
                // 起点只在第一下记，之后 index 会随着让位变化
                let start = (drag?.id == id) ? drag!.startIndex : index
                if finished {
                    let order = arranged(moving: id, from: start, by: dy).map(\.id)
                    // 松手：被拖的卡从指尖位置滑进空位，同一条曲线
                    withAnimation(motion) {
                        settings.cardOrder = order
                        drag = nil
                    }
                } else {
                    drag = (id, start, dy)
                }
            } : nil
        )
    }

    // MARK: 浮窗与整叠

    /// 浮窗压在最上层（z 200）。整叠展开时下移 46 给它让位，
    /// 浮窗同时移到整叠右上角，两个动作同一条曲线。
    private func stackWithPill(_ list: [StackItem]) -> some View {
        ZStack(alignment: .topTrailing) {
            deck(list)
                .offset(y: expanded ? DS.stackShift : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            QuickPill(
                expanded: expanded,
                onFocusTap: { locateFlow() },
                onStatsTap: {
                    NotificationCenter.default.post(name: .openStatsRequested, object: nil)
                },
                onCalendarTap: { openCalendar() },
                onSettingsTap: {
                    NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
                }
            )
            .padding(.top, expanded ? 0 : DS.pillInsetTop)
            .padding(.trailing, expanded ? 0 : DS.pillInsetRight)
            .zIndex(200)
        }
        .frame(width: DS.cardW,
               height: stackHeight(expanded: true, count: list.count) + DS.stackShift,
               alignment: .top)
    }

    /// 整叠展开并让 Flow 卡亮一下，帮用户找到它
    private func locateFlow() {
        withAnimation(motion) { presentation.expanded = true }
        withAnimation(DS.fade) { flowHighlight = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(DS.fade) { flowHighlight = false }
        }
    }

    // MARK: 一叠

    private func deck(_ list: [StackItem]) -> some View {
        let n = list.count

        return ZStack(alignment: .top) {
            ForEach(Array(list.enumerated()), id: \.element.id) { pair in
                let i = pair.offset
                let item = pair.element
                let full: Double = (expanded || i == 0) ? 1 : 0
                let dragging = drag?.id == item.id
                card(item, index: i, count: n, fullness: full)
                    // 拿起来的卡放大一点、阴影加深，看得出它浮在上面
                    .shadow(color: .black.opacity(dragging ? DS.dragShadow : 0),
                            radius: dragging ? 18 : 0, y: dragging ? 10 : 0)
                    // 重按的缩放挂在这一层，和堆叠本身的缩放各管各的
                    .scaleEffect(pressedIndex == i ? DS.pressScale : (dragging ? DS.dragScale : 1))
                    .animation(DS.press, value: dragging)
                    // 主卡压在最上面完整显示，后面的往下露出底边
                    .offset(y: yOffset(index: i, dragging: dragging))
                    // 让位的卡顺滑地挪过去；被拖的那张直接跟手，不加动画
                    .animation(dragging ? nil : motion, value: list.map(\.id))
                    // 锚点必须恒定。展开时 scale 回到 1，anchor 本来就不起作用，
                    // 可一旦让它在 .bottom 和 .center 之间切换，SwiftUI 会把锚点也插值，
                    // 最顶上那张明明 offset 和 scale 都没变，却跟着挪了一下。
                    .scaleEffect(expanded ? 1 : 1 - DS.shrink * CGFloat(i), anchor: .bottom)
                    .zIndex(dragging ? DS.dragZ : Double(n - i))
            }
        }
        // 高度恒定取展开后的最大值，收起时下方是透明留白。
        // 窗口因此从头到尾不改尺寸，SwiftUI 的动画不会被布局打断。
        .frame(width: DS.cardW, height: stackHeight(expanded: true, count: n), alignment: .top)
    }

    private func yOffset(index i: Int, dragging: Bool) -> CGFloat {
        guard expanded else { return CGFloat(i) * DS.peek }
        let step = DS.cardH + DS.gap
        if dragging, let d = drag { return CGFloat(d.startIndex) * step + d.dy }
        return CGFloat(i) * step
    }

    @ViewBuilder
    private func card(_ item: StackItem, index i: Int, count n: Int, fullness: Double) -> some View {
        switch item {
        case .event(let e, let toStart):
            EventCard(
                event: e,
                progress: toStart ? 0 : model.progress(e, now: now),
                warning: toStart ? false : model.isWarning(e, now: now),
                countdown: TimeFormat.countdown(model.remaining(e, now: now, counting: toStart)),
                subtitle: toStart ? L("panel.toStart") : nil,
                fullness: fullness,
                collapsedScale: 1 - DS.shrink * CGFloat(i)
            )
            .overlay { interaction(i, count: n, id: item.id) }
        case .access:
            AccessPanel(calendarService: calendarService)
                .overlay { interaction(i, count: n, id: item.id) }
        case .empty:
            MessagePanel(head: L("panel.emptyHead"), message: L("panel.emptyBody"))
                .overlay { interaction(i, count: n, id: item.id) }
        case .flow:
            FlowCard(
                focus: focus, now: now, fullness: fullness,
                collapsedScale: 1 - DS.shrink * CGFloat(i),
                interaction: AnyView(interaction(i, count: n, id: item.id)),
                onStatsTap: {
                    NotificationCenter.default.post(name: .openStatsRequested, object: nil)
                },
                highlight: flowHighlight)
        }
    }

    private func stackHeight(expanded: Bool, count n: Int) -> CGFloat {
        expanded
            ? CGFloat(n) * DS.cardH + CGFloat(max(0, n - 1)) * DS.gap
            : DS.cardH + CGFloat(max(0, n - 1)) * DS.peek
    }

    /// 窗口高度：恒取展开后的最大值，加上四周那圈留白
    private func panelHeight() -> CGFloat {
        stackHeight(expanded: true, count: baseItems.count) + DS.stackShift + DS.panelInset * 2
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
