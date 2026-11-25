import SwiftUI

public enum ShareCardFormat: String, CaseIterable, Identifiable {
    case story = "Story (9:16)"
    case square = "Square (1:1)"

    public var id: String { rawValue }

    public var size: CGSize {
        switch self {
        case .story: return CGSize(width: 360, height: 640)
        case .square: return CGSize(width: 360, height: 360)
        }
    }
}

/// VoltSlide-style shareable summary card for a completed fast.
public struct FastShareCardView: View {
    public let record: FastRecord
    public let theme: AppTheme
    public let streak: Int
    public let format: ShareCardFormat

    public init(
        record: FastRecord,
        theme: AppTheme,
        streak: Int,
        format: ShareCardFormat = .story
    ) {
        self.record = record
        self.theme = theme
        self.streak = streak
        self.format = format
    }

    public var body: some View {
        ZStack {
            theme.backgroundGradient

            VStack(spacing: format == .story ? 24 : 14) {
                HStack {
                    Text("FASTSPAN")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(2.4)
                        .foregroundStyle(Color.white.opacity(0.9))
                    Spacer()
                    Text(record.protocolName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.primaryColor.opacity(0.18))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 4)

                ValleyProgressView(
                    progress: min(1.0, record.actualDuration / max(1.0, record.targetDuration)),
                    totalProgress: record.actualDuration / max(1.0, record.targetDuration),
                    phase: record.isGoalAchieved ? .targetReached : .active,
                    lineWidth: 5,
                    showLabels: false
                ) {
                    VStack(spacing: 4) {
                        Text(record.isGoalAchieved ? "GOAL MET" : "COMPLETED")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(theme.primaryColor)

                        Text(record.formattedDuration)
                            .font(.system(size: format == .story ? 42 : 34, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("Target \(record.formattedTarget)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
                .frame(height: format == .story ? 210 : 150)

                HStack(spacing: 10) {
                    shareStatPill(title: "STREAK", value: "\(streak)d")
                    if let mood = record.mood {
                        shareStatPill(title: "FEELING", value: mood)
                    } else {
                        shareStatPill(title: "DATE", value: record.startTime.formatted(.dateTime.month(.abbreviated).day()))
                    }
                }

                Spacer(minLength: 4)

                Text("100% Privacy-First Fasting")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(24)
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func shareStatPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
