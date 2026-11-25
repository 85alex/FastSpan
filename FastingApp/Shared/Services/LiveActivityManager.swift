import Foundation
#if os(iOS) && canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

/// Manages ActivityKit Live Activities and Dynamic Island countdown presentation.
@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()

    #if os(iOS) && canImport(ActivityKit)
    private var activeActivityID: String? = nil
    #endif

    public var isLiveActivitySupported: Bool {
        #if os(iOS) && canImport(ActivityKit)
        return ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        return false
        #endif
    }

    private init() {}

    /// Starts, updates, or ends the Live Activity for the active fast.
    /// Uses native SpringBoard countdown rendering (`Text(timerInterval:)`) so zero polling is required.
    public func evaluateLiveActivity(
        isEnabled: Bool = true,
        startTime: Date?,
        targetDuration: TimeInterval,
        protocolName: String,
        themeID: String,
        countsUp: Bool = false,
        at now: Date = Date()
    ) {
        guard isEnabled, let start = startTime else {
            endLiveActivity()
            return
        }

        let targetEnd = start.addingTimeInterval(max(60, targetDuration))
        let isOvertime = now >= targetEnd

        startOrUpdateActivity(
            startTime: start,
            targetEndTime: targetEnd,
            protocolName: protocolName,
            themeID: themeID,
            isOvertime: isOvertime,
            countsUp: countsUp
        )
    }

    private func startOrUpdateActivity(
        startTime: Date,
        targetEndTime: Date,
        protocolName: String,
        themeID: String,
        isOvertime: Bool,
        countsUp: Bool
    ) {
        #if os(iOS) && canImport(ActivityKit)
        let state = FastingActivityAttributes.ContentState(
            startTime: startTime,
            targetEndTime: targetEndTime,
            protocolName: protocolName,
            themeID: themeID,
            isOvertime: isOvertime,
            countsUp: countsUp
        )
        let content = ActivityContent(
            state: state,
            staleDate: isOvertime ? nil : targetEndTime
        )

        let activeActivities = Activity<FastingActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
        let matchingActivity = activeActivities.first { activity in
            if let activeID = self.activeActivityID {
                return activity.id == activeID
            }
            return true
        } ?? activeActivities.first

        if let existing = matchingActivity {
            self.activeActivityID = existing.id

            // Clean up any duplicate orphaned activities if more than one somehow exists
            for extra in activeActivities where extra.id != existing.id {
                nonisolated(unsafe) let extraToEnd = extra
                Task {
                    let emptyContent: ActivityContent<FastingActivityAttributes.ContentState>? = nil
                    await extraToEnd.end(emptyContent, dismissalPolicy: .immediate)
                }
            }

            // Skip redundant SpringBoard IPC if the Live Activity already displays this exact state
            if existing.activityState == .active && existing.content.state == state {
                return
            }

            nonisolated(unsafe) let activityToUpdate = existing
            Task {
                await activityToUpdate.update(content)
            }
        } else {
            guard isLiveActivitySupported else { return }
            let attributes = FastingActivityAttributes(fastID: UUID().uuidString)
            do {
                let activity = try Activity.request(attributes: attributes, content: content)
                self.activeActivityID = activity.id
            } catch {
                print("[LiveActivityManager] Request error: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Ends and dismisses the Live Activity immediately.
    public func endLiveActivity() {
        #if os(iOS) && canImport(ActivityKit)
        self.activeActivityID = nil
        let activities = Activity<FastingActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        for activity in activities {
            nonisolated(unsafe) let activityToEnd = activity
            Task {
                let emptyContent: ActivityContent<FastingActivityAttributes.ContentState>? = nil
                await activityToEnd.end(emptyContent, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
