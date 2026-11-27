import SwiftUI
#if canImport(SwiftData)
import SwiftData
#endif
#if os(watchOS)
import WatchKit
#endif

/// Main Apple Watch tracker view with dipped-line horizon diurnal progress tracker.
public struct WatchTrackerView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if canImport(SwiftData)
    @Environment(\.modelContext) private var modelContext
    #endif
    #if os(watchOS)
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    #endif
    @State private var fastingManager = FastingManager.shared
    @State private var showProtocolPicker: Bool = false

    // Digital Crown Time Travel State
    @State private var scrubFraction: Double? = nil
    @State private var crownProgress: Double = 0.0
    @State private var scrubReferenceDate: Date = Date()
    @State private var snapBackTask: Task<Void, Never>? = nil

    public init() {}

    private var isDimmed: Bool {
        #if os(watchOS)
        return isLuminanceReduced
        #else
        return false
        #endif
    }

    private var hasLiveTimer: Bool {
        fastingManager.activeStartTime != nil || fastingManager.lastCompletedFastEndTime != nil
    }

    private var isCrownActive: Bool {
        !isDimmed && !showProtocolPicker && scenePhase == .active
    }

    public var body: some View {
        NavigationStack {
            Group {
                if !hasLiveTimer || scenePhase == .background || showProtocolPicker || scrubFraction != nil {
                    // Static render: zero timer wakeups when idle, backgrounded, covered by picker, or scrubbing
                    watchContent(at: Date())
                } else if isDimmed {
                    // Always-On Display (wrist down): 1 wakeup/min, HH:MM precision, pure OLED black
                    TimelineView(.everyMinute) { timeline in
                        watchContent(at: timeline.date)
                    }
                } else if scenePhase == .active {
                    // Wrist up & active: low-power 1s periodic timer (never 60Hz CADisplayLink)
                    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                        watchContent(at: timeline.date)
                    }
                } else {
                    watchContent(at: Date())
                }
            }
            #if os(watchOS)
            .focusable(isCrownActive)
            .digitalCrownRotation(
                detent: $crownProgress,
                from: 0.0,
                through: 1.0,
                by: 0.01,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            ) { event in
                handleCrownChange(event.offset)
            } onIdle: {
                scheduleSnapBack()
            }
            #endif
            .onAppear {
                syncCrownToLive()
            }
            .onChange(of: isDimmed) { _, dimmed in
                if dimmed {
                    cancelScrubbingImmediately()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    cancelScrubbingImmediately()
                } else if scrubFraction == nil {
                    syncCrownToLive()
                }
            }
            .onChange(of: showProtocolPicker) { _, presented in
                if presented {
                    cancelScrubbingImmediately()
                } else {
                    syncCrownToLive()
                }
            }
            .onChange(of: fastingManager.activeStartTime) { _, _ in
                if scrubFraction == nil {
                    syncCrownToLive()
                }
            }
            .sheet(isPresented: $showProtocolPicker) {
                WatchProtocolPicker()
            }
        }
    }

    @ViewBuilder
    private func watchContent(at date: Date) -> some View {
        let snapshot = fastingManager.calculateCurrentSnapshot(at: date)
        let effectiveProgress = scrubFraction ?? snapshot.progressFraction
        let effectivePhase: FastingPhase = scrubFraction != nil
            ? (scrubFraction! >= 1.0 ? .targetReached : .active)
            : snapshot.phase
        let atmosphere = AtmosphericPalette.forProgress(effectiveProgress, phase: effectivePhase)
        let quantizedLiveStep = Int((snapshot.progressFraction * 100.0).rounded())

        ZStack {
            // True OLED Black (pure black in Always-On Display saves significant watch battery)
            Color.black
                .ignoresSafeArea()

            if !isDimmed {
                LinearGradient(
                    colors: [atmosphere.topColor.opacity(0.35), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 4) {
                // Header Status
                if scrubFraction != nil && !isDimmed {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.9, blue: 0.4))
                        Text("TIME TRAVEL")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    .padding(.top, 2)
                } else if snapshot.phase != .idle {
                    HStack(spacing: 4) {
                        Image(systemName: atmosphere.phaseIcon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(atmosphere.accentColor)
                        Text(atmosphere.phaseLabel)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                // Watch Hero: Dipped Line Horizon Tracker
                watchDippedTracker(
                    snapshot: snapshot,
                    effectiveProgress: effectiveProgress,
                    effectivePhase: effectivePhase
                )

                Spacer(minLength: 0)

                // Action Buttons
                if scrubFraction != nil && !isDimmed {
                    Button {
                        endScrubbing()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: atmosphere.phaseIcon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(atmosphere.accentColor)
                            Text(atmosphere.phaseLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if snapshot.phase == .idle {
                    Button {
                        triggerHaptic()
                        withAnimation {
                            fastingManager.startFast(protocol: fastingManager.activeProtocol)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Start Fast")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Protocol Selector
                    Button {
                        showProtocolPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(fastingManager.activeProtocol.name)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        triggerHaptic()
                        withAnimation {
                            if let record = fastingManager.endFast() {
                                #if canImport(SwiftData)
                                modelContext.insert(record)
                                try? modelContext.save()
                                #endif
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                            Text("End Fast")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 2)
        }
        .onChange(of: quantizedLiveStep) { _, _ in
            if scrubFraction == nil {
                crownProgress = snapshot.progressFraction
            }
        }
    }

    // MARK: - Watch Dipped Line Horizon
    private func watchDippedTracker(
        snapshot: FastingSnapshot,
        effectiveProgress: Double,
        effectivePhase: FastingPhase
    ) -> some View {
        let dimmed = isDimmed
        return ZStack {
            ValleyProgressView(
                progress: effectiveProgress,
                totalProgress: scrubFraction ?? snapshot.totalProgressFraction,
                phase: effectivePhase,
                lineWidth: 4,
                showLabels: false
            ) {
                VStack(spacing: 1) {
                    if let scrub = scrubFraction, !dimmed {
                        let targetDuration = snapshot.phase != .idle
                            ? fastingManager.activeTargetDuration
                            : fastingManager.activeProtocol.fastingDuration
                        let baseStartTime = snapshot.startTime ?? scrubReferenceDate
                        let scrubElapsed = targetDuration * scrub
                        let scrubRemaining = max(0, targetDuration - scrubElapsed)
                        let scrubClockTime = baseStartTime.addingTimeInterval(scrubElapsed)

                        Text("\(formatClockTime(scrubClockTime)) • \(Int((scrub * 100).rounded()))%")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.9))

                        Text(formatHMS(scrubElapsed))
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.white)
                            .contentTransition(.numericText())

                        Text(scrubRemaining > 0 ? "-\(formatHMS(scrubRemaining))" : "GOAL MET")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(scrubRemaining > 0 ? Color.white.opacity(0.65) : Color.orange)
                    } else if snapshot.phase == .idle {
                        if let timeSinceLast = dimmed ? snapshot.formattedTimeSinceLastFastHM : snapshot.formattedTimeSinceLastFast {
                            Text("EATING")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.7))
                            Text(timeSinceLast)
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.white)
                        } else {
                            Text(fastingManager.activeProtocol.formattedRatio)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text("FASTSPAN")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    } else {
                        let isPastGoal = snapshot.phase == .targetReached || snapshot.phase == .overtime
                        Text(
                            snapshot.phase == .overtime
                                ? "OVERTIME"
                                : (snapshot.phase == .targetReached ? "GOAL MET" : snapshot.percentageString)
                        )
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text(dimmed ? snapshot.formattedElapsedTimeHM : snapshot.formattedElapsedTime)
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.white)

                        if isPastGoal {
                            Text(dimmed ? snapshot.formattedOvertimeTimeHM : snapshot.formattedOvertimeTime)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(snapshot.phase == .overtime ? Color.red : Color.orange)
                        } else {
                            Text(dimmed ? snapshot.formattedRemainingTimeHM : snapshot.formattedRemainingTime)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
            }
            .frame(height: 110)
        }
    }

    // MARK: - Digital Crown Time Travel Helpers
    private func handleCrownChange(_ offset: Double) {
        guard isCrownActive else { return }
        if scrubFraction == nil {
            scrubReferenceDate = Date()
        }
        scrubFraction = min(1.0, max(0.0, offset))
        scheduleSnapBack()
    }

    private func scheduleSnapBack() {
        snapBackTask?.cancel()
        snapBackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            endScrubbing()
        }
    }

    private func endScrubbing() {
        snapBackTask?.cancel()
        snapBackTask = nil
        let liveProgress = fastingManager.calculateCurrentSnapshot(at: Date()).progressFraction
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            scrubFraction = nil
        }
        crownProgress = liveProgress
    }

    private func cancelScrubbingImmediately() {
        snapBackTask?.cancel()
        snapBackTask = nil
        scrubFraction = nil
        syncCrownToLive()
    }

    private func syncCrownToLive() {
        crownProgress = fastingManager.calculateCurrentSnapshot(at: Date()).progressFraction
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

    private func triggerHaptic() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
}
