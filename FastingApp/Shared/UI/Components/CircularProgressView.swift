import SwiftUI

/// High-performance circular progress indicator supporting gradients, overtime halos, and live ticks.
public struct CircularProgressView: View {
    public let progress: Double          // 0.0 to 1.0 (main ring)
    public let totalProgress: Double     // Can exceed 1.0 for overtime
    public let phase: FastingPhase
    public let theme: AppTheme
    public let lineWidth: CGFloat
    public let centerContent: AnyView?

    public init<Center: View>(
        progress: Double,
        totalProgress: Double,
        phase: FastingPhase,
        theme: AppTheme,
        lineWidth: CGFloat = 22,
        @ViewBuilder centerContent: () -> Center
    ) {
        self.progress = progress
        self.totalProgress = totalProgress
        self.phase = phase
        self.theme = theme
        self.lineWidth = lineWidth
        self.centerContent = AnyView(centerContent())
    }

    public init(
        progress: Double,
        totalProgress: Double,
        phase: FastingPhase,
        theme: AppTheme,
        lineWidth: CGFloat = 22
    ) {
        self.progress = progress
        self.totalProgress = totalProgress
        self.phase = phase
        self.theme = theme
        self.lineWidth = lineWidth
        self.centerContent = nil
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Overtime halo glow (when > 100%)
            if phase == .overtime || totalProgress > 1.0 {
                Circle()
                    .stroke(
                        theme.overtimeColor.opacity(0.25),
                        style: StrokeStyle(lineWidth: lineWidth + 8, lineCap: .round)
                    )
                    .blur(radius: 8)

                // Overtime secondary track
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, totalProgress - 1.0)))
                    .stroke(
                        theme.overtimeGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            // Main Progress Arc
            Circle()
                .trim(from: 0.0, to: CGFloat(min(1.0, max(0.001, progress))))
                .stroke(
                    phase == .overtime ? theme.overtimeGradient : theme.ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: (phase == .overtime ? theme.overtimeColor : theme.primaryColor).opacity(0.35),
                    radius: 10,
                    x: 0,
                    y: 0
                )

            // Center slot for typography & countdown
            if let content = centerContent {
                content
            }
        }
        .padding(lineWidth / 2)
    }
}
