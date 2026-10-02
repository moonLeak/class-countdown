import SwiftUI
import AppKit

/// 一块透明的交互区，专门接鼠标。
///
/// 单击和二段重按必须由同一个 NSView 处理：
/// 压力事件只发给按下那一刻接住 mouseDown 的视图，
/// 交给 SwiftUI 的手势去抢 mouseDown，压力事件就永远到不了这里。
struct InteractionArea: NSViewRepresentable {
    var onClick: () -> Void
    var onForceClick: () -> Void
    /// 按压深度反馈：进入二段时回 true，松手回 false
    var onPressing: (Bool) -> Void
    /// 拖动整个窗口之后回调。和 onDrag 互斥：有 onDrag 时拖动是排序
    var onWindowMoved: (() -> Void)? = nil
    /// 垂直拖动：位移（向下为正）与是否结束。为 nil 时不响应拖动。
    var onDrag: ((CGFloat, Bool) -> Void)? = nil

    func makeNSView(context: Context) -> PressureView {
        let v = PressureView()
        v.onClick = onClick
        v.onForce = onForceClick
        v.onPressing = onPressing
        v.onDrag = onDrag
        v.onWindowMoved = onWindowMoved
        return v
    }

    func updateNSView(_ v: PressureView, context: Context) {
        v.onClick = onClick
        v.onForce = onForceClick
        v.onPressing = onPressing
        v.onDrag = onDrag
        v.onWindowMoved = onWindowMoved
    }
}

final class PressureView: NSView {

    var onClick: () -> Void = {}
    var onForce: () -> Void = {}
    var onPressing: (Bool) -> Void = { _ in }
    var onDrag: ((CGFloat, Bool) -> Void)?
    var onWindowMoved: (() -> Void)?

    private var forcedThisDrag = false
    private var dragStartY: CGFloat = 0
    private var dragStartX: CGFloat = 0
    private var dragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 不配置这个，触控板只会给一段的压力，stage 永远到不了 2
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: .primaryDefault)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        forcedThisDrag = false
        dragging = false
        dragStartY = event.locationInWindow.y
        dragStartX = event.locationInWindow.x
    }

    override func mouseDragged(with event: NSEvent) {
        guard !forcedThisDrag else { return }
        // 没有排序手势时，拖动就是移动整个窗口。performDrag 会接管到松手为止，
        // 松手事件被它吃掉，所以不会再当成一次单击
        if onDrag == nil, let moved = onWindowMoved, let window {
            let p = event.locationInWindow
            if hypot(p.x - dragStartX, p.y - dragStartY) > 4 {
                onPressing(false)
                window.performDrag(with: event)
                moved()
            }
            return
        }
        guard let onDrag else { return }
        // 窗口坐标 y 向上，界面坐标向下，取反
        let dy = dragStartY - event.locationInWindow.y
        if !dragging, abs(dy) > 4 { dragging = true }
        if dragging { onDrag(dy, false) }
    }

    override func mouseUp(with event: NSEvent) {
        if dragging {
            dragging = false
            onPressing(false)
            onDrag?(dragStartY - event.locationInWindow.y, true)
            return
        }
        onPressing(false)
        // 已经当成重按处理过就不再当单击，否则一次操作触发两件事
        guard !forcedThisDrag else { return }
        let p = convert(event.locationInWindow, from: nil)
        guard bounds.contains(p) else { return }
        onClick()
    }

    override func pressureChange(with event: NSEvent) {
        guard event.stage >= 2, !forcedThisDrag else { return }
        forcedThisDrag = true
        onPressing(true)
        onForce()
    }

}
