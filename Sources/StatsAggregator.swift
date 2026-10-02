import Foundation

/// 统计页的聚合逻辑。纯函数，不依赖 UI，当前时刻与日历都由调用方传入。
/// 只统计专注时长。专注块按开始时间归入时段，跨午夜的块算在开始那一天。

enum StatsPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
}

enum StatsMetric: String, CaseIterable, Identifiable {
    case total, dailyAverage
    var id: String { rawValue }
}

struct StatsBucket: Identifiable, Equatable {
    /// 在本周期里的序号：日 0...23，周 0...6，月 0...(天数-1)，年 0...11
    let index: Int
    let start: Date
    let seconds: TimeInterval
    var id: Int { index }
}

struct StatsSnapshot {
    let period: StatsPeriod
    let rangeStart: Date
    /// 不含
    let rangeEnd: Date
    let buckets: [StatsBucket]
    /// 当前指标的值（总时长或日均时长），单位秒
    let value: TimeInterval
    /// 上一个周期同一指标的值
    let previousValue: TimeInterval

    /// 与上一周期相比的变化比例。上一周期为 0 时没有可比的基数，返回 nil。
    var delta: Double? {
        previousValue > 0 ? (value - previousValue) / previousValue : nil
    }
}

enum StatsAggregator {

    // MARK: 周期范围

    static func range(of period: StatsPeriod, containing date: Date,
                      calendar: Calendar) -> (start: Date, end: Date) {
        let comp: Calendar.Component
        switch period {
        case .day:   comp = .day
        case .week:  comp = .weekOfYear
        case .month: comp = .month
        case .year:  comp = .year
        }
        let interval = calendar.dateInterval(of: comp, for: date)
            ?? DateInterval(start: date, duration: 86_400)
        return (interval.start, interval.end)
    }

    /// 向前或向后翻若干页
    static func shifted(_ anchor: Date, period: StatsPeriod, by n: Int,
                        calendar: Calendar) -> Date {
        let comp: Calendar.Component
        switch period {
        case .day:   comp = .day
        case .week:  comp = .weekOfYear
        case .month: comp = .month
        case .year:  comp = .year
        }
        return calendar.date(byAdding: comp, value: n, to: anchor) ?? anchor
    }

    /// 下一页还没到现在之后就不能翻
    static func canGoNext(anchor: Date, period: StatsPeriod, now: Date,
                          calendar: Calendar) -> Bool {
        let current = range(of: period, containing: anchor, calendar: calendar)
        return current.end <= now
    }

    // MARK: 聚合

    static func snapshot(blocks: [FocusBlock], period: StatsPeriod, metric: StatsMetric,
                         anchor: Date, now: Date, calendar: Calendar) -> StatsSnapshot {
        let r = range(of: period, containing: anchor, calendar: calendar)
        let buckets = makeBuckets(blocks: blocks, period: period, start: r.start,
                                  end: r.end, calendar: calendar)
        let value = metricValue(buckets: buckets, metric: metric, start: r.start,
                                end: r.end, now: now, calendar: calendar)

        let prevAnchor = shifted(anchor, period: period, by: -1, calendar: calendar)
        let pr = range(of: period, containing: prevAnchor, calendar: calendar)
        let prevBuckets = makeBuckets(blocks: blocks, period: period, start: pr.start,
                                      end: pr.end, calendar: calendar)
        let prevValue = metricValue(buckets: prevBuckets, metric: metric, start: pr.start,
                                    end: pr.end, now: now, calendar: calendar)

        return StatsSnapshot(period: period, rangeStart: r.start, rangeEnd: r.end,
                             buckets: buckets, value: value, previousValue: prevValue)
    }

    private static func makeBuckets(blocks: [FocusBlock], period: StatsPeriod,
                                    start: Date, end: Date, calendar: Calendar) -> [StatsBucket] {
        // 先建出所有桶的起点
        var starts: [Date] = []
        switch period {
        case .day:
            for h in 0..<24 {
                if let d = calendar.date(byAdding: .hour, value: h, to: start) { starts.append(d) }
            }
        case .week, .month:
            var d = start
            while d < end {
                starts.append(d)
                guard let n = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = n
            }
        case .year:
            for m in 0..<12 {
                if let d = calendar.date(byAdding: .month, value: m, to: start) { starts.append(d) }
            }
        }

        var sums = [TimeInterval](repeating: 0, count: starts.count)
        for b in blocks where b.start >= start && b.start < end {
            // 找到最后一个不晚于开始时间的桶
            var idx = 0
            for (i, s) in starts.enumerated() where s <= b.start { idx = i }
            sums[idx] += b.duration
        }
        return starts.enumerated().map { StatsBucket(index: $0.offset, start: $0.element, seconds: sums[$0.offset]) }
    }

    private static func metricValue(buckets: [StatsBucket], metric: StatsMetric,
                                    start: Date, end: Date, now: Date,
                                    calendar: Calendar) -> TimeInterval {
        let total = buckets.reduce(0) { $0 + $1.seconds }
        guard metric == .dailyAverage else { return total }
        // 日均按已经过去的天数算，本周期还没过完时不拿未来的天数去稀释
        let tomorrow = calendar.date(byAdding: .day, value: 1,
                                     to: calendar.startOfDay(for: now)) ?? now
        let limit = min(end, max(tomorrow, start))
        let days = max(1, calendar.dateComponents([.day], from: start, to: limit).day ?? 1)
        return total / Double(days)
    }

    // MARK: 刻度

    /// 友好步长（小时）。取最小的步长，使 3 × 步长 不小于最大值。
    private static let steps: [Double] = [
        0.25, 0.5, 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50
    ]

    static func niceStep(maxSeconds: TimeInterval) -> TimeInterval {
        let maxHours = maxSeconds / 3600
        for s in steps where s * 3 >= maxHours { return s * 3600 }
        // 超出表的范围：按 1、2、2.5、5 乘以十的幂继续往上找
        var scale = 100.0
        while true {
            for m in [1.0, 2.0, 2.5, 5.0] where m * scale * 3 >= maxHours {
                return m * scale * 3600
            }
            scale *= 10
        }
    }
}
