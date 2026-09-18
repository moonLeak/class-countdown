import SwiftUI
import AppKit

/// 一次滚动手势只前进一格，与滑动距离无关。
///
/// 没有走 NSViewRepresentable：那样的 NSView 要么参与命中测试、挡住上层的点击，
/// 要么退出命中测试、连滚轮事件也收不到。本地事件监听没有这个两难，
/// 再配合 onHover 限定范围，鼠标不在这叠卡片上就不响应。
struct ScrollStepModifier: ViewModifier {
    var enabled: Bool
    var onStep: (Int) -> Void

    @State private var hovering = false
    @State private var monitor: Any?
    /// 鼠标滚轮没有手势相位，用时间窗口兜底
    @State private var armed = true

    func body(content: Content) -> some View {
        content
            .onHover { hovering = $0 }
            .onAppear { install() }
            .onDisappear { remove() }
    }

    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard enabled, hovering else { return event }

            // 惯性阶段整段忽略：手指已经离开触控板，不该再算作新手势
            guard event.momentumPhase.isEmpty else { return nil }

            if event.phase.contains(.began) {
                fire(event)
            } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                armed = true
            } else if event.phase.isEmpty {
                // 传统鼠标滚轮：一格一格来，节流 150 毫秒
                if armed {
                    fire(event)
                    armed = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { armed = true }
                }
            }
            return nil   // 消费掉，别让它继续往下传
        }
    }

    private func remove() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    private func fire(_ event: NSEvent) {
        let dy = event.scrollingDeltaY
        guard abs(dy) > 0.5 else { return }
        // 向下滚把最前面那张送到队尾
        onStep(dy < 0 ? 1 : -1)
    }
}

extension View {
    func onScrollStep(enabled: Bool, perform: @escaping (Int) -> Void) -> some View {
        modifier(ScrollStepModifier(enabled: enabled, onStep: perform))
    }
}
