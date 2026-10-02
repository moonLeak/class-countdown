import Foundation

/// 专注进行中保持屏幕常亮，休息和空闲时释放。
final class ScreenAwake {
    private var activity: NSObjectProtocol?

    func set(_ on: Bool) {
        if on, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated],
                reason: "TimeTool focus session")
        } else if !on, let a = activity {
            ProcessInfo.processInfo.endActivity(a)
            activity = nil
        }
    }
}
