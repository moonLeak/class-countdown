import SwiftUI

/// 设计画布 v6.3 定下的全部数值，改设计只改这一处。
enum DS {

    // MARK: 尺寸
    /// 卡片本体，比例取自 iOS systemMedium 小组件（329×155pt）
    static let cardW: CGFloat = 340
    static let cardH: CGFloat = 160
    static let radius: CGFloat = 28
    /// 水平内边距约等于圆角的 0.78 倍，小于这个值文字会落进圆弧的视觉范围
    static let padX: CGFloat = 22
    static let padY: CGFloat = 18

    // MARK: 堆叠
    /// 每张后卡露出的高度 = padY + 名称行高 + 余量，刚好读完名称
    static let peek: CGFloat = 40
    /// 展开后的卡间距
    static let gap: CGFloat = 10
    /// 每往后一层缩小的比例
    static let shrink: CGFloat = 0.04

    // MARK: 字号与字重（三级，一一对应）
    static let fDisplay: CGFloat = 54
    static let wDisplay: Font.Weight = .medium      // 500
    static let fBody: CGFloat = 13
    static let wBody: Font.Weight = .semibold       // 590
    static let fCaption: CGFloat = 11
    static let wCaption: Font.Weight = .regular     // 400

    // MARK: 明暗
    /// 用语义色而非写死的透明度：系统会按背景自动调整，
    /// 画布上的百分比只是层级关系的参照。
    static let l1 = Color.primary            // 倒计时数字
    static let l2 = Color.secondary          // 日程名称
    static let l3 = Color.secondary.opacity(0.78)   // 时间与百分比

    // MARK: 进度条
    /// 正常态填充的上下两端不透明度
    static let fillTop: Double = 0.34
    static let fillBottom: Double = 0.20
    static let edgeAlpha: Double = 0.55
    /// 警示态：颜色换成橙色的同时提高浓度，
    /// 这样即便日历本身就是橙色，状态变化仍然读得出来。
    static let warnFillTop: Double = 0.52
    static let warnFillBottom: Double = 0.34
    static let warnEdgeAlpha: Double = 0.88
    /// 警示色。这个色位在设计上专留给警示，不作为任何日历的颜色。
    static let warn = Color(red: 1.0, green: 0.624, blue: 0.039)   // #FF9F0A

    // MARK: 动效
    static let motion: Animation = .spring(response: 0.42, dampingFraction: 0.82)
    static let fade: Animation = .easeInOut(duration: 0.3)
}

/// Liquid Glass 的近似实现。
/// macOS 26 起可换成系统的 .glassEffect()，这里手写是为了兼容 macOS 14。
struct GlassCard: ViewModifier {
    var depth: Int = 0
    var radius: CGFloat = DS.radius

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Rectangle().fill(.regularMaterial)
                    Rectangle().fill(Color.white.opacity(0.10 - Double(depth) * 0.015))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.30), Color.white.opacity(0.07)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.40 - Double(depth) * 0.08), radius: 14, y: 10)
    }
}

extension View {
    func glassCard(depth: Int = 0, radius: CGFloat = DS.radius) -> some View {
        modifier(GlassCard(depth: depth, radius: radius))
    }
}
