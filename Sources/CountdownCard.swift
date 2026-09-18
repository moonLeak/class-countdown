import SwiftUI

/// 单张日程卡。340×160，内部只有信息，一个控件都没有。
/// 操作入口在整叠的右键菜单上，见 CardStack。
struct CountdownCard: View {

    let event: ScheduleModel.EventSnapshot
    let now: Date
    let progress: Double
    let warning: Bool
    /// 倒计时与底部行在收起状态下要不要显示。
    /// 被压住的卡只留名称，否则半透明玻璃会把下层的大数字透上来。
    let showsDetail: Bool
    /// 被压住时名称移到左下角，因为能看见的只有底边那一条
    let titleAtBottom: Bool
    /// 待开始状态下数字上方那行小字
    var subtitle: String? = nil
    /// 倒计时文本，由外部算好传进来
    let countdown: String

    private var barColor: Color { warning ? DS.warn : event.calendarColor }
    private var fillTop: Double { warning ? DS.warnFillTop : DS.fillTop }
    private var fillBottom: Double { warning ? DS.warnFillBottom : DS.fillBottom }
    private var edgeAlpha: Double { warning ? DS.warnEdgeAlpha : DS.edgeAlpha }

    var body: some View {
        ZStack(alignment: .topLeading) {
            progressLayer
            content
        }
        .frame(width: DS.cardW, height: DS.cardH)
        // clipShape 套在整个 ZStack 外面：进度条走到边缘时不会露出直角
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(event.title)，\(countdown)"))
    }

    // MARK: 背景进度条

    private var progressLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width * progress
            ZStack(alignment: .leading) {
                Color.clear
                LinearGradient(
                    colors: [barColor.opacity(fillTop), barColor.opacity(fillBottom)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: w)
                // 右缘那道亮线是 Liquid Glass 的折射感来源
                Rectangle()
                    .fill(barColor.opacity(edgeAlpha))
                    .frame(width: 1)
                    .offset(x: w)
            }
            .animation(DS.motion, value: progress)
            .animation(DS.fade, value: warning)
        }
    }

    // MARK: 内容

    private var content: some View {
        ZStack(alignment: .topLeading) {
            // 名称：展开时在左上，被压住时在左下并带上百分比
            VStack {
                if titleAtBottom { Spacer() }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(event.title)
                        .font(.system(size: DS.fBody, weight: DS.wBody))
                        .foregroundStyle(DS.l2)
                        .lineLimit(1)
                    if titleAtBottom {
                        Spacer()
                        Text(TimeFormat.percent(progress))
                            .font(.system(size: DS.fCaption, weight: DS.wCaption))
                            .foregroundStyle(DS.l3)
                            .monospacedDigit()
                    }
                }
                if !titleAtBottom { Spacer() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // 倒计时：绝对居中于卡片高度，所以它的中心就是卡片的中心
            if showsDetail {
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
            }

            // 底部：起止时间与百分比同一基线
            if showsDetail {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Text(TimeFormat.range(event.start, event.end))
                            .font(.system(size: DS.fCaption, weight: DS.wCaption))
                            .foregroundStyle(DS.l3)
                            .monospacedDigit()
                        Spacer()
                        Text(TimeFormat.percent(progress))
                            .font(.system(size: DS.fCaption, weight: DS.wCaption))
                            .foregroundStyle(DS.l3)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.horizontal, DS.padX)
        .padding(.vertical, DS.padY)
    }
}
