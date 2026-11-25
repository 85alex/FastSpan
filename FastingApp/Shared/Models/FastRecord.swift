import Foundation
#if canImport(SwiftData)
import SwiftData

@Model
public final class FastRecord: Identifiable {
    public var id: UUID = UUID()
    public var startTime: Date = Date()
    public var endTime: Date?
    public var targetDurationHours: Double = 16.0
    public var protocolName: String = "16:8"
    public var isCompleted: Bool = false
    public var notes: String?
    public var mood: String?
    public var createdAt: Date = Date()

    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        targetDurationHours: Double = 16.0,
        protocolName: String = "16:8",
        isCompleted: Bool = false,
        notes: String? = nil,
        mood: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.targetDurationHours = targetDurationHours
        self.protocolName = protocolName
        self.isCompleted = isCompleted
        self.notes = notes
        self.mood = mood
        self.createdAt = createdAt
    }

    public var targetDuration: TimeInterval {
        targetDurationHours * 3600.0
    }

    public var actualDuration: TimeInterval {
        let end = endTime ?? Date()
        return max(0, end.timeIntervalSince(startTime))
    }

    public var actualDurationHours: Double {
        actualDuration / 3600.0
    }

    public var isGoalAchieved: Bool {
        actualDuration >= targetDuration
    }

    public var overtimeDuration: TimeInterval {
        max(0, actualDuration - targetDuration)
    }

    public var formattedDuration: String {
        let totalSeconds = Int(actualDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    public var formattedTarget: String {
        let hours = Int(targetDurationHours)
        let minutes = Int((targetDurationHours - Double(hours)) * 60)
        if minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(hours)h"
    }

    /// Creates a SwiftData `ModelContainer` configured for either private iCloud sync or local-only storage.
    public static func makeModelContainer(iCloudSyncEnabled: Bool) -> ModelContainer {
        makeModelContainerWithStatus(iCloudSyncEnabled: iCloudSyncEnabled).container
    }

    /// Creates a SwiftData `ModelContainer` and reports whether CloudKit sync actually activated
    /// (as opposed to falling back to local-only storage).
    public static func makeModelContainerWithStatus(iCloudSyncEnabled: Bool) -> (container: ModelContainer, isCloudKitActive: Bool) {
        let schema = Schema([FastRecord.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: iCloudSyncEnabled ? .automatic : .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return (container, iCloudSyncEnabled)
        } catch {
            // Fall back to local-only storage if CloudKit container initialization fails
            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                return (container, false)
            } catch {
                fatalError("Failed to initialize FastRecord ModelContainer: \(error)")
            }
        }
    }
}
#else
public final class FastRecord: Identifiable, Codable {
    public var id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var targetDurationHours: Double
    public var protocolName: String
    public var isCompleted: Bool
    public var notes: String?
    public var mood: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        targetDurationHours: Double = 16.0,
        protocolName: String = "16:8",
        isCompleted: Bool = false,
        notes: String? = nil,
        mood: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.targetDurationHours = targetDurationHours
        self.protocolName = protocolName
        self.isCompleted = isCompleted
        self.notes = notes
        self.mood = mood
        self.createdAt = createdAt
    }

    public var targetDuration: TimeInterval {
        targetDurationHours * 3600.0
    }

    public var actualDuration: TimeInterval {
        let end = endTime ?? Date()
        return max(0, end.timeIntervalSince(startTime))
    }

    public var actualDurationHours: Double {
        actualDuration / 3600.0
    }

    public var isGoalAchieved: Bool {
        actualDuration >= targetDuration
    }

    public var overtimeDuration: TimeInterval {
        max(0, actualDuration - targetDuration)
    }

    public var formattedDuration: String {
        let totalSeconds = Int(actualDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    public var formattedTarget: String {
        let hours = Int(targetDurationHours)
        let minutes = Int((targetDurationHours - Double(hours)) * 60)
        if minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(hours)h"
    }
}
#endif
