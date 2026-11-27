import Foundation
import SwiftUI
#if os(watchOS) && canImport(WidgetKit)
import WidgetKit
#endif

public enum TrackerVisualMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case valley = "Valley Arc"
    case circular = "Classic Ring"

    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .valley: return "mountain.2.fill"
        case .circular: return "circle.circle"
        }
    }
}

/// Core state coordinator and timer engine for the fasting application.
@MainActor
@Observable
public final class FastingManager {
    public static let shared = FastingManager()

    // MARK: - Active Fast State
    public var activeStartTime: Date? = nil
    public var activeTargetDuration: TimeInterval = 16.0 * 3600.0
    public var activeProtocol: FastingProtocol = .standard16_8
    public var selectedTheme: AppTheme = .solarAmber
    public var visualMode: TrackerVisualMode = .valley
    public var liveActivitiesEnabled: Bool = true
    public var liveActivityCountsUp: Bool = false
    public var notifyOneHourBefore: Bool = true
    public var notifyTargetReached: Bool = true
    public var notifyOneHourPast: Bool = true
    public var iCloudSyncEnabled: Bool = true
    public var hasAcceptedMedicalDisclaimer: Bool = false
    /// Reflects whether SwiftData actually initialized with CloudKit (false if opted out or fell back to local).
    public var isCloudKitActive: Bool = false
    private var launchICloudSyncEnabled: Bool = true

    /// True when the user has toggled iCloud sync since launch and must restart for the store to rebind.
    public var iCloudSyncNeedsRestart: Bool {
        iCloudSyncEnabled != launchICloudSyncEnabled
    }

    // MARK: - Post-Fast / Eating Window Tracking
    public var lastCompletedFastEndTime: Date? = nil
    /// Set when a fast is completed on the paired Apple Watch so iPhone prompts for notes/mood on next open.
    public var pendingFeedbackRecordID: UUID? = nil
    public var onRemoteFastCompleted: (@MainActor (FastRecord) -> Void)? = nil {
        didSet {
            guard let handler = onRemoteFastCompleted, !pendingRemoteCompletedRecords.isEmpty else { return }
            let queued = pendingRemoteCompletedRecords
            pendingRemoteCompletedRecords.removeAll()
            for record in queued {
                handler(record)
            }
        }
    }
    private var lastStateMutationDate: Date = .distantPast
    private var processedRemoteRecordIDs: [UUID] = []
    private var pendingRemoteCompletedRecords: [FastRecord] = []

    // MARK: - Streak & Analytics Cache
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0

    // MARK: - User Defaults Keys
    private let keyStartTime = "fasting_active_start_time"
    private let keyTargetDuration = "fasting_active_target_duration"
    private let keyProtocolId = "fasting_active_protocol_id"
    private let keyThemeId = "fasting_selected_theme_id"
    private let keyVisualMode = "fasting_visual_mode"
    private let keyLastCompletedEndTime = "fasting_last_completed_end_time"
    private let keyLastStateMutationDate = "fasting_last_state_mutation_date"
    private let keyPendingFeedbackRecordID = "fasting_pending_feedback_record_id"
    private let keyProcessedRemoteRecordIDs = "fasting_processed_remote_record_ids"
    private let keyLiveActivitiesEnabled = "fasting_live_activities_enabled"
    private let keyLiveActivityCountsUp = "fasting_live_activity_counts_up"
    private let keyNotifyOneHourBefore = "fasting_notify_one_hour_before"
    private let keyNotifyTargetReached = "fasting_notify_target_reached"
    private let keyNotifyOneHourPast = "fasting_notify_one_hour_past"
    private let keyICloudSyncEnabled = "fasting_icloud_sync_enabled"
    private let keyHasAcceptedMedicalDisclaimer = "fasting_has_accepted_medical_disclaimer"

    private static var minTargetDuration: TimeInterval {
        FastingProtocol.minFastingHours * 3600.0
    }

    private static var maxTargetDuration: TimeInterval {
        FastingProtocol.maxFastingHours * 3600.0
    }

    private static func clampedTargetDuration(_ duration: TimeInterval) -> TimeInterval {
        min(maxTargetDuration, max(minTargetDuration, duration))
    }

    public init() {
        loadPersistedState()
        syncComplications()
        setupWatchSyncListeners()
    }

    // MARK: - Fasting Lifecycle Operations

    /// Starts a new fast with the specified protocol and optional retroactive start time.
    public func startFast(
        protocol fastingProtocol: FastingProtocol = .standard16_8,
        startTime: Date = Date()
    ) {
        let mutationDate = Date()
        let clampedDuration = Self.clampedTargetDuration(fastingProtocol.fastingDuration)
        let safeProtocol = fastingProtocol.fastingDuration > Self.maxTargetDuration
            ? resolvedProtocol(for: clampedDuration, current: .warrior20_4)
            : fastingProtocol
        self.activeProtocol = safeProtocol
        self.activeTargetDuration = clampedDuration
        self.activeStartTime = startTime
        recordMutationDate(mutationDate)

        persistActiveState()

        // Schedule local notifications
        syncNotifications()

        // Start or update Live Activity if enabled
        syncLiveActivity()

        // Mirror state for watch face complications
        syncComplications()

        // Sync with Apple Watch
        WatchSyncService.shared.sendStartFast(
            startTime: startTime,
            targetDuration: activeTargetDuration,
            protocolId: safeProtocol.id,
            sentAt: mutationDate
        )
    }

    /// Ends the current active fast and generates a completed `FastRecord`.
    public func endFast(
        endTime: Date = Date(),
        notes: String? = nil,
        mood: String? = nil
    ) -> FastRecord? {
        guard let record = completeActiveFastLocally(
            endTime: endTime,
            recordID: UUID(),
            notes: notes,
            mood: mood,
            mutationDate: Date()
        ) else {
            return nil
        }

        // Notify paired device with full completed fast metadata and record ID
        WatchSyncService.shared.sendEndFast(
            startTime: record.startTime,
            endTime: record.endTime ?? endTime,
            targetDuration: record.targetDuration,
            protocolId: activeProtocol.id,
            protocolName: record.protocolName,
            recordID: record.id,
            sentAt: lastStateMutationDate
        )

        return record
    }

    /// Clears the pending Watch-completed fast feedback prompt once the user saves or skips it.
    public func clearPendingFeedbackRecord() {
        self.pendingFeedbackRecordID = nil
        UserDefaults.standard.removeObject(forKey: keyPendingFeedbackRecordID)
    }

    /// Handles a completed fast synced from the paired device (Watch -> iPhone or iPhone -> Watch).
    public func handleRemoteEndFast(_ payload: RemoteEndFastPayload) {
        if let incomingID = payload.recordID, processedRemoteRecordIDs.contains(incomingID) {
            return
        }

        let isNewerState = payload.sentAt > self.lastStateMutationDate
        let resolvedStartTime = payload.startTime ?? (isNewerState ? self.activeStartTime : nil)
        let resolvedTargetDuration = payload.targetDuration ?? self.activeTargetDuration
        let resolvedProtocolName: String
        if let name = payload.protocolName, !name.isEmpty {
            resolvedProtocolName = name
        } else if let protoId = payload.protocolId,
                  let preset = FastingProtocol.allPresets.first(where: { $0.id == protoId }) {
            resolvedProtocolName = preset.name
        } else {
            resolvedProtocolName = self.activeProtocol.name
        }

        let safeEndTime = resolvedStartTime.map { max($0, payload.endTime) } ?? payload.endTime

        if isNewerState {
            if self.lastCompletedFastEndTime == nil || safeEndTime > self.lastCompletedFastEndTime! {
                self.lastCompletedFastEndTime = safeEndTime
                UserDefaults.standard.set(safeEndTime.timeIntervalSince1970, forKey: keyLastCompletedEndTime)
            }
            recordMutationDate(payload.sentAt)
            if self.activeStartTime != nil {
                self.activeStartTime = nil
                clearPersistedActiveState()
                NotificationManager.shared.cancelAllFastingNotifications()
                LiveActivityManager.shared.endLiveActivity()
            }
            syncComplications()
        } else if self.lastCompletedFastEndTime == nil || safeEndTime > self.lastCompletedFastEndTime! {
            self.lastCompletedFastEndTime = safeEndTime
            UserDefaults.standard.set(safeEndTime.timeIntervalSince1970, forKey: keyLastCompletedEndTime)
            syncComplications()
        }

        guard let start = resolvedStartTime else {
            return
        }

        let recordID = payload.recordID ?? UUID()
        let record = FastRecord(
            id: recordID,
            startTime: start,
            endTime: safeEndTime,
            targetDurationHours: resolvedTargetDuration / 3600.0,
            protocolName: resolvedProtocolName,
            isCompleted: true,
            notes: nil,
            mood: nil
        )

        recordProcessedRemoteRecordID(recordID)

        #if !os(watchOS)
        self.pendingFeedbackRecordID = recordID
        UserDefaults.standard.set(recordID.uuidString, forKey: keyPendingFeedbackRecordID)
        #endif

        if let handler = self.onRemoteFastCompleted {
            handler(record)
        } else {
            self.pendingRemoteCompletedRecords.append(record)
        }
    }

    private func recordProcessedRemoteRecordID(_ id: UUID) {
        if !processedRemoteRecordIDs.contains(id) {
            processedRemoteRecordIDs.append(id)
            if processedRemoteRecordIDs.count > 25 {
                processedRemoteRecordIDs.removeFirst(processedRemoteRecordIDs.count - 25)
            }
            UserDefaults.standard.set(
                processedRemoteRecordIDs.map(\.uuidString),
                forKey: keyProcessedRemoteRecordIDs
            )
        }
    }

    private func completeActiveFastLocally(
        endTime: Date,
        recordID: UUID,
        notes: String? = nil,
        mood: String? = nil,
        mutationDate: Date
    ) -> FastRecord? {
        guard let start = activeStartTime else { return nil }
        let safeEndTime = max(start, endTime)

        let record = FastRecord(
            id: recordID,
            startTime: start,
            endTime: safeEndTime,
            targetDurationHours: activeTargetDuration / 3600.0,
            protocolName: activeProtocol.name,
            isCompleted: true,
            notes: notes,
            mood: mood
        )

        // Track and persist last completed fast end time for "Time since last fast"
        self.lastCompletedFastEndTime = safeEndTime
        UserDefaults.standard.set(safeEndTime.timeIntervalSince1970, forKey: keyLastCompletedEndTime)
        recordMutationDate(mutationDate)

        // Clear active fast state
        self.activeStartTime = nil
        clearPersistedActiveState()

        // Cancel notifications & dismiss Live Activity
        NotificationManager.shared.cancelAllFastingNotifications()
        LiveActivityManager.shared.endLiveActivity()
        syncComplications()

        return record
    }

    /// Cancels an active fast without saving a completed record.
    public func cancelFast() {
        let mutationDate = Date()
        recordMutationDate(mutationDate)
        self.activeStartTime = nil
        clearPersistedActiveState()

        NotificationManager.shared.cancelAllFastingNotifications()
        LiveActivityManager.shared.endLiveActivity()
        syncComplications()
        WatchSyncService.shared.sendCancelFast(sentAt: mutationDate)
    }

    /// Selects and persists the user's preferred fasting protocol (updates complications when idle).
    public func selectProtocol(_ fastingProtocol: FastingProtocol) {
        let clampedDuration = Self.clampedTargetDuration(fastingProtocol.fastingDuration)
        let safeProtocol = fastingProtocol.fastingDuration > Self.maxTargetDuration
            ? resolvedProtocol(for: clampedDuration, current: .warrior20_4)
            : fastingProtocol
        self.activeProtocol = safeProtocol
        self.activeTargetDuration = clampedDuration
        let defaults = UserDefaults.standard
        defaults.set(safeProtocol.id, forKey: keyProtocolId)
        defaults.set(clampedDuration, forKey: keyTargetDuration)
        syncComplications()
    }

    /// Atomically updates both start time and target duration of an ongoing fast in a single sync cycle,
    /// avoiding duplicate notifications, Live Activity IPC, complication reloads, and WatchConnectivity sends.
    public func updateOngoingFast(startTime newStartTime: Date, targetDuration newDuration: TimeInterval) {
        let clampedDuration = Self.clampedTargetDuration(newDuration)
        let resolvedProtocol = resolvedProtocol(for: clampedDuration, current: activeProtocol)

        if activeStartTime == nil {
            // If called from "Started earlier?" while idle, start the fast retroactively
            startFast(protocol: resolvedProtocol, startTime: min(Date(), newStartTime))
            return
        }

        let mutationDate = Date()
        self.activeStartTime = min(Date(), newStartTime)
        self.activeTargetDuration = clampedDuration
        self.activeProtocol = resolvedProtocol
        recordMutationDate(mutationDate)
        persistActiveState()

        syncNotifications()
        syncLiveActivity()
        syncComplications()

        if let start = activeStartTime {
            WatchSyncService.shared.sendStartFast(
                startTime: start,
                targetDuration: activeTargetDuration,
                protocolId: activeProtocol.id,
                sentAt: mutationDate
            )
        }
    }

    /// Retroactively updates the start time of an ongoing fast.
    public func updateStartTime(_ newStartTime: Date) {
        guard activeStartTime != nil else { return }
        let mutationDate = Date()
        self.activeStartTime = min(Date(), newStartTime)
        recordMutationDate(mutationDate)
        persistActiveState()

        syncNotifications()
        syncLiveActivity()
        syncComplications()

        if let start = activeStartTime {
            WatchSyncService.shared.sendStartFast(
                startTime: start,
                targetDuration: activeTargetDuration,
                protocolId: activeProtocol.id,
                sentAt: mutationDate
            )
        }
    }

    /// Changes the target duration of an ongoing or pending fast.
    public func updateTargetDuration(_ duration: TimeInterval) {
        let clampedDuration = Self.clampedTargetDuration(duration)
        self.activeTargetDuration = clampedDuration
        self.activeProtocol = resolvedProtocol(for: clampedDuration, current: activeProtocol)
        let defaults = UserDefaults.standard
        defaults.set(activeTargetDuration, forKey: keyTargetDuration)
        defaults.set(activeProtocol.id, forKey: keyProtocolId)
        persistActiveState()
        syncComplications()

        if let start = activeStartTime {
            let mutationDate = Date()
            recordMutationDate(mutationDate)
            syncNotifications()
            syncLiveActivity()

            WatchSyncService.shared.sendStartFast(
                startTime: start,
                targetDuration: activeTargetDuration,
                protocolId: activeProtocol.id,
                sentAt: mutationDate
            )
        }
    }

    private func resolvedProtocol(for duration: TimeInterval, current: FastingProtocol) -> FastingProtocol {
        if abs(current.fastingDuration - duration) < 1.0 {
            return current
        }
        return FastingProtocol.allPresets.first(where: { abs($0.fastingDuration - duration) < 60.0 })
            ?? .custom(hours: duration / 3600.0)
    }

    /// Selects and switches the visual theme.
    public func selectTheme(_ theme: AppTheme) {
        self.selectedTheme = theme
        UserDefaults.standard.set(theme.id, forKey: keyThemeId)

        if activeStartTime != nil {
            syncLiveActivity()
        }
    }

    /// Enables or disables Live Activities and immediately starts/dismisses any active Live Activity.
    public func setLiveActivitiesEnabled(_ enabled: Bool) {
        self.liveActivitiesEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: keyLiveActivitiesEnabled)
        syncLiveActivity()
    }

    /// Toggles whether the Live Activity timer counts up (elapsed) or down (remaining) and updates any active Live Activity immediately.
    public func setLiveActivityCountsUp(_ countsUp: Bool) {
        self.liveActivityCountsUp = countsUp
        UserDefaults.standard.set(countsUp, forKey: keyLiveActivityCountsUp)
        syncLiveActivity()
        syncComplications()
        WatchSyncService.shared.sendTimerPreference(countsUp: countsUp)
    }

    /// Opts in or out of private iCloud sync for fasting history (takes effect on next app launch).
    public func setICloudSyncEnabled(_ enabled: Bool) {
        self.iCloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: keyICloudSyncEnabled)
    }

    /// Records the user's acceptance of the first-launch medical disclaimer.
    public func acceptMedicalDisclaimer() {
        self.hasAcceptedMedicalDisclaimer = true
        UserDefaults.standard.set(true, forKey: keyHasAcceptedMedicalDisclaimer)
    }

    /// Persists notification preference for 1 hour before goal and updates pending notifications.
    public func setNotifyOneHourBefore(_ enabled: Bool) {
        self.notifyOneHourBefore = enabled
        UserDefaults.standard.set(enabled, forKey: keyNotifyOneHourBefore)
        syncNotifications()
    }

    /// Persists notification preference for goal reached and updates pending notifications.
    public func setNotifyTargetReached(_ enabled: Bool) {
        self.notifyTargetReached = enabled
        UserDefaults.standard.set(enabled, forKey: keyNotifyTargetReached)
        syncNotifications()
    }

    /// Persists notification preference for 1 hour overtime and updates pending notifications.
    public func setNotifyOneHourPast(_ enabled: Bool) {
        self.notifyOneHourPast = enabled
        UserDefaults.standard.set(enabled, forKey: keyNotifyOneHourPast)
        syncNotifications()
    }

    /// Reconciles pending local notifications with the current active fast and user preferences.
    public func syncNotifications(force: Bool = false) {
        guard let start = activeStartTime else {
            NotificationManager.shared.cancelPendingFastingNotifications()
            return
        }
        NotificationManager.shared.scheduleFastingNotifications(
            startTime: start,
            targetDuration: activeTargetDuration,
            protocolName: activeProtocol.name,
            notifyOneHourBefore: notifyOneHourBefore,
            notifyTargetReached: notifyTargetReached,
            notifyOneHourPast: notifyOneHourPast,
            force: force
        )
    }

    /// Reconciles the Live Activity with the current active fast state (called on start, edit, toggle, or app foreground).
    public func syncLiveActivity() {
        LiveActivityManager.shared.evaluateLiveActivity(
            isEnabled: liveActivitiesEnabled,
            startTime: activeStartTime,
            targetDuration: activeTargetDuration,
            protocolName: activeProtocol.name,
            themeID: selectedTheme.id,
            countsUp: liveActivityCountsUp
        )
    }

    /// Mirrors lightweight fasting state to the App Group and requests an event-driven watchOS complication reload
    /// ONLY when the shared snapshot actually changed (protects Watch battery & WidgetKit daily reload budget).
    public func syncComplications() {
        let snapshot = SharedFastingSnapshot(
            startTime: activeStartTime,
            targetDuration: activeTargetDuration,
            protocolName: activeProtocol.formattedRatio,
            lastCompletedFastEndTime: lastCompletedFastEndTime,
            countsUp: liveActivityCountsUp
        )
        let existing = SharedFastingStore.load()
        guard existing != snapshot else { return }
        SharedFastingStore.save(snapshot)
        #if os(watchOS) && canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedFastingStore.complicationKind)
        #endif
    }

    // MARK: - Snapshot & Calculations

    /// Computes the current real-time snapshot of the fasting state.
    public func calculateCurrentSnapshot(at now: Date = Date()) -> FastingSnapshot {
        guard let start = activeStartTime else {
            return .idle(
                currentProtocol: activeProtocol,
                lastCompletedEndTime: lastCompletedFastEndTime,
                at: now
            )
        }
        return FastingSnapshot.calculate(
            startTime: start,
            targetDuration: activeTargetDuration,
            protocol: activeProtocol,
            lastCompletedEndTime: lastCompletedFastEndTime,
            at: now
        )
    }

    /// Calculates current streak and longest streak from completed records.
    public func updateStreaks(from records: [FastRecord]) {
        if let latestEnd = records.filter({ $0.isCompleted }).compactMap(\.endTime).max() {
            if self.lastCompletedFastEndTime == nil || latestEnd > self.lastCompletedFastEndTime! {
                self.lastCompletedFastEndTime = latestEnd
                UserDefaults.standard.set(latestEnd.timeIntervalSince1970, forKey: keyLastCompletedEndTime)
                syncComplications()
            }
        }

        let streaks = calculateStreaks(from: records)
        self.currentStreak = streaks.current
        self.longestStreak = streaks.longest
    }

    public func calculateStreaks(from records: [FastRecord]) -> (current: Int, longest: Int) {
        let calendar = Calendar.current
        let completed = records.filter { $0.isCompleted && $0.isGoalAchieved }
        guard !completed.isEmpty else { return (0, 0) }

        // Group fast end dates by day
        let daySet = Set(completed.compactMap { record -> Date? in
            guard let end = record.endTime else { return nil }
            return calendar.startOfDay(for: end)
        })

        let sortedDays = daySet.sorted(by: >)
        guard let latestDay = sortedDays.first else { return (0, 0) }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

        // Streak is alive if user finished a fast today or yesterday
        var currentStreakCount = 0
        if latestDay == today || latestDay == yesterday {
            var checkDay = latestDay
            for day in sortedDays {
                if day == checkDay {
                    currentStreakCount += 1
                    guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
                    checkDay = prevDay
                } else if day < checkDay {
                    break
                }
            }
        }

        // Longest streak
        var longestStreakCount = 0
        var tempStreak = 0
        var expectedNextDay: Date? = nil

        for day in sortedDays.reversed() {
            if let expected = expectedNextDay {
                if day == expected {
                    tempStreak += 1
                } else {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            expectedNextDay = calendar.date(byAdding: .day, value: 1, to: day)
            longestStreakCount = max(longestStreakCount, tempStreak)
        }

        return (currentStreakCount, max(currentStreakCount, longestStreakCount))
    }

    /// Filters history according to Free (7-day window) vs. Pro (Lifetime).
    public func filterRecords(_ records: [FastRecord], isPro: Bool) -> [FastRecord] {
        if isPro {
            return records.sorted { $0.startTime > $1.startTime }
        }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        return records
            .filter { $0.startTime >= cutoffDate }
            .sorted { $0.startTime > $1.startTime }
    }

    // MARK: - State Persistence

    private func recordMutationDate(_ date: Date) {
        self.lastStateMutationDate = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: keyLastStateMutationDate)
    }

    private func persistActiveState() {
        let defaults = UserDefaults.standard
        if let start = activeStartTime {
            defaults.set(start.timeIntervalSince1970, forKey: keyStartTime)
            defaults.set(activeTargetDuration, forKey: keyTargetDuration)
            defaults.set(activeProtocol.id, forKey: keyProtocolId)
        }
    }

    private func clearPersistedActiveState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: keyStartTime)
    }

    /// Selects the tracker visual mode (Valley vs Classic Circular).
    public func setVisualMode(_ mode: TrackerVisualMode) {
        self.visualMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: keyVisualMode)
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard

        if let savedThemeId = defaults.string(forKey: keyThemeId) {
            self.selectedTheme = AppTheme.find(by: savedThemeId)
        }

        if let savedModeRaw = defaults.string(forKey: keyVisualMode),
           let mode = TrackerVisualMode(rawValue: savedModeRaw) {
            self.visualMode = mode
        }

        if defaults.object(forKey: keyLiveActivitiesEnabled) != nil {
            self.liveActivitiesEnabled = defaults.bool(forKey: keyLiveActivitiesEnabled)
        }

        if defaults.object(forKey: keyLiveActivityCountsUp) != nil {
            self.liveActivityCountsUp = defaults.bool(forKey: keyLiveActivityCountsUp)
        }

        if defaults.object(forKey: keyNotifyOneHourBefore) != nil {
            self.notifyOneHourBefore = defaults.bool(forKey: keyNotifyOneHourBefore)
        }

        if defaults.object(forKey: keyNotifyTargetReached) != nil {
            self.notifyTargetReached = defaults.bool(forKey: keyNotifyTargetReached)
        }

        if defaults.object(forKey: keyNotifyOneHourPast) != nil {
            self.notifyOneHourPast = defaults.bool(forKey: keyNotifyOneHourPast)
        }

        if defaults.object(forKey: keyICloudSyncEnabled) != nil {
            self.iCloudSyncEnabled = defaults.bool(forKey: keyICloudSyncEnabled)
        }
        self.launchICloudSyncEnabled = self.iCloudSyncEnabled

        if defaults.object(forKey: keyHasAcceptedMedicalDisclaimer) != nil {
            self.hasAcceptedMedicalDisclaimer = defaults.bool(forKey: keyHasAcceptedMedicalDisclaimer)
        }

        if let lastEndTimestamp = defaults.object(forKey: keyLastCompletedEndTime) as? Double {
            self.lastCompletedFastEndTime = Date(timeIntervalSince1970: lastEndTimestamp)
        }

        if let lastMutationTimestamp = defaults.object(forKey: keyLastStateMutationDate) as? Double {
            self.lastStateMutationDate = Date(timeIntervalSince1970: lastMutationTimestamp)
        }

        if let pendingIDString = defaults.string(forKey: keyPendingFeedbackRecordID),
           let pendingID = UUID(uuidString: pendingIDString) {
            self.pendingFeedbackRecordID = pendingID
        }

        if let processedStrings = defaults.stringArray(forKey: keyProcessedRemoteRecordIDs) {
            self.processedRemoteRecordIDs = processedStrings.compactMap { UUID(uuidString: $0) }
        }

        let savedTargetDuration = defaults.double(forKey: keyTargetDuration)
        if savedTargetDuration > 0 {
            self.activeTargetDuration = Self.clampedTargetDuration(savedTargetDuration)
        }

        if let protocolId = defaults.string(forKey: keyProtocolId) {
            if let preset = FastingProtocol.allPresets.first(where: { $0.id == protocolId }) {
                self.activeProtocol = preset
                if savedTargetDuration <= 0 {
                    self.activeTargetDuration = preset.fastingDuration
                }
            } else {
                let clamped = Self.clampedTargetDuration(self.activeTargetDuration)
                self.activeTargetDuration = clamped
                self.activeProtocol = FastingProtocol.allPresets.first(where: { abs($0.fastingDuration - clamped) < 60.0 })
                    ?? .custom(hours: clamped / 3600.0)
            }
        }

        if let startTimestamp = defaults.object(forKey: keyStartTime) as? Double {
            self.activeStartTime = Date(timeIntervalSince1970: startTimestamp)
        }
    }

    private func setupWatchSyncListeners() {
        WatchSyncService.shared.onReceiveStartFast = { [weak self] startTime, targetDuration, protocolId, sentAt in
            guard let self = self, sentAt > self.lastStateMutationDate else { return }
            let clampedDuration = Self.clampedTargetDuration(targetDuration)
            let proto = FastingProtocol.allPresets.first(where: { $0.id == protocolId })
                ?? FastingProtocol.allPresets.first(where: { abs($0.fastingDuration - clampedDuration) < 60.0 })
                ?? .custom(hours: clampedDuration / 3600.0)
            self.activeProtocol = proto
            self.activeTargetDuration = clampedDuration
            self.activeStartTime = startTime
            self.recordMutationDate(sentAt)
            self.persistActiveState()
            self.syncNotifications()
            self.syncLiveActivity()
            self.syncComplications()
        }

        WatchSyncService.shared.onReceiveEndFast = { [weak self] payload in
            self?.handleRemoteEndFast(payload)
        }

        WatchSyncService.shared.onReceiveCancelFast = { [weak self] sentAt in
            guard let self = self, sentAt > self.lastStateMutationDate else { return }
            self.recordMutationDate(sentAt)
            self.activeStartTime = nil
            self.clearPersistedActiveState()
            NotificationManager.shared.cancelAllFastingNotifications()
            LiveActivityManager.shared.endLiveActivity()
            self.syncComplications()
        }

        WatchSyncService.shared.onReceiveTimerPreference = { [weak self] countsUp in
            guard let self = self, self.liveActivityCountsUp != countsUp else { return }
            self.liveActivityCountsUp = countsUp
            UserDefaults.standard.set(countsUp, forKey: self.keyLiveActivityCountsUp)
            self.syncLiveActivity()
            self.syncComplications()
        }
    }
}
