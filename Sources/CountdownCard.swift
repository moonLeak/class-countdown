import SwiftUI

/// 单张日程卡。340×160，内部只有信息，一个控件都没有。
struct CountdownCard: View {

    let event: ScheduleModel.EventSnapshot
    let progress: Double
    let warning: Bool
    let countdown: String
    var subtitle: String? = nil

    /// 完整程度：1 是完整一张卡，0 是被压在下面只露出底边。
    /// 用连续值而不是布尔，三处文字才能一起淡进淡出；
    /// 布尔会让 SwiftUI 直接增删视图，那就是一跳一跳的来源。
    let fullness: Double

    /// 这张卡收起时被 scaleEffect 缩成的比例（1 - shrink * 层号）。
    /// 露出的那一条在缩放后高度恰好是 peek，换算回卡片自身坐标要除以它，
    /// 文字才能在肉眼看到的那一条里居中。
    var collapsedScale: CGFloat = 1

    var body: some View {
        progressLayer
            .frame(width: DS.cardW, height: DS.cardH)
            // overlay 不会被带 padding 的内容撑大
            .overlay { content }
            // 先裁剪再上玻璃：glassEffect 只画背景，不管内容越界
            .clipShape(DS.cardShape)
            .glassCard()
            // 收起态的名称与倒计时：放在 padding 之外的底部条里，条高 = 露出高度，垂直居中
            .overlay(alignment: .bottom) {
                titleRow(showsCountdown: true)
                    .padding(.horizontal, DS.padX)
                    .frame(width: DS.cardW, height: DS.peek / collapsedScale, alignment: .center)
                    .opacity(1 - fullness)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(event.title)，\(countdown)"))
    }

    /// 常态与警示态各画一层，靠透明度此消彼长。
    ///
    /// 不直接换 LinearGradient 的颜色：渐变的插值在两个色相之间会经过一段发灰的中间色，
    /// 蓝到橙尤其明显。两层叠着交叉淡入淡出，中途看到的是两种颜色叠加，不会脏。
    private var progressLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width * progress
            ZStack(alignment: .leading) {
                Color.clear
                bar(color: event.calendarColor,
                    top: DS.fillTop, bottom: DS.fillBottom,
                    edge: DS.edgeAlpha, width: w)
                    .opacity(warning ? 0 : 1)
                bar(color: DS.warn,
                    top: DS.warnFillTop, bottom: DS.warnFillBottom,
                    edge: DS.warnEdgeAlpha, width: w)
                    .opacity(warning ? 1 : 0)
            }
        }
        // 只在 warning 翻转时animate，进度条每秒的增长不受影响
        .animation(DS.warnShift, value: warning)
    }

    private func bar(color: Color, top: Double, bottom: Double,
                     edge: Double, width w: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [color.opacity(top), color.opacity(bottom)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: w)
            Rectangle()
                .fill(color.opacity(edge))
                .frame(width: 1)
                .offset(x: w)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var content: some View {
        ZStack {
            // 名称有上下两份，靠透明度此消彼长，位置切换才是渐变而不是跳变
            titleRow(showsCountdown: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(fullness)

            // 倒计时垂直居中于卡片，所以它的中心就是卡片的中心
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: DS.fCaption, weight: DS.wCaption))
                        .foregroundStyle(DS.l3)
                }
                Text(countdown)
                    .font(.system(size: DS.fDisplay, weight: DS.wDisplay))
                    .monospacedDigit()
                    .foregroundStyle(DS.l1)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .opacity(fullness)

            // 底部：起止时间
            HStack(spacing: 10) {
                Text(TimeFormat.range(event.start, event.end))
                    .font(.system(size: DS.fCaption, weight: DS.wCaption))
                    .foregroundStyle(DS.l3)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .opacity(fullness)
        }
        .padding(.horizontal, DS.padX)
        .padding(.vertical, DS.padY)
    }

    private func titleRow(showsCountdown: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(event.title)
                .font(.system(size: DS.fBody, weight: DS.wBody))
                .foregroundStyle(DS.l2)
                .lineLimit(1)
            if showsCountdown {
                Spacer(minLength: 0)
                Text(countdown)
                    .font(.system(size: DS.fCaption, weight: DS.wCaption))
                    .foregroundStyle(DS.l3)
                    .monospacedDigit()
            }
        }
    }
}
