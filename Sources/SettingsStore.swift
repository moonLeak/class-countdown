import Foundation
import Combine

/// UserDefaults 包装。存日历勾选、全天事件开关、预警阈值。
@MainActor
final class SettingsStore: ObservableObject {

    private enum Key {
        static let excludedCalendars = "excludedCalendarIDs"
        static let includeAllDay     = "includeAllDay"
        static let warnSeconds       = "warnSeconds"
        static let showTitleInMenuBar = "showTitleInMenuBar"
    }

    /// 存“排除”而不是“勾选”，这样新加的日历默认参与倒计时。
    @Published var excludedCalendarIDs: Set<String> {
        didSet { defaults.set(Array(excludedCalendarIDs), forKey: Key.excludedCalendars) }
    }

    @Published var includeAllDay: Bool {
        didSet { defaults.set(includeAllDay, forKey: Key.includeAllDay) }
    }

    /// FR-12：剩余时间低于该值时进度条与数字转警示色。
    @Published var warnSeconds: Int {
        didSet { defaults.set(warnSeconds, forKey: Key.warnSeconds) }
    }

    @Published var showTitleInMenuBar: Bool {
        didSet { defaults.set(showTitleInMenuBar, forKey: Key.showTitleInMenuBar) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.includeAllDay: false,
            Key.warnSeconds: 300,
            Key.showTitleInMenuBar: true
        ])
        self.excludedCalendarIDs = Set(defaults.stringArray(forKey: Key.excludedCalendars) ?? [])
        self.includeAllDay      = defaults.bool(forKey: Key.includeAllDay)
        self.warnSeconds        = defaults.integer(forKey: Key.warnSeconds)
        self.showTitleInMenuBar = defaults.bool(forKey: Key.showTitleInMenuBar)
    }

    func isEnabled(calendarID: String) -> Bool {
        !excludedCalendarIDs.contains(calendarID)
    }

    func setEnabled(_ enabled: Bool, calendarID: String) {
        if enabled { excludedCalendarIDs.remove(calendarID) }
        else       { excludedCalendarIDs.insert(calendarID) }
    }
}
