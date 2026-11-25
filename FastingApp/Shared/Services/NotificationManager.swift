import Foundation
#if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
import UserNotifications
#endif

public extension Notification.Name {
    static let fastSpanRequestEndFast = Notification.Name("fastSpanRequestEndFast")
}

/// Privacy-first local notification manager handling the 3-stage fasting notification schedule.
@MainActor
public final class NotificationManager: NSObject {
    public static let shared = NotificationManager()

    nonisolated public static let categoryIdentifier = "FASTING_NOTIFICATION_CATEGORY"
    nonisolated public static let actionEndFast = "ACTION_END_FAST"

    nonisolated public static let idOneHourBefore = "fasting_one_hour_before"
    nonisolated public static let idTargetReached = "fasting_target_reached"
    nonisolated public static let idOneHourPast = "fasting_one_hour_past"

    private struct ScheduleSignature: Equatable {
        let startTime: Date
        let targetDuration: TimeInterval
        let protocolName: String
        let notifyOneHourBefore: Bool
        let notifyTargetReached: Bool
        let notifyOneHourPast: Bool
    }

    private var hasPendingEndFastAction: Bool = false
    private var lastScheduledSignature: ScheduleSignature? = nil

    private override init() {
        super.init()
        #if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
            setupNotificationCategories()
        }
        #endif
    }

    /// Requests user authorization for alert, sound, and badge notifications.
    public func requestAuthorization() async -> Bool {
        #if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
        guard Bundle.main.bundleIdentifier != nil else { return true }
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[NotificationManager] Auth error: \(error.localizedDescription)")
            return false
        }
        #else
        return true
        #endif
    }

    /// Returns `true` when the user has explicitly denied notifications in system Settings.
    public func isNotificationsDenied() async -> Bool {
        #if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
        guard Bundle.main.bundleIdentifier != nil else { return false }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
        #else
        return false
        #endif
    }

    /// Consumes and clears a pending "End Fast & Log" notification action (handles cold launches).
    public func consumePendingEndFastAction() -> Bool {
        guard hasPendingEndFastAction else { return false }
        hasPendingEndFastAction = false
        return true
    }

    fileprivate func recordPendingEndFastAction() {
        hasPendingEndFastAction = true
        NotificationCenter.default.post(name: .fastSpanRequestEndFast, object: nil)
    }

    /// Schedules the enabled milestone notifications for an active fast.
    /// Skips redundant XPC calls when the schedule parameters have not changed.
    /// Only replaces pending requests so any already-delivered completion banner stays visible.
    public func scheduleFastingNotifications(
        startTime: Date,
        targetDuration: TimeInterval,
        protocolName: String,
        notifyOneHourBefore: Bool = true,
        notifyTargetReached: Bool = true,
        notifyOneHourPast: Bool = true,
        force: Bool = false
    ) {
        let signature = ScheduleSignature(
            startTime: startTime,
            targetDuration: targetDuration,
            protocolName: protocolName,
            notifyOneHourBefore: notifyOneHourBefore,
            notifyTargetReached: notifyTargetReached,
            notifyOneHourPast: notifyOneHourPast
        )
        if !force, lastScheduledSignature == signature {
            return
        }
        lastScheduledSignature = signature

        #if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.idOneHourBefore,
            Self.idTargetReached,
            Self.idOneHourPast
        ])
        let targetEndTime = startTime.addingTimeInterval(targetDuration)
        let oneHourBefore = targetEndTime.addingTimeInterval(-3600)
        let oneHourPast = targetEndTime.addingTimeInterval(3600)
        let now = Date()

        // 1. Notification: 1 Hour Before Done (only if more than 1 hour remains)
        if notifyOneHourBefore && oneHourBefore > now {
            let content = UNMutableNotificationContent()
            content.title = "Almost There! ⏱️"
            content.body = "1 hour remaining in your \(protocolName) fast. Stay hydrated!"
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, oneHourBefore.timeIntervalSince(now)),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.idOneHourBefore,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        // 2. Notification: Fast Target Reached
        if notifyTargetReached && targetEndTime > now {
            let content = UNMutableNotificationContent()
            content.title = "Fast Complete! 🎉"
            content.body = "You reached your \(protocolName) goal! Counting overtime until you break your fast."
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, targetEndTime.timeIntervalSince(now)),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.idTargetReached,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        // 3. Notification: 1 Hour Past Target (Overtime milestone)
        if notifyOneHourPast && oneHourPast > now {
            let content = UNMutableNotificationContent()
            content.title = "1 Hour Overtime ⭐"
            content.body = "You are 1 hour past your \(protocolName) goal. Great discipline!"
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, oneHourPast.timeIntervalSince(now)),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.idOneHourPast,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
        #endif
    }

    /// Removes pending fasting notifications without clearing already-delivered banners.
    public func cancelPendingFastingNotifications() {
        lastScheduledSignature = nil
        #if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.idOneHourBefore,
            Self.idTargetReached,
            Self.idOneHourPast
        ])
        #endif
    }

    /// Cancels all scheduled and delivered fasting notifications (called when fast ends or is reset).
    public func cancelAllFastingNotifications() {
        lastScheduledSignature = nil
        #if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        let ids = [
            Self.idOneHourBefore,
            Self.idTargetReached,
            Self.idOneHourPast
        ]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        #endif
    }

    #if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
    private func setupNotificationCategories() {
        let endAction = UNNotificationAction(
            identifier: Self.actionEndFast,
            title: "End Fast & Log",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [endAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    #endif
}

#if (os(iOS) || os(watchOS)) && canImport(UserNotifications)
extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.actionIdentifier == Self.actionEndFast {
            await MainActor.run {
                self.recordPendingEndFastAction()
            }
        }
    }
}
#endif
