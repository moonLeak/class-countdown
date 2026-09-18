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
    static let fillTop: Double = 0.34
    static let fillBottom: Double = 0.20
    static let edgeAlpha: Double = 0.55
    /// 警示态：颜色换成橙色的同时提高浓度，
    /// 这样即便日历本身就是橙色，状态变化仍然读得出来。
    static let warnFillTop: Double = 0.52
    static let warnFillBottom: Double = 0.34
    static let warnEdgeAlpha: Double = 0.88
    /// 警示色。这个色位专留给警示，不作为任何日历的颜色。
    static let warn = Color(red: 1.0, green: 0.624, blue: 0.039)   // #FF9F0A

    // MARK: 动效
    /// 与设计画布同一条曲线：cubic-bezier(.32, .72, 0, 1)，起步快收尾慢。
    /// 不用 spring：弹簧有回弹，画布上没有，换算过来手感就对不上。
    static let duration: Double = 0.42
    static let motion: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: duration)
    static let fadeDuration: Double = 0.3
    static let fade: Animation = .easeInOut(duration: fadeDuration)

    /// 面板出现：从菜单栏那个小图标的位置放大成整张卡。
    /// 起点取 0.22，再小就看不出是从图标长出来的，只剩一团模糊在闪。
    static let appearScale: CGFloat = 0.22
    static let appearDuration: Double = 0.34
    static let appear: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: appearDuration)

    /// 转警示色的过渡。比交互动效慢一截：
    /// 这是状态变化不是操作反馈，太快会被当成闪烁。
    static let warnShift: Animation = .easeInOut(duration: 0.6)

    /// 二段重按的反馈：按下时整叠轻轻一沉，松开弹回
    static let pressScale: CGFloat = 0.972
    static let press: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.14)
    /// 沉下去停留多久再弹回。等于下沉动画跑完再多一点，手指才读得到这一下
    static let pressHold: Double = 0.18
    /// 弹回并跳去日历之后，隔这么久再收面板
    static let dismissDelay: Double = 0.22

    /// 面板四周留白，容纳玻璃投影的扩散，小于这个值投影会被窗口切掉
    static let panelInset: CGFloat = 32

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

/// 卡片材质：系统的 Liquid Glass。只面向 macOS 26 及以上。
/// 注意 glassEffect 只在背景画材质，不裁剪内容，
/// 所以调用方要自己先 clipShape，见 CountdownCard。
struct GlassCard: ViewModifier {
    var radius: CGFloat = DS.radius

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func glassCard(radius: CGFloat = DS.radius) -> some View {
        modifier(GlassCard(radius: radius))
    }
}
