import SwiftUI
#if canImport(WidgetKit) && canImport(ActivityKit)
import WidgetKit
import ActivityKit

/// FastSpan Lock Screen & Dynamic Island Live Activity.
/// Uses native SpringBoard `Text(timerInterval:)` and `ProgressView(timerInterval:)`
/// so the countdown and progress bar animate smoothly at zero app CPU cost.
public struct FastingLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingActivityAttributes.self) { context in
            lockScreenBanner(context: context)
                .activityBackgroundTint(Color(red: 0.08, green: 0.05, blue: 0.14))
                .activitySystemActionForegroundColor(Color(red: 1.0, green: 0.72, blue: 0.25))
        } dynamicIsland: { context in
            let overtime = isOvertime(for: context)
            return DynamicIsland {
                // Expanded Leading: Diurnal Icon & Protocol
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: overtime ? "sun.max.fill" : "sun.horizon.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentColor(isOvertime: overtime))
                        Text(context.state.protocolName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 4)
                }

                // Expanded Trailing: Status Pill
                DynamicIslandExpandedRegion(.trailing) {
                    statusPill(for: context.state, isOvertime: overtime, tracking: 0.5)
                        .padding(.trailing, 4)
                }

                // Expanded Bottom: Full-width Countdown, End Time & Native Progress Bar
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            countdownText(for: context.state, isOvertime: overtime, fontSize: 28)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 1) {
                                Text(overtime ? "ENDED" : "ENDS")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .tracking(0.8)
                                    .foregroundStyle(Color.white.opacity(0.55))
                                Text(formatTime(context.state.targetEndTime))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(accentColor(isOvertime: overtime))
                            }
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                        }

                        if overtime || context.state.startTime >= context.state.targetEndTime {
                            overtimeFooter(isOvertime: true)
                        } else {
                            ProgressView(
                                timerInterval: context.state.startTime...context.state.targetEndTime,
                                countsDown: false
                            ) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .tint(accentColor(isOvertime: false))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: overtime ? "checkmark.circle.fill" : "sun.horizon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor(isOvertime: overtime))
                    .padding(.leading, 2)
            } compactTrailing: {
                compactCountdownText(for: context.state, isOvertime: overtime)
                    .padding(.trailing, 2)
            } minimal: {
                Image(systemName: overtime ? "checkmark.circle.fill" : "sun.horizon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor(isOvertime: overtime))
            }
        }
    }

    // MARK: - Lock Screen / StandBy Banner
    private func lockScreenBanner(context: ActivityViewContext<FastingActivityAttributes>) -> some View {
        let overtime = isOvertime(for: context)

        return ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.06, blue: 0.18),
                    Color(red: 0.06, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: overtime ? "sun.max.fill" : "sun.horizon.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accentColor(isOvertime: overtime))
                        Text("FASTSPAN")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(Color.white.opacity(0.75))
                        Text("• \(context.state.protocolName)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }

                    Spacer()

                    statusPill(for: context.state, isOvertime: overtime, tracking: 0.6)
                }

                HStack(alignment: .firstTextBaseline) {
                    countdownText(for: context.state, isOvertime: overtime, fontSize: 30)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(overtime ? "ENDED" : "ENDS")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text(formatTime(context.state.targetEndTime))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                }

                if overtime || context.state.startTime >= context.state.targetEndTime {
                    overtimeFooter(isOvertime: true)
                } else {
                    ProgressView(
                        timerInterval: context.state.startTime...context.state.targetEndTime,
                        countsDown: false
                    ) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(accentColor(isOvertime: false))
                }
            }
            .padding(16)
        }
    }

    // MARK: - Helpers
    /// ActivityKit flips `context.isStale` to `true` at `staleDate` (`targetEndTime`) and re-renders
    /// automatically even while the app is suspended, so checking `isStale` transitions the UI to overtime
    /// with zero app wakeup.
    private func isOvertime(for context: ActivityViewContext<FastingActivityAttributes>) -> Bool {
        context.state.isOvertime || context.isStale
    }

    private func statusLabel(for state: FastingActivityAttributes.ContentState, isOvertime: Bool) -> String {
        if isOvertime {
            return "GOAL MET"
        }
        return state.countsUp ? "ELAPSED" : "REMAINING"
    }

    private func accentColor(isOvertime: Bool) -> Color {
        isOvertime
            ? Color(red: 1.0, green: 0.85, blue: 0.25)
            : Color(red: 1.0, green: 0.62, blue: 0.22)
    }

    private func statusPill(
        for state: FastingActivityAttributes.ContentState,
        isOvertime: Bool,
        tracking: CGFloat
    ) -> some View {
        HStack(spacing: 4) {
            if isOvertime {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
            }
            Text(statusLabel(for: state, isOvertime: isOvertime))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(tracking)
        }
        .foregroundStyle(accentColor(isOvertime: isOvertime))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(accentColor(isOvertime: isOvertime).opacity(0.16))
        .clipShape(Capsule())
    }

    private func overtimeFooter(isOvertime: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accentColor(isOvertime: isOvertime))
            Text("Fast complete · Counting overtime")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(accentColor(isOvertime: isOvertime).opacity(0.9))
            Spacer()
        }
    }

    @ViewBuilder
    private func countdownText(
        for state: FastingActivityAttributes.ContentState,
        isOvertime: Bool,
        fontSize: CGFloat
    ) -> some View {
        if state.countsUp {
            Text(timerInterval: state.startTime...Date.distantFuture, countsDown: false)
                .font(.system(size: fontSize, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(isOvertime ? accentColor(isOvertime: true) : Color.white)
        } else if isOvertime || state.startTime >= state.targetEndTime {
            Text("+\(Text(timerInterval: state.targetEndTime...Date.distantFuture, countsDown: false))")
                .font(.system(size: fontSize, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(accentColor(isOvertime: true))
        } else {
            Text(timerInterval: state.startTime...state.targetEndTime, countsDown: true)
                .font(.system(size: fontSize, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color.white)
        }
    }

    @ViewBuilder
    private func compactCountdownText(
        for state: FastingActivityAttributes.ContentState,
        isOvertime: Bool
    ) -> some View {
        Group {
            if state.countsUp {
                Text(timerInterval: state.startTime...Date.distantFuture, countsDown: false)
            } else if isOvertime || state.startTime >= state.targetEndTime {
                Text("+\(Text(timerInterval: state.targetEndTime...Date.distantFuture, countsDown: false))")
            } else {
                Text(timerInterval: state.startTime...state.targetEndTime, countsDown: true)
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(accentColor(isOvertime: isOvertime))
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: 52, alignment: .trailing)
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
#endif
