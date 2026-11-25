import Foundation

/// Lightweight, SwiftData-free snapshot of fasting state mirrored into the App Group
/// so watchOS complications can read state in <1ms with minimal memory footprint.
public struct SharedFastingSnapshot: Equatable, Sendable {
    public let startTime: Date?
    public let targetDuration: TimeInterval
    public let protocolName: String
    public let lastCompletedFastEndTime: Date?
    public let countsUp: Bool

    public var isFasting: Bool { startTime != nil }

    public var targetEndTime: Date? {
        guard let startTime else { return nil }
        return startTime.addingTimeInterval(max(60, targetDuration))
    }

    public init(
        startTime: Date? = nil,
        targetDuration: TimeInterval = 16.0 * 3600.0,
        protocolName: String = "16:8",
        lastCompletedFastEndTime: Date? = nil,
        countsUp: Bool = false
    ) {
        self.startTime = startTime
        self.targetDuration = targetDuration
        self.protocolName = protocolName
        self.lastCompletedFastEndTime = lastCompletedFastEndTime
        self.countsUp = countsUp
    }
}

/// App Group UserDefaults bridge between FastSpanWatch and FastSpanWatchWidgets.
public enum SharedFastingStore {
    public static let appGroupIdentifier = "group.com.alexpandelidis.fastspan"
    public static let complicationKind = "FastingComplications"

    private static let keyStartTime = "shared_fasting_start_time"
    private static let keyTargetDuration = "shared_fasting_target_duration"
    private static let keyProtocolName = "shared_fasting_protocol_name"
    private static let keyLastCompletedEndTime = "shared_fasting_last_completed_end_time"
    private static let keyCountsUp = "shared_fasting_counts_up"

    public static func resolvedDefaults(suiteName: String = appGroupIdentifier) -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    public static func save(
        _ snapshot: SharedFastingSnapshot,
        defaults: UserDefaults = resolvedDefaults()
    ) {
        if let start = snapshot.startTime {
            defaults.set(start.timeIntervalSince1970, forKey: keyStartTime)
        } else {
            defaults.removeObject(forKey: keyStartTime)
        }

        defaults.set(snapshot.targetDuration, forKey: keyTargetDuration)
        defaults.set(snapshot.protocolName, forKey: keyProtocolName)
        defaults.set(snapshot.countsUp, forKey: keyCountsUp)

        if let lastEnd = snapshot.lastCompletedFastEndTime {
            defaults.set(lastEnd.timeIntervalSince1970, forKey: keyLastCompletedEndTime)
        } else {
            defaults.removeObject(forKey: keyLastCompletedEndTime)
        }
    }

    public static func load(
        defaults: UserDefaults = resolvedDefaults()
    ) -> SharedFastingSnapshot {
        let startTime: Date?
        if let startTimestamp = defaults.object(forKey: keyStartTime) as? Double {
            startTime = Date(timeIntervalSince1970: startTimestamp)
        } else {
            startTime = nil
        }

        let storedDuration = defaults.double(forKey: keyTargetDuration)
        let targetDuration = storedDuration > 0 ? storedDuration : 16.0 * 3600.0

        let protocolName = defaults.string(forKey: keyProtocolName) ?? "16:8"

        let lastCompletedEndTime: Date?
        if let endTimestamp = defaults.object(forKey: keyLastCompletedEndTime) as? Double {
            lastCompletedEndTime = Date(timeIntervalSince1970: endTimestamp)
        } else {
            lastCompletedEndTime = nil
        }

        let countsUp = defaults.bool(forKey: keyCountsUp)

        return SharedFastingSnapshot(
            startTime: startTime,
            targetDuration: targetDuration,
            protocolName: protocolName,
            lastCompletedFastEndTime: lastCompletedEndTime,
            countsUp: countsUp
        )
    }
}
