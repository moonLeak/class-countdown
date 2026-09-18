import SwiftUI

/// 需求 5.1：280pt 正方形卡片。
/// 三层：底层横向进度条背景、中层内容、顶层悬停才显现的操作图标。
struct CountdownCard: View {

    @ObservedObject var model: ScheduleModel
    @ObservedObject var tick: TickEngine
    @ObservedObject var settings: SettingsStore
    @ObservedObject var calendarService: CalendarService

    @State private var hovering = false

    private let side: CGFloat = 280

    private var now: Date { tick.now }
    private var remaining: TimeInterval { model.remaining(now: now) }
    private var progress: Double { model.progress(now: now) }
    private var isWarning: Bool {
        if case .running = model.phase { return remaining <= Double(settings.warnSeconds) }
        return false
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            progressBackground
            content
        }
        .frame(width: side, height: side)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onHover { hovering = $0 }
    }

    // MARK: 背景层

    private var progressBackground: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear
                Rectangle()
                    .fill(isWarning ? Color.orange.opacity(0.28) : Color.accentColor.opacity(0.22))
                    .frame(width: geo.size.width * progress)
                    .animation(.linear(duration: 0.5), value: progress)
            }
        }
    }

    // MARK: 内容层

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .needsAccess: accessPrompt
        case .empty:       emptyState
        case .running(let e):  eventBody(e, label: nil)
        case .upcoming(let e): eventBody(e, label: "开始于 \(TimeFormat.clock(e.start))")
        }
    }

    private func eventBody(_ e: ScheduleModel.EventSnapshot, label: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：日程标题
            Text(e.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if model.overlapCount > 0 {
                Text("还有 \(model.overlapCount) 个重叠日程")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            Spacer()

            // 中部：倒计时主体
            VStack(alignment: .leading, spacing: 2) {
                if let label {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Text(TimeFormat.countdown(remaining))
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isWarning ? Color.orange : Color.primary)
                    .contentTransition(.numericText())
            }

            Spacer()

            // 底部：起止时间 + 百分比 + 操作
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TimeFormat.range(e.start, e.end))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    actionRow
                }
                Spacer()
                // 百分比是进度条的冗余非颜色编码，色觉异常也能读。
                Text(TimeFormat.percent(progress))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(e.title)，还剩 \(TimeFormat.countdown(remaining))"))
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("设置")

            Button {
                if let url = URL(string: "ical://") { NSWorkspaceBridge.open(url) }
            } label: {
                Image(systemName: "calendar")
            }
            .buttonStyle(.plain)
            .help("打开日历")

            Button {
                NSWorkspaceBridge.quit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("退出")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .opacity(hovering ? 1 : 0.25)
        .animation(.easeInOut(duration: 0.15), value: hovering)
    }

    // MARK: 空状态与权限

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("接下来没有日程")
                .font(.system(size: 16, weight: .medium))
            Text("未来 48 小时内，勾选的日历里没有事件。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            actionRow
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("需要日历访问权限")
                .font(.system(size: 16, weight: .medium))
            Text("应用只读取日程的标题和起止时间，不会修改任何日程，也不联网。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("请求权限") { calendarService.requestAccess() }
                Button("打开系统设置") { NSWorkspaceBridge.openCalendarPrivacySettings() }
            }
            .controlSize(.small)
            Spacer()
            actionRow
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
