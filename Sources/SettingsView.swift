import SwiftUI
import EventKit

/// 设置面板。措辞按 macOS 系统设置的习惯：
/// 左侧是名词短语的标签，语义交给右侧的控件承担。
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var calendarService: CalendarService

    var body: some View {
        TabView {
            general.tabItem { Label("通用", systemImage: "gearshape") }
            calendars.tabItem { Label("日历", systemImage: "calendar") }
        }
        .frame(width: 440, height: 400)
    }

    private var general: some View {
        Form {
            Section("通用") {
                Picker("界面语言", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                LaunchAtLoginToggle()
            }

            Section("菜单栏") {
                Picker("显示内容", selection: $settings.menuBarContent) {
                    ForEach(MenuBarContent.allCases) { Text($0.label).tag($0) }
                }
            }

            Section("倒计时") {
                Toggle("包含全天事件", isOn: $settings.includeAllDay)
                Picker("临近结束警示", selection: $settings.warnSeconds) {
                    Text("关闭").tag(0)
                    Text("剩余 1 分钟").tag(60)
                    Text("剩余 3 分钟").tag(180)
                    Text("剩余 5 分钟").tag(300)
                    Text("剩余 10 分钟").tag(600)
                }
            }

            Section {
                HStack {
                    Text("退出 ClassCountdown")
                    Spacer()
                    Button("退出", role: .destructive) { NSWorkspaceBridge.quit() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var calendars: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("只有勾选的日历参与倒计时。进度条会用日历自己的颜色。")
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

    var body: some View {
        Toggle("登录时打开", isOn: Binding(
            get: { enabled },
            set: { newValue in
                LaunchAtLogin.set(newValue)
                enabled = LaunchAtLogin.isEnabled
            }
        ))
    }
}
