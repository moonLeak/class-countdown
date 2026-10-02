import SwiftUI

/// 系统级浮窗。
/// 收起时是顶牌右上角的一个小圆（向左箭头），鼠标移上去向左展开成图标条；
/// 整叠展开后移到整叠右上角，常显图标条。
struct QuickPill: View {

    /// 整叠是否展开
    let expanded: Bool
    /// 鼠标是否在卡叠范围内。不在时浮窗只留很淡的阴影，不抢眼
    let stackHovered: Bool
    let onFocusTap: () -> Void
    let onStatsTap: () -> Void
    let onCalendarTap: () -> Void
    let onSettingsTap: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var widthAnimation: Animation { reduceMotion ? .easeInOut(duration: 0.1) : DS.pillWidth }

    private var open: Bool { expanded || hovering }
    private var barWidth: CGFloat { CGFloat(4) * DS.pillHit + 8 }

    var body: some View {
        ZStack(alignment: .trailing) {
            // 图标条：先画满宽，用裁剪和透明度表现展开，宽度变化平滑
            HStack(spacing: 0) {
                pillButton("scope", L("pill.focus"), onFocusTap)
                pillButton("chart.bar", L("flow.a11y.stats"), onStatsTap)
                pillButton("calendar", L("menu.openCalendar"), onCalendarTap)
                pillButton("gearshape", L("menu.settings"), onSettingsTap)
            }
            .frame(width: barWidth, alignment: .trailing)
            .opacity(open ? 1 : 0)

            Image(systemName: "chevron.left")
                .font(.system(size: DS.pillChevron, weight: .semibold))
                .foregroundStyle(DS.l1)
                .frame(width: DS.pillH, height: DS.pillH)
                .opacity(open ? 0 : 1)
        }
        .frame(width: open ? barWidth : DS.pillH, height: DS.pillH, alignment: .trailing)
        .clipShape(Capsule())
        .glassCapsule()
        .shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, y: shadow.y)
        .animation(DS.fade, value: stackHovered)
        .contentShape(Capsule())
        .onHover { h in withAnimation(widthAnimation) { hovering = h } }
        .animation(widthAnimation, value: open)
    }

    /// 三档阴影：鼠标不在卡叠上时很淡；在卡叠上时正常；悬停在浮窗上展开时最明显
    private var shadow: (opacity: Double, radius: CGFloat, y: CGFloat) {
        if hovering { return (DS.pillShadowActive, 7, 4) }
        if stackHovered || expanded { return (DS.pillShadowHover, 5, 3) }
        return (DS.pillShadowRest, 3, 1)
    }

    private func pillButton(_ symbol: String, _ label: String,
                            _ action: @escaping () -> Void) -> some View {
        PillIcon(symbol: symbol, label: label, action: action)
    }
}

/// 浮窗里的一个图标。鼠标移上去时底下浮起一个小圆，带一点阴影，强调当前这个
private struct PillIcon: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: DS.pillIcon, weight: hovered ? .semibold : .regular))
                .foregroundStyle(DS.l1)
                .frame(width: DS.pillHit, height: DS.pillHit)
                .background(
                    Circle()
                        .fill(SwiftUI.Color.primary.opacity(hovered ? DS.pillIconHoverFill : 0))
                        .shadow(color: .black.opacity(hovered ? DS.pillIconHoverShadow : 0),
                                radius: 3, y: 1)
                )
                .scaleEffect(hovered ? 1.06 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .onHover { h in withAnimation(DS.toggle) { hovered = h } }
        .accessibilityLabel(Text(label))
    }
}
