import SwiftUI
#if canImport(SwiftData)
import SwiftData
#endif

/// Flagship FastSpan home screen featuring diurnal sunset-to-sunrise background transitions (Yellow -> Red -> Purple -> Yellow),
/// ultra-smooth dipped-line horizon tracker, and interactive drag-to-preview scrubbing.
public struct MainTrackerView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if canImport(SwiftData)
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FastRecord.startTime, order: .reverse) private var allRecords: [FastRecord]
    #else
    @State private var allRecords: [FastRecord] = []
    #endif

    @State private var fastingManager = FastingManager.shared
    @State private var storeManager = StoreManager.shared

    @State private var showProtocolPicker: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var showCompleteSheet: Bool = false
    @State private var showHistorySheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showCancelConfirmation: Bool = false
    @State private var justCompletedRecord: FastRecord? = nil

    // Interactive Drag-to-Preview Scrubbing State
    @State private var scrubFraction: Double? = nil

    public init() {}

    private var isModalCoveringTracker: Bool {
        showProtocolPicker || showEditSheet || showCompleteSheet || showHistorySheet || showSettingsSheet || showPaywall || justCompletedRecord != nil
    }

    private var isTimelinePaused: Bool {
        scenePhase != .active
            || isModalCoveringTracker
            || (fastingManager.activeStartTime == nil && fastingManager.lastCompletedFastEndTime == nil)
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isTimelinePaused {
                    trackerContent(at: Date())
                } else {
                    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                        trackerContent(at: timeline.date)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showProtocolPicker) {
                ProtocolPickerView(currentProtocol: fastingManager.activeProtocol) { chosen in
                    fastingManager.selectProtocol(chosen)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                FastDetailSheet(
                    mode: fastingManager.activeStartTime == nil ? .startRetroactive : .editOngoing,
                    initialStartTime: fastingManager.activeStartTime ?? Date(),
                    initialTargetHours: fastingManager.activeTargetDuration / 3600.0,
                    onSaveEdit: { newStart, newTargetHours in
                        fastingManager.updateOngoingFast(
                            startTime: newStart,
                            targetDuration: newTargetHours * 3600.0
                        )
                    }
                )
            }
            .sheet(isPresented: $showCompleteSheet) {
                FastDetailSheet(
                    mode: .completeFast,
                    onConfirmComplete: { notes, mood in
                        if let record = fastingManager.endFast(notes: notes, mood: mood) {
                            #if canImport(SwiftData)
                            modelContext.insert(record)
                            try? modelContext.save()
                            #endif
                            fastingManager.updateStreaks(from: [record] + allRecords)
                            self.justCompletedRecord = record
                        }
                    }
                )
            }
            .sheet(item: $justCompletedRecord) { record in
                ShareSheetModal(
                    record: record,
                    theme: fastingManager.selectedTheme,
                    streak: fastingManager.currentStreak
                )
            }
            .sheet(isPresented: $showHistorySheet) {
                HistoryView()
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsThemeView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Cancel Current Fast?", isPresented: $showCancelConfirmation) {
                Button("Keep Fasting", role: .cancel) {}
                Button("Cancel Fast", role: .destructive) {
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    #endif
                    withAnimation {
                        fastingManager.cancelFast()
                    }
                }
            } message: {
                Text("This will discard your current fast without saving it to your history.")
            }
            .onAppear {
                fastingManager.updateStreaks(from: allRecords)
                consumePendingEndFastIfNeeded()
            }
            .onChange(of: allRecords.count) { _, _ in
                fastingManager.updateStreaks(from: allRecords)
            }
            .onReceive(NotificationCenter.default.publisher(for: .fastSpanRequestEndFast)) { _ in
                consumePendingEndFastIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func trackerContent(at date: Date) -> some View {
        let snapshot = fastingManager.calculateCurrentSnapshot(at: date)
        let effectiveProgress = scrubFraction ?? snapshot.progressFraction
        let effectivePhase: FastingPhase = scrubFraction != nil
            ? (scrubFraction! >= 1.0 ? .targetReached : .active)
            : snapshot.phase

        let atmosphere = AtmosphericPalette.forProgress(effectiveProgress, phase: effectivePhase)

        ZStack {
            // Dynamic Sunset-to-Sunrise Diurnal Background:
            // Bright Yellow (Morning) -> Sunset Red -> Midnight Purple (Middle of night) -> Dawn Red/Orange -> Bright Yellow (End)
            LinearGradient(
                colors: [atmosphere.topColor, atmosphere.bottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                // Top Header Bar
                headerBar(atmosphere: atmosphere)

                // Diurnal / Scrubbing Phase Badge
                phaseStatusBadge(snapshot: snapshot, atmosphere: atmosphere, effectiveProgress: effectiveProgress)

                Spacer()

                // Dipped-Line Horizon Tracker with Smooth Curve & Interactive Drag-to-Preview
                dippedLineTracker(snapshot: snapshot, atmosphere: atmosphere)

                // Metric Pills Row
                metricPillsRow(snapshot: snapshot, atmosphere: atmosphere)

                Spacer()

                // Bottom Action Controls
                bottomActionControls(snapshot: snapshot, atmosphere: atmosphere)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Top Header Bar
    private func consumePendingEndFastIfNeeded() {
        if NotificationManager.shared.consumePendingEndFastAction(),
           fastingManager.activeStartTime != nil {
            showCompleteSheet = true
        }
    }

    private func headerBar(atmosphere: AtmosphericPalette) -> some View {
        HStack {
            // Gear Settings Button
            Button {
                showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.25))
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    )
            }

            Spacer()

            // App Brand
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Text("FASTSPAN")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(Color.white)

                    if storeManager.isProUnlocked {
                        ProBadgeView(size: 9)
                    }
                }

                Text(fastingManager.activeProtocol.name.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Color.white.opacity(0.85))
            }

            Spacer()

            // History Button
            Button {
                showHistorySheet = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.25))
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    )
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Phase / Scrubbing Status Badge
    private func phaseStatusBadge(snapshot: FastingSnapshot, atmosphere: AtmosphericPalette, effectiveProgress: Double) -> some View {
        Group {
            if scrubFraction != nil {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.9, blue: 0.4))
                    Text("TIME TRAVEL PREVIEW")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.40))
                        .overlay(Capsule().stroke(Color.white.opacity(0.30), lineWidth: 1))
                )
            } else if snapshot.phase != .idle {
                HStack(spacing: 6) {
                    Image(systemName: atmosphere.phaseIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text(atmosphere.phaseLabel)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Dipped-Line Horizon Tracker with Smooth Curve & Interactive Drag
    private func dippedLineTracker(snapshot: FastingSnapshot, atmosphere: AtmosphericPalette) -> some View {
        let startTimeStr: String? = snapshot.startTime != nil ? formatClockTime(snapshot.startTime!) : nil
        let endTimeStr: String? = snapshot.targetEndTime != nil ? formatClockTime(snapshot.targetEndTime!) : nil

        return ZStack {
            ValleyProgressView(
                progress: snapshot.progressFraction,
                totalProgress: snapshot.totalProgressFraction,
                phase: snapshot.phase,
                lineWidth: 5,
                showLabels: true,
                startTimeLabel: startTimeStr,
                endTimeLabel: endTimeStr,
                isInteractive: true,
                onScrub: { fraction in
                    if fraction == nil {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.scrubFraction = nil
                        }
                    } else {
                        self.scrubFraction = fraction
                    }
                }
            ) {
                VStack(spacing: 4) {
                    if let scrub = scrubFraction {
                        // Interactive Scrubbing Preview Mode
                        let targetDuration = snapshot.phase != .idle
                            ? fastingManager.activeTargetDuration
                            : fastingManager.activeProtocol.fastingDuration
                        let baseStartTime = snapshot.startTime ?? Date()

                        let scrubElapsed = targetDuration * scrub
                        let scrubRemaining = max(0, targetDuration - scrubElapsed)
                        let scrubClockTime = baseStartTime.addingTimeInterval(scrubElapsed)

                        Text("PREVIEW • \(formatClockTime(scrubClockTime))")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(Color.white.opacity(0.85))

                        Text(formatHMS(scrubElapsed))
                            .font(.system(size: 42, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.white)
                            .contentTransition(.numericText())

                        Text("\(formatHMS(scrubRemaining)) remaining (\(Int(scrub * 100))%)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.80))
                    } else if snapshot.phase == .idle {
                        // Idle Mode
                        if let timeSinceLast = snapshot.formattedTimeSinceLastFast {
                            Text("TIME SINCE LAST FAST")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(Color.white.opacity(0.75))

                            Text(timeSinceLast)
                                .font(.system(size: 38, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.white)
                                .contentTransition(.numericText())

                            Text("Eating Window • Goal: \(fastingManager.activeProtocol.formattedRatio)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.85))
                        } else {
                            Text("READY TO FAST")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(Color.white.opacity(0.75))

                            Text(fastingManager.activeProtocol.formattedRatio)
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                    } else {
                        // Live Active Fast Mode
                        let isPastGoal = snapshot.phase == .targetReached || snapshot.phase == .overtime
                        if isPastGoal {
                            Text(snapshot.phase == .overtime ? "OVERTIME" : "GOAL MET")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(snapshot.phase == .overtime ? Color.red.opacity(0.4) : Color.black.opacity(0.35))
                                .clipShape(Capsule())
                        } else {
                            Text(snapshot.percentageString)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .tracking(1.0)
                                .foregroundStyle(Color.white.opacity(0.9))
                        }

                        Text(snapshot.formattedElapsedTime)
                            .font(.system(size: 42, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.white)

                        if isPastGoal {
                            Text("\(snapshot.formattedOvertimeTime) overtime")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                        } else {
                            Text("\(snapshot.formattedRemainingTime) remaining")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.75))
                        }
                    }
                }
            }
            .frame(height: 250)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Metric Pills Row
    private func metricPillsRow(snapshot: FastingSnapshot, atmosphere: AtmosphericPalette) -> some View {
        HStack(spacing: 8) {
            if snapshot.phase == .idle {
                if let window = snapshot.formattedTimeSinceLastFastShort {
                    flatMetricPill(
                        icon: "fork.knife",
                        title: "Window",
                        value: window
                    )
                } else {
                    flatMetricPill(
                        icon: "target",
                        title: "Goal",
                        value: fastingManager.activeProtocol.formattedRatio
                    )
                }

                flatMetricPill(
                    icon: "bolt.fill",
                    title: "Streak",
                    value: "\(fastingManager.currentStreak) Days"
                )

                flatMetricPill(
                    icon: "trophy.fill",
                    title: "Best",
                    value: "\(fastingManager.longestStreak) Days"
                )
            } else {
                flatMetricPill(
                    icon: "sunset.fill",
                    title: "Started",
                    value: formatClockTime(snapshot.startTime ?? Date())
                )

                flatMetricPill(
                    icon: "sunrise.fill",
                    title: "Target",
                    value: formatClockTime(snapshot.targetEndTime ?? Date())
                )

                flatMetricPill(
                    icon: "bolt.fill",
                    title: "Streak",
                    value: "\(fastingManager.currentStreak) Days"
                )
            }
        }
    }

    private func flatMetricPill(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
            }

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom Action Controls
    private func bottomActionControls(snapshot: FastingSnapshot, atmosphere: AtmosphericPalette) -> some View {
        VStack(spacing: 10) {
            if scrubFraction != nil {
                // Scrubbing hint
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 12))
                    Text("Release finger to resume live tracking")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.80))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.30))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
            } else if snapshot.phase == .idle {
                // Protocol Selector Button
                Button {
                    showProtocolPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: fastingManager.activeProtocol.iconName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text(fastingManager.activeProtocol.name)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.60))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.22))
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    )
                }

                // Start Fast Button
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        fastingManager.startFast(protocol: fastingManager.activeProtocol)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Start Fast")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                }

                // Adjust start time
                Button {
                    showEditSheet = true
                } label: {
                    Text("Started earlier? Adjust start time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.70))
                }
                .padding(.top, 2)
            } else {
                // Active Fast Controls
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    showCompleteSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("End Fast & Log")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                }

                HStack(spacing: 14) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Text("Edit Timing")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.20))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            )
                    }

                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        showCancelConfirmation = true
                    } label: {
                        Text("Cancel Fast")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.4, blue: 0.4))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.20))
                                    .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
                            )
                    }
                }
            }
        }
    }

    private func formatClockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func formatHMS(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
