import SwiftUI
import AppKit

@main
struct InvestMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏 App：隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        // 请求通知授权
        AlertNotifier.shared.requestPermission()

        controller = MenuBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理
    }
}
