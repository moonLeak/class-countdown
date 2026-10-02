import SwiftUI
import Charts

/// 统计窗口的内容。只统计专注时间，不显示个数，不分类。
struct StatsView: View {

    @ObservedObject var focus: FocusController
    @ObservedObject private var l10n = L10n.shared

    @State private var period: StatsPeriod = .week
    @State private var metric: StatsMetric = .total
    /// 当前看的是哪个周期里的某一天
    @State private var anchor = Date()
    @State private var hovered: Int?

    private var calendar: Calendar { .current }

    private var snapshot: StatsSnapshot {
        StatsAggregator.snapshot(blocks: focus.blocks, period: period, metric: metric,
                                 anchor: anchor, now: Date(), calendar: calendar)
    }

    var body: some View {
        let snap = snapshot
        VStack(alignment: .leading, spacing: 18) {
            topRow
            totalRow(snap)
            chart(snap)
        }
        .padding(.horizontal, DS.statsPad)
        .padding(.vertical, DS.statsPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: period) { _, _ in hovered = nil }
    }

    // MARK: 第一行：指标与周期

    private var topRow: some View {
        HStack {
            Menu {
                ForEach(StatsMetric.allCases) { m in
                    Button {
                        metric = m
                    } label: {
                        if m == metric { Label(label(m), systemImage: "checkmark") }
                        else { Text(label(m)) }
                    }
                }
            } label: {
                Text(label(metric))
            }
            .menuStyle(.button)
            .fixedSize()

            Spacer()

            Picker("", selection: $period) {
                ForEach(StatsPeriod.allCases) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
        }
    }

    // MARK: 第二行：总量、变化、翻页

    private func totalRow(_ snap: StatsSnapshot) -> some View {
        let parts = Self.hoursAndMinutes(snap.value)
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if parts.hours > 0 {
                        Text("\(parts.hours)").font(numeralFont)
                        Text(L("stats.unit.hour")).font(unitFont).foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                    Text(String(format: "%02d", parts.minutes)).font(numeralFont)
                    Text(L("stats.unit.min")).font(unitFont).foregroundStyle(.secondary)
                }
                .monospacedDigit()
                deltaBadge(snap)
            }
            Spacer()
            rangeNavigator(snap)
        }
    }

    private var numeralFont: Font { .system(size: DS.fNumeral, weight: .semibold) }
    private var unitFont: Font { .system(size: 16, weight: .medium) }

    @ViewBuilder
    private func deltaBadge(_ snap: StatsSnapshot) -> some View {
        if let d = snap.delta {
            let up = d >= 0
            HStack(spacing: 5) {
                Text(up ? "▲" : "▼").font(.system(size: 10))
                Text("\(Int((abs(d) * 100).rounded()))%")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(up ? DS.Color.up : DS.Color.down)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill((up ? DS.Color.up : DS.Color.down).opacity(0.16)))
        } else {
            // 占位，保持两行的高度不随有无变化而跳
            Color.clear.frame(height: 30)
        }
    }

    private func rangeNavigator(_ snap: StatsSnapshot) -> some View {
        let canNext = StatsAggregator.canGoNext(anchor: anchor, period: period,
                                                now: Date(), calendar: calendar)
        return HStack(spacing: 10) {
            navButton("chevron.left", enabled: true) {
                anchor = StatsAggregator.shifted(anchor, period: period, by: -1, calendar: calendar)
            }
            Text(rangeText(snap))
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 150)
            navButton("chevron.right", enabled: canNext) {
                anchor = StatsAggregator.shifted(anchor, period: period, by: 1, calendar: calendar)
            }
        }
    }

    private func navButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(.primary.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
        .accessibilityLabel(Text(symbol == "chevron.left" ? L("stats.a11y.prev") : L("stats.a11y.next")))
    }

    // MARK: 图表

    private func chart(_ snap: StatsSnapshot) -> some View {
        let maxSeconds = snap.buckets.map(\.seconds).max() ?? 0
        let step = StatsAggregator.niceStep(maxSeconds: maxSeconds)
        let top = step * 3
        let ticks = Set(xTickIndices(snap))
        return Chart {
            ForEach(snap.buckets) { b in
                BarMark(
                    x: .value("t", Self.key(b.index)),
                    y: .value("v", b.seconds),
                    width: .ratio(DS.statsBarRatio)
                )
                .cornerRadius(40)
                .foregroundStyle(LinearGradient(
                    colors: [DS.Color.barTop, DS.Color.barBottom],
                    startPoint: .top, endPoint: .bottom))
                // 悬停时其他柱降到 55%
                .opacity(hovered == nil || hovered == b.index ? 1 : 0.55)
            }
        }
        .chartYScale(domain: 0...top)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [step, step * 2, step * 3]) { v in
                AxisGridLine().foregroundStyle(.primary.opacity(0.14))
                AxisValueLabel {
                    if let s = v.as(Double.self) {
                        Text(Self.axisText(s)).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { v in
                AxisValueLabel {
                    // 类别轴会给每个桶都画标签，太密的周期只保留选中的那几个
                    if let k = v.as(String.self), let i = Int(k), ticks.contains(i),
                       i < snap.buckets.count {
                        Text(xLabel(snap.buckets[i])).font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let p):
                            let x = p.x - geo[proxy.plotFrame!].origin.x
                            let k: String? = proxy.value(atX: x, as: String.self)
                            withAnimation(DS.toggle) {
                                hovered = k.flatMap { Int($0) }
                                    .flatMap { (0..<snap.buckets.count).contains($0) ? $0 : nil }
                            }
                        case .ended:
                            withAnimation(DS.toggle) { hovered = nil }
                        }
                    }
                if let h = hovered, h < snap.buckets.count,
                   let x = proxy.position(forX: Self.key(h)), let frame = proxy.plotFrame {
                    let origin = geo[frame].origin
                    tooltip(snap.buckets[h])
                        .position(x: min(max(origin.x + x, 70), geo.size.width - 70), y: 14)
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(DS.bar, value: snap.buckets)
        .frame(maxHeight: .infinity)
    }

    private func tooltip(_ b: StatsBucket) -> some View {
        Text("\(tooltipTitle(b))  \(Self.durationText(b.seconds))")
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.regularMaterial))
            .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
    }

    // MARK: 文字

    private func label(_ m: StatsMetric) -> String {
        m == .total ? L("stats.metric.total") : L("stats.metric.average")
    }

    private func label(_ p: StatsPeriod) -> String { L("stats.period.\(p.rawValue)") }

    /// 横轴标签。小时、日太密，隔几个显示一个
    private func xTickIndices(_ snap: StatsSnapshot) -> [Int] {
        let n = snap.buckets.count
        switch period {
        case .day:   return [0, 6, 12, 18]
        case .week:  return Array(0..<n)
        case .month: return stride(from: 0, to: n, by: 5).map { $0 } + [n - 1]
        case .year:  return Array(0..<n)
        }
    }

    private func xLabel(_ b: StatsBucket) -> String {
        let f = DateFormatter()
        f.locale = L10n.shared.locale
        f.calendar = calendar
        switch period {
        case .day:   f.setLocalizedDateFormatFromTemplate("j")
        case .week:  f.setLocalizedDateFormatFromTemplate("EEEEE")
        case .month: f.setLocalizedDateFormatFromTemplate("d")
        case .year:  f.setLocalizedDateFormatFromTemplate("MMM")
        }
        return f.string(from: b.start)
    }

    private func tooltipTitle(_ b: StatsBucket) -> String {
        let f = DateFormatter()
        f.locale = L10n.shared.locale
        f.calendar = calendar
        switch period {
        case .day:   f.setLocalizedDateFormatFromTemplate("jm")
        case .week, .month: f.setLocalizedDateFormatFromTemplate("MMMd")
        case .year:  f.setLocalizedDateFormatFromTemplate("yMMM")
        }
        return f.string(from: b.start)
    }

    private func rangeText(_ snap: StatsSnapshot) -> String {
        let f = DateFormatter()
        f.locale = L10n.shared.locale
        f.calendar = calendar
        let last = calendar.date(byAdding: .day, value: -1, to: snap.rangeEnd) ?? snap.rangeStart
        switch period {
        case .day:
            f.setLocalizedDateFormatFromTemplate("yMMMMd")
            return f.string(from: snap.rangeStart)
        case .week:
            let g = DateIntervalFormatter()
            g.locale = f.locale
            g.calendar = calendar
            g.dateTemplate = "yMMMd"
            return g.string(from: snap.rangeStart, to: last)
        case .month:
            f.setLocalizedDateFormatFromTemplate("yMMMM")
            return f.string(from: snap.rangeStart)
        case .year:
            f.setLocalizedDateFormatFromTemplate("y")
            return f.string(from: snap.rangeStart)
        }
    }

    // MARK: 数值格式

    /// 横轴按类别排，序号补零保证顺序稳定
    static func key(_ index: Int) -> String { String(format: "%02d", index) }

    static func hoursAndMinutes(_ seconds: TimeInterval) -> (hours: Int, minutes: Int) {
        let total = Int((seconds / 60).rounded())
        return (total / 60, total % 60)
    }

    /// 刻度文字：小于 1 小时用分钟
    static func axisText(_ seconds: TimeInterval) -> String {
        if seconds < 3600 { return "\(Int((seconds / 60).rounded()))m" }
        let h = seconds / 3600
        return h == h.rounded() ? "\(Int(h))h" : String(format: "%.2gh", h)
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let p = hoursAndMinutes(seconds)
        return p.hours > 0 ? "\(p.hours)h \(p.minutes)m" : "\(p.minutes)m"
    }
}
