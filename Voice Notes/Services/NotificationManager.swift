import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("❌ NotificationManager: Failed to request authorization: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - Transcription Notifications

    func notifyTranscriptionComplete(recordingTitle: String, duration: TimeInterval) {
        Task {
            // Check if we have permission
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                print("⚠️ NotificationManager: No permission to send notifications")
                return
            }

            // Check if app is in background
            let isInBackground = await UIApplication.shared.applicationState != .active

            // Only send notification if app is in background
            guard isInBackground else {
                print("ℹ️ NotificationManager: App is active, skipping notification")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Transcription Complete"
            content.body = "'\(recordingTitle)' is ready to view"
            content.sound = .default
            content.badge = NSNumber(value: await UIApplication.shared.applicationIconBadgeNumber + 1)
            content.categoryIdentifier = "TRANSCRIPTION_COMPLETE"

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Deliver immediately
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ NotificationManager: Transcription complete notification sent")
            } catch {
                print("❌ NotificationManager: Failed to send transcription notification: \(error)")
            }
        }
    }

    func notifySummaryComplete(recordingTitle: String) {
        Task {
            // Check if we have permission
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                print("⚠️ NotificationManager: No permission to send notifications")
                return
            }

            // Check if app is in background
            let isInBackground = await UIApplication.shared.applicationState != .active

            // Only send notification if app is in background
            guard isInBackground else {
                print("ℹ️ NotificationManager: App is active, skipping notification")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Summary Ready"
            content.body = "'\(recordingTitle)' has been summarized"
            content.sound = .default
            content.badge = NSNumber(value: await UIApplication.shared.applicationIconBadgeNumber + 1)
            content.categoryIdentifier = "SUMMARY_COMPLETE"

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Deliver immediately
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ NotificationManager: Summary complete notification sent")
            } catch {
                print("❌ NotificationManager: Failed to send summary notification: \(error)")
            }
        }
    }

    // MARK: - Model Download Notifications

    func notifyModelDownloadComplete(modelName: String, modelSize: String) {
        Task {
            // Check if we have permission
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                print("⚠️ NotificationManager: No permission to send notifications")
                return
            }

            // Check if app is in background
            let isInBackground = await UIApplication.shared.applicationState != .active

            // Only send notification if app is in background
            guard isInBackground else {
                print("ℹ️ NotificationManager: App is active, skipping notification")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Model Downloaded"
            content.body = "\(modelName) (\(modelSize)) is ready for offline transcription"
            content.sound = .default
            content.badge = NSNumber(value: await UIApplication.shared.applicationIconBadgeNumber + 1)
            content.categoryIdentifier = "MODEL_DOWNLOAD_COMPLETE"

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Deliver immediately
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ NotificationManager: Model download complete notification sent")
            } catch {
                print("❌ NotificationManager: Failed to send model download notification: \(error)")
            }
        }
    }

    func notifyModelDownloadFailed(modelName: String, error: String) {
        Task {
            // Check if we have permission
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                print("⚠️ NotificationManager: No permission to send notifications")
                return
            }

            // Check if app is in background
            let isInBackground = await UIApplication.shared.applicationState != .active

            // Only send notification if app is in background
            guard isInBackground else {
                print("ℹ️ NotificationManager: App is active, skipping notification")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Download Failed"
            content.body = "\(modelName) download failed"
            content.sound = .default
            content.categoryIdentifier = "MODEL_DOWNLOAD_FAILED"

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Deliver immediately
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ NotificationManager: Model download failed notification sent")
            } catch {
                print("❌ NotificationManager: Failed to send model download failed notification: \(error)")
            }
        }
    }

    // MARK: - Badge Management

    func clearBadge() {
        Task {
            await UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
