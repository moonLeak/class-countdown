import SwiftUI
import EventKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var calendarService: CalendarService

    var body: some View {
        TabView {
            general.tabItem { Label("通用", systemImage: "gearshape") }
            calendars.tabItem { Label("日历", systemImage: "calendar") }
        }
        .frame(width: 420, height: 340)
    }

    private var general: some View {
        Form {
            Toggle("菜单栏显示日程标题", isOn: $settings.showTitleInMenuBar)
            Toggle("把全天事件也算进来", isOn: $settings.includeAllDay)
            Picker("剩余多久时变警示色", selection: $settings.warnSeconds) {
                Text("1 分钟").tag(60)
                Text("3 分钟").tag(180)
                Text("5 分钟").tag(300)
                Text("10 分钟").tag(600)
                Text("不提示").tag(0)
            }
            Divider()
            LaunchAtLoginToggle()
        }
        .formStyle(.grouped)
        .padding()
    }

    private var calendars: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("只有勾选的日历参与倒计时。")
                .font(.caption)
                .foregroundStyle(.secondary)
            List {
                ForEach(calendarService.calendars, id: \.calendarIdentifier) { cal in
                    Toggle(isOn: Binding(
                        get: { settings.isEnabled(calendarID: cal.calendarIdentifier) },
                        set: { settings.setEnabled($0, calendarID: cal.calendarIdentifier) }
                    )) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor ?? CGColor(gray: 0.5, alpha: 1)))
                                .frame(width: 8, height: 8)
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

/// SMAppService 的开机自启开关（FR-9）。
struct LaunchAtLoginToggle: View {
    @State private var enabled = LaunchAtLogin.isEnabled

    var body: some View {
        Toggle("开机自动启动", isOn: Binding(
            get: { enabled },
            set: { newValue in
                LaunchAtLogin.set(newValue)
                enabled = LaunchAtLogin.isEnabled
            }
        ))
    }
}
