import SwiftUI

/// 卡片里的胶囊按钮，用系统的玻璃：primary 带专注绿的 tint，ghost 是无色玻璃。
/// 同一行里的两个按钮要放进 GlassEffectContainer，靠得近时玻璃会自然融合。
struct GlassButton: View {
    enum Variant { case primary, ghost }

    let title: String
    var symbol: String? = nil
    var width: CGFloat = DS.buttonW
    var variant: Variant = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: DS.fButton, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: DS.fButton, weight: .semibold))
            }
            .foregroundStyle(variant == .primary ? SwiftUI.Color.white : DS.l1)
            .frame(width: width, height: DS.buttonH)
            .glassEffect(
                variant == .primary
                    ? Glass.regular.tint(DS.Color.focus).interactive()
                    : Glass.regular.interactive(),
                in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 只有符号的小按钮，热区 28
struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(hovering ? DS.l1 : DS.l3)
                .frame(width: DS.iconHit, height: DS.iconHit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.fade) { hovering = h } }
        .accessibilityLabel(Text(label))
    }
}

/// 按下时轻轻缩一下
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(DS.press, value: configuration.isPressed)
    }
}

/// 一轮四节的圆点：做完的实心，当前这节拉长成胶囊，没到的淡点
struct CycleDots: View {
    let total: Int
    let done: Int
    /// 进行中才有当前节
    let currentIndex: Int?

    var body: some View {
        HStack(spacing: DS.dotGap) {
            ForEach(0..<total, id: \.self) { i in
                let isCurrent = (currentIndex == i)
                Capsule()
                    .fill(SwiftUI.Color.primary.opacity(
                        isCurrent ? DS.dotNow : (i < done ? DS.dotDone : DS.dotTodo)))
                    .frame(width: isCurrent ? DS.dotCurrent : DS.dot, height: DS.dot)
            }
        }
        .animation(DS.fade, value: currentIndex)
        .animation(DS.fade, value: done)
    }
}
