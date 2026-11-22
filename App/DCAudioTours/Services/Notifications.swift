import UserNotifications

/// Local notifications announce arrival at a stop when the app is in the background.
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Called on the main actor with (tourId, stopId) when the listener taps an arrival notification.
    var onOpenStop: (@MainActor (String, String) -> Void)?

    // Show arrival banners even while the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let tourId = info["tourId"] as? String, let stopId = info["stopId"] as? String else { return }
        await MainActor.run { onOpenStop?(tourId, stopId) }
    }
}

enum ArrivalNotifications {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func post(stopName: String, tourTitle: String, tourId: String, stopId: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "You've arrived")
        content.body = "\(stopName) · \(tourTitle)"
        content.sound = .default
        content.userInfo = ["tourId": tourId, "stopId": stopId]
        let request = UNNotificationRequest(identifier: "arrival-\(stopId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
