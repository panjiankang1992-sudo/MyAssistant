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
    requestCalendarAccess { [weak self] granted in
      guard let self = self else { return }
      guard granted else {
        result(FlutterError(code: "calendar_denied", message: "没有日历访问权限", details: nil))
        return
      }
      let start = Date(timeIntervalSince1970: TimeInterval(startMillis) / 1000.0)
      let end = Date(timeIntervalSince1970: TimeInterval(endMillis) / 1000.0)
      let predicate = self.eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
      let events = self.eventStore.events(matching: predicate)
      let payload = events
        .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map { event in
          [
            "id": event.calendarItemIdentifier,
            "title": event.title ?? "",
            "notes": event.notes ?? "",
            "location": event.location ?? "",
            "startMillis": Int64(event.startDate.timeIntervalSince1970 * 1000),
            "endMillis": Int64(event.endDate.timeIntervalSince1970 * 1000),
            "allDay": event.isAllDay,
            "platform": "macos"
          ] as [String : Any]
        }
      result(payload)
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

  private func int64Value(_ value: Any?) -> Int64? {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? NSNumber { return value.int64Value }
    return nil
  }
}
