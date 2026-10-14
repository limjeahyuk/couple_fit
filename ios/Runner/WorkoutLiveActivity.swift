import ActivityKit
import Flutter
import UserNotifications

/// MethodChannel "couplefit/live_activity": start / update / end the lock-screen workout timer.
enum WorkoutLiveActivity {
  static func register(_ messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "couplefit/live_activity", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard #available(iOS 16.2, *) else { return result(nil) }
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "start": start(args)
        case "update": update(args)
        case "end": end()
        default: return result(FlutterMethodNotImplemented)
        }
        result(nil)
      }
  }

  private static func date(_ ms: Any?) -> Date? {
    (ms as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
  }

  private static func state(_ a: [String: Any]) -> WorkoutAttributes.ContentState {
    .init(
      title: a["title"] as? String ?? "", detail: a["detail"] as? String ?? "",
      restEnd: date(a["restEnd"]), doneSets: a["doneSets"] as? Int ?? 0,
      totalSets: a["totalSets"] as? Int ?? 0)
  }

  @available(iOS 16.2, *)
  private static func start(_ a: [String: Any]) {
    end()
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let s = state(a)
    let attrs = WorkoutAttributes(
      routine: a["routine"] as? String ?? "", startedAt: date(a["startedAt"]) ?? Date())
    _ = try? Activity.request(attributes: attrs, content: .init(state: s, staleDate: s.restEnd))
    scheduleRestAlert(s)
  }

  @available(iOS 16.2, *)
  private static func update(_ a: [String: Any]) {
    let s = state(a)
    Task {
      for act in Activity<WorkoutAttributes>.activities {
        await act.update(.init(state: s, staleDate: s.restEnd))
      }
    }
    scheduleRestAlert(s)
  }

  @available(iOS 16.2, *)
  private static func end() {
    Task {
      for act in Activity<WorkoutAttributes>.activities {
        await act.end(nil, dismissalPolicy: .immediate)
      }
    }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest"])
  }

  /// Rings when rest is over even if the phone is locked (the app is suspended then).
  private static func scheduleRestAlert(_ s: WorkoutAttributes.ContentState) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["rest"])
    guard let end = s.restEnd, end.timeIntervalSinceNow > 0.5 else { return }
    let n = UNMutableNotificationContent()
    n.title = "휴식 끝!"
    n.body = s.detail
    n.sound = .default
    center.add(
      UNNotificationRequest(
        identifier: "rest", content: n,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: end.timeIntervalSinceNow, repeats: false)))
  }
}
