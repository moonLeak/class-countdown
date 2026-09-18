import Foundation

/// 设计画布 v6.3 定下的固定格式，不提供自定义。
enum TimeFormat {

    /// >= 24h -> "1d 3:05" ／ >= 1h -> "1:23:47" ／ < 1h -> "23:47"
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
        clockFormatter.string(from: date)
    }

    /// DateFormatter 构造开销不小，倒计时每秒都在刷新，缓存一个
    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("jm")   // 跟随系统 12/24 小时制
        return f
    }()

    static func percent(_ p: Double) -> String {
        "\(Int((p * 100).rounded()))%"
    }

    /// 菜单栏标题截断
    static func truncate(_ title: String, limit: Int = 12) -> String {
        title.count <= limit ? title : String(title.prefix(limit)) + "…"
    }

    /// 菜单栏那一行：名称与剩余时间之间用斜杠分隔
    static func menuBar(title: String, time: String, showTitle: Bool) -> String {
        showTitle ? "\(truncate(title)) / \(time)" : time
    }
}
