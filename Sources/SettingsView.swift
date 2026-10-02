import SwiftUI
import EventKit

/// 设置窗口的内容区，随工具栏标签切换。措辞按 macOS 系统设置的习惯：
/// 左侧是名词短语的标签，语义交给右侧的控件承担。
struct SettingsRoot: View {
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var settings: SettingsStore
    @ObservedObject var calendarService: CalendarService
    /// 语言一改，这里立刻重画
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Group {
            switch navigation.tab {
            case .general:   GeneralTab(settings: settings)
            case .calendars: CalendarsTab(settings: settings, calendarService: calendarService)
            case .focus:     FocusTab(settings: settings, focus: AppState.shared.focus)
            case .about:     AboutTab()
            }
        }
        // 窗口很宽时内容居中，最大宽取自设计规格
        .frame(maxWidth: DS.settingsContentMaxW)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GeneralTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section(L("tab.general")) {
                Picker(L("row.language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                LaunchAtLoginToggle()
            }

            Section(L("sec.appearance")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("appearance.clarity"))
                    HStack(spacing: 10) {
                        Text(L("appearance.solid"))
                            .font(.system(size: DS.fCaption)).foregroundStyle(.secondary)
                        Slider(value: $settings.cardClarity, in: 0...1)
                        Text(L("appearance.clear"))
                            .font(.system(size: DS.fCaption)).foregroundStyle(.secondary)
                    }
                    Text(L("appearance.clarity.hint"))
                        .font(.system(size: DS.fCaption)).foregroundStyle(.secondary)
                }
            }

            Section(L("sec.menubar")) {
                Picker(L("menubar.style"), selection: $settings.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if settings.menuBarStyle == .badge {
                    Toggle(L("menubar.badgeProgress"), isOn: $settings.badgeProgress)
                }
                Picker(L("row.menubarContent"), selection: $settings.menuBarContent) {
                    ForEach(MenuBarContent.allCases) { Text($0.label).tag($0) }
                }
                // 只显示时间时没有两段可分，这几项就没有意义，
                // 按系统设置的习惯留在原地置灰，而不是让它们消失
                Group {
                    Picker(L("row.separator"), selection: $settings.separatorPreset) {
                        ForEach(SeparatorPreset.allCases) { Text($0.label).tag($0) }
                    }
                    if settings.separatorPreset == .custom {
                        TextField(L("sep.customField"), text: $settings.customSeparator)
                    }
                    LabeledContent(L("sep.preview")) {
                        Text(TimeFormat.menuBar(title: "EK 210 Lab", time: "23:47",
                                                showTitle: true,
                                                separator: settings.separator))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!settings.showsTitleInMenuBar)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(L("menubar.showNext"), isOn: $settings.showNextWhenIdle)
                    Text(L("menubar.showNext.hint"))
                        .font(.system(size: DS.fCaption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct CalendarsTab: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var calendarService: CalendarService

    var body: some View {
        Form {
            Section {
                ForEach(calendarService.calendars, id: \.calendarIdentifier) { cal in
                    Toggle(isOn: Binding(
                        get: { settings.isEnabled(calendarID: cal.calendarIdentifier) },
                        set: { settings.setEnabled($0, calendarID: cal.calendarIdentifier) }
                    )) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor ?? CGColor(gray: 0.5, alpha: 1)))
                                .frame(width: 9, height: 9)
                            Text(cal.title)
                            if let src = cal.source?.title {
                                Text(src).font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text(L("tab.calendars"))
            } footer: {
                Text(L("calendars.hint"))
            }

            Section(L("sec.countdown")) {
                Toggle(L("row.includeAllDay"), isOn: $settings.includeAllDay)
                Picker(L("row.warn"), selection: $settings.warnSeconds) {
                    Text(L("warn.off")).tag(0)
                    Text(L("warn.minutes", 1)).tag(60)
                    Text(L("warn.minutes", 3)).tag(180)
                    Text(L("warn.minutes", 5)).tag(300)
                    Text(L("warn.minutes", 10)).tag(600)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct FocusTab: View {
    @ObservedObject var settings: SettingsStore
    let focus: FocusController

    var body: some View {
        Form {
            Section(L("focus.sec.durations")) {
                Stepper(value: $settings.focusMinutes, in: 1...120) {
                    LabeledContent(L("focus.focusMinutes"), value: L("unit.minutes", settings.focusMinutes))
                }
                Stepper(value: $settings.shortBreakMinutes, in: 1...60) {
                    LabeledContent(L("focus.shortBreak"), value: L("unit.minutes", settings.shortBreakMinutes))
                }
                Stepper(value: $settings.longBreakMinutes, in: 1...60) {
                    LabeledContent(L("focus.longBreak"), value: L("unit.minutes", settings.longBreakMinutes))
                }
            }

            Section(L("focus.sec.auto")) {
                Toggle(L("focus.autoBreak"), isOn: $settings.autoStartBreak)
                Toggle(L("focus.autoFocus"), isOn: $settings.autoStartFocus)
            }

            Section {
                Toggle(L("focus.keepAwake"), isOn: $settings.keepAwake)
                Toggle(L("focus.notify"), isOn: $settings.notifyOnEnd)
            }

            Section {
                Toggle(L("focus.writeCalendar"), isOn: $settings.writeToCalendar)
                if settings.writeToCalendar {
                    Picker(L("focus.calendar"), selection: $settings.focusCalendarID) {
                        Text(L("focus.calendar.new")).tag("")
                        ForEach(focus.writableCalendars, id: \.id) { c in
                            Text(c.source.isEmpty ? c.title : "\(c.title) · \(c.source)").tag(c.id)
                        }
                    }
                }
            } header: {
                Text(L("tab.calendars"))
            } footer: {
                Text(L("focus.writeCalendar.hint"))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct AboutTab: View {
    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [DS.Color.eventDefault, DS.Color.focus],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                    Text("TimeTool")
                        .font(.title2.weight(.semibold))
                        .padding(.top, 8)
                    Text(String(format: L("about.version"), version))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section(L("sec.other")) {
                LabeledContent(L("row.quitApp")) {
                    Button(L("menu.quit"), role: .destructive) { NSWorkspaceBridge.quit() }
                        .foregroundStyle(DS.Color.danger)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

/// SMAppService 的开机自启开关
struct LaunchAtLoginToggle: View {
    @State private var enabled = LaunchAtLogin.isEnabled
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Toggle(L("row.launchAtLogin"), isOn: Binding(
            get: { enabled },
            set: { newValue in
                LaunchAtLogin.set(newValue)
                enabled = LaunchAtLogin.isEnabled
            }
        ))
    }
}
