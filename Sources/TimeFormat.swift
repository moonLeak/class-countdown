import Foundation

/// 需求 5.2 的固定格式规则。不提供自定义。
enum TimeFormat {

    /// >= 24h  -> "1d 3:05"
    /// >= 1h   -> "1:23:47"
    /// <  1h   -> "23:47"
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let d = total / 86400
        let h = (total % 86400) / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if d > 0 { return String(format: "%dd %d:%02d", d, h, m) }
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    /// 卡片底部的 "10:10 – 12:00"
    static func range(_ start: Date, _ end: Date) -> String {
        "\(clock(start)) – \(clock(end))"
    }

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("jm")   // 跟随系统 12/24 小时制
        return f.string(from: date)
    }

    /// 菜单栏标题截断
    static func truncate(_ title: String, limit: Int = 12) -> String {
        title.count <= limit ? title : String(title.prefix(limit)) + "…"
    }

    static func percent(_ p: Double) -> String {
        "\(Int((p * 100).rounded()))%"
    }
}
