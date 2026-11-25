import Testing
import Foundation
@testable import FastingAppCore

struct NotificationTests {

    @Test func testNotificationMilestoneMath() {
        let startTime = Date(timeIntervalSince1970: 1000000)
        let targetDuration: TimeInterval = 16 * 3600 // 16h = 57600s
        let targetEndTime = startTime.addingTimeInterval(targetDuration)

        let oneHourBefore = targetEndTime.addingTimeInterval(-3600)
        let oneHourPast = targetEndTime.addingTimeInterval(3600)

        #expect(oneHourBefore.timeIntervalSince(startTime) == 15 * 3600)
        #expect(targetEndTime.timeIntervalSince(startTime) == 16 * 3600)
        #expect(oneHourPast.timeIntervalSince(startTime) == 17 * 3600)
    }

    @Test @MainActor func testNotificationConstants() {
        #expect(NotificationManager.idOneHourBefore == "fasting_one_hour_before")
        #expect(NotificationManager.idTargetReached == "fasting_target_reached")
        #expect(NotificationManager.idOneHourPast == "fasting_one_hour_past")
        #expect(NotificationManager.categoryIdentifier == "FASTING_NOTIFICATION_CATEGORY")
    }
}
