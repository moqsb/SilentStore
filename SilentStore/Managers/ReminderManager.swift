import Foundation
import UserNotifications

final class ReminderManager {
    static let shared = ReminderManager()
    private let reminderId = "silentstore.weekly.reminder"

    func scheduleWeeklyReminder(weekday: Int, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "SilentStore Reminder"
        content.body = "Don't forget to review your secure vault."
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId])
    }
}
