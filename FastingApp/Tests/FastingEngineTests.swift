import Testing
import Foundation
@testable import FastingAppCore

struct FastingEngineTests {

    @Test func testPresetsAndCustomProtocols() {
        let preset16 = FastingProtocol.standard16_8
        #expect(preset16.fastingHours == 16.0)
        #expect(preset16.eatingHours == 8.0)
        #expect(preset16.formattedRatio == "16:8")
        #expect(preset16.fastingDuration == 16.0 * 3600.0)

        let custom = FastingProtocol.custom(hours: 17.5)
        #expect(custom.fastingHours == 17.5)
        #expect(custom.isCustom == true)
        #expect(custom.formattedRatio == "17h 30m")
    }

    @Test func testSnapshotCalculation_ActiveFast() {
        let baseStart = Date(timeIntervalSince1970: 1000000)
        let now = baseStart.addingTimeInterval(8 * 3600) // 8 hours in
        let proto = FastingProtocol.standard16_8

        let snapshot = FastingSnapshot.calculate(
            startTime: baseStart,
            targetDuration: 16 * 3600,
            protocol: proto,
            at: now
        )

        #expect(snapshot.phase == .active)
        #expect(snapshot.elapsedTime == 8 * 3600)
        #expect(snapshot.remainingTime == 8 * 3600)
        #expect(snapshot.progressFraction == 0.5)
        #expect(snapshot.percentageString == "50%")
    }

    @Test func testSnapshotCalculation_TargetReachedAndOvertime() {
        let baseStart = Date(timeIntervalSince1970: 1000000)
        let proto = FastingProtocol.standard16_8

        // Exactly at 16 hours
        let nowAtGoal = baseStart.addingTimeInterval(16 * 3600)
        let snapGoal = FastingSnapshot.calculate(
            startTime: baseStart,
            targetDuration: 16 * 3600,
            protocol: proto,
            at: nowAtGoal
        )
        #expect(snapGoal.phase == .targetReached)
        #expect(snapGoal.progressFraction == 1.0)
        #expect(snapGoal.remainingTime == 0)

        // 17.5 hours in (overtime)
        let nowOvertime = baseStart.addingTimeInterval(17.5 * 3600)
        let snapOvertime = FastingSnapshot.calculate(
            startTime: baseStart,
            targetDuration: 16 * 3600,
            protocol: proto,
            at: nowOvertime
        )
        #expect(snapOvertime.phase == .overtime)
        #expect(snapOvertime.overtimeTime == 1.5 * 3600)
        #expect(snapOvertime.totalProgressFraction > 1.0)
    }

    @Test @MainActor func testStreakCalculation() {
        let manager = FastingManager.shared
        let calendar = Calendar.current
        let today = Date()

        guard let day1 = calendar.date(byAdding: .day, value: -2, to: today),
              let day2 = calendar.date(byAdding: .day, value: -1, to: today),
              let day3 = calendar.date(byAdding: .day, value: 0, to: today) else {
            return
        }

        let record1 = FastRecord(
            startTime: day1.addingTimeInterval(-16 * 3600),
            endTime: day1,
            targetDurationHours: 16,
            isCompleted: true
        )

        let record2 = FastRecord(
            startTime: day2.addingTimeInterval(-16 * 3600),
            endTime: day2,
            targetDurationHours: 16,
            isCompleted: true
        )

        let record3 = FastRecord(
            startTime: day3.addingTimeInterval(-16 * 3600),
            endTime: day3,
            targetDurationHours: 16,
            isCompleted: true
        )

        let streaks = manager.calculateStreaks(from: [record1, record2, record3])
        #expect(streaks.current == 3)
        #expect(streaks.longest == 3)
    }
}
