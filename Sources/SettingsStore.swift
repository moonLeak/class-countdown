import Foundation
import Combine

/// 界面语言。只管软件自身的文字，日程名称永远按日历里的原文显示。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, zhHans, zhHant, en, ja, ko, de, fr, es, pt, ru

    var id: String { rawValue }

    @MainActor var label: String {
        switch self {
        case .system: return L("lang.system")
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

/// 菜单栏里名称和时间之间的分隔符。
/// 常用的几个列成预设，剩下的交给自定义——
/// 全靠输入框的话，光是打出一个间隔号就够麻烦的。
enum SeparatorPreset: String, CaseIterable, Identifiable {
    case slash, dot, bullet, bar, dash, space, custom

    var id: String { rawValue }

    /// custom 没有固定字符，由 customSeparator 决定
    var glyph: String? {
        switch self {
        case .slash:  return "/"
        case .dot:    return "·"
        case .bullet: return "•"
        case .bar:    return "|"
        case .dash:   return "—"
        case .space:  return " "
        case .custom: return nil
        }
    }

    @MainActor var label: String {
        switch self {
        case .space:  return L("sep.space")
        case .custom: return L("sep.custom")
        default:      return glyph ?? ""
        }
    }
}

/// 菜单栏显示什么
enum MenuBarContent: String, CaseIterable, Identifiable {
    case nameAndTime, timeOnly
    var id: String { rawValue }
    @MainActor var label: String {
        switch self {
        case .nameAndTime: return L("menubar.nameAndTime")
        case .timeOnly:    return L("menubar.timeOnly")
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
        static let separatorPreset   = "menuBarSeparatorPreset"
        static let customSeparator   = "menuBarCustomSeparator"
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
            // 当场换文案，不等重启
            L10n.shared.apply(language)
        }
    }

    @Published var separatorPreset: SeparatorPreset {
        didSet { defaults.set(separatorPreset.rawValue, forKey: Key.separatorPreset) }
    }

    /// 只在预设选到 custom 时生效，留空就退回斜杠
    @Published var customSeparator: String {
        didSet { defaults.set(customSeparator, forKey: Key.customSeparator) }
    }

    /// 真正写进菜单栏的那个字符串
    var separator: String {
        if let g = separatorPreset.glyph { return g }
        return customSeparator.isEmpty ? "/" : customSeparator
    }

    var showsTitleInMenuBar: Bool { menuBarContent == .nameAndTime }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.includeAllDay: false,
            Key.warnSeconds: 300,
            Key.menuBarContent: MenuBarContent.nameAndTime.rawValue,
            Key.language: AppLanguage.system.rawValue,
            Key.separatorPreset: SeparatorPreset.slash.rawValue,
            Key.customSeparator: "/"
        ])
        self.excludedCalendarIDs = Set(defaults.stringArray(forKey: Key.excludedCalendars) ?? [])
        self.includeAllDay      = defaults.bool(forKey: Key.includeAllDay)
        self.warnSeconds        = defaults.integer(forKey: Key.warnSeconds)
        self.menuBarContent     = MenuBarContent(rawValue: defaults.string(forKey: Key.menuBarContent) ?? "")
                                  ?? .nameAndTime
        self.language           = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "")
                                  ?? .system
        self.separatorPreset    = SeparatorPreset(rawValue: defaults.string(forKey: Key.separatorPreset) ?? "")
                                  ?? .slash
        self.customSeparator    = defaults.string(forKey: Key.customSeparator) ?? "/"
        // didSet 在 init 里不触发，这里补一次
        L10n.shared.apply(self.language)
    }

    func isEnabled(calendarID: String) -> Bool {
        !excludedCalendarIDs.contains(calendarID)
    }

    func setEnabled(_ enabled: Bool, calendarID: String) {
        if enabled { excludedCalendarIDs.remove(calendarID) }
        else       { excludedCalendarIDs.insert(calendarID) }
    }

    /// 界面文案由 L10n 当场切换。这里同时写一份 AppleLanguages，
    /// 让系统自带的控件（关于窗口、右键菜单里的系统项）下次启动也跟上。
    private func applyLanguage() {
        if let code = language.localeCode {
            defaults.set([code], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
