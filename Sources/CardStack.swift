import SwiftUI
import AppKit

/// 弹出面板：重叠的日程堆成一叠卡包。
/// 单击展开收起，右键出菜单，收起时滚轮一次手势换一张。
struct CardStack: View {

    @ObservedObject var model: ScheduleModel
    @ObservedObject var tick: TickEngine
    @ObservedObject var calendarService: CalendarService

    @State private var expanded = false
    /// 顺序会被滚轮轮转，存的是相对当前列表的偏移
    @State private var rotation = 0
    /// 刚被送到队尾的那张先沉下去再浮起来，眼睛才跟得上它去了哪
    @State private var dimmedID: String?
    @State private var deckScale: CGFloat = 1

    private var now: Date { tick.now }

    var body: some View {
        Group {
            switch model.phase {
            case .needsAccess: AccessPanel(calendarService: calendarService)
            case .empty:       MessagePanel(head: "接下来没有日程",
                                            message: "未来 48 小时内，勾选的日历里没有事件。")
            case .upcoming(let e): singleCard(e, toStart: true)
            case .running(let list): deck(list)
            }
        }
        .padding(16)
        .contextMenu { menuItems }
    }

    // MARK: 菜单：应用级操作，挂在整叠上而不是某张卡上

    @ViewBuilder
    private var menuItems: some View {
        SettingsLink { Text("设置…") }
        Button("关于 ClassCountdown") { NSApplication.shared.orderFrontStandardAboutPanel(nil) }
        Divider()
        Button("退出") { NSWorkspaceBridge.quit() }
    }

    // MARK: 单张

    private func singleCard(_ e: ScheduleModel.EventSnapshot, toStart: Bool) -> some View {
        CountdownCard(
            event: e,
            now: now,
            progress: toStart ? 0 : model.progress(e, now: now),
            warning: toStart ? false : model.isWarning(e, now: now),
            showsDetail: true,
            titleAtBottom: false,
            subtitle: toStart ? "距开始" : nil,
            countdown: TimeFormat.countdown(model.remaining(e, now: now, counting: toStart))
        )
    }

    // MARK: 一叠

    private func deck(_ list: [ScheduleModel.EventSnapshot]) -> some View {
        let ordered = rotated(list)
        let n = ordered.count
        let height = expanded
            ? CGFloat(n) * DS.cardH + CGFloat(n - 1) * DS.gap
            : DS.cardH + CGFloat(n - 1) * DS.peek

        return ZStack(alignment: .top) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { pair in
                let i = pair.offset
                let e = pair.element
                let front = (i == 0)
                let full = expanded || front
                CountdownCard(
                    event: e,
                    now: now,
                    progress: model.progress(e, now: now),
                    warning: model.isWarning(e, now: now),
                    showsDetail: full,
                    titleAtBottom: !full,
                    countdown: TimeFormat.countdown(model.remaining(e, now: now))
                )
                // 主卡压在最上面完整显示，后面的往下露出底边
                .offset(y: expanded ? CGFloat(i) * (DS.cardH + DS.gap) : CGFloat(i) * DS.peek)
                // 收起时以底边为轴缩放，露出的那条边才会齐平
                .scaleEffect(expanded ? 1 : 1 - DS.shrink * CGFloat(i),
                             anchor: expanded ? .center : .bottom)
                .opacity(dimmedID == e.id ? 0.25 : 1)
                .zIndex(Double(n - i))
            }
        }
        .frame(width: DS.cardW, height: height, alignment: .top)
        .scaleEffect(deckScale)
        .contentShape(Rectangle())
        .onScrollStep(enabled: !expanded) { step in
            advance(by: step, count: n, ordered: ordered)
        }
        .onTapGesture {
            withAnimation(DS.motion) { expanded.toggle() }
        }
        .animation(DS.motion, value: expanded)
        .animation(DS.motion, value: rotation)
        .animation(DS.fade, value: dimmedID)
    }

    private func rotated(_ list: [ScheduleModel.EventSnapshot]) -> [ScheduleModel.EventSnapshot] {
        guard list.count > 1 else { return list }
        let k = ((rotation % list.count) + list.count) % list.count
        return Array(list[k...] + list[..<k])
    }

    private func advance(by step: Int, count: Int, ordered: [ScheduleModel.EventSnapshot]) {
        guard count > 1 else { return }
        let sent = step > 0 ? ordered.first : ordered.last
        withAnimation(DS.motion) {
            rotation += step
            dimmedID = sent?.id
            deckScale = 0.985           // 整叠轻压一下，翻动才有重量
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(DS.motion) { deckScale = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(DS.fade) { dimmedID = nil }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("需要日历访问权限")
                .font(.system(size: 17, weight: DS.wBody))
                .foregroundStyle(DS.l1)
            Text("只读取日程的标题和起止时间，不会修改任何日程，也不联网。")
                .font(.system(size: DS.fCaption, weight: DS.wCaption))
                .foregroundStyle(DS.l3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Button("请求权限") { calendarService.requestAccess() }
                    .buttonStyle(.borderedProminent)
                Button("系统设置") { NSWorkspaceBridge.openCalendarPrivacySettings() }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, DS.padX)
        .padding(.vertical, DS.padY)
        .frame(width: DS.cardW, height: DS.cardH, alignment: .leading)
        .glassCard()
    }
}
