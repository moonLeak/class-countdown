import SwiftUI

@main
@MainActor
struct ClassCountdownApp: App {

    @StateObject private var settings: SettingsStore
    @StateObject private var calendarService: CalendarService
    @StateObject private var tick: TickEngine
    @StateObject private var model: ScheduleModel

    init() {
        let settings = SettingsStore()
        let service  = CalendarService()
        let tick     = TickEngine()
        let model    = ScheduleModel(calendarService: service, settings: settings, tick: tick)

        _settings        = StateObject(wrappedValue: settings)
        _calendarService = StateObject(wrappedValue: service)
        _tick            = StateObject(wrappedValue: tick)
        _model           = StateObject(wrappedValue: model)

        service.requestAccess()
    }

    var body: some Scene {
        // .window 样式才能放自定义 SwiftUI 视图；默认的 .menu 只能放菜单项。
        MenuBarExtra {
            CountdownCard(model: model,
                          tick: tick,
                          settings: settings,
                          calendarService: calendarService)
        } label: {
            MenuBarLabel(model: model, tick: tick, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, calendarService: calendarService)
        }
    }
}

/// 菜单栏那一行文字（需求 5.2 末段）。
struct MenuBarLabel: View {
    @ObservedObject var model: ScheduleModel
    @ObservedObject var tick: TickEngine
    @ObservedObject var settings: SettingsStore

    var body: some View {
        switch model.phase {
        case .needsAccess:
            Image(systemName: "calendar.badge.exclamationmark")
        case .empty:
            Image(systemName: "calendar")
        case .running(let e):
            Text(compose(e.title, TimeFormat.countdown(model.remaining(now: tick.now))))
        case .upcoming(let e):
            Text(compose(e.title, "↑" + TimeFormat.countdown(model.remaining(now: tick.now))))
        }
    }

    private func compose(_ title: String, _ time: String) -> String {
        settings.showTitleInMenuBar
            ? "\(TimeFormat.truncate(title)) · \(time)"
            : time
    }
}
