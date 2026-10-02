import Foundation

/// 写进日历的专注事件的标记。
/// 读取日程时按它过滤掉自己写入的事件，避免倒计时卡把专注当成课程显示。
/// 不是整个日历排除，所以用户把专注写进自己常看的日历也不会受影响。
enum FocusCalendarMarker {

    static let prefix = "TimeTool-focus:"

    static func notes(for block: FocusBlock) -> String {
        "TimeTool\n\(prefix)\(block.id.uuidString)"
    }

    static func isOurs(notes: String?) -> Bool {
        notes?.contains(prefix) == true
    }

    static func blockID(from notes: String?) -> UUID? {
        guard let notes, let r = notes.range(of: prefix) else { return nil }
        let rest = notes[r.upperBound...]
        let token = rest.prefix { $0.isHexDigit || $0 == "-" }
        return UUID(uuidString: String(token))
    }
}
