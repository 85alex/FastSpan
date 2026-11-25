import SwiftUI

/// Defines the dynamic diurnal atmosphere (Bright Yellow -> Sunset Red -> Dark Midnight Purple -> Sunrise Red/Orange -> Bright Yellow)
public struct AtmosphericPalette: Sendable {
    public let topColor: Color
    public let bottomColor: Color
    public let accentColor: Color
    public let strokeColor: Color
    public let sunColor: Color
    public let isLightBackground: Bool
    public let phaseLabel: String
    public let phaseIcon: String

    public static func forProgress(_ progress: Double, phase: FastingPhase = .active) -> AtmosphericPalette {
        let p = min(1.0, max(0.0, progress))

        if phase == .idle {
            return AtmosphericPalette(
                topColor: Color(red: 0.95, green: 0.68, blue: 0.12),    // Bright Golden Yellow / Day Start
                bottomColor: Color(red: 0.85, green: 0.42, blue: 0.08), // Warm Amber
                accentColor: Color(red: 1.00, green: 0.88, blue: 0.30),
                strokeColor: Color.white,
                sunColor: Color(red: 1.0, green: 0.92, blue: 0.40),
                isLightBackground: true,
                phaseLabel: "READY TO FAST",
                phaseIcon: "sun.max.fill"
            )
        }

        if phase == .overtime || progress > 1.0 {
            return AtmosphericPalette(
                topColor: Color(red: 0.98, green: 0.75, blue: 0.15),    // Radiant Goal Sunrise
                bottomColor: Color(red: 0.90, green: 0.48, blue: 0.10),
                accentColor: Color(red: 1.00, green: 0.90, blue: 0.40),
                strokeColor: Color.white,
                sunColor: Color(red: 1.0, green: 0.95, blue: 0.50),
                isLightBackground: true,
                phaseLabel: "OVERTIME SUNRISE",
                phaseIcon: "sun.horizon.fill"
            )
        }

        if phase == .targetReached {
            return AtmosphericPalette(
                topColor: Color(red: 0.96, green: 0.75, blue: 0.14),    // Bright Goal Morning
                bottomColor: Color(red: 0.88, green: 0.45, blue: 0.08),
                accentColor: Color(red: 1.00, green: 0.90, blue: 0.35),
                strokeColor: Color.white,
                sunColor: Color(red: 1.0, green: 0.95, blue: 0.45),
                isLightBackground: true,
                phaseLabel: "GOAL REACHED",
                phaseIcon: "checkmark.seal.fill"
            )
        }

        // 0.0 -> 0.5: Sunset / Descent (Yellow -> Red/Crimson -> Deep Midnight Purple)
        if p <= 0.5 {
            let t = p / 0.5 // 0.0 to 1.0

            if t < 0.4 {
                // 0.0 -> 0.2: Bright Yellow to Fiery Sunset Orange/Red
                let localT = t / 0.4
                let top = lerp(
                    from: (0.95, 0.68, 0.12), // Bright Yellow
                    to: (0.88, 0.25, 0.10),   // Sunset Red-Orange
                    t: localT
                )
                let bottom = lerp(
                    from: (0.85, 0.42, 0.08),
                    to: (0.65, 0.12, 0.15),
                    t: localT
                )
                return AtmosphericPalette(
                    topColor: top,
                    bottomColor: bottom,
                    accentColor: Color(red: 1.0, green: 0.85, blue: 0.3),
                    strokeColor: Color.white.opacity(0.9),
                    sunColor: Color(red: 1.0, green: 0.9, blue: 0.4),
                    isLightBackground: true,
                    phaseLabel: "GOLDEN SUNSET",
                    phaseIcon: "sunset.fill"
                )
            } else if t < 0.75 {
                // 0.2 -> 0.375: Sunset Red to Crimson Dusk
                let localT = (t - 0.4) / 0.35
                let top = lerp(
                    from: (0.88, 0.25, 0.10), // Sunset Red
                    to: (0.42, 0.08, 0.32),   // Deep Crimson/Purple
                    t: localT
                )
                let bottom = lerp(
                    from: (0.65, 0.12, 0.15),
                    to: (0.22, 0.04, 0.24),
                    t: localT
                )
                return AtmosphericPalette(
                    topColor: top,
                    bottomColor: bottom,
                    accentColor: Color(red: 1.0, green: 0.6, blue: 0.7),
                    strokeColor: Color.white.opacity(0.85),
                    sunColor: Color(red: 1.0, green: 0.5, blue: 0.4),
                    isLightBackground: false,
                    phaseLabel: "CRIMSON DUSK",
                    phaseIcon: "sunset.fill"
                )
            } else {
                // 0.375 -> 0.5: Crimson Dusk to Deep Velvet Midnight Purple
                let localT = (t - 0.75) / 0.25
                let top = lerp(
                    from: (0.42, 0.08, 0.32),
                    to: (0.12, 0.05, 0.22),   // Deep Midnight Purple
                    t: localT
                )
                let bottom = lerp(
                    from: (0.22, 0.04, 0.24),
                    to: (0.05, 0.02, 0.12),   // Pitch Night Violet
                    t: localT
                )
                return AtmosphericPalette(
                    topColor: top,
                    bottomColor: bottom,
                    accentColor: Color(red: 0.75, green: 0.55, blue: 1.0),
                    strokeColor: Color.white.opacity(0.85),
                    sunColor: Color(red: 0.9, green: 0.8, blue: 1.0),
                    isLightBackground: false,
                    phaseLabel: "MIDNIGHT PURPLE",
                    phaseIcon: "moon.stars.fill"
                )
            }
        } else {
            // 0.5 -> 1.0: Sunrise / Ascent (Deep Midnight Purple -> Crimson Dawn -> Orange -> Bright Yellow)
            let t = (p - 0.5) / 0.5 // 0.0 to 1.0

            if t < 0.25 {
                // 0.5 -> 0.625: Midnight Purple to Predawn Crimson
                let localT = t / 0.25
                let top = lerp(
                    from: (0.12, 0.05, 0.22), // Midnight Purple
                    to: (0.42, 0.08, 0.30),   // Predawn Crimson
                    t: localT
                )
                let bottom = lerp(
                    from: (0.05, 0.02, 0.12),
                    to: (0.22, 0.04, 0.20),
                    t: localT
                )
                return AtmosphericPalette(
                    topColor: top,
                    bottomColor: bottom,
                    accentColor: Color(red: 0.85, green: 0.50, blue: 1.0),
                    strokeColor: Color.white.opacity(0.85),
                    sunColor: Color(red: 0.95, green: 0.65, blue: 0.85),
                    isLightBackground: false,
                    phaseLabel: "PREDAWN RISE",
                    phaseIcon: "moon.stars.fill"
                )
            } else if t < 0.65 {
                // 0.625 -> 0.825: Predawn Crimson to Sunrise Red/Orange
                let localT = (t - 0.25) / 0.40
                let top = lerp(
                    from: (0.42, 0.08, 0.30),
                    to: (0.90, 0.30, 0.08),   // Radiant Sunrise Red/Orange
                    t: localT
                )
                let bottom = lerp(
                    from: (0.22, 0.04, 0.20),
                    to: (0.70, 0.20, 0.05),
                    t: localT
                )
                return AtmosphericPalette(
                    topColor: top,
                    bottomColor: bottom,
                    accentColor: Color(red: 1.0, green: 0.75, blue: 0.25),
                    strokeColor: Color.white.opacity(0.9),
                    sunColor: Color(red: 1.0, green: 0.75, blue: 0.3),
                    isLightBackground: true,
                    phaseLabel: "SUNRISE DAWN",
                    phaseIcon: "sunrise.fill"
                )
            } else {
                // 0.825 -> 1.0: Sunrise Orange to Bright Golden Yellow
                let localT = (t - 0.65) / 0.35
                let top = lerp(
                    from: (0.90, 0.30, 0.08),
                    to: (0.96, 0.75, 0.14),   // Bright Golden Yellow
                    t: localT
                )
                let bottom = lerp(
                    from: (0.70, 0.20, 0.05),
                    to: (0.88, 0.45, 0.08),
                    t: localT
                )
                return AtmosphericPalette(
                    topColor: top,
                    bottomColor: bottom,
                    accentColor: Color(red: 1.0, green: 0.90, blue: 0.35),
                    strokeColor: Color.white,
                    sunColor: Color(red: 1.0, green: 0.95, blue: 0.45),
                    isLightBackground: true,
                    phaseLabel: "GOLDEN MORNING",
                    phaseIcon: "sun.max.fill"
                )
            }
        }
    }

    private static func lerp(from: (Double, Double, Double), to: (Double, Double, Double), t: Double) -> Color {
        let f = min(1.0, max(0.0, t))
        return Color(
            red: from.0 + (to.0 - from.0) * f,
            green: from.1 + (to.1 - from.1) * f,
            blue: from.2 + (to.2 - from.2) * f
        )
    }
}

/// Lightweight SwiftUI Shape for the smooth cosine dipped-horizon curve.
/// Allowing SwiftUI/Metal to `.trim(from:to:)` this shape directly avoids rebuilding
/// and trimming a 60-segment Path in Swift twice per second.
private struct SmoothHorizonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let xStart = rect.width * 0.06
        let xEnd = rect.width * 0.94
        let xSpan = max(1.0, xEnd - xStart)
        let yBaseline = rect.height * 0.38
        let yDip = rect.height * 0.70

        let steps = 48
        path.move(to: CGPoint(x: xStart, y: yBaseline))
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let x = xStart + xSpan * CGFloat(t)
            let dipFactor = CGFloat((1.0 - cos(2.0 * .pi * t)) / 2.0)
            let y = yBaseline + (yDip - yBaseline) * dipFactor
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

/// Ultra-smooth continuous dipped-horizon progress tracker with interactive drag-to-preview scrubbing.
public struct ValleyProgressView: View {
    public let progress: Double          // 0.0 to 1.0
    public let totalProgress: Double     // Can exceed 1.0
    public let phase: FastingPhase
    public let lineWidth: CGFloat
    public let showLabels: Bool
    public let startTimeLabel: String?
    public let endTimeLabel: String?
    public let isInteractive: Bool
    public let onScrub: ((Double?) -> Void)?
    public let centerContent: AnyView?

    @State private var isDragging: Bool = false
    @State private var dragProgress: Double? = nil
    @State private var lastHapticStep: Int? = nil
    #if os(iOS)
    @State private var selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    #endif

    // Static constellation of small white dot stars scattered around the midnight dip
    private static let midnightStars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.38, 0.46, 2.0, 0.75),
        (0.42, 0.54, 1.5, 0.60),
        (0.45, 0.38, 2.5, 0.90),
        (0.47, 0.62, 1.8, 0.70),
        (0.50, 0.46, 2.8, 0.95), // Center midnight star
        (0.53, 0.58, 1.5, 0.65),
        (0.55, 0.40, 2.2, 0.85),
        (0.58, 0.52, 1.8, 0.70),
        (0.62, 0.46, 2.0, 0.80),
        (0.36, 0.64, 1.2, 0.50),
        (0.64, 0.62, 1.4, 0.55),
        (0.48, 0.82, 1.5, 0.60),
        (0.52, 0.84, 1.8, 0.70)
    ]

    public init<Center: View>(
        progress: Double,
        totalProgress: Double,
        phase: FastingPhase,
        lineWidth: CGFloat = 5,
        showLabels: Bool = true,
        startTimeLabel: String? = nil,
        endTimeLabel: String? = nil,
        isInteractive: Bool = false,
        onScrub: ((Double?) -> Void)? = nil,
        @ViewBuilder centerContent: () -> Center
    ) {
        self.progress = progress
        self.totalProgress = totalProgress
        self.phase = phase
        self.lineWidth = lineWidth
        self.showLabels = showLabels
        self.startTimeLabel = startTimeLabel
        self.endTimeLabel = endTimeLabel
        self.isInteractive = isInteractive
        self.onScrub = onScrub
        self.centerContent = AnyView(centerContent())
    }

    public init(
        progress: Double,
        totalProgress: Double,
        phase: FastingPhase,
        lineWidth: CGFloat = 5,
        showLabels: Bool = true,
        startTimeLabel: String? = nil,
        endTimeLabel: String? = nil,
        isInteractive: Bool = false,
        onScrub: ((Double?) -> Void)? = nil
    ) {
        self.progress = progress
        self.totalProgress = totalProgress
        self.phase = phase
        self.lineWidth = lineWidth
        self.showLabels = showLabels
        self.startTimeLabel = startTimeLabel
        self.endTimeLabel = endTimeLabel
        self.isInteractive = isInteractive
        self.onScrub = onScrub
        self.centerContent = nil
    }

    public var body: some View {
        let displayProgress = dragProgress ?? progress
        let atmosphere = AtmosphericPalette.forProgress(displayProgress, phase: phase)

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Smooth continuous dipped-horizon geometry
            let xStart = w * 0.06
            let xEnd = w * 0.94
            let xSpan = max(1.0, xEnd - xStart)
            let yBaseline = h * 0.38
            let yDip = h * 0.70

            let t = min(1.0, max(0.0, displayProgress))
            let sunPos = evaluateSmoothHorizonPoint(t: t, xStart: xStart, xSpan: xSpan, yBaseline: yBaseline, yDip: yDip)

            ZStack {
                // Midnight Star Field (Small white dots illuminating the night sky around the dip)
                ForEach(0..<Self.midnightStars.count, id: \.self) { idx in
                    let star = Self.midnightStars[idx]
                    Circle()
                        .fill(Color.white.opacity(star.3 * (atmosphere.isLightBackground ? 0.35 : 0.85)))
                        .frame(width: star.2, height: star.2)
                        .position(x: w * star.0, y: h * star.1)
                }

                // Background Track Path (GPU-backed continuous curve)
                SmoothHorizonShape()
                    .stroke(
                        Color.white.opacity(0.20),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )

                // Active Progress Stroke (trimmed directly without per-tick path rebuilding)
                SmoothHorizonShape()
                    .trim(from: 0.0, to: CGFloat(max(0.001, t)))
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: lineWidth + 1.5, lineCap: .round, lineJoin: .round)
                    )

                // Milestone Markers
                let strokeClearance = (lineWidth + 1.5) / 2.0 + 4.0

                // Left Tick (Sunset/Dusk onset & Start Time)
                let pDusk = evaluateSmoothHorizonPoint(t: 0.20, xStart: xStart, xSpan: xSpan, yBaseline: yBaseline, yDip: yDip)
                let hasStartLabel = showLabels && (startTimeLabel?.isEmpty == false)
                let duskHalfHeight: CGFloat = !showLabels ? 5.0 : (hasStartLabel ? 17.5 : 11.0)
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1.5, height: 10)
                    if showLabels {
                        Text("DUSK")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.65))
                        if let start = startTimeLabel, !start.isEmpty {
                            Text(start)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .position(x: pDusk.x, y: pDusk.y + strokeClearance + duskHalfHeight)

                // Middle Bottom Tick (Midnight apex)
                let pMidnight = evaluateSmoothHorizonPoint(t: 0.50, xStart: xStart, xSpan: xSpan, yBaseline: yBaseline, yDip: yDip)
                let midnightHalfHeight: CGFloat = showLabels ? 11.0 : 5.0
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1.5, height: 10)
                    if showLabels {
                        Text("MIDNIGHT")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                }
                .position(x: pMidnight.x, y: pMidnight.y + strokeClearance + midnightHalfHeight)

                // Right Tick (Sunrise/Dawn completion & Target End Time)
                let pDawn = evaluateSmoothHorizonPoint(t: 0.80, xStart: xStart, xSpan: xSpan, yBaseline: yBaseline, yDip: yDip)
                let hasEndLabel = showLabels && (endTimeLabel?.isEmpty == false)
                let dawnHalfHeight: CGFloat = !showLabels ? 5.0 : (hasEndLabel ? 17.5 : 11.0)
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1.5, height: 10)
                    if showLabels {
                        Text("DAWN")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.65))
                        if let end = endTimeLabel, !end.isEmpty {
                            Text(end)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .position(x: pDawn.x, y: pDawn.y + strokeClearance + dawnHalfHeight)

                // Moving Celestial Sun (Traveler Node)
                // Only animate drag press/release scaling — NOT per-second timer ticks (avoids continuous 60-120Hz GPU drain).
                ZStack {
                    Circle()
                        .fill(atmosphere.sunColor.opacity(isDragging ? 0.6 : 0.4))
                        .frame(width: isDragging ? 32 : 24, height: isDragging ? 32 : 24)

                    Circle()
                        .fill(atmosphere.sunColor)
                        .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDragging)
                .position(sunPos)

                // Center Content
                if let content = centerContent {
                    content
                        .position(x: w / 2, y: h * 0.22)
                }

                // Invisible touch scrubbing layer
                if isInteractive {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let rawT = Double((value.location.x - xStart) / xSpan)
                                    let clampedT = min(1.0, max(0.0, rawT))
                                    if !self.isDragging {
                                        #if os(iOS)
                                        self.selectionFeedbackGenerator.prepare()
                                        #endif
                                    }
                                    self.isDragging = true
                                    self.dragProgress = clampedT
                                    self.onScrub?(clampedT)

                                    // Quantize haptics to 2% detents (50 steps) instead of buzzing at 60-120Hz
                                    let step = Int((clampedT * 50.0).rounded())
                                    if step != self.lastHapticStep {
                                        self.lastHapticStep = step
                                        triggerSelectionFeedback()
                                    }
                                }
                                .onEnded { _ in
                                    self.lastHapticStep = nil
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        self.isDragging = false
                                        self.dragProgress = nil
                                        self.onScrub?(nil)
                                    }
                                }
                        )
                }
            }
        }
    }

    /// Evaluates smooth coordinate: x moves linearly, y smoothly dips and rises with continuous trigonometric curvature
    private func evaluateSmoothHorizonPoint(
        t: Double,
        xStart: CGFloat,
        xSpan: CGFloat,
        yBaseline: CGFloat,
        yDip: CGFloat
    ) -> CGPoint {
        let clampedT = min(1.0, max(0.0, t))
        let x = xStart + xSpan * CGFloat(clampedT)

        // Smooth cosine bell: y(t) = yBaseline + (yDip - yBaseline) * (1 - cos(2*pi*t)) / 2
        let angle = 2.0 * .pi * clampedT
        let dipFactor = CGFloat((1.0 - cos(angle)) / 2.0)
        let y = yBaseline + (yDip - yBaseline) * dipFactor

        return CGPoint(x: x, y: y)
    }

    private func triggerSelectionFeedback() {
        #if os(iOS)
        selectionFeedbackGenerator.selectionChanged()
        #endif
    }
}
