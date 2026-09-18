import Foundation
import EventKit
import Combine

/// 当前日程状态机。文档 8.1 中的 EventStore 模块。
/// 输入：CalendarService 的事件列表 + SettingsStore 的筛选 + TickEngine 的当前时间。
/// 输出：卡片和菜单栏要显示的一切。
@MainActor
final class ScheduleModel: ObservableObject {

    enum Phase: Equatable {
        /// 正在进行中的日程，倒计时到结束。
        case running(EventSnapshot)
        /// 没有进行中的日程，倒计时到下一个开始。
        case upcoming(EventSnapshot)
        /// 窗口内什么都没有。
        case empty
        /// 没有日历权限。
        case needsAccess
    }

    struct EventSnapshot: Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date

        static func == (a: EventSnapshot, b: EventSnapshot) -> Bool {
            a.id == b.id && a.start == b.start && a.end == b.end
        }
    }

    @Published private(set) var phase: Phase = .needsAccess
    /// 与当前日程时间重叠、但被优先级规则排掉的日程数量。
    @Published private(set) var overlapCount: Int = 0

    private let calendarService: CalendarService
    private let settings: SettingsStore
    private var bag = Set<AnyCancellable>()

    init(calendarService: CalendarService, settings: SettingsStore, tick: TickEngine) {
        self.calendarService = calendarService
        self.settings = settings

        // 三个来源任一变化都重算。重算只是遍历几十条事件，开销可忽略。
        tick.$now
            .combineLatest(calendarService.$events, calendarService.$access)
            .sink { [weak self] now, events, access in
                self?.recompute(now: now, events: events, access: access)
            }
            .store(in: &bag)

        settings.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.recompute(now: Date(),
                                   events: self.calendarService.events,
                                   access: self.calendarService.access)
                }
            }
            .store(in: &bag)
    }

    // MARK: - 核心计算

    private func recompute(now: Date, events: [EKEvent], access: CalendarService.Access) {
        guard access == .granted else {
            set(.needsAccess, overlaps: 0)
            return
        }

        let pool = events.filter { keep($0) }

        // 正在进行：start <= now < end
        let running = pool.filter { ev in
            guard let s = ev.startDate, let e = ev.endDate else { return false }
            return s <= now && now < e
        }

        if !running.isEmpty {
            // 重叠时取最先结束的那个，也就是最先释放用户的那件事。
            let winner = running.min { lhs, rhs in
                (lhs.endDate ?? .distantFuture) < (rhs.endDate ?? .distantFuture)
            }!
            set(.running(snapshot(winner)), overlaps: running.count - 1)
            return
        }

        // 没有进行中的，找下一个开始的
        let upcoming = pool
            .filter { ($0.startDate ?? .distantPast) > now }
            .min { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }

        // 显式写 Phase，闭包里的 .upcoming 简写有时推断不出来
        let next: Phase = upcoming.map { Phase.upcoming(snapshot($0)) } ?? Phase.empty
        set(next, overlaps: 0)
    }

    /// 心跳每 0.5 秒来一次，但 phase 只在真正变化时赋值，
    /// 否则 SwiftUI 会为没变的内容重绘整张卡片。
    private func set(_ newPhase: Phase, overlaps: Int) {
        if phase != newPhase { phase = newPhase }
        if overlapCount != overlaps { overlapCount = overlaps }
    }

    private func keep(_ event: EKEvent) -> Bool {
        guard let s = event.startDate, let e = event.endDate, e >= s else { return false }
        if event.isAllDay && !settings.includeAllDay { return false }
        if let calID = event.calendar?.calendarIdentifier,
           !settings.isEnabled(calendarID: calID) { return false }
        return true
    }

    private func snapshot(_ event: EKEvent) -> EventSnapshot {
        EventSnapshot(
            id: event.calendarItemIdentifier,
            title: (event.title?.isEmpty == false ? event.title! : "（无标题）"),
            start: event.startDate,
            end: event.endDate
        )
    }

    // MARK: - 派生值

    /// 剩余秒数 r = max(0, target - now)
    func remaining(now: Date) -> TimeInterval {
        switch phase {
        case .running(let e):  return max(0, e.end.timeIntervalSince(now))
        case .upcoming(let e): return max(0, e.start.timeIntervalSince(now))
        case .empty, .needsAccess: return 0
        }
    }

    /// 进度 p = (now - start) / (end - start)，夹在 [0, 1]。
    /// upcoming 阶段没有天然的分母，返回 0，卡片背景保持空。
    func progress(now: Date) -> Double {
        guard case .running(let e) = phase else { return 0 }
        let span = e.end.timeIntervalSince(e.start)
        guard span > 0 else { return 1 }   // 零时长日程，直接算满
        let done = now.timeIntervalSince(e.start) / span
        return min(1, max(0, done))
    }

    var currentEventID: String? {
        switch phase {
        case .running(let e), .upcoming(let e): return e.id
        case .empty, .needsAccess: return nil
        }
    }
}
