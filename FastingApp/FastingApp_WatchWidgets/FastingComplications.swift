import SwiftUI
import WidgetKit

public enum ComplicationPhase: Equatable, Sendable {
    case active
    case overtime
    case idle
}

public struct FastingTimelineEntry: TimelineEntry {
    public let date: Date
    public let phase: ComplicationPhase
    public let protocolName: String
    public let startTime: Date?
    public let targetEndTime: Date?
    public let lastCompletedFastEndTime: Date?
    public let countsUp: Bool

    public init(
        date: Date,
        phase: ComplicationPhase,
        protocolName: String,
        startTime: Date? = nil,
        targetEndTime: Date? = nil,
        lastCompletedFastEndTime: Date? = nil,
        countsUp: Bool = false
    ) {
        self.date = date
        self.phase = phase
        self.protocolName = protocolName
        self.startTime = startTime
        self.targetEndTime = targetEndTime
        self.lastCompletedFastEndTime = lastCompletedFastEndTime
        self.countsUp = countsUp
    }
}

/// Zero-polling WidgetKit complication provider:
/// - Returns at most 2 entries (active -> overtime transition) with `policy: .never`.
/// - System compositor natively animates `ProgressView(timerInterval:)` and `Text(timerInterval:)` / `.relative`
///   with zero background extension wakeups.
public struct FastingComplicationsProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> FastingTimelineEntry {
        let now = Date()
        return FastingTimelineEntry(
            date: now,
            phase: .active,
            protocolName: "16:8",
            startTime: now.addingTimeInterval(-12 * 3600),
            targetEndTime: now.addingTimeInterval(4 * 3600),
            countsUp: false
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (FastingTimelineEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let snapshot = SharedFastingStore.load()
        let entries = Self.makeEntries(from: snapshot, now: Date())
        completion(entries.first ?? placeholder(in: context))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<FastingTimelineEntry>) -> Void) {
        let snapshot = SharedFastingStore.load()
        let entries = Self.makeEntries(from: snapshot, now: Date())
        // Event-driven reloads via WidgetCenter.shared.reloadTimelines(ofKind:) when state mutates.
        completion(Timeline(entries: entries, policy: .never))
    }

    /// Maximum duration (24h) to keep a relative eating-window timer ticking on the watch face
    /// before transitioning cleanly to static "Ready" mode with zero wakeups.
    private static let maxEatingWindowDisplayDuration: TimeInterval = 24 * 3600

    /// Pure timeline builder: produces 1–2 entries with zero polling.
    public static func makeEntries(
        from snapshot: SharedFastingSnapshot,
        now: Date = Date()
    ) -> [FastingTimelineEntry] {
        guard let start = snapshot.startTime, let end = snapshot.targetEndTime, start < end else {
            if let lastEnd = snapshot.lastCompletedFastEndTime {
                let eatingCutoff = lastEnd.addingTimeInterval(maxEatingWindowDisplayDuration)
                if now < eatingCutoff {
                    let eatingEntry = FastingTimelineEntry(
                        date: now,
                        phase: .idle,
                        protocolName: snapshot.protocolName,
                        lastCompletedFastEndTime: lastEnd,
                        countsUp: snapshot.countsUp
                    )
                    let staticReadyEntry = FastingTimelineEntry(
                        date: eatingCutoff,
                        phase: .idle,
                        protocolName: snapshot.protocolName,
                        lastCompletedFastEndTime: nil,
                        countsUp: snapshot.countsUp
                    )
                    return [eatingEntry, staticReadyEntry]
                }
            }
            return [
                FastingTimelineEntry(
                    date: now,
                    phase: .idle,
                    protocolName: snapshot.protocolName,
                    lastCompletedFastEndTime: nil,
                    countsUp: snapshot.countsUp
                )
            ]
        }

        if now >= end {
            return [
                FastingTimelineEntry(
                    date: now,
                    phase: .overtime,
                    protocolName: snapshot.protocolName,
                    startTime: start,
                    targetEndTime: end,
                    lastCompletedFastEndTime: snapshot.lastCompletedFastEndTime,
                    countsUp: snapshot.countsUp
                )
            ]
        }

        // Active now, automatically transitions to overtime at `end` without waking the extension.
        let activeEntry = FastingTimelineEntry(
            date: now,
            phase: .active,
            protocolName: snapshot.protocolName,
            startTime: start,
            targetEndTime: end,
            lastCompletedFastEndTime: snapshot.lastCompletedFastEndTime,
            countsUp: snapshot.countsUp
        )
        let overtimeEntry = FastingTimelineEntry(
            date: end,
            phase: .overtime,
            protocolName: snapshot.protocolName,
            startTime: start,
            targetEndTime: end,
            lastCompletedFastEndTime: snapshot.lastCompletedFastEndTime,
            countsUp: snapshot.countsUp
        )
        return [activeEntry, overtimeEntry]
    }
}

public struct FastingComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    public let entry: FastingTimelineEntry

    public init(entry: FastingTimelineEntry) {
        self.entry = entry
    }

    public var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .accessoryCorner:
                cornerView
            case .accessoryInline:
                inlineView
            default:
                rectangularView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Circular
    @ViewBuilder
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            switch entry.phase {
            case .active:
                if let start = entry.startTime, let end = entry.targetEndTime, start < end {
                    ProgressView(timerInterval: start...end, countsDown: false) {
                        Image(systemName: "flame.fill")
                            .widgetAccentable()
                    } currentValueLabel: {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .widgetAccentable()
                    }
                    .progressViewStyle(.circular)
                    .tint(.orange)
                }

            case .overtime:
                Gauge(value: 1.0, in: 0...1) {
                    Image(systemName: "checkmark.seal.fill")
                } currentValueLabel: {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .widgetAccentable()
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.orange)

            case .idle:
                VStack(spacing: 1) {
                    Image(systemName: entry.lastCompletedFastEndTime != nil ? "fork.knife" : "sun.max.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.orange)
                        .widgetAccentable()
                    Text(entry.protocolName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }

    // MARK: - Rectangular
    @ViewBuilder
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            switch entry.phase {
            case .active:
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .widgetAccentable()
                    Text("FASTING • \(entry.protocolName)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }

                if let start = entry.startTime, let end = entry.targetEndTime, start < end {
                    ProgressView(timerInterval: start...end, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(.orange)

                    HStack(spacing: 4) {
                        Text(timerInterval: start...end, countsDown: !entry.countsUp)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(entry.countsUp ? "elapsed" : "left")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }

            case .overtime:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .widgetAccentable()
                    Text("GOAL MET • \(entry.protocolName)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }

                ProgressView(value: 1.0)
                    .tint(.orange)

                if let start = entry.startTime {
                    Text(start, style: .relative)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }

            case .idle:
                if let lastEnd = entry.lastCompletedFastEndTime {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .widgetAccentable()
                        Text("EATING • \(entry.protocolName)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }

                    Text(lastEnd, style: .relative)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)

                    Text("Since last fast")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .widgetAccentable()
                        Text("FASTSPAN")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }

                    Text("Ready • \(entry.protocolName)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text("Tap to start fast")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Corner
    @ViewBuilder
    private var cornerView: some View {
        switch entry.phase {
        case .active:
            Image(systemName: "flame.fill")
                .font(.title3.bold())
                .foregroundStyle(Color.orange)
                .widgetAccentable()
                .widgetLabel {
                    if let start = entry.startTime, let end = entry.targetEndTime, start < end {
                        Text(timerInterval: start...end, countsDown: !entry.countsUp)
                    } else {
                        Text(entry.protocolName)
                    }
                }

        case .overtime:
            Image(systemName: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(Color.orange)
                .widgetAccentable()
                .widgetLabel {
                    if let start = entry.startTime {
                        Text(start, style: .relative)
                    } else {
                        Text("Goal Met")
                    }
                }

        case .idle:
            Image(systemName: entry.lastCompletedFastEndTime != nil ? "fork.knife" : "sun.max.fill")
                .font(.title3.bold())
                .foregroundStyle(Color.orange)
                .widgetAccentable()
                .widgetLabel {
                    if let lastEnd = entry.lastCompletedFastEndTime {
                        Text(lastEnd, style: .relative)
                    } else {
                        Text("Ready \(entry.protocolName)")
                    }
                }
        }
    }

    // MARK: - Inline
    @ViewBuilder
    private var inlineView: some View {
        switch entry.phase {
        case .active:
            if let start = entry.startTime, let end = entry.targetEndTime, start < end {
                Label {
                    Text(timerInterval: start...end, countsDown: !entry.countsUp)
                } icon: {
                    Image(systemName: "flame.fill")
                }
            } else {
                Label("Fasting \(entry.protocolName)", systemImage: "flame.fill")
            }

        case .overtime:
            if let start = entry.startTime {
                Label {
                    Text(start, style: .relative)
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
            } else {
                Label("Goal Met", systemImage: "checkmark.seal.fill")
            }

        case .idle:
            if let lastEnd = entry.lastCompletedFastEndTime {
                Label {
                    Text(lastEnd, style: .relative)
                } icon: {
                    Image(systemName: "fork.knife")
                }
            } else {
                Label("Ready • \(entry.protocolName)", systemImage: "sun.max.fill")
            }
        }
    }
}

public struct FastingComplications: Widget {
    public let kind: String = SharedFastingStore.complicationKind

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastingComplicationsProvider()) { entry in
            FastingComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("FastSpan Tracker")
        .description("Track your fasting progress and eating window on your watch face with zero background polling.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}
