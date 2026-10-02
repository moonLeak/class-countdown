import Foundation

/// 专注状态机。纯逻辑：不碰 UI，不读系统时间，所有方法的当前时刻都由调用方传入，
/// 这样单测可以任意快进。状态命名与 docs/DESIGN-SPEC.md 4.3 一致。

enum FocusState: String, Codable, Equatable {
    case idle
    case focusing
    case focusPaused
    case breakWaiting
    case breaking
    case longBreakWaiting
    case longBreaking
}

struct FocusConfig: Equatable, Codable {
    var focusDuration: TimeInterval = 25 * 60
    var shortBreakDuration: TimeInterval = 5 * 60
    var longBreakDuration: TimeInterval = 15 * 60
    /// 一轮的专注节数，第 4 节之后进入长休息
    var cyclesPerRound = 4
    /// 专注结束后自动开始休息
    var autoStartBreak = false
    /// 休息结束后自动开始下一轮专注（长休息之后一律回到 idle）
    var autoStartFocus = false
}

/// 一个已经结束的专注块。休息不记录。
struct FocusBlock: Codable, Equatable, Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    /// 实际专注的秒数，不含暂停
    let duration: TimeInterval
    /// 是否做满了计划时长
    let isComplete: Bool
}

/// 进程意外退出时用来补记的快照。只存当前专注块的开始时间和上次已知时间，不做心跳。
struct FocusSnapshot: Codable, Equatable {
    var blockID: UUID
    var blockStart: Date
    var plannedDuration: TimeInterval
    /// 上次保存这份快照的时刻
    var lastKnown: Date
    /// 截至 lastKnown 已经专注的秒数
    var focusedAtLastKnown: TimeInterval
}

struct FocusEngine {

    /// 合盖超过这个时长，本次专注在合盖那一刻结束。固定值，不进设置。
    static let sleepLimit: TimeInterval = 15 * 60

    private(set) var state: FocusState = .idle
    var config: FocusConfig
    /// 本轮已经做满的专注节数，界面上的四个点
    private(set) var completedInRound = 0

    private struct CurrentBlock {
        let id: UUID
        let start: Date
        let planned: TimeInterval
        /// 进入当前运行段之前累计的专注秒数
        var accumulated: TimeInterval
        /// 当前运行段的开始时刻，暂停时为 nil
        var segmentStart: Date?
    }

    private var block: CurrentBlock?
    /// 专注或休息的截止时刻，暂停与等待状态下为 nil
    private var endsAt: Date?
    private var remainingWhenPaused: TimeInterval = 0
    private var sleptAt: Date?
    private var finished: [FocusBlock] = []

    init(config: FocusConfig = FocusConfig()) {
        self.config = config
    }

    // MARK: 输出

    /// 取走已结束的专注块，由调用方写入存储
    mutating func drainFinished() -> [FocusBlock] {
        defer { finished.removeAll() }
        return finished
    }

    /// 显示用的剩余秒数
    func remaining(now: Date) -> TimeInterval {
        switch state {
        case .idle:             return config.focusDuration
        case .focusPaused:      return remainingWhenPaused
        case .breakWaiting:     return config.shortBreakDuration
        case .longBreakWaiting: return config.longBreakDuration
        case .focusing, .breaking, .longBreaking:
            return max(0, (endsAt ?? now).timeIntervalSince(now))
        }
    }

    /// 进度填充的比例。专注随已用时间增长，休息随剩余时间收缩。
    func progress(now: Date) -> Double {
        switch state {
        case .idle:
            return 0
        case .focusing, .focusPaused:
            return clamp(1 - remaining(now: now) / config.focusDuration)
        case .breakWaiting:
            return 1
        case .longBreakWaiting:
            return 1
        case .breaking:
            return clamp(remaining(now: now) / config.shortBreakDuration)
        case .longBreaking:
            return clamp(remaining(now: now) / config.longBreakDuration)
        }
    }

    var isBreak: Bool {
        switch state {
        case .breakWaiting, .breaking, .longBreakWaiting, .longBreaking: return true
        default: return false
        }
    }

    // MARK: 事件

    mutating func start(now: Date) {
        switch state {
        case .idle:
            beginFocus(at: now)
        case .breakWaiting:
            state = .breaking
            endsAt = now.addingTimeInterval(config.shortBreakDuration)
        case .longBreakWaiting:
            state = .longBreaking
            endsAt = now.addingTimeInterval(config.longBreakDuration)
        default:
            break
        }
    }

    /// 休息中不可暂停
    mutating func pause(now: Date) {
        guard state == .focusing, var b = block, let end = endsAt else { return }
        if let seg = b.segmentStart { b.accumulated += now.timeIntervalSince(seg) }
        b.segmentStart = nil
        block = b
        remainingWhenPaused = max(0, end.timeIntervalSince(now))
        endsAt = nil
        state = .focusPaused
    }

    mutating func resume(now: Date) {
        guard state == .focusPaused, var b = block else { return }
        b.segmentStart = now
        block = b
        endsAt = now.addingTimeInterval(remainingWhenPaused)
        state = .focusing
    }

    /// 回到 idle，四个点清零。进行中的专注按手动停止记录，已记录的不删。
    mutating func reset(now: Date) {
        if state == .focusing || state == .focusPaused {
            closeBlock(endingAt: now, complete: false)
        }
        state = .idle
        completedInRound = 0
        endsAt = nil
        block = nil
    }

    mutating func skipBreak(now: Date) {
        switch state {
        case .breakWaiting, .breaking:
            state = .idle
            endsAt = nil
        case .longBreakWaiting, .longBreaking:
            state = .idle
            endsAt = nil
            completedInRound = 0
        default:
            break
        }
    }

    /// 每秒心跳。一次可以跨过多个状态，例如睡眠醒来后专注与休息都已经过完。
    mutating func tick(now: Date) {
        while true {
            guard let end = endsAt, now >= end else { return }
            switch state {
            case .focusing:
                closeBlock(endingAt: end, complete: true)
                completedInRound += 1
                enterBreak(at: end)
            case .breaking:
                if config.autoStartFocus {
                    beginFocus(at: end)
                } else {
                    state = .idle
                    endsAt = nil
                }
            case .longBreaking:
                state = .idle
                endsAt = nil
                completedInRound = 0
            default:
                return
            }
        }
    }

    // MARK: 睡眠与唤醒

    mutating func willSleep(now: Date) {
        tick(now: now)
        sleptAt = now
    }

    /// 合盖不超过阈值：计时继续，睡眠时间照常计入。
    /// 超过阈值：本次专注在合盖那一刻结束。
    mutating func didWake(now: Date) {
        defer { sleptAt = nil }
        if let slept = sleptAt, state == .focusing,
           now.timeIntervalSince(slept) > Self.sleepLimit {
            closeBlock(endingAt: slept, complete: false)
            state = .idle
            endsAt = nil
            block = nil
        }
        tick(now: now)
    }

    // MARK: 快照与补记

    func snapshot(now: Date) -> FocusSnapshot? {
        guard let b = block, state == .focusing || state == .focusPaused else { return nil }
        return FocusSnapshot(blockID: b.id, blockStart: b.start,
                             plannedDuration: b.planned, lastKnown: now,
                             focusedAtLastKnown: focused(b, at: now))
    }

    /// 启动时发现上次留下快照，说明进程没有正常收尾，按上次已知时间保守补记
    static func recoveredBlock(from s: FocusSnapshot) -> FocusBlock? {
        let focused = min(max(0, s.focusedAtLastKnown), s.plannedDuration)
        guard focused >= 1 else { return nil }
        return FocusBlock(id: s.blockID, start: s.blockStart, end: s.lastKnown,
                          duration: focused,
                          isComplete: focused >= s.plannedDuration)
    }

    // MARK: 内部

    private mutating func beginFocus(at t: Date) {
        block = CurrentBlock(id: UUID(), start: t, planned: config.focusDuration,
                             accumulated: 0, segmentStart: t)
        endsAt = t.addingTimeInterval(config.focusDuration)
        state = .focusing
    }

    private mutating func enterBreak(at t: Date) {
        let isLong = completedInRound >= config.cyclesPerRound
        if config.autoStartBreak {
            state = isLong ? .longBreaking : .breaking
            endsAt = t.addingTimeInterval(isLong ? config.longBreakDuration
                                                 : config.shortBreakDuration)
        } else {
            state = isLong ? .longBreakWaiting : .breakWaiting
            endsAt = nil
        }
    }

    private mutating func closeBlock(endingAt end: Date, complete: Bool) {
        guard let b = block else { return }
        let focusedSeconds = complete ? b.planned : focused(b, at: end)
        block = nil
        guard focusedSeconds >= 1 else { return }
        finished.append(FocusBlock(id: b.id, start: b.start, end: end,
                                   duration: focusedSeconds, isComplete: complete))
    }

    private func focused(_ b: CurrentBlock, at t: Date) -> TimeInterval {
        var total = b.accumulated
        if let seg = b.segmentStart { total += max(0, t.timeIntervalSince(seg)) }
        return min(total, b.planned)
    }

    private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}
