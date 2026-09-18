import Foundation
import Combine

/// 界面语言。只管软件自身的文字，日程名称永远按日历里的原文显示。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, zhHans, zhHant, en, ja, ko, de, fr, es, pt, ru

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en:     return "English"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        case .de:     return "Deutsch"
        case .fr:     return "Français"
        case .es:     return "Español"
        case .pt:     return "Português"
        case .ru:     return "Русский"
        }
    }

    /// 写进 AppleLanguages 的标识，system 表示交回系统决定
    var localeCode: String? {
        switch self {
        case .system: return nil
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .en:     return "en"
        case .ja:     return "ja"
        case .ko:     return "ko"
        case .de:     return "de"
        case .fr:     return "fr"
        case .es:     return "es"
        case .pt:     return "pt"
        case .ru:     return "ru"
        }
    }
}

/// 菜单栏显示什么
enum MenuBarContent: String, CaseIterable, Identifiable {
    case nameAndTime, timeOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nameAndTime: return "名称与剩余时间"
        case .timeOnly:    return "仅剩余时间"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {

    private enum Key {
        static let excludedCalendars = "excludedCalendarIDs"
        static let includeAllDay     = "includeAllDay"
        static let warnSeconds       = "warnSeconds"
        static let menuBarContent    = "menuBarContent"
        static let language          = "appLanguage"
    }

    /// 存“排除”而不是“勾选”，这样新加的日历默认参与倒计时
    @Published var excludedCalendarIDs: Set<String> {
        didSet { defaults.set(Array(excludedCalendarIDs), forKey: Key.excludedCalendars) }
    }

    @Published var includeAllDay: Bool {
        didSet { defaults.set(includeAllDay, forKey: Key.includeAllDay) }
    }

    /// 剩余时间低于该值时进度条整条转橙，0 表示关闭
    @Published var warnSeconds: Int {
        didSet { defaults.set(warnSeconds, forKey: Key.warnSeconds) }
    }

    @Published var menuBarContent: MenuBarContent {
        didSet { defaults.set(menuBarContent.rawValue, forKey: Key.menuBarContent) }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Key.language)
            applyLanguage()
        }
    }

    var showsTitleInMenuBar: Bool { menuBarContent == .nameAndTime }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.includeAllDay: false,
            Key.warnSeconds: 300,
            Key.menuBarContent: MenuBarContent.nameAndTime.rawValue,
            Key.language: AppLanguage.system.rawValue
        ])
        self.excludedCalendarIDs = Set(defaults.stringArray(forKey: Key.excludedCalendars) ?? [])
        self.includeAllDay      = defaults.bool(forKey: Key.includeAllDay)
        self.warnSeconds        = defaults.integer(forKey: Key.warnSeconds)
        self.menuBarContent     = MenuBarContent(rawValue: defaults.string(forKey: Key.menuBarContent) ?? "")
                                  ?? .nameAndTime
        self.language           = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "")
                                  ?? .system
    }

    func isEnabled(calendarID: String) -> Bool {
        !excludedCalendarIDs.contains(calendarID)
    }

    func setEnabled(_ enabled: Bool, calendarID: String) {
        if enabled { excludedCalendarIDs.remove(calendarID) }
        else       { excludedCalendarIDs.insert(calendarID) }
    }

    /// 语言要下次启动才全面生效，这是 AppleLanguages 的固有行为
    private func applyLanguage() {
        if let code = language.localeCode {
            defaults.set([code], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
