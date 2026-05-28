import Cocoa
import EventKit
import FlutterMacOS

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
