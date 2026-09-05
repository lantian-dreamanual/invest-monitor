import Foundation
import AppKit
import UserNotifications

/// 本地通知发送器
/// 优先使用 UserNotifications.framework；若 UN 通知无法显示（如 adhoc 签名开发阶段），
/// 自动回退到 osascript display notification 确保通知可见。
final class AlertNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertNotifier()

    /// 通知点击回调：传递规则 ID
    var onNotificationTap: ((String) -> Void)?

    /// UN 通知是否可用（授权通过且能弹 banner）
    /// 首次发通知后通过 getDeliveredNotifications 验证
    private var unAvailable: Bool?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// 请求通知授权（alert + sound）
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                // 授权后发一条静默测试通知，检查是否真的能弹 banner
                self.checkUNAvailability()
            }
        }
    }

    /// 检查 UNUserNotificationCenter 是否真的能弹 banner
    /// 发一条测试通知，3 秒后检查 deliveredNotifications，有记录则说明可用
    private func checkUNAvailability() {
        let testContent = UNMutableNotificationContent()
        testContent.title = ""
        testContent.body = ""
        testContent.sound = nil
        let req = UNNotificationRequest(
            identifier: "un-availability-check",
            content: testContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        UNUserNotificationCenter.current().add(req) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                    let found = notifications.contains { $0.request.identifier == "un-availability-check" }
                    self.unAvailable = found
                    if found {
                        // 清除测试通知
                        UNUserNotificationCenter.current().removeDeliveredNotifications(
                            withIdentifiers: ["un-availability-check"]
                        )
                    }
                }
            }
        }
    }

    /// 发送预警通知
    func sendNotification(rule: AlertRule, currentValue: Double) {
        let dirText = rule.direction == .above ? "涨到" : "跌到"
        let valueText = formatValue(rule: rule, value: currentValue)
        let thresholdText = formatThreshold(rule: rule)
        let body = "\(rule.targetName) 已\(dirText) \(valueText)（阈值 \(thresholdText)）\n\(rule.label)"
        let title = "\(rule.targetName) 到价提醒"

        // 先尝试 UNUserNotificationCenter
        if unAvailable != false {
            sendViaUN(rule: rule, title: title, body: body)
        }

        // 如果 UN 确认不可用，或作为双保险，同时用 osascript
        if unAvailable == false {
            sendViaOSA(title: title, body: body)
        }

        // 首次发送：UN 状态未知时双发（UN + osascript），确保用户一定能看到
        if unAvailable == nil {
            sendViaOSA(title: title, body: body)
        }
    }

    /// 通过 UNUserNotificationCenter 发送
    private func sendViaUN(rule: AlertRule, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: rule.id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("UN 通知发送失败: \(error.localizedDescription)")
            }
        }
    }

    /// 通过 osascript 发送（fallback）
    private func sendViaOSA(title: String, body: String) {
        // 转义双引号
        let escTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"\(escBody)\" with title \"\(escTitle)\" sound name \"default\""
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        try? task.run()
    }

    /// 格式化当前值
    private func formatValue(rule: AlertRule, value: Double) -> String {
        switch rule.targetType {
        case .goldCNY:
            return String(format: "%.2f", value)
        case .sector:
            return String(format: "%.2f%%", value)
        case .fund:
            if rule.fundMetric == .changePct {
                return String(format: "%.2f%%", value)
            }
            return String(format: "%.3f", value)
        }
    }

    /// 格式化阈值
    private func formatThreshold(rule: AlertRule) -> String {
        switch rule.targetType {
        case .goldCNY:
            return String(format: "%.2f", rule.threshold)
        case .sector:
            return String(format: "%.2f%%", rule.threshold)
        case .fund:
            if rule.fundMetric == .changePct {
                return String(format: "%.2f%%", rule.threshold)
            }
            return String(format: "%.3f", rule.threshold)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 始终显示通知，即使 App 在前台
        completionHandler([.banner, .sound])
    }

    /// 用户点击通知时调用：提取规则 ID，回调打开面板并切换到对应 Tab
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let ruleId = response.notification.request.identifier
        onNotificationTap?(ruleId)
        completionHandler()
    }
}
