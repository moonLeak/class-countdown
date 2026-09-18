import Foundation
import Combine

/// 每秒心跳。对齐到整秒边界触发，避免数字跳秒或回跳。
/// 只驱动“显示刷新”，不触发日历重新拉取（两条链路分开，见需求 8.2）。
@MainActor
final class TickEngine: ObservableObject {

    @Published private(set) var now: Date = Date()

    private var timer: Timer?

    init() { schedule() }
    // 同 CalendarService：不写 deinit。

    private func schedule() {
        timer?.invalidate()
        // 0.5 秒轮询：即便系统偶尔延迟触发，整秒也不会被跳过。
        // 空闲 CPU 影响可忽略，但比 1 秒定时器在边界上稳得多。
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        // .common 保证下拉菜单打开、窗口拖动时仍然走时。
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
