import SwiftUI

/// 专注卡。与 EventCard 共用骨架：标题、大数字、进度填充、底行。
/// 专注、休息、长休息三种变体由 FocusEngine 的状态决定。
struct FlowCard: View {

    @ObservedObject var focus: FocusController
    let now: Date
    /// 完整程度，含义同 EventCard
    let fullness: Double
    var collapsedScale: CGFloat = 1
    /// 盖在内容上、控件下面的交互区，由卡片叠传入
    let interaction: AnyView
    let onStatsTap: () -> Void
    /// 浮窗的定位图标点过之后闪一下
    var highlight = false

    private var engine: FocusEngine { focus.engine }
    private var title: String { engine.isBreak ? L(focus.breakTitleKey) : L("flow.title.focus") }
    private var countdown: String { TimeFormat.countdown(engine.remaining(now: now)) }

    var body: some View {
        progressLayer
            .frame(width: DS.cardW, height: DS.cardH)
            .overlay { content }
            .clipShape(DS.cardShape)
            .glassCard(tint: engine.state == .idle ? nil : DS.Color.focus.opacity(DS.glassTint))
            // 收起态的名称与倒计时，和 EventCard 的露出条同一套规格
            .overlay(alignment: .bottom) {
                strip
                    .padding(.horizontal, DS.padX)
                    .frame(width: DS.cardW, height: DS.peek / collapsedScale, alignment: .center)
                    .opacity(1 - fullness)
            }
            .overlay { interaction }
            .overlay { controls }
            .overlay {
                DS.cardShape
                    .stroke(DS.Color.focus, lineWidth: 2)
                    .opacity(highlight ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .contain)
    }

    // MARK: 层

    private var progressLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width * engine.progress(now: now)
            ZStack(alignment: .leading) {
                Color.clear
                ProgressFill.bar(color: DS.Color.focus,
                                 top: DS.fillTop, bottom: DS.fillBottom,
                                 edge: DS.edgeAlpha, width: w)
            }
        }
    }

    private var content: some View {
        ZStack {
            Text(title)
                .font(.system(size: DS.fBody, weight: DS.wBody))
                .foregroundStyle(DS.l2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(fullness)
            Text(countdown)
                .font(.system(size: DS.fDisplay, weight: DS.wDisplay))
                .monospacedDigit()
                .foregroundStyle(DS.l1)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .opacity(fullness)
        }
        .padding(.horizontal, DS.padX)
        .padding(.vertical, DS.padY)
    }

    private var strip: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.system(size: DS.fBody, weight: DS.wBody))
                .foregroundStyle(DS.l2)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(countdown)
                .font(.system(size: DS.fCaption, weight: DS.wCaption))
                .foregroundStyle(DS.l3)
                .monospacedDigit()
        }
    }

    // MARK: 底行

    private var controls: some View {
        VStack {
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 0) {
                CycleDots(total: engine.config.cyclesPerRound,
                          done: engine.completedInRound,
                          currentIndex: isWorking ? engine.completedInRound : nil)
                IconButton(symbol: "arrow.counterclockwise", label: L("flow.a11y.reset")) {
                    focus.reset()
                }
                .padding(.leading, DS.iconGap - (DS.iconHit - 13) / 2)
                IconButton(symbol: "chart.bar", label: L("flow.a11y.stats"), action: onStatsTap)
                Spacer(minLength: 0)
                buttons
            }
            .padding(.leading, DS.padX)
            .padding(.trailing, DS.insetConcentric)
            .frame(height: DS.rowCenter * 2)
        }
        .opacity(fullness)
        // 收起时整行不接事件，点击交给下面的交互区去展开卡叠
        .allowsHitTesting(fullness > 0.99)
    }

    private var isWorking: Bool { engine.state == .focusing || engine.state == .focusPaused }

    @ViewBuilder
    private var buttons: some View {
        GlassEffectContainer(spacing: DS.buttonGap) {
          HStack(spacing: DS.buttonGap) {
            switch engine.state {
            case .idle:
                GlassButton(title: L("flow.button.start"), symbol: "play.fill") { focus.primaryAction() }
            case .focusing:
                GlassButton(title: L("flow.button.pause"), symbol: "pause.fill", variant: .ghost) {
                    focus.primaryAction()
                }
            case .focusPaused:
                GlassButton(title: L("flow.button.resume"), symbol: "play.fill") { focus.primaryAction() }
            case .breakWaiting, .longBreakWaiting:
                GlassButton(title: L("flow.button.skip"), width: DS.skipW, variant: .ghost) {
                    focus.skipBreak()
                }
                GlassButton(title: L("flow.button.start"), symbol: "play.fill") { focus.primaryAction() }
            case .breaking, .longBreaking:
                GlassButton(title: L("flow.button.skip"), variant: .ghost) { focus.skipBreak() }
            }
          }
        }
    }
}
