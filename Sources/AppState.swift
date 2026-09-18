import Foundation
import Combine

/// 全应用共享的一份状态。
/// 面板改成自己管的 NSPanel 之后，SwiftUI 场景不再是唯一入口，
/// 需要一个所有人都能拿到的持有者。
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let settings = SettingsStore()
    let calendar = CalendarService()
    let tick = TickEngine()
    lazy var model = ScheduleModel(calendarService: calendar, settings: settings, tick: tick)

    private init() {}

    func start() {
        tick.start()
        model.start()
        calendar.start()
    }
}
