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
    /// 每张后卡露出的高度。文字在这一条里垂直居中，不再贴着卡片底边。
    /// 原值 40，按要求收到 2/3。
    static let peek: CGFloat = 21
    /// 展开后的卡间距
    static let gap: CGFloat = 10
    /// 每往后一层缩小的比例
    static let shrink: CGFloat = 0.04

    // MARK: 设置窗口
    static let settingsW: CGFloat = 540
    static let settingsH: CGFloat = 600
    static let settingsMinW: CGFloat = 420
    static let settingsMinH: CGFloat = 380
    /// 内容区最大宽，窗口更宽时居中
    static let settingsContentMaxW: CGFloat = 560

    // MARK: 玻璃质感
    /// 磨砂的五档，用 Apple 的系统材质，从薄到厚，模糊依次加重
    static let frostLevels: [Material] = [
        .ultraThinMaterial, .thinMaterial, .regularMaterial, .thickMaterial, .ultraThickMaterial
    ]
    /// 质感滑块的五个档位。完整范围 0 是最磨砂，1 是最通透，
    /// 只开放 0.6 到 1 这一段，再往磨砂那边卡片就接近不透明了
    static let clarityStops: [Double] = [0.6, 0.7, 0.8, 0.9, 1.0]
    static let cardClarityDefault: Double = 0.6
    /// clear 玻璃上垫的一层固定遮罩。Apple 对 clear 玻璃的建议做法：
    /// 深色外观垫黑，白字在亮背景上也读得出来；浅色外观垫白，黑字在暗背景上也读得出来。
    /// 浓度固定，不随质感滑块变，所以滑块只改模糊，不改明暗
    static let clearVeilDark: Double = 0.35
    static let clearVeilLight: Double = 0.30

    // MARK: 浮窗 QuickPill
    static let pillH: CGFloat = 34
    static let pillGap: CGFloat = 12
    /// 展开后整叠下移量 = pillH + pillGap
    static let stackShift: CGFloat = pillH + pillGap
    static let pillHit: CGFloat = 30
    static let pillIcon: CGFloat = 15
    static let pillChevron: CGFloat = 17
    /// 收起态的位置：卡顶向下 14，距卡右边 18
    static let pillInsetTop: CGFloat = 14
    static let pillInsetRight: CGFloat = 18
    /// 浮窗阴影三档：静止、鼠标在卡叠上、悬停展开
    static let pillShadowRest: Double = 0.05
    static let pillShadowHover: Double = 0.14
    static let pillShadowActive: Double = 0.22
    /// 图标悬停时底下小圆的浓度与阴影
    static let pillIconHoverFill: Double = 0.12
    static let pillIconHoverShadow: Double = 0.18
    static let pillWidth: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.3)

    // MARK: 统计窗口
    static let statsW: CGFloat = 560
    static let statsH: CGFloat = 660
    static let statsPad: CGFloat = 28
    /// 柱宽 = 槽宽 × 0.66
    static let statsBarRatio: CGFloat = 0.66
    static let bar: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.38)
    static let toggle: Animation = .easeInOut(duration: 0.2)
    static let fNumeral: CGFloat = 60

    // MARK: Flow 卡底行
    /// 底行中心线距卡片底边，按钮、四个点、图标共用
    static let rowCenter: CGFloat = 28
    /// 按钮距卡片右、下边的距离 = 圆角 28 - 按钮半径 16
    static let insetConcentric: CGFloat = 12
    static let buttonW: CGFloat = 92
    static let skipW: CGFloat = 64
    static let buttonH: CGFloat = 32
    static let buttonGap: CGFloat = 8
    static let dot: CGFloat = 8
    static let dotCurrent: CGFloat = 26
    static let dotGap: CGFloat = 6
    static let dotDone: Double = 0.85
    static let dotNow: Double = 0.35
    static let dotTodo: Double = 0.22
    static let iconHit: CGFloat = 28
    /// 点组与图标、图标与图标之间的视觉间距
    static let iconGap: CGFloat = 13
    static let fButton: CGFloat = 12
    static let primaryAlpha: Double = 0.55
    static let ghostAlpha: Double = 0.12

    // MARK: 菜单栏徽标
    static let badgeH: CGFloat = 20
    static let badgeRadius: CGFloat = 6
    static let badgePadX: CGFloat = 8
    static let badgeFont: CGFloat = 13
    /// 底色是状态色 40%，进度填充 90%；浅色菜单栏底色提高一档
    static let badgeBaseAlpha: Double = 0.40
    static let badgeBaseAlphaLight: Double = 0.55
    static let badgeFillAlpha: Double = 0.90

    // MARK: 拖动排序
    /// 拿起的卡：放大 1.02，阴影 55% 的浓度，层级 60
    static let dragScale: CGFloat = 1.02
    static let dragShadow: Double = 0.35
    static let dragZ: Double = 60

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
    static let l1 = SwiftUI.Color.primary            // 倒计时数字
    static let l2 = SwiftUI.Color.secondary          // 日程名称
    static let l3 = SwiftUI.Color.secondary.opacity(0.78)   // 时间与倒计时

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
    static let warn = SwiftUI.Color(red: 1.0, green: 0.624, blue: 0.039)   // #FF9F0A

    // MARK: 状态色
    /// 命名空间 DS.Color。在 DS 内部写 Color 指的是它，要用 SwiftUI 的写 SwiftUI.Color。
    enum Color {
        /// 专注与休息，统一用绿色
        static let focus = SwiftUI.Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)   // #30D158
        /// 退出等破坏性操作
        static let danger = SwiftUI.Color(red: 1.0, green: 69 / 255, blue: 58 / 255)       // #FF453A
        /// 日历没有颜色时的兜底
        static let eventDefault = SwiftUI.Color(red: 10 / 255, green: 132 / 255, blue: 1.0) // #0A84FF
        /// 统计柱渐变
        static let barTop = SwiftUI.Color(red: 122 / 255, green: 214 / 255, blue: 168 / 255)
        static let barBottom = SwiftUI.Color(red: 52 / 255, green: 150 / 255, blue: 112 / 255)
        /// 变化徽章：涨与跌
        static let up = SwiftUI.Color(red: 0x7B / 255, green: 0xE0 / 255, blue: 0xAD / 255)
        static let down = SwiftUI.Color(red: 1.0, green: 0x9A / 255, blue: 0x8F / 255)
    }

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

/// 卡片材质：系统的 Liquid Glass。
///
/// 最底下是 clear 玻璃，负责边缘折射和高光，本身几乎不模糊，是“光滑”的那一端。
/// 设置里的“玻璃质感”滑块往磨砂那边推，就在玻璃上叠系统材质，
/// 从超薄到超厚五档，相邻两档交叉淡入，模糊程度连续变化，亮度不跟着变。
/// 明暗交给外观模式（跟随系统、浅色、深色），材质会自己适配。
/// 注意 glassEffect 只在背景画材质，不裁剪内容，
/// 所以调用方要自己先 clipShape，见 EventCard。
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.cardClarity) private var clarity
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background { frost }
            .glassEffect(Glass.clear.interactive(), in: shape)
    }

    private var frost: some View {
        // 磨砂程度 0 到 1，再映射到五档材质之间的位置 0 到 5
        let f = 1 - min(max(clarity, 0), 1)
        let p = f * Double(DS.frostLevels.count)
        return ZStack {
            shape.fill(scheme == .dark
                       ? SwiftUI.Color.black.opacity(DS.clearVeilDark)
                       : SwiftUI.Color.white.opacity(DS.clearVeilLight))
            ForEach(DS.frostLevels.indices, id: \.self) { k in
                // 第 k 档在 p = k + 1 时满，向两边线性淡出
                shape.fill(DS.frostLevels[k])
                    .opacity(max(0, 1 - abs(p - Double(k + 1))))
            }
        }
    }
}

/// 卡片透明度，0 到 1，越大越透。由卡叠在根上放进环境，里面所有玻璃共用
private struct CardClarityKey: EnvironmentKey {
    static let defaultValue: Double = 0.5
}

extension EnvironmentValues {
    var cardClarity: Double {
        get { self[CardClarityKey.self] }
        set { self[CardClarityKey.self] = newValue }
    }
}

extension View {
    func glassCard(radius: CGFloat = DS.radius) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }

    func glassCapsule() -> some View {
        modifier(GlassSurface(shape: Capsule()))
    }
}
