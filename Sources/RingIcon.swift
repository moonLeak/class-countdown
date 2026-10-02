import AppKit

/// 菜单栏进度环：底部一圈浅灰轨道，上面一段进度弧，从 12 点钟方向顺时针走。
/// 做成 template image，系统会按菜单栏明暗自动着色（浅色模式黑，深色模式白）。
/// template 只看 alpha，所以轨道用低透明度表现“灰”，进度弧用满不透明度。
enum RingIcon {
    static func image(progress: Double, size: CGFloat = 16, line: CGFloat = 2.2) -> NSImage {
        let p = min(max(progress, 0), 1)
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let inset = line / 2 + 0.5
            let r = rect.insetBy(dx: inset, dy: inset)
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = r.width / 2

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius,
                            startAngle: 0, endAngle: 360)
            track.lineWidth = line
            NSColor.black.withAlphaComponent(0.28).setStroke()
            track.stroke()

            if p > 0 {
                let arc = NSBezierPath()
                // AppKit 坐标系 y 向上：90° 是 12 点钟，clockwise 则角度递减
                arc.appendArc(withCenter: center, radius: radius,
                              startAngle: 90, endAngle: 90 - 360 * p, clockwise: true)
                arc.lineWidth = line
                arc.lineCapStyle = .round
                NSColor.black.setStroke()
                arc.stroke()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
