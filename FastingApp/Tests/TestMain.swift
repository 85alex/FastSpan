import Foundation
@testable import FastingAppCore

@main
struct TestMain {
    @MainActor
    static func main() {
        print("========================================")
        print("🧪 RUNNING FASTSPAN COMPREHENSIVE TEST SUITE")
        print("========================================\n")

        var passed = 0
        var failed = 0

        func assertTest(_ name: String, _ condition: Bool) {
            if condition {
                print("  ✅ PASS: \(name)")
                passed += 1
            } else {
                print("  ❌ FAIL: \(name)")
                failed += 1
            }
        }

        // --- 1. Protocols & Presets Tests ---
        print("▶️ [1/6] Testing Fasting Protocols & Presets...")
        let standard16 = FastingProtocol.standard16_8
        assertTest("16:8 Fasting Duration is 16 hours", standard16.fastingHours == 16.0 && standard16.fastingDuration == 57600.0)
        assertTest("16:8 Eating window is 8 hours", standard16.eatingHours == 8.0)
        assertTest("16:8 Formatted ratio is '16:8'", standard16.formattedRatio == "16:8")

        let custom17_5 = FastingProtocol.custom(hours: 17.5)
        assertTest("Custom 17.5h Protocol computes correct ratio", custom17_5.formattedRatio == "17h 30m" && custom17_5.isCustom)
        assertTest("13:11 Circadian fast is 13 hours", FastingProtocol.circadian13_11.fastingHours == 13.0)
        assertTest("All presets count is 8", FastingProtocol.allPresets.count == 8)

        // --- 2. Live Fasting Snapshot & Overtime Math ---
        print("\n▶️ [2/6] Testing Timer Engine & Snapshot Math...")
        let baseStart = Date(timeIntervalSince1970: 1000000)

        // 8h in (50%)
        let now8h = baseStart.addingTimeInterval(8 * 3600)
        let snap8h = FastingSnapshot.calculate(startTime: baseStart, targetDuration: 16 * 3600, protocol: standard16, at: now8h)
        assertTest("Phase is active at 8h", snap8h.phase == .active)
        assertTest("Elapsed is 8h & Remaining is 8h", snap8h.elapsedTime == 28800 && snap8h.remainingTime == 28800)
        assertTest("Progress fraction is 0.50 (50%)", snap8h.progressFraction == 0.5 && snap8h.percentageString == "50%")

        // 16h in (Goal reached)
        let now16h = baseStart.addingTimeInterval(16 * 3600)
        let snap16h = FastingSnapshot.calculate(startTime: baseStart, targetDuration: 16 * 3600, protocol: standard16, at: now16h)
        assertTest("Phase is targetReached at 16h", snap16h.phase == .targetReached)
        assertTest("Progress fraction is 1.0", snap16h.progressFraction == 1.0 && snap16h.remainingTime == 0)

        // 18h in (Overtime)
        let now18h = baseStart.addingTimeInterval(18 * 3600)
        let snap18h = FastingSnapshot.calculate(startTime: baseStart, targetDuration: 16 * 3600, protocol: standard16, at: now18h)
        assertTest("Phase is overtime at 18h (>1h past goal)", snap18h.phase == .overtime)
        assertTest("Overtime duration is 2 hours", snap18h.overtimeTime == 7200)
        assertTest("Total progress fraction exceeds 1.0", snap18h.totalProgressFraction == 1.125)

        // Time Since Last Fast (Eating Window)
        let lastFastEnd = baseStart.addingTimeInterval(16 * 3600)
        let nowEating = lastFastEnd.addingTimeInterval(3.5 * 3600) // 3h 30m eating
        let snapIdle = FastingSnapshot.idle(currentProtocol: standard16, lastCompletedEndTime: lastFastEnd, at: nowEating)
        assertTest("Time since last fast is 3.5 hours (12600s)", snapIdle.timeSinceLastFast == 12600)
        assertTest("Formatted time since last fast is 03:30:00", snapIdle.formattedTimeSinceLastFast == "03:30:00")
        assertTest("Short formatted time is '3h 30m'", snapIdle.formattedTimeSinceLastFastShort == "3h 30m")

        // --- 3. Streak Engine ---
        print("\n▶️ [3/6] Testing Streak Engine...")
        let manager = FastingManager.shared
        let calendar = Calendar.current
        let today = Date()

        if let day1 = calendar.date(byAdding: .day, value: -2, to: today),
           let day2 = calendar.date(byAdding: .day, value: -1, to: today),
           let day3 = calendar.date(byAdding: .day, value: 0, to: today) {

            let record1 = FastRecord(startTime: day1.addingTimeInterval(-16 * 3600), endTime: day1, targetDurationHours: 16, isCompleted: true)
            let record2 = FastRecord(startTime: day2.addingTimeInterval(-16 * 3600), endTime: day2, targetDurationHours: 16, isCompleted: true)
            let record3 = FastRecord(startTime: day3.addingTimeInterval(-16 * 3600), endTime: day3, targetDurationHours: 16, isCompleted: true)

            let streaks = manager.calculateStreaks(from: [record1, record2, record3])
            assertTest("Current streak is 3 consecutive days", streaks.current == 3)
            assertTest("Longest streak is 3 consecutive days", streaks.longest == 3)
        }

        // --- 4. 3-Stage Notifications & Milestone Windows ---
        print("\n▶️ [4/6] Testing 3-Stage Notification Calculations...")
        let targetDuration: TimeInterval = 16 * 3600
        let targetEnd = baseStart.addingTimeInterval(targetDuration)
        let oneHourBefore = targetEnd.addingTimeInterval(-3600)
        let oneHourPast = targetEnd.addingTimeInterval(3600)

        assertTest("1 Hour Before is exactly target - 3600s", oneHourBefore.timeIntervalSince(baseStart) == 15 * 3600)
        assertTest("Target End is exactly target", targetEnd.timeIntervalSince(baseStart) == 16 * 3600)
        assertTest("1 Hour Past is exactly target + 3600s", oneHourPast.timeIntervalSince(baseStart) == 17 * 3600)

        // --- 5. Pro StoreKit Gating & CSV Export ---
        print("\n▶️ [5/6] Testing Pro Feature Gating & CSV Export...")
        assertTest("Pro features count is 4", ProFeature.allCases.count == 4)
        assertTest("Slate Minimal is Free", AppTheme.slateMinimal.isPro == false)
        assertTest("Solar Amber is Free", AppTheme.solarAmber.isPro == false)
        assertTest("Deep Midnight is Pro", AppTheme.deepMidnight.isPro == true)
        assertTest("Cyber Neon is Pro", AppTheme.cyberNeon.isPro == true)

        let now = Date()
        let recent1 = FastRecord(startTime: now.addingTimeInterval(-1 * 86400), isCompleted: true)
        let recent2 = FastRecord(startTime: now.addingTimeInterval(-3 * 86400), isCompleted: true)
        let old1 = FastRecord(startTime: now.addingTimeInterval(-10 * 86400), isCompleted: true)
        let old2 = FastRecord(startTime: now.addingTimeInterval(-20 * 86400), isCompleted: true)

        let allRecords = [recent1, recent2, old1, old2]
        let freeHistory = manager.filterRecords(allRecords, isPro: false)
        let proHistory = manager.filterRecords(allRecords, isPro: true)

        assertTest("Free tier limits history to last 7 days (2 records)", freeHistory.count == 2)
        assertTest("Pro tier provides full lifetime history (4 records)", proHistory.count == 4)

        // CSV Export formatting test
        let exportRecord = FastRecord(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            startTime: Date(timeIntervalSince1970: 1700000000),
            endTime: Date(timeIntervalSince1970: 1700057600),
            targetDurationHours: 16.0,
            protocolName: "16:8 LeanGains",
            isCompleted: true,
            notes: "Note with, comma and \"quotes\"",
            mood: "⚡ Energized"
        )
        let csvOutput = CSVExportService.shared.generateCSVString(from: [exportRecord])
        assertTest("CSV contains header row", csvOutput.contains("ID,Start Time,End Time,Target Hours,Actual Hours,Status,Protocol Name,Notes,Mood"))
        assertTest("CSV escapes quotes and commas correctly", csvOutput.contains("\"Note with, comma and \"\"quotes\"\"\""))
        assertTest("CSV includes record ID", csvOutput.contains("11111111-2222-3333-4444-555555555555"))

        // --- 6. Valley Arc & Diurnal Atmospheric Transitions ---
        print("\n▶️ [6/6] Testing Valley Arc & Diurnal Atmosphere...")
        assertTest("Visual modes available include Valley and Circular", TrackerVisualMode.allCases.count == 2)
        assertTest("Valley default icon is mountain.2.fill", TrackerVisualMode.valley.iconName == "mountain.2.fill")

        let duskAtmosphere = AtmosphericPalette.forProgress(0.1, phase: .active)
        assertTest("0.1 progress gives Golden Sunset atmosphere", duskAtmosphere.phaseLabel.contains("SUNSET") || duskAtmosphere.phaseLabel.contains("DUSK"))

        let midnightAtmosphere = AtmosphericPalette.forProgress(0.5, phase: .active)
        assertTest("0.5 progress gives Deep Night Purple atmosphere", midnightAtmosphere.phaseLabel.contains("PURPLE") || midnightAtmosphere.phaseLabel.contains("MIDNIGHT") || midnightAtmosphere.phaseLabel.contains("NIGHT"))

        let dawnAtmosphere = AtmosphericPalette.forProgress(0.95, phase: .active)
        assertTest("0.95 progress gives Golden Morning atmosphere", dawnAtmosphere.phaseLabel.contains("MORNING") || dawnAtmosphere.phaseLabel.contains("DAWN") || dawnAtmosphere.phaseLabel.contains("SUNRISE"))

        let overtimeAtmosphere = AtmosphericPalette.forProgress(1.2, phase: .overtime)
        assertTest("Overtime gives Overtime Sunrise atmosphere", overtimeAtmosphere.phaseLabel.contains("OVERTIME"))

        // --- 7. iCloud Sync Preference ---
        print("\n▶️ [7/7] Testing iCloud Sync Opt-In / Opt-Out Preference...")
        let syncDefaultsKey = "fasting_icloud_sync_enabled"
        let savedSyncPref = UserDefaults.standard.object(forKey: syncDefaultsKey)
        UserDefaults.standard.removeObject(forKey: syncDefaultsKey)
        let freshManager = FastingManager()
        assertTest("iCloud sync defaults to ON", freshManager.iCloudSyncEnabled == true)
        assertTest("No restart needed initially", freshManager.iCloudSyncNeedsRestart == false)
        freshManager.setICloudSyncEnabled(false)
        assertTest("iCloud sync can be opted out", freshManager.iCloudSyncEnabled == false)
        assertTest("Restart flagged after toggling off", freshManager.iCloudSyncNeedsRestart == true)
        let reloadedManager = FastingManager()
        assertTest("Opt-out persists across reloads", reloadedManager.iCloudSyncEnabled == false)
        assertTest("Fresh launch after reload does not require restart", reloadedManager.iCloudSyncNeedsRestart == false)
        if let saved = savedSyncPref {
            UserDefaults.standard.set(saved, forKey: syncDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: syncDefaultsKey)
        }

        // --- 8. SharedFastingStore Complication Bridge ---
        print("\n▶️ [8/8] Testing SharedFastingStore Complication Bridge...")
        let suiteName = "com.alexpandelidis.fastspan.tests.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let lastEnd = Date(timeIntervalSince1970: 1_699_950_000)
        let savedSnap = SharedFastingSnapshot(
            startTime: start,
            targetDuration: 18 * 3600,
            protocolName: "18:6",
            lastCompletedFastEndTime: lastEnd,
            countsUp: true
        )
        SharedFastingStore.save(savedSnap, defaults: testDefaults)
        let loadedSnap = SharedFastingStore.load(defaults: testDefaults)
        assertTest("SharedFastingStore round-trips startTime", loadedSnap.startTime == start)
        assertTest("SharedFastingStore round-trips targetDuration", loadedSnap.targetDuration == 18 * 3600)
        assertTest("SharedFastingStore round-trips protocolName", loadedSnap.protocolName == "18:6")
        assertTest("SharedFastingStore round-trips lastCompletedFastEndTime", loadedSnap.lastCompletedFastEndTime == lastEnd)
        assertTest("SharedFastingStore round-trips countsUp", loadedSnap.countsUp == true)
        assertTest("SharedFastingStore computes targetEndTime", loadedSnap.targetEndTime == start.addingTimeInterval(18 * 3600))

        let idleSnap = SharedFastingSnapshot(
            startTime: nil,
            targetDuration: 16 * 3600,
            protocolName: "16:8",
            lastCompletedFastEndTime: lastEnd,
            countsUp: false
        )
        SharedFastingStore.save(idleSnap, defaults: testDefaults)
        let loadedIdle = SharedFastingStore.load(defaults: testDefaults)
        assertTest("SharedFastingStore clears startTime when idle", loadedIdle.startTime == nil && !loadedIdle.isFasting)
        assertTest("SharedFastingStore preserves eating window end time", loadedIdle.lastCompletedFastEndTime == lastEnd)
        assertTest("SharedFastingSnapshot equality detects unchanged state for complication dedup", loadedIdle == idleSnap)
        testDefaults.removePersistentDomain(forName: suiteName)

        // --- 9. Bug Fixes & Battery Optimization Regression Tests ---
        print("\n▶️ [9/9] Testing Bug Fixes & Battery Optimization Regressions...")
        let defaults = UserDefaults.standard
        let backupKeys = [
            "fasting_active_start_time",
            "fasting_active_target_duration",
            "fasting_active_protocol_id",
            "fasting_last_completed_end_time",
            "fasting_last_state_mutation_date"
        ]
        var backedUpValues: [String: Any] = [:]
        for key in backupKeys {
            if let val = defaults.object(forKey: key) {
                backedUpValues[key] = val
            }
            defaults.removeObject(forKey: key)
        }

        // 9a. Protocol selection persists across launches when idle
        let protoManager = FastingManager()
        protoManager.selectProtocol(.warrior20_4)
        let reloadedProtoManager = FastingManager()
        assertTest("Selected protocol persists when idle across reloads", reloadedProtoManager.activeProtocol.id == FastingProtocol.warrior20_4.id)
        assertTest("Selected target duration persists when idle", reloadedProtoManager.activeTargetDuration == 20.0 * 3600.0)

        // 9b. "Started earlier?" (updateOngoingFast while idle) starts fast retroactively
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        reloadedProtoManager.updateOngoingFast(startTime: twoHoursAgo, targetDuration: 18 * 3600)
        assertTest("updateOngoingFast starts fast retroactively when idle", reloadedProtoManager.activeStartTime != nil)
        assertTest("Retroactive fast updates protocol to matching 18:6 preset", reloadedProtoManager.activeProtocol.id == FastingProtocol.moderate18_6.id)
        assertTest("Retroactive fast preserves earlier start time", abs((reloadedProtoManager.activeStartTime ?? .distantPast).timeIntervalSince(twoHoursAgo)) < 2.0)

        // 9c. Editing target duration to custom hours updates activeProtocol too
        reloadedProtoManager.updateOngoingFast(startTime: twoHoursAgo, targetDuration: 17.5 * 3600)
        assertTest("Custom duration edit updates protocol to custom 17.5h", reloadedProtoManager.activeProtocol.isCustom && reloadedProtoManager.activeProtocol.fastingHours == 17.5)

        // 9d. endFast clamps endTime >= startTime
        let earlierThanStart = twoHoursAgo.addingTimeInterval(-3600)
        let clampedRecord = reloadedProtoManager.endFast(endTime: earlierThanStart)
        assertTest("endFast returns completed record", clampedRecord != nil)
        assertTest("endFast clamps endTime >= startTime", (clampedRecord?.endTime ?? .distantPast) >= (clampedRecord?.startTime ?? .distantFuture))

        // 9e. updateStreaks finds latest completed endTime even when records are unsorted
        let oldEnd = Date().addingTimeInterval(-48 * 3600)
        let newerEnd = Date().addingTimeInterval(-1 * 3600)
        let olderRec = FastRecord(startTime: oldEnd.addingTimeInterval(-16 * 3600), endTime: oldEnd, targetDurationHours: 16, isCompleted: true)
        let newerRec = FastRecord(startTime: newerEnd.addingTimeInterval(-16 * 3600), endTime: newerEnd, targetDurationHours: 16, isCompleted: true)
        let streakManager = FastingManager()
        streakManager.lastCompletedFastEndTime = nil
        streakManager.updateStreaks(from: [olderRec, newerRec]) // intentionally unsorted (oldest first)
        assertTest("updateStreaks selects true max endTime from unsorted records", streakManager.lastCompletedFastEndTime == newerEnd)

        // 9f. Always-On Display HH:MM formatters & targetReached atmosphere
        assertTest("Elapsed HM formatter omits seconds", snap8h.formattedElapsedTimeHM == "08:00")
        assertTest("Remaining HM formatter omits seconds", snap8h.formattedRemainingTimeHM == "08:00")
        assertTest("Overtime HM formatter omits seconds", snap18h.formattedOvertimeTimeHM == "+02:00")
        assertTest("Eating window HM formatter omits seconds", snapIdle.formattedTimeSinceLastFastHM == "03:30")
        let goalAtmosphere = AtmosphericPalette.forProgress(1.0, phase: .targetReached)
        assertTest("targetReached phase produces GOAL REACHED atmosphere", goalAtmosphere.phaseLabel == "GOAL REACHED")

        // Restore UserDefaults
        for key in backupKeys {
            if let val = backedUpValues[key] {
                defaults.set(val, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        print("\n========================================")
        print("🎉 TEST RESULTS SUMMARY")
        print("Passed: \(passed) | Failed: \(failed)")
        print("========================================")
        if failed > 0 {
            exit(1)
        }
    }
}
