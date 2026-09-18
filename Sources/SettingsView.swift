import SwiftUI
import EventKit

/// 设置面板。措辞按 macOS 系统设置的习惯：
/// 左侧是名词短语的标签，语义交给右侧的控件承担。
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var calendarService: CalendarService
    /// 语言一改，这里立刻重画
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        TabView {
            general.tabItem { Label(L("tab.general"), systemImage: "gearshape") }
            calendars.tabItem { Label(L("tab.calendars"), systemImage: "calendar") }
        }
        .frame(width: 440, height: 400)
    }

    private var general: some View {
        Form {
            Section(L("tab.general")) {
                Picker(L("row.language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                LaunchAtLoginToggle()
            }

            Section(L("sec.menubar")) {
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

            Section {
                HStack {
                    Text(L("row.quitApp"))
                    Spacer()
                    Button(L("menu.quit"), role: .destructive) { NSWorkspaceBridge.quit() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var calendars: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("calendars.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            List {
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
            }
        }
        .padding()
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
