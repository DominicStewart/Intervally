//
//  NotificationService.swift
//  RunLoop
//
//  Manages local notifications for interval boundaries.
//  Schedules notifications at absolute dates as fallback for background timing.
//

import Foundation
import UserNotifications

/// Service for scheduling local notifications at interval boundaries
final class NotificationService {

    // MARK: - Notification Center

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    /// Request notification permission from user
    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        } catch {
            print("❌ Failed to request notification permission: \(error.localizedDescription)")
        }
    }

    // MARK: - Scheduling

    /// Schedule a notification for an interval boundary
    /// - Parameters:
    ///   - date: Absolute date/time for notification
    ///   - title: Notification title (interval name)
    ///   - subtitle: Optional subtitle (e.g., "Next: Walk")
    ///   - identifier: Unique identifier for this notification
    func scheduleIntervalNotification(
        at date: Date,
        title: String,
        subtitle: String? = nil,
        identifier: String
    ) async {
        // Don't schedule notifications in the past
        guard date > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = subtitle ?? ""
        content.sound = UNNotificationSound(named: UNNotificationSoundName("chime.wav"))
        content.interruptionLevel = .timeSensitive

        // Use date-based trigger
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("📅 Scheduled notification for \(date): \(title)")
        } catch {
            print("❌ Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    /// Cancel all pending notifications
    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        print("🗑️ Cancelled all notifications")
    }

    /// Cancel specific notification by identifier
    func cancel(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled notification: \(identifier)")
    }

    // MARK: - Helpers

    /// Get count of pending notifications (for debugging)
    func pendingCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }
}
