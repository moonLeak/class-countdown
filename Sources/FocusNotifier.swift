import Foundation
import UserNotifications

/// 专注或休息自然结束时发系统通知，带默认提示音。
/// 第一次需要发的时候才向系统申请通知权限。
@MainActor
final class FocusNotifier {

    func notify(title: String, body: String) {
        // 开发用的模拟模式下不申请权限，免得弹窗卡住测试
        guard CalendarService.mockPath == nil else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { Self.post(title: title, body: body, center: center) }
                }
            case .authorized, .provisional:
                Self.post(title: title, body: body, center: center)
            default:
                break
            }
        }
    }

    private nonisolated static func post(title: String, body: String, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                         content: content, trigger: nil))
    }
}
