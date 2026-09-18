import Foundation
import EventKit
import SwiftUI
import Combine

/// 当前日程状态机。
/// v6.3 起重叠日程全部返回，由界面堆成一叠，不再只挑一个出来。
@MainActor
final class ScheduleModel: ObservableObject {

    enum Phase: Equatable {
        /// 正在进行的日程，按结束时间升序：最先释放你的排在最前
        case running([EventSnapshot])
        /// 没有进行中的，倒数到下一个开始
        case upcoming(EventSnapshot)
        case empty
        case needsAccess
    }

    struct EventSnapshot: Equatable, Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        /// 所属日历的颜色，进度条直接用它
        let calendarColor: Color

        /// 标题和日历颜色也要比。
        /// 只比 id 和起止时间的话，在日历里改个名字，
        /// 新快照会被判成“和旧的一样”，界面就永远停在旧标题上。
        static func == (a: EventSnapshot, b: EventSnapshot) -> Bool {
            a.id == b.id
                && a.start == b.start
                && a.end == b.end
                && a.title == b.title
                && a.calendarColor == b.calendarColor
        }
    }

    @Published private(set) var phase: Phase = .needsAccess

    private let calendarService: CalendarService
    private let settings: SettingsStore
    private let tick: TickEngine
    private var bag = Set<AnyCancellable>()

    init(calendarService: CalendarService, settings: SettingsStore, tick: TickEngine) {
        self.calendarService = calendarService
        self.settings = settings
        self.tick = tick
    }

    /// 建立订阅。不能放在 init 里：init 期间 self 尚未完成初始化，
    /// 逃逸到闭包里编译器会拒绝。
    func start() {
        tick.$now
            .combineLatest(calendarService.$events, calendarService.$access)
            .sink { [weak self] now, events, access in
                self?.recompute(now: now, events: events, access: access)
            }
            .store(in: &bag)

        settings.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
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
            set(.needsAccess)
            return
        }

        let pool = events.filter { keep($0) }

        let running = pool
            .filter { ev in
                guard let s = ev.startDate, let e = ev.endDate else { return false }
                return s <= now && now < e
            }
            .sorted { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }

        if !running.isEmpty {
            set(.running(running.map(snapshot)))
            return
        }

        let next = pool
            .filter { ($0.startDate ?? .distantPast) > now }
            .min { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }

        set(next.map { Phase.upcoming(snapshot($0)) } ?? Phase.empty)
    }

    /// 心跳每 0.5 秒来一次，phase 只在真正变化时赋值，
    /// 否则 SwiftUI 会为没变的内容重绘整叠卡片。
    private func set(_ newPhase: Phase) {
        if phase != newPhase { phase = newPhase }
    }

    private func keep(_ event: EKEvent) -> Bool {
        guard let s = event.startDate, let e = event.endDate, e >= s else { return false }
        if event.isAllDay && !settings.includeAllDay { return false }
        if let calID = event.calendar?.calendarIdentifier,
           !settings.isEnabled(calendarID: calID) { return false }
        return true
    }

    private func snapshot(_ event: EKEvent) -> EventSnapshot {
        let cg = event.calendar?.cgColor ?? CGColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)
        return EventSnapshot(
            id: event.calendarItemIdentifier,
            title: (event.title?.isEmpty == false ? event.title! : "（无标题）"),
            start: event.startDate,
            end: event.endDate,
            calendarColor: Color(cgColor: cg)
        )
    }

    // MARK: - 派生值

    /// 剩余秒数 r = max(0, target - now)
    func remaining(_ e: EventSnapshot, now: Date, counting toStart: Bool = false) -> TimeInterval {
        max(0, (toStart ? e.start : e.end).timeIntervalSince(now))
    }

    /// 进度 p = (now - start) / (end - start)，夹在 [0, 1]
    func progress(_ e: EventSnapshot, now: Date) -> Double {
        let span = e.end.timeIntervalSince(e.start)
        guard span > 0 else { return 1 }          // 零时长日程直接算满
        return min(1, max(0, now.timeIntervalSince(e.start) / span))
    }

    /// 临近结束：进度条整条转橙，见设计画布 v6.1 的定案
    func isWarning(_ e: EventSnapshot, now: Date) -> Bool {
        let threshold = settings.warnSeconds
        guard threshold > 0 else { return false }
        let left = e.end.timeIntervalSince(now)
        return left > 0 && left <= Double(threshold)
    }

    /// 菜单栏那行文字要用的那一个日程
    var frontEvent: EventSnapshot? {
        switch phase {
        case .running(let list): return list.first
        case .upcoming(let e): return e
        case .empty, .needsAccess: return nil
        }
    }
}
