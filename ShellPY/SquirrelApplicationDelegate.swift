//
//  SquirrelApplicationDelegate.swift
//  Squirrel
//
//  Created by Leo Liu on 5/6/24.
//

import UserNotifications
import AppKit
import Carbon.HIToolbox
import UniformTypeIdentifiers

final class SquirrelApplicationDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  static let rimeWikiURL = URL(string: "https://github.com/rime/home/wiki")!
  static let updateNotificationIdentifier = "SquirrelUpdateNotification"
  static let notificationIdentifier = "SquirrelNotification"

  let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
  var config: SquirrelConfig?
  var panel: SquirrelPanel?
  var enableNotifications = false

  // Plugin Host Launcher (for isolated helper app)
  private var pluginHostLauncher: PluginHostLauncher?

  // 快捷键事件监听器
  private var eventMonitor: Any?
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandler: EventHandlerRef?

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }

  func applicationWillFinishLaunching(_ notification: Notification) {
    panel = SquirrelPanel(position: .zero)
    addObservers()

    // 注册全局快捷键监听
    setupGlobalHotkey()
  }

  func applicationWillTerminate(_ notification: Notification) {
    // 清理 LLM service
    print("[LLM] Shutting down llama.cpp service...")
    llama_shutdown_c()

    // 清理事件监听器
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
    }

    // 清理 Carbon 热键
    if let hotKeyRef = hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
    if let eventHandler = eventHandler {
      RemoveEventHandler(eventHandler)
    }

    // swiftlint:disable:next notification_center_detachment
    NotificationCenter.default.removeObserver(self)
    DistributedNotificationCenter.default().removeObserver(self)
    panel?.hide()
  }

  func deploy() {
    print("Start maintenance...")
    self.shutdownRime()
    self.startRime(fullCheck: true)
    self.loadSettings()
  }

  func syncUserData() {
    print("Sync user data")
    _ = rimeAPI.sync_user_data()
  }

  func openLogFolder() {
    NSWorkspace.shared.open(SquirrelApp.logDir)
  }

  func openRimeFolder() {
    NSWorkspace.shared.open(SquirrelApp.userDir)
  }

  func checkForUpdates() {
    print("Update checking not available (Sparkle framework removed)")
  }

  func openWiki() {
    NSWorkspace.shared.open(Self.rimeWikiURL)
  }

  static func showMessage(msgText: String?) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .provisional]) { _, error in
      if let error = error {
        print("User notification authorization error: \(error.localizedDescription)")
      }
    }
    center.getNotificationSettings { settings in
      if (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) && settings.alertSetting == .enabled {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Squirrel", comment: "")
        if let msgText = msgText {
          content.subtitle = msgText
        }
        content.interruptionLevel = .active
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: nil)
        center.add(request) { error in
          if let error = error {
            print("User notification request error: \(error.localizedDescription)")
          }
        }
      }
    }
  }

  func setupRime() {
    createDirIfNotExist(path: SquirrelApp.userDir)
    createDirIfNotExist(path: SquirrelApp.logDir)
    // swiftlint:disable identifier_name
    let notification_handler: @convention(c) (UnsafeMutableRawPointer?, RimeSessionId, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void = notificationHandler
    let context_object = Unmanaged.passUnretained(self).toOpaque()
    // swiftlint:enable identifier_name
    rimeAPI.set_notification_handler(notification_handler, context_object)

    var squirrelTraits = RimeTraits.rimeStructInit()
    squirrelTraits.setCString(Bundle.main.sharedSupportPath!, to: \.shared_data_dir)
    squirrelTraits.setCString(SquirrelApp.userDir.path(), to: \.user_data_dir)
    squirrelTraits.setCString(SquirrelApp.logDir.path(), to: \.log_dir)
    squirrelTraits.setCString("Squirrel", to: \.distribution_code_name)
    squirrelTraits.setCString("鼠鬚管", to: \.distribution_name)
    squirrelTraits.setCString(Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String, to: \.distribution_version)
    squirrelTraits.setCString("rime.squirrel", to: \.app_name)
    rimeAPI.setup(&squirrelTraits)
  }

  func startRime(fullCheck: Bool) {
    print("Initializing la rime...")
    rimeAPI.initialize(nil)
    // check for configuration updates
    if rimeAPI.start_maintenance(fullCheck) {
      // update squirrel config
      // print("[DEBUG] maintenance suceeds")
      _ = rimeAPI.deploy_config_file("squirrel.yaml", "config_version")
    } else {
      // print("[DEBUG] maintenance fails")
    }
  }

  func initializeLLM() {
    // Get model path from app bundle
    guard let modelPath = Bundle.main.path(forResource: "pinyin-250215", ofType: "gguf", inDirectory: "llm_models") else {
      print("[LLM] Model file not found in bundle")
      return
    }

    print("[LLM] Initializing llama.cpp service...")
    print("[LLM] Model path: \(modelPath)")
    print("[LLM] Using built-in pinyin chat template")

    // Initialize with 2 workers, 512 context size
    // Chat template is built-in, so pass NULL for template path
    let success = llama_initialize_c(modelPath, 512, 2, nil)

    if success {
      print("[LLM] llama.cpp service initialized successfully")
    } else {
      print("[LLM] Failed to initialize llama.cpp service")
    }
  }

  func loadSettings() {
    config = SquirrelConfig()
    if !config!.openBaseConfig() {
      return
    }

    enableNotifications = config!.getString("show_notifications_when") != "never"
    if let panel = panel, let config = self.config {
      panel.load(config: config, forDarkMode: false)
      panel.load(config: config, forDarkMode: true)
    }
  }

  func loadSettings(for schemaID: String) {
    if schemaID.count == 0 || schemaID.first == "." {
      return
    }
    let schema = SquirrelConfig()
    if let panel = panel, let config = self.config {
      if schema.open(schemaID: schemaID, baseConfig: config) && schema.has(section: "style") {
        panel.load(config: schema, forDarkMode: false)
        panel.load(config: schema, forDarkMode: true)
      } else {
        panel.load(config: config, forDarkMode: false)
        panel.load(config: config, forDarkMode: true)
      }
    }
    schema.close()
  }

  // prevent freezing the system
  func problematicLaunchDetected() -> Bool {
    var detected = false
    let logFile = FileManager.default.temporaryDirectory.appendingPathComponent("squirrel_launch.json", conformingTo: .json)
    // print("[DEBUG] archive: \(logFile)")
    do {
      let archive = try Data(contentsOf: logFile, options: [.uncached])
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .millisecondsSince1970
      let previousLaunch = try decoder.decode(Date.self, from: archive)
      if previousLaunch.timeIntervalSinceNow >= -2 {
        detected = true
      }
    } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {

    } catch {
      print("Error occurred during processing launch time archive: \(error.localizedDescription)")
      return detected
    }
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .millisecondsSince1970
      let record = try encoder.encode(Date.now)
      try record.write(to: logFile)
    } catch {
      print("Error occurred during saving launch time to archive: \(error.localizedDescription)")
    }
    return detected
  }

  // add an awakeFromNib item so that we can set the action method.  Note that
  // any menuItems without an action will be disabled when displayed in the Text
  // Input Menu.
  func addObservers() {
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: nil, using: workspaceWillPowerOff)

    let notifCenter = DistributedNotificationCenter.default()
    notifCenter.addObserver(forName: .init("SquirrelReloadNotification"), object: nil, queue: nil, using: rimeNeedsReload)
    notifCenter.addObserver(forName: .init("SquirrelSyncNotification"), object: nil, queue: nil, using: rimeNeedsSync)
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    print("Squirrel is quitting.")
    rimeAPI.cleanup_all_sessions()
    return .terminateNow
  }

}

private func notificationHandler(contextObject: UnsafeMutableRawPointer?, sessionId: RimeSessionId, messageTypeC: UnsafePointer<CChar>?, messageValueC: UnsafePointer<CChar>?) {
  let delegate: SquirrelApplicationDelegate = Unmanaged<SquirrelApplicationDelegate>.fromOpaque(contextObject!).takeUnretainedValue()

  let messageType = messageTypeC.map { String(cString: $0) }
  let messageValue = messageValueC.map { String(cString: $0) }
  if messageType == "deploy" {
    switch messageValue {
    case "start":
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_start", comment: ""))
    case "success":
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_success", comment: ""))
    case "failure":
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_failure", comment: ""))
    default:
      break
    }
    return
  }
  // off
  if !delegate.enableNotifications {
    return
  }

  if messageType == "schema", let messageValue = messageValue, let schemaName = try? /^[^\/]*\/(.*)$/.firstMatch(in: messageValue)?.output.1 {
    delegate.showStatusMessage(msgTextLong: String(schemaName), msgTextShort: String(schemaName))
    return
  } else if messageType == "option" {
    let state = messageValue?.first != "!"
    let optionName = if state {
      messageValue
    } else {
      String(messageValue![messageValue!.index(after: messageValue!.startIndex)...])
    }
    if let optionName = optionName {
      optionName.withCString { name in
        let stateLabelLong = delegate.rimeAPI.get_state_label_abbreviated(sessionId, name, state, false)
        let stateLabelShort = delegate.rimeAPI.get_state_label_abbreviated(sessionId, name, state, true)
        let longLabel = stateLabelLong.str.map { String(cString: $0) }
        let shortLabel = stateLabelShort.str.map { String(cString: $0) }
        delegate.showStatusMessage(msgTextLong: longLabel, msgTextShort: shortLabel)
      }
    }
  }
}

private extension SquirrelApplicationDelegate {
  func showStatusMessage(msgTextLong: String?, msgTextShort: String?) {
    if !(msgTextLong ?? "").isEmpty || !(msgTextShort ?? "").isEmpty {
      panel?.updateStatus(long: msgTextLong ?? "", short: msgTextShort ?? "")
    }
  }

  func shutdownRime() {
    config?.close()
    rimeAPI.finalize()
  }

  func workspaceWillPowerOff(_: Notification) {
    print("Finalizing before logging out.")
    self.shutdownRime()
  }

  func rimeNeedsReload(_: Notification) {
    print("Reloading rime on demand.")
    self.deploy()
  }

  func rimeNeedsSync(_: Notification) {
    print("Sync rime on demand.")
    self.syncUserData()
  }

  func createDirIfNotExist(path: URL) {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path.path()) {
      do {
        try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
      } catch {
        print("Error creating user data directory: \(path.path())")
      }
    }
  }
}

extension NSApplication {
  var squirrelAppDelegate: SquirrelApplicationDelegate {
    self.delegate as! SquirrelApplicationDelegate
  }
}

// MARK: - Global Hotkey Management
extension SquirrelApplicationDelegate {
  fileprivate func setupGlobalHotkey() {
    // 使用 Carbon 注册全局热键 (Cmd+Shift+Space)
    // 这种方式不需要辅助功能权限
    let hotKeyID = EventHotKeyID(signature: OSType(0x41495047), id: 1) // 'AIPG' = AI Plugin

    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

    // 注册事件处理器
    let eventHandlerCallback: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
      guard let userData = userData else { return OSStatus(eventNotHandledErr) }
      let delegate = Unmanaged<SquirrelApplicationDelegate>.fromOpaque(userData).takeUnretainedValue()

      // 如果输入法正在处理输入,不响应快捷键
      if delegate.panel?.isVisible == true {
        return OSStatus(eventNotHandledErr)
      }

      // 只负责启动 Helper（如果未运行），运行后由 Helper 自己的热键处理
      DispatchQueue.main.async {
        delegate.pluginHostLauncher?.ensureHelperRunning()
      }

      return noErr
    }

    let userData = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(GetApplicationEventTarget(), eventHandlerCallback, 1, &eventType, userData, &eventHandler)

    // 注册热键: Cmd(cmdKey) + Shift(shiftKey) + Space(49)
    let modifiers = UInt32(cmdKey | shiftKey)
    let keyCode = UInt32(kVK_Space) // 49 是 Space 键的 keyCode

    RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

    print("Global hotkey registered: Cmd+Shift+Space")
  }

}
