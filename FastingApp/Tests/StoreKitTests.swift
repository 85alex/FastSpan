import Testing
import Foundation
@testable import FastingAppCore

struct StoreKitTests {

    @Test @MainActor func testProFeaturesMetadata() {
        let features = ProFeature.allCases
        #expect(features.count == 4)

        let dynamicIsland = ProFeature.dynamicIsland
        #expect(dynamicIsland.title == "Smart Dynamic Island")

        let themes = ProFeature.premiumThemes
        #expect(themes.title == "All Visual Themes")

        let history = ProFeature.unlimitedHistory
        #expect(history.title == "Unlimited Lifetime History")

        let csv = ProFeature.csvExport
        #expect(csv.title == "Full CSV Data Export")
    }

    @Test @MainActor func testThemeFreeVsProClassification() {
        let slate = AppTheme.slateMinimal
        let solar = AppTheme.solarAmber
        let midnight = AppTheme.deepMidnight
        let emerald = AppTheme.emeraldZen
        let coral = AppTheme.sunsetCoral
        let cyber = AppTheme.cyberNeon

        #expect(slate.isPro == false)
        #expect(solar.isPro == false)
        #expect(midnight.isPro == true)
        #expect(emerald.isPro == true)
        #expect(coral.isPro == true)
        #expect(cyber.isPro == true)
    }

    @Test @MainActor func testHistoryFilteringFreeVsPro() {
        let manager = FastingManager.shared
        let now = Date()

        // 3 recent fasts (within last 7 days)
        let recent1 = FastRecord(startTime: now.addingTimeInterval(-1 * 86400), isCompleted: true)
        let recent2 = FastRecord(startTime: now.addingTimeInterval(-3 * 86400), isCompleted: true)
        let recent3 = FastRecord(startTime: now.addingTimeInterval(-5 * 86400), isCompleted: true)

        // 2 older fasts (10 days and 20 days ago)
        let old1 = FastRecord(startTime: now.addingTimeInterval(-10 * 86400), isCompleted: true)
        let old2 = FastRecord(startTime: now.addingTimeInterval(-20 * 86400), isCompleted: true)

        let allRecords = [recent1, recent2, recent3, old1, old2]

        // Free tier test -> returns only recent 3
        let freeResults = manager.filterRecords(allRecords, isPro: false)
        #expect(freeResults.count == 3)

        // Pro tier test -> returns all 5
        let proResults = manager.filterRecords(allRecords, isPro: true)
        #expect(proResults.count == 5)
    }
}
