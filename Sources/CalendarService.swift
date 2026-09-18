import Foundation
import EventKit
import Combine

/// 封装 EKEventStore：权限、拉取 48 小时窗口、监听变更。
/// 重复日程（课表）用 enumerateEvents 拿已展开的实例，不自己解析 RRULE。
@MainActor
final class CalendarService: ObservableObject {

    enum Access {
        case unknown, granted, denied
    }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var calendars: [EKCalendar] = []
    /// 已按时间排序的窗口内事件（未做日历/全天筛选，筛选在 ScheduleModel 做）。
    @Published private(set) var events: [EKEvent] = []

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?
    private var refreshTimer: Timer?

    /// NFR：只拉未来 48 小时。往前留 1 小时，覆盖“已经开始很久”的长日程。
    private let lookBack: TimeInterval  = -60 * 60
    private let lookAhead: TimeInterval = 48 * 60 * 60

    init() {}

    /// 订阅与首次拉取。不能放在 init 里：init 期间 self 尚未完成初始化，
    /// 逃逸到并发闭包里会报 "reference to captured var 'self'"。
    func start() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }

        // 兜底轮询：变更通知偶尔不触发（尤其 CalDAV 同步完成时）。
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }

        // 系统唤醒后重新拉取：休眠期间的同步不会补发通知。
        NSWorkspaceNotificationBridge.onWake { [weak self] in
            Task { @MainActor in self?.reload() }
        }

        requestAccess()
    }

    // 不写 deinit：deinit 是非隔离上下文，触碰 @MainActor 属性在不同 Swift 版本
    // 下从警告到报错不等。这个对象随 App 活到进程结束，没有回收时机。

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                self.access = granted ? .granted : .denied
                if granted { self.reload() }
            }
        }
    }

    func reload() {
        guard access == .granted else { return }

        calendars = store.calendars(for: .event)
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        let now   = Date()
        let start = now.addingTimeInterval(lookBack)
        let end   = now.addingTimeInterval(lookAhead)

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        var found: [EKEvent] = []
        // enumerateEvents 返回的是展开后的实例，重复日程每次出现算一条。
        store.enumerateEvents(matching: predicate) { event, _ in
            if event.status != .canceled { found.append(event) }
        }

        events = found.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }

    /// 在系统日历 app 中打开该日程。
    func revealInCalendar(_ event: EKEvent) {
        guard let id = event.calendarItemIdentifier
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "ical://ekevent/\(id)") else { return }
        NSWorkspaceBridge.open(url)
    }
}
