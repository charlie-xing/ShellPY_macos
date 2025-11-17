//
//  PluginHostLauncher.swift
//  Squirrel
//
//  Manages launching and communication with SquirrelPluginHost helper app
//

import Foundation
import AppKit

final class PluginHostLauncher: NSObject {
    private var helperAppProcess: Process?
    private var isHelperRunning = false

    override init() {
        super.init()
    }

    /// 确保 Helper 应用正在运行（如果未运行则启动）
    /// 如果已经运行，则不做任何操作（让 Helper 自己的热键处理逻辑接管）
    func ensureHelperRunning() {
        // 检查 helper app 是否已经在运行
        let runningApps = NSWorkspace.shared.runningApplications
        if let helperApp = runningApps.first(where: { $0.bundleIdentifier == "im.rime.plugin.host" }) {
            print("PluginHostLauncher: Helper app is already running, letting it handle the hotkey")
            isHelperRunning = true
            return
        }

        print("PluginHostLauncher: Helper app not running, launching...")

        // 获取当前活动的应用（用于传递给 Helper）
        let currentApp = NSWorkspace.shared.frontmostApplication
        let sourceAppName = currentApp?.localizedName ?? "Unknown"
        let sourceAppBundleId = currentApp?.bundleIdentifier ?? ""
        let sourceAppProcessId = currentApp?.processIdentifier ?? -1

        // Get path to helper app
        guard let helperPath = getHelperAppPath() else {
            print("PluginHostLauncher: Failed to find helper app")
            showErrorAlert("Helper app not found")
            return
        }

        // Check if helper exists
        guard FileManager.default.fileExists(atPath: helperPath) else {
            print("PluginHostLauncher: Helper app does not exist at path")
            showErrorAlert("Helper app not installed")
            return
        }

        // Launch helper app
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false

        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: helperPath),
            configuration: configuration
        ) { [weak self] app, error in
            if let error = error {
                print("PluginHostLauncher: Failed to launch helper: \(error)")
                self?.showErrorAlert("Failed to launch helper app: \(error.localizedDescription)")
            } else {
                print("PluginHostLauncher: Helper app launched successfully")
                self?.isHelperRunning = true

                // 确保应用激活
                if let app = app {
                    app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                }

                // 延迟发送源应用信息
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let userInfo: [String: Any] = [
                        "sourceAppName": sourceAppName,
                        "sourceAppBundleId": sourceAppBundleId,
                        "sourceAppProcessId": sourceAppProcessId
                    ]

                    DistributedNotificationCenter.default().post(
                        name: .init("SetSourceApplication"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            }
        }
    }

    /// Launch or show the SquirrelPluginHost helper application
    /// 逻辑：
    /// 1. 如果 helper app 未启动 -> 启动并显示窗口
    /// 2. 如果 helper app 已启动:
    ///    a. 窗口在前台且是 key window -> 隐藏窗口
    ///    b. 其他情况 -> 显示并激活窗口
    func launchHelperApp() {
        // 获取当前活动的应用（在切换到 helper app 之前）
        // 注意: 当没有窗口选中时(如点击桌面), frontmostApplication 可能返回 Finder
        let currentApp = NSWorkspace.shared.frontmostApplication
        let sourceAppName = currentApp?.localizedName ?? "Unknown"
        let sourceAppBundleId = currentApp?.bundleIdentifier ?? ""
        let sourceAppProcessId = currentApp?.processIdentifier ?? -1

        print("PluginHostLauncher: Triggered from app: \(sourceAppName) (\(sourceAppBundleId)), PID: \(sourceAppProcessId)")

        // 先检查 helper app 是否已经在运行
        let runningApps = NSWorkspace.shared.runningApplications
        if let helperApp = runningApps.first(where: { $0.bundleIdentifier == "im.rime.plugin.host" }) {
            print("PluginHostLauncher: Helper app is already running")

            // 关键优化: 在激活前先判断 helper app 当前是否在前台
            // 如果 helper app 是当前活跃应用，说明窗口在前台，应该隐藏
            // 否则，应该激活并显示窗口
            let shouldHide = helperApp.isActive

            print("PluginHostLauncher: Helper app isActive=\(helperApp.isActive), shouldHide=\(shouldHide)")

            if shouldHide {
                // 窗口当前在前台，发送隐藏通知
                print("PluginHostLauncher: Window is in foreground, sending hide notification")
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "sourceAppName": sourceAppName,
                        "sourceAppBundleId": sourceAppBundleId,
                        "sourceAppProcessId": sourceAppProcessId,
                        "shouldHide": true
                    ]

                    DistributedNotificationCenter.default().post(
                        name: .init("TogglePluginHostWindow"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            } else {
                // 窗口不在前台（可能隐藏或在后台），先激活应用再发送显示通知
                print("PluginHostLauncher: Window is hidden or in background, activating and showing")
                // 使用更强制的激活方式,确保即使在没有前台应用时也能激活
                helperApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

                // 给一点时间让应用激活
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let userInfo: [String: Any] = [
                        "sourceAppName": sourceAppName,
                        "sourceAppBundleId": sourceAppBundleId,
                        "sourceAppProcessId": sourceAppProcessId,
                        "shouldHide": false
                    ]

                    DistributedNotificationCenter.default().post(
                        name: .init("TogglePluginHostWindow"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            }

            isHelperRunning = true
            return
        }

        print("PluginHostLauncher: Helper app not running, launching...")

        // Get path to helper app
        guard let helperPath = getHelperAppPath() else {
            print("PluginHostLauncher: Failed to find helper app")
            showErrorAlert("Helper app not found")
            return
        }

        print("PluginHostLauncher: Helper app path: \(helperPath)")

        // Check if helper exists
        guard FileManager.default.fileExists(atPath: helperPath) else {
            print("PluginHostLauncher: Helper app does not exist at path")
            showErrorAlert("Helper app not installed")
            return
        }

        // Launch helper app using NSWorkspace
        // Helper app 会在 applicationDidFinishLaunching 中自动显示窗口
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // 确保应用启动后立即成为活跃应用,即使没有其他窗口选中
        configuration.addsToRecentItems = false

        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: helperPath),
            configuration: configuration
        ) { [weak self] app, error in
            if let error = error {
                print("PluginHostLauncher: Failed to launch helper: \(error)")
                self?.showErrorAlert("Failed to launch helper app: \(error.localizedDescription)")
            } else {
                print("PluginHostLauncher: Helper app launched successfully, window will be shown automatically")
                self?.isHelperRunning = true

                // 确保应用激活 - 在某些情况下 configuration.activates 可能不够
                if let app = app {
                    app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                }

                // 延迟发送源应用信息，确保 helper app 已完成初始化
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let userInfo: [String: Any] = [
                        "sourceAppName": sourceAppName,
                        "sourceAppBundleId": sourceAppBundleId,
                        "sourceAppProcessId": sourceAppProcessId
                    ]

                    DistributedNotificationCenter.default().post(
                        name: .init("SetSourceApplication"),
                        object: nil,
                        userInfo: userInfo
                    )
                }
            }
        }
    }

    /// Terminate the helper app
    func terminateHelperApp() {
        guard isHelperRunning else { return }

        print("PluginHostLauncher: Terminating helper app...")

        // Find running helper app
        let runningApps = NSWorkspace.shared.runningApplications
        if let helperApp = runningApps.first(where: { $0.bundleIdentifier == "im.rime.plugin.host" }) {
            helperApp.terminate()
            isHelperRunning = false
            print("PluginHostLauncher: Helper app terminated")
        }
    }

    /// Bring helper app to front if it's running
    private func bringHelperToFront() {
        let runningApps = NSWorkspace.shared.runningApplications
        if let helperApp = runningApps.first(where: { $0.bundleIdentifier == "im.rime.plugin.host" }) {
            helperApp.activate(options: .activateIgnoringOtherApps)
        }
    }

    /// Get the path to the helper app
    private func getHelperAppPath() -> String? {
        // Helper app should be at: Squirrel.app/Contents/Library/LoginItems/SquirrelPluginHost.app
        let mainBundleURL = Bundle.main.bundleURL

        let helperURL = mainBundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LoginItems")
            .appendingPathComponent("SquirrelPluginHost.app")

        return helperURL.path
    }

    /// Show error alert
    private func showErrorAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "AI Plugin Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    deinit {
        terminateHelperApp()
    }
}
