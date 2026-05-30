import Cocoa
import EventKit
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {
  private let eventStore = EKEventStore()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      super.applicationDidFinishLaunching(notification)
      return
    }
    let channel = FlutterMethodChannel(
      name: "my_assistant/calendar",
      binaryMessenger: controller.engine.binaryMessenger
    )
    let reminderChannel = FlutterMethodChannel(
      name: "my_assistant/todo_reminders",
      binaryMessenger: controller.engine.binaryMessenger
    )
    let smsChannel = FlutterMethodChannel(
      name: "my_assistant/sms",
      binaryMessenger: controller.engine.binaryMessenger
    )
    let permissionsChannel = FlutterMethodChannel(
      name: "my_assistant/permissions",
      binaryMessenger: controller.engine.binaryMessenger
    )
    let appLauncherChannel = FlutterMethodChannel(
      name: "my_assistant/app_launcher",
      binaryMessenger: controller.engine.binaryMessenger
    )
    permissionsChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "openPermissionSettings":
        guard
          let args = call.arguments as? [String: Any],
          let target = args["target"] as? String
        else {
          result(false)
          return
        }
        self?.openPermissionSettings(target: target, result: result)
      case "openAuthorizationSettings", "openAppSettings":
        result(self?.openAppPrivacySettings() ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    appLauncherChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "listApps":
        result(self?.listLaunchableApplications() ?? [])
      case "openApp":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "缺少应用参数", details: nil))
          return
        }
        result(self?.openLaunchableApplication(args: args) ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "openCalendar" {
        self?.openCalendarApp(result: result)
        return
      }
      guard call.method == "fetchEvents" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let startMillis = self?.int64Value(args["startMillis"]),
        let endMillis = self?.int64Value(args["endMillis"])
      else {
        result(FlutterError(code: "bad_args", message: "缺少日历查询时间范围", details: nil))
        return
      }
      self?.fetchEvents(startMillis: startMillis, endMillis: endMillis, result: result)
    }
    reminderChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "ensureNotificationPermission":
        self?.ensureNotificationPermission(result: result)
      case "schedule":
        guard
          let args = call.arguments as? [String: Any],
          let id = args["id"] as? String,
          let title = args["title"] as? String,
          let body = args["body"] as? String,
          let fireAtMillis = self?.int64Value(args["fireAtMillis"])
        else {
          result(FlutterError(code: "bad_args", message: "缺少提醒参数", details: nil))
          return
        }
        self?.scheduleTodoReminder(
          id: id,
          title: title,
          body: body,
          fireAtMillis: fireAtMillis,
          result: result
        )
      case "cancel":
        guard
          let args = call.arguments as? [String: Any],
          let id = args["id"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "缺少提醒 ID", details: nil))
          return
        }
        self?.cancelTodoReminder(id: id, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    smsChannel.setMethodCallHandler { call, result in
      guard call.method == "fetchRecent" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // macOS sandboxed apps cannot reliably read Messages/SMS content.
      // Return an empty list so Flutter can safely fall back without blocking startup.
      result([])
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func fetchEvents(startMillis: Int64, endMillis: Int64, result: @escaping FlutterResult) {
    requestCalendarAccess { [weak self] calendarGranted in
      guard let self = self else { return }
      guard calendarGranted else {
        result(FlutterError(code: "calendar_denied", message: "没有日历访问权限", details: nil))
        return
      }
      let start = Date(timeIntervalSince1970: TimeInterval(startMillis) / 1000.0)
      let end = Date(timeIntervalSince1970: TimeInterval(endMillis) / 1000.0)
      let payload = self.fetchCalendarEvents(start: start, end: end)
      self.requestReminderAccess { remindersGranted in
        guard remindersGranted else {
          result(payload)
          return
        }
        self.fetchReminders(start: start, end: end) { reminders in
          result(payload + reminders)
        }
      }
    }
  }

  private func fetchCalendarEvents(start: Date, end: Date) -> [[String: Any]] {
    let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
    let events = eventStore.events(matching: predicate)
    return events
        .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map { event in
          let startMillis = Int64(event.startDate.timeIntervalSince1970 * 1000)
          let endMillis = Int64(event.endDate.timeIntervalSince1970 * 1000)
          return [
            "id": "macos-event-\(event.calendarItemIdentifier)-\(startMillis)",
            "title": event.title ?? "",
            "notes": event.notes ?? "",
            "location": event.location ?? "",
            "startMillis": startMillis,
            "endMillis": endMillis,
            "allDay": event.isAllDay,
            "platform": "macos",
            "sourceType": "event"
          ] as [String : Any]
        }
  }

  private func fetchReminders(
    start: Date,
    end: Date,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    let predicate = eventStore.predicateForIncompleteReminders(
      withDueDateStarting: start,
      ending: end,
      calendars: nil
    )
    eventStore.fetchReminders(matching: predicate) { reminders in
      let payload = (reminders ?? [])
        .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .compactMap { reminder -> [String: Any]? in
          guard let dueComponents = reminder.dueDateComponents else { return nil }
          var normalizedDueComponents = dueComponents
          if normalizedDueComponents.calendar == nil {
            normalizedDueComponents.calendar = Calendar.current
          }
          guard let due = normalizedDueComponents.date else { return nil }
          let startMillis = Int64(due.timeIntervalSince1970 * 1000)
          let endMillis = Int64(due.addingTimeInterval(60 * 60).timeIntervalSince1970 * 1000)
          return [
            "id": "macos-reminder-\(reminder.calendarItemIdentifier)-\(startMillis)",
            "title": reminder.title ?? "",
            "notes": reminder.notes ?? "",
            "location": "",
            "startMillis": startMillis,
            "endMillis": endMillis,
            "allDay": dueComponents.hour == nil,
            "platform": "macos",
            "sourceType": "reminder"
          ] as [String: Any]
        }
      DispatchQueue.main.async { completion(payload) }
    }
  }

  private func openCalendarApp(result: @escaping FlutterResult) {
    let paths = [
      "/System/Applications/Calendar.app",
      "/Applications/Calendar.app"
    ]
    for path in paths {
      let url = URL(fileURLWithPath: path)
      if FileManager.default.fileExists(atPath: path) {
        result(NSWorkspace.shared.open(url))
        return
      }
    }
    result(false)
  }

  private func openPermissionSettings(target: String, result: @escaping FlutterResult) {
    switch target {
    case "calendar":
      requestCalendarAccess { [weak self] granted in
        if granted {
          result(true)
        } else {
          result(self?.openPrivacyPane("Privacy_Calendars") ?? false)
        }
      }
    case "reminders":
      requestReminderAccess { [weak self] granted in
        if granted {
          result(true)
        } else {
          result(self?.openPrivacyPane("Privacy_Reminders") ?? false)
        }
      }
    case "notifications":
      ensureNotificationPermission { [weak self] response in
        if let granted = response as? Bool, granted {
          result(true)
        } else {
          result(self?.openSystemSettingsURL("x-apple.systempreferences:com.apple.preference.notifications") ?? false)
        }
      }
    case "voice":
      result(openPrivacyPane("Privacy_Microphone"))
    default:
      result(openAppPrivacySettings())
    }
  }

  private func openAppPrivacySettings() -> Bool {
    return openSystemSettingsURL("x-apple.systempreferences:com.apple.preference.security")
  }

  private func listLaunchableApplications() -> [[String: Any]] {
    let directories = [
      "/Applications",
      "/System/Applications",
      "/System/Applications/Utilities",
      "/Applications/Utilities"
    ]
    var seen = Set<String>()
    var apps: [[String: Any]] = []
    for directory in directories {
      let url = URL(fileURLWithPath: directory, isDirectory: true)
      guard let entries = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      ) else { continue }
      for entry in entries where entry.pathExtension == "app" {
        let bundle = Bundle(url: entry)
        let bundleId = bundle?.bundleIdentifier ?? entry.path
        guard !seen.contains(bundleId) else { continue }
        seen.insert(bundleId)
        let info = bundle?.infoDictionary
        let rawLabel = (info?["CFBundleDisplayName"] as? String)
          ?? (info?["CFBundleName"] as? String)
        let label = rawLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
          ?? entry.deletingPathExtension().lastPathComponent
        apps.append([
          "platform": "macos",
          "id": bundleId,
          "label": label,
          "subtitle": bundleId,
          "bundleId": bundleId,
          "path": entry.path
        ])
      }
    }
    return apps.sorted {
      let lhs = ($0["label"] as? String) ?? ""
      let rhs = ($1["label"] as? String) ?? ""
      return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
  }

  private func openLaunchableApplication(args: [String: Any]) -> Bool {
    if
      let path = args["path"] as? String,
      !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
    let bundleId = (args["bundleId"] as? String) ?? (args["id"] as? String)
    guard
      let id = bundleId?.trimmingCharacters(in: .whitespacesAndNewlines),
      !id.isEmpty,
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
    else { return false }
    return NSWorkspace.shared.open(url)
  }

  private func openPrivacyPane(_ pane: String) -> Bool {
    return openSystemSettingsURL("x-apple.systempreferences:com.apple.preference.security?\(pane)")
  }

  private func openSystemSettingsURL(_ raw: String) -> Bool {
    guard let url = URL(string: raw) else { return false }
    return NSWorkspace.shared.open(url)
  }

  private func scheduleTodoReminder(
    id: String,
    title: String,
    body: String,
    fireAtMillis: Int64,
    result: @escaping FlutterResult
  ) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "notification_error", message: error.localizedDescription, details: nil))
        }
        return
      }
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "notification_denied", message: "没有通知权限", details: nil))
        }
        return
      }
      let fireAt = Date(timeIntervalSince1970: TimeInterval(fireAtMillis) / 1000.0)
      let interval = fireAt.timeIntervalSinceNow
      guard interval > 0 else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
      let request = UNNotificationRequest(
        identifier: "todo-\(id)",
        content: content,
        trigger: trigger
      )
      center.removePendingNotificationRequests(withIdentifiers: ["todo-\(id)"])
      center.add(request) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "notification_error", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    }
  }

  private func ensureNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "notification_error", message: error.localizedDescription, details: nil))
        } else {
          result(granted)
        }
      }
    }
  }

  private func cancelTodoReminder(id: String, result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: ["todo-\(id)"]
    )
    result(nil)
  }

  private func requestCalendarAccess(_ completion: @escaping (Bool) -> Void) {
    let status = EKEventStore.authorizationStatus(for: .event)
    switch status {
    case .authorized:
      completion(true)
    case .denied, .restricted:
      completion(false)
    case .notDetermined:
      if #available(macOS 14.0, *) {
        eventStore.requestFullAccessToEvents { granted, _ in
          DispatchQueue.main.async { completion(granted) }
        }
      } else {
        eventStore.requestAccess(to: .event) { granted, _ in
          DispatchQueue.main.async { completion(granted) }
        }
      }
    case .fullAccess:
      completion(true)
    case .writeOnly:
      completion(false)
    @unknown default:
      completion(false)
    }
  }

  private func requestReminderAccess(_ completion: @escaping (Bool) -> Void) {
    let status = EKEventStore.authorizationStatus(for: .reminder)
    switch status {
    case .authorized:
      completion(true)
    case .denied, .restricted:
      completion(false)
    case .notDetermined:
      if #available(macOS 14.0, *) {
        eventStore.requestFullAccessToReminders { granted, _ in
          DispatchQueue.main.async { completion(granted) }
        }
      } else {
        eventStore.requestAccess(to: .reminder) { granted, _ in
          DispatchQueue.main.async { completion(granted) }
        }
      }
    case .fullAccess:
      completion(true)
    case .writeOnly:
      completion(false)
    @unknown default:
      completion(false)
    }
  }

  private func int64Value(_ value: Any?) -> Int64? {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? NSNumber { return value.int64Value }
    return nil
  }
}
