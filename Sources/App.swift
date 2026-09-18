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

        // 订阅统一在各自的 start() 里建立，见 CalendarService.start 的注释。
        tick.start()
        model.start()
        service.start()
    }

    var body: some Scene {
        // .window 样式才能放自定义 SwiftUI 视图；默认的 .menu 只能放菜单项。
        MenuBarExtra {
            CardStack(model: model, tick: tick, calendarService: calendarService)
        } label: {
            MenuBarLabel(model: model, tick: tick, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, calendarService: calendarService)
        }
    }
}

/// 菜单栏那一行文字
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
        case .running(let list):
            if let e = list.first {
                Text(TimeFormat.menuBar(
                    title: e.title,
                    time: TimeFormat.countdown(model.remaining(e, now: tick.now)),
                    showTitle: settings.showsTitleInMenuBar))
            }
        case .upcoming(let e):
            Text(TimeFormat.menuBar(
                title: e.title,
                time: "↑" + TimeFormat.countdown(model.remaining(e, now: tick.now, counting: true)),
                showTitle: settings.showsTitleInMenuBar))
        }
    }
}
