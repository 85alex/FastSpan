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

    public var body: some View {
        NavigationStack {
            Group {
                if !hasLiveTimer || scenePhase == .background || showProtocolPicker {
                    // Static render: zero timer wakeups when idle, backgrounded, or covered by picker
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
            .sheet(isPresented: $showProtocolPicker) {
                WatchProtocolPicker()
            }
        }
    }

    @ViewBuilder
    private func watchContent(at date: Date) -> some View {
        let snapshot = fastingManager.calculateCurrentSnapshot(at: date)
        let atmosphere = AtmosphericPalette.forProgress(snapshot.progressFraction, phase: snapshot.phase)

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

            ScrollView {
                VStack(spacing: 6) {
                    // Header Status
                    if snapshot.phase != .idle {
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

                    // Watch Hero: Dipped Line Horizon Tracker
                    watchDippedTracker(snapshot: snapshot, atmosphere: atmosphere)

                    // Action Buttons
                    if snapshot.phase == .idle {
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
            }
        }
    }

    // MARK: - Watch Dipped Line Horizon
    private func watchDippedTracker(snapshot: FastingSnapshot, atmosphere: AtmosphericPalette) -> some View {
        let dimmed = isDimmed
        return ZStack {
            ValleyProgressView(
                progress: snapshot.progressFraction,
                totalProgress: snapshot.totalProgressFraction,
                phase: snapshot.phase,
                lineWidth: 4,
                showLabels: false
            ) {
                VStack(spacing: 1) {
                    if snapshot.phase == .idle {
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

    private func triggerHaptic() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
}
