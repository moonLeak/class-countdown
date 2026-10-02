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

/// 菜单栏图标样式：圆环或徽标
enum MenuBarStyle: String, CaseIterable, Identifiable {
    case ring, badge
    var id: String { rawValue }
    @MainActor var label: String {
        switch self {
        case .ring:  return L("menubar.style.ring")
        case .badge: return L("menubar.style.badge")
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
        static let menuBarStyle      = "menubar.style"
        static let badgeProgress     = "menubar.badgeProgress"
        static let showNextWhenIdle  = "menubar.showNextWhenIdle"
        static let focusMinutes      = "focus.focusMinutes"
        static let shortBreakMinutes = "focus.shortBreakMinutes"
        static let longBreakMinutes  = "focus.longBreakMinutes"
        static let autoStartBreak    = "focus.autoStartBreak"
        static let autoStartFocus    = "focus.autoStartFocus"
        static let keepAwake         = "focus.keepAwake"
        static let flowCardSlot      = "cards.flowSlot"
        static let writeToCalendar   = "focus.writeToCalendar"
        static let focusCalendarID   = "focus.calendarID"
        static let notifyOnEnd       = "focus.notifyOnEnd"
        static let cardClarity       = "cards.clarity"
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

    @Published var menuBarStyle: MenuBarStyle {
        didSet { defaults.set(menuBarStyle.rawValue, forKey: Key.menuBarStyle) }
    }

    /// 徽标底色是否随进度从左往右填充，关掉就是纯色
    @Published var badgeProgress: Bool {
        didSet { defaults.set(badgeProgress, forKey: Key.badgeProgress) }
    }

    /// 没有进行中的日程时，菜单栏是否显示下一个日程的倒计时
    @Published var showNextWhenIdle: Bool {
        didSet { defaults.set(showNextWhenIdle, forKey: Key.showNextWhenIdle) }
    }

    @Published var focusMinutes: Int {
        didSet { defaults.set(focusMinutes, forKey: Key.focusMinutes) }
    }
    @Published var shortBreakMinutes: Int {
        didSet { defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes) }
    }
    @Published var longBreakMinutes: Int {
        didSet { defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes) }
    }
    /// 专注结束后自动开始休息
    @Published var autoStartBreak: Bool {
        didSet { defaults.set(autoStartBreak, forKey: Key.autoStartBreak) }
    }
    /// 休息结束后自动开始下一轮专注
    @Published var autoStartFocus: Bool {
        didSet { defaults.set(autoStartFocus, forKey: Key.autoStartFocus) }
    }
    /// 专注进行中保持屏幕常亮
    @Published var keepAwake: Bool {
        didSet { defaults.set(keepAwake, forKey: Key.keepAwake) }
    }
    /// Flow 卡在卡叠里的位置，-1 表示默认的最底层。
    /// 日程卡的顺序由结束时间决定，不能手动排，所以只记 Flow 卡的位置。
    @Published var flowCardSlot: Int {
        didSet { defaults.set(flowCardSlot, forKey: Key.flowCardSlot) }
    }

    /// 把完成的专注写入日历。需要完整日历访问权限
    @Published var writeToCalendar: Bool {
        didSet { defaults.set(writeToCalendar, forKey: Key.writeToCalendar) }
    }
    /// 写入的目标日历。空表示还没选，第一次写入时会新建一个专注日历并记在这里
    @Published var focusCalendarID: String {
        didSet { defaults.set(focusCalendarID, forKey: Key.focusCalendarID) }
    }

    /// 专注或休息自然结束时发系统通知
    @Published var notifyOnEnd: Bool {
        didSet { defaults.set(notifyOnEnd, forKey: Key.notifyOnEnd) }
    }

    /// 卡片透明度，0 到 1，越大越透
    @Published var cardClarity: Double {
        didSet { defaults.set(cardClarity, forKey: Key.cardClarity) }
    }

    var focusConfig: FocusConfig {
        FocusConfig(focusDuration: TimeInterval(focusMinutes) * 60,
                    shortBreakDuration: TimeInterval(shortBreakMinutes) * 60,
                    longBreakDuration: TimeInterval(longBreakMinutes) * 60,
                    cyclesPerRound: 4,
                    autoStartBreak: autoStartBreak,
                    autoStartFocus: autoStartFocus)
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
            Key.customSeparator: "/",
            Key.menuBarStyle: MenuBarStyle.ring.rawValue,
            Key.badgeProgress: true,
            Key.showNextWhenIdle: true,
            Key.focusMinutes: 25,
            Key.shortBreakMinutes: 5,
            Key.longBreakMinutes: 15,
            Key.autoStartBreak: false,
            Key.autoStartFocus: false,
            Key.keepAwake: true,
            Key.flowCardSlot: -1,
            Key.writeToCalendar: false,
            Key.focusCalendarID: "",
            Key.notifyOnEnd: true,
            Key.cardClarity: DS.cardClarityDefault
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
        self.menuBarStyle       = MenuBarStyle(rawValue: defaults.string(forKey: Key.menuBarStyle) ?? "")
                                  ?? .ring
        self.badgeProgress      = defaults.bool(forKey: Key.badgeProgress)
        self.showNextWhenIdle   = defaults.bool(forKey: Key.showNextWhenIdle)
        self.focusMinutes       = defaults.integer(forKey: Key.focusMinutes)
        self.shortBreakMinutes  = defaults.integer(forKey: Key.shortBreakMinutes)
        self.longBreakMinutes   = defaults.integer(forKey: Key.longBreakMinutes)
        self.autoStartBreak     = defaults.bool(forKey: Key.autoStartBreak)
        self.autoStartFocus     = defaults.bool(forKey: Key.autoStartFocus)
        self.keepAwake          = defaults.bool(forKey: Key.keepAwake)
        self.flowCardSlot       = defaults.integer(forKey: Key.flowCardSlot)
        self.writeToCalendar    = defaults.bool(forKey: Key.writeToCalendar)
        self.focusCalendarID    = defaults.string(forKey: Key.focusCalendarID) ?? ""
        self.notifyOnEnd        = defaults.bool(forKey: Key.notifyOnEnd)
        self.cardClarity        = defaults.double(forKey: Key.cardClarity)
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
