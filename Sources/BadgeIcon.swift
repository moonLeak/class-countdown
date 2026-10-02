import AppKit

/// 菜单栏徽标：带底色的圆角框，框里是剩余时间。
/// 底色是状态色 40%，进度填充是状态色 90%，从左往右长。
/// 不是 template image：颜色要原样显示，所以文字自己画成白色带暗阴影，
/// 在浅色和深色菜单栏上都能读。
enum BadgeIcon {

    static func image(text: String, color: NSColor, progress: Double?) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: DS.badgeFont, weight: .medium)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 0.5
        shadow.shadowOffset = NSSize(width: 0, height: -0.5)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .shadow: shadow
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let textSize = str.size()
        let size = NSSize(width: ceil(textSize.width) + DS.badgePadX * 2, height: DS.badgeH)

        let img = NSImage(size: size, flipped: false) { rect in
            // 浅色菜单栏背景亮，底色不透明度提高一档，白字才有依托
            let isDark = NSAppearance.currentDrawing()
                .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let baseAlpha = isDark ? DS.badgeBaseAlpha : DS.badgeBaseAlphaLight

            let shape = NSBezierPath(roundedRect: rect,
                                     xRadius: DS.badgeRadius, yRadius: DS.badgeRadius)
            color.withAlphaComponent(baseAlpha).setFill()
            shape.fill()

            if let p = progress, p > 0 {
                NSGraphicsContext.saveGraphicsState()
                shape.addClip()
                color.withAlphaComponent(DS.badgeFillAlpha).setFill()
                NSRect(x: 0, y: 0, width: rect.width * min(p, 1), height: rect.height).fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            str.draw(at: NSPoint(x: DS.badgePadX,
                                 y: (rect.height - textSize.height) / 2))
            return true
        }
        img.isTemplate = false
        return img
    }
}
