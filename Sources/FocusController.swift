import Foundation
import Combine

/// 把 FocusEngine 接到应用里：心跳、睡眠唤醒、存储、常亮、设置。
/// 引擎本身是纯逻辑，所有和时钟、磁盘、系统有关的事都在这里。
@MainActor
final class FocusController: ObservableObject {

    /// 不用 @Published：心跳每半秒都会改一次内部状态（例如睡眠时刻），
    /// 但只有状态真的变了才需要通知界面，由 apply 手动发
    private(set) var engine: FocusEngine
    /// 休息卡标题在提示语里轮换的序号，每次进入休息加一
    @Published private(set) var breakTitleIndex = 0

    private let settings: SettingsStore
    private let tick: TickEngine
    private let store = FocusController.makeStore()
    private let awake = ScreenAwake()
    private var bag = Set<AnyCancellable>()

    init(settings: SettingsStore, tick: TickEngine) {
        self.settings = settings
        self.tick = tick
        self.engine = FocusEngine(config: settings.focusConfig)
    }

    func start() {
        // 上次没有正常收尾，按上次已知时间补记
        store.recoverPending()

        tick.$now
            .sink { [weak self] now in
                Task { @MainActor in self?.apply { $0.tick(now: now) } }
            }
            .store(in: &bag)

        // 设置改了：空闲或等待时立刻生效，进行中的这一段保持原来的时长
        settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.syncConfig() }
            }
            .store(in: &bag)

        NSWorkspaceNotificationBridge.onSleep { [weak self] in
            Task { @MainActor in
                self?.apply { $0.willSleep(now: Date()) }
                self?.saveSnapshot(now: Date())
            }
        }
        NSWorkspaceNotificationBridge.onWake { [weak self] in
            Task { @MainActor in self?.apply { $0.didWake(now: Date()) } }
        }
    }

    /// 统计页读这份记录
    var blocks: [FocusBlock] { store.blocks }

    // MARK: 操作

    /// 主按钮：按当前状态决定做什么
    func primaryAction() {
        let now = Date()
        switch engine.state {
        case .idle, .breakWaiting, .longBreakWaiting:
            syncConfig(force: true)
            apply { $0.start(now: now) }
        case .focusing:
            apply { $0.pause(now: now) }
        case .focusPaused:
            apply { $0.resume(now: now) }
        case .breaking, .longBreaking:
            apply { $0.skipBreak(now: now) }
        }
    }

    func skipBreak() { apply { $0.skipBreak(now: Date()) } }
    func reset() { apply { $0.reset(now: Date()) } }

    /// 正常退出时留一份快照，下次启动按它补记
    func persistOnQuit() { saveSnapshot(now: Date()) }

    // MARK: 派生

    var breakTitleKey: String {
        engine.state == .longBreakWaiting || engine.state == .longBreaking
            ? "flow.longBreak" : "flow.break.\(breakTitleIndex % 5)"
    }

    // MARK: 内部

    /// 开发用模拟模式下不碰真实记录：用临时目录，并从模拟 JSON 的 focusBlocks 填充，
    /// 这样统计页有数据可看。每条是 { daysAgo, hour, minutes, count }，
    /// 从当天 hour 点起每隔 30 分钟一个，共 count 个。
    private static func makeStore() -> FocusStore {
        guard let path = CalendarService.mockPath else { return FocusStore() }
        let dir = URL(fileURLWithPath: "/private/tmp/timetool-mock-focus")
        try? FileManager.default.removeItem(at: dir)
        let store = FocusStore(directory: dir)
        guard let data = FileManager.default.contents(atPath: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return store }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for entry in (root["focusBlocks"] as? [[String: Any]]) ?? [] {
            let daysAgo = (entry["daysAgo"] as? Int) ?? 0
            let hour = (entry["hour"] as? Double) ?? 9
            let minutes = (entry["minutes"] as? Double) ?? 25
            let count = (entry["count"] as? Int) ?? 1
            guard let day = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            for i in 0..<count {
                let start = day.addingTimeInterval(hour * 3600 + Double(i) * 30 * 60)
                store.append(FocusBlock(id: UUID(), start: start,
                                        end: start.addingTimeInterval(minutes * 60),
                                        duration: minutes * 60, isComplete: true))
            }
        }
        return store
    }

    /// 所有状态变化都走这里：取走结束的专注块、更新常亮与快照
    private func apply(_ change: (inout FocusEngine) -> Void) {
        let before = engine.state
        var next = engine
        change(&next)
        let finished = next.drainFinished()
        // 没有任何变化就不发布，避免心跳白白触发重绘
        let changed = next.state != before || !finished.isEmpty
        engine = next
        guard changed else { return }
        objectWillChange.send()

        finished.forEach { store.append($0) }
        if next.isBreak, !Self.isBreak(before) { breakTitleIndex += 1 }
        awake.set(settings.keepAwake && next.state == .focusing)
        saveSnapshot(now: Date())
    }

    private static func isBreak(_ s: FocusState) -> Bool {
        s == .breakWaiting || s == .breaking || s == .longBreakWaiting || s == .longBreaking
    }

    private func syncConfig(force: Bool = false) {
        switch engine.state {
        case .idle, .breakWaiting, .longBreakWaiting:
            engine.config = settings.focusConfig
        default:
            // 进行中只改自动开始开关，时长保持不变
            engine.config.autoStartBreak = settings.autoStartBreak
            engine.config.autoStartFocus = settings.autoStartFocus
        }
        if !settings.keepAwake { awake.set(false) }
        objectWillChange.send()
    }

    private func saveSnapshot(now: Date) {
        store.setPending(engine.snapshot(now: now))
    }
}
