import SwiftUI

/// 系统级浮窗。
/// 收起时是顶牌右上角的一个小圆（向左箭头），鼠标移上去向左展开成图标条；
/// 整叠展开后移到整叠右上角，常显图标条。
struct QuickPill: View {

    /// 整叠是否展开
    let expanded: Bool
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
        .glassEffect(.regular, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 7, y: 4)
        .contentShape(Capsule())
        .onHover { h in withAnimation(widthAnimation) { hovering = h } }
        .animation(widthAnimation, value: open)
    }

    private func pillButton(_ symbol: String, _ label: String,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: DS.pillIcon, weight: .regular))
                .foregroundStyle(DS.l1)
                .frame(width: DS.pillHit, height: DS.pillHit)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(label))
    }
}
