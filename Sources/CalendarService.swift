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
            // 必须先解包成 let：Task 的闭包是并发的，
            // 里面不能引用被捕获的 var（weak self 就是个 var）。
            guard let self else { return }
            Task { @MainActor in self.reload() }
        }

        // 兜底轮询：变更通知偶尔不触发（尤其 CalDAV 同步完成时）。
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.reload() }
        }

        // 系统唤醒后重新拉取：休眠期间的同步不会补发通知。
        NSWorkspaceNotificationBridge.onWake { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.reload() }
        }

        requestAccess()
    }

    // 不写 deinit：deinit 是非隔离上下文，触碰 @MainActor 属性在不同 Swift 版本
    // 下从警告到报错不等。这个对象随 App 活到进程结束，没有回收时机。

    /// 开发用：启动参数 --mock-events <json 路径> 时，不读系统日历，也不请求权限，
    /// 直接用 JSON 里描述的日程。见 DevData/mock-events.json 与 dev.sh。
    private static var mockPath: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--mock-events"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private func loadMock(_ path: String) {
        guard let data = FileManager.default.contents(atPath: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        let anchor = Date()

        var made: [String: EKCalendar] = [:]
        for c in (root["calendars"] as? [[String: Any]]) ?? [] {
            guard let name = c["name"] as? String else { continue }
            let cal = EKCalendar(for: .event, eventStore: store)
            cal.title = name
            cal.cgColor = Self.cgColor(hex: c["color"] as? String)
            made[name] = cal
        }

        var list: [EKEvent] = []
        for e in (root["events"] as? [[String: Any]]) ?? [] {
            guard let title = e["title"] as? String else { continue }
            let ev = EKEvent(eventStore: store)
            ev.title = title
            ev.calendar = made[e["calendar"] as? String ?? ""]
            let start = (e["startMinutes"] as? Double) ?? 0
            let length = (e["durationMinutes"] as? Double) ?? 60
            ev.startDate = anchor.addingTimeInterval(start * 60)
            ev.endDate = anchor.addingTimeInterval((start + length) * 60)
            ev.isAllDay = (e["allDay"] as? Bool) ?? false
            list.append(ev)
        }
        calendars = made.values.sorted { $0.title < $1.title }
        events = list.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        access = .granted
    }

    private static func cgColor(hex: String?) -> CGColor {
        guard var h = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")),
              h.count == 6, let v = UInt32(h, radix: 16) else {
            return CGColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)
        }
        h = ""
        return CGColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                       green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    func requestAccess() {
        if let path = Self.mockPath {
            loadMock(path)
            return
        }
        store.requestFullAccessToEvents { [weak self] granted, _ in
            guard let self else { return }
            Task { @MainActor in
                self.access = granted ? .granted : .denied
                if granted { self.reload() }
            }
        }
    }

    func reload() {
        // 模拟模式下日程是固定的，不能被定时重拉冲掉
        guard Self.mockPath == nil, access == .granted else { return }

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
