import SwiftUI

/// Dynamic diurnal sky background with a setting sun (left), expanded night starfield,
/// occasional shooting stars, and a rising sun (right) for live fasting and time-travel scrubbing.
public struct CelestialSkyBackgroundView: View {
    public let progress: Double
    public let phase: FastingPhase
    public let isScrubbing: Bool

    @State private var liveMeteorProgress: CGFloat = 0.0
    @State private var liveMeteorActive: Bool = false
    @State private var liveMeteorIndex: Int = 0

    public init(progress: Double, phase: FastingPhase, isScrubbing: Bool = false) {
        self.progress = progress
        self.phase = phase
        self.isScrubbing = isScrubbing
    }

    private struct StarSpec {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let opacity: Double
    }

    private struct MeteorTrajectory {
        let startX: CGFloat
        let startY: CGFloat
        let endX: CGFloat
        let endY: CGFloat
    }

    // Deterministic full-sky starfield (~56 stars across upper & mid sky)
    private static let stars: [StarSpec] = [
        StarSpec(x: 0.06, y: 0.09, radius: 1.4, opacity: 0.75),
        StarSpec(x: 0.13, y: 0.15, radius: 2.0, opacity: 0.90),
        StarSpec(x: 0.19, y: 0.07, radius: 1.2, opacity: 0.60),
        StarSpec(x: 0.25, y: 0.21, radius: 1.7, opacity: 0.80),
        StarSpec(x: 0.31, y: 0.11, radius: 2.3, opacity: 0.95),
        StarSpec(x: 0.37, y: 0.17, radius: 1.3, opacity: 0.65),
        StarSpec(x: 0.43, y: 0.08, radius: 1.8, opacity: 0.85),
        StarSpec(x: 0.49, y: 0.14, radius: 2.4, opacity: 0.95),
        StarSpec(x: 0.56, y: 0.06, radius: 1.3, opacity: 0.65),
        StarSpec(x: 0.62, y: 0.19, radius: 2.1, opacity: 0.90),
        StarSpec(x: 0.69, y: 0.10, radius: 1.5, opacity: 0.75),
        StarSpec(x: 0.76, y: 0.16, radius: 2.2, opacity: 0.90),
        StarSpec(x: 0.83, y: 0.08, radius: 1.4, opacity: 0.70),
        StarSpec(x: 0.90, y: 0.14, radius: 1.9, opacity: 0.85),
        StarSpec(x: 0.95, y: 0.22, radius: 1.2, opacity: 0.55),

        StarSpec(x: 0.08, y: 0.27, radius: 1.6, opacity: 0.75),
        StarSpec(x: 0.16, y: 0.33, radius: 1.2, opacity: 0.60),
        StarSpec(x: 0.22, y: 0.29, radius: 2.0, opacity: 0.85),
        StarSpec(x: 0.29, y: 0.36, radius: 1.4, opacity: 0.65),
        StarSpec(x: 0.35, y: 0.26, radius: 1.8, opacity: 0.80),
        StarSpec(x: 0.42, y: 0.32, radius: 1.3, opacity: 0.60),
        StarSpec(x: 0.48, y: 0.25, radius: 2.5, opacity: 0.95),
        StarSpec(x: 0.54, y: 0.34, radius: 1.5, opacity: 0.70),
        StarSpec(x: 0.60, y: 0.28, radius: 1.9, opacity: 0.85),
        StarSpec(x: 0.67, y: 0.35, radius: 1.2, opacity: 0.55),
        StarSpec(x: 0.73, y: 0.27, radius: 2.2, opacity: 0.90),
        StarSpec(x: 0.80, y: 0.33, radius: 1.4, opacity: 0.70),
        StarSpec(x: 0.87, y: 0.26, radius: 1.8, opacity: 0.80),
        StarSpec(x: 0.93, y: 0.34, radius: 1.5, opacity: 0.70),

        StarSpec(x: 0.05, y: 0.44, radius: 1.3, opacity: 0.55),
        StarSpec(x: 0.12, y: 0.49, radius: 1.8, opacity: 0.75),
        StarSpec(x: 0.20, y: 0.42, radius: 1.2, opacity: 0.50),
        StarSpec(x: 0.27, y: 0.51, radius: 1.6, opacity: 0.65),
        StarSpec(x: 0.34, y: 0.46, radius: 2.0, opacity: 0.80),
        StarSpec(x: 0.41, y: 0.54, radius: 1.4, opacity: 0.60),
        StarSpec(x: 0.47, y: 0.45, radius: 2.3, opacity: 0.90),
        StarSpec(x: 0.53, y: 0.52, radius: 1.5, opacity: 0.65),
        StarSpec(x: 0.59, y: 0.43, radius: 1.9, opacity: 0.80),
        StarSpec(x: 0.65, y: 0.50, radius: 1.3, opacity: 0.55),
        StarSpec(x: 0.72, y: 0.44, radius: 2.0, opacity: 0.80),
        StarSpec(x: 0.79, y: 0.51, radius: 1.4, opacity: 0.60),
        StarSpec(x: 0.86, y: 0.45, radius: 1.7, opacity: 0.70),
        StarSpec(x: 0.94, y: 0.49, radius: 1.2, opacity: 0.50),

        StarSpec(x: 0.10, y: 0.60, radius: 1.2, opacity: 0.40),
        StarSpec(x: 0.24, y: 0.63, radius: 1.5, opacity: 0.50),
        StarSpec(x: 0.38, y: 0.59, radius: 1.3, opacity: 0.45),
        StarSpec(x: 0.51, y: 0.64, radius: 1.8, opacity: 0.60),
        StarSpec(x: 0.64, y: 0.60, radius: 1.4, opacity: 0.45),
        StarSpec(x: 0.77, y: 0.62, radius: 1.6, opacity: 0.50),
        StarSpec(x: 0.89, y: 0.58, radius: 1.2, opacity: 0.40),
        StarSpec(x: 0.45, y: 0.70, radius: 1.3, opacity: 0.35),
        StarSpec(x: 0.55, y: 0.71, radius: 1.5, opacity: 0.40),
    ]

    private static let meteorTrajectories: [MeteorTrajectory] = [
        MeteorTrajectory(startX: 0.18, startY: 0.10, endX: 0.54, endY: 0.28),
        MeteorTrajectory(startX: 0.78, startY: 0.08, endX: 0.42, endY: 0.26),
        MeteorTrajectory(startX: 0.30, startY: 0.14, endX: 0.68, endY: 0.32),
        MeteorTrajectory(startX: 0.86, startY: 0.16, endX: 0.50, endY: 0.34),
    ]

    private var clampedProgress: Double {
        min(1.0, max(0.0, progress))
    }

    private var nightVisibility: Double {
        if phase == .idle || phase == .targetReached || phase == .overtime || progress >= 1.0 {
            return 0.0
        }
        let p = clampedProgress
        if p <= 0.20 || p >= 0.80 {
            return 0.0
        } else if p < 0.38 {
            return (p - 0.20) / 0.18
        } else if p <= 0.62 {
            return 1.0
        } else {
            return (0.80 - p) / 0.18
        }
    }

    private var isNightActive: Bool {
        nightVisibility > 0.35
    }

    private struct SunState {
        let xFraction: CGFloat
        let yFraction: CGFloat
        let opacity: Double
        let coreColor: Color
        let glowColor: Color
    }

    private var sunState: SunState {
        if phase == .idle {
            return SunState(
                xFraction: 0.16,
                yFraction: 0.17,
                opacity: 1.0,
                coreColor: Color(red: 1.0, green: 0.96, blue: 0.72),
                glowColor: Color(red: 1.0, green: 0.84, blue: 0.30)
            )
        }
        if phase == .targetReached || phase == .overtime || progress >= 1.0 {
            return SunState(
                xFraction: 0.84,
                yFraction: 0.17,
                opacity: 1.0,
                coreColor: Color(red: 1.0, green: 0.97, blue: 0.76),
                glowColor: Color(red: 1.0, green: 0.86, blue: 0.32)
            )
        }

        let p = clampedProgress

        // Left side: Sun comes down & sets below horizon (0.0 -> 0.36)
        if p <= 0.36 {
            let u = p / 0.36
            let x = 0.16 + 0.08 * CGFloat(u)
            let y = 0.17 + 0.48 * CGFloat(u * u)
            let opacity = u < 0.62 ? 1.0 : max(0.0, 1.0 - (u - 0.62) / 0.38)
            let warm = Color(
                red: 1.0,
                green: 0.88 - 0.42 * u,
                blue: 0.34 - 0.18 * u
            )
            let core = Color(
                red: 1.0,
                green: 0.96 - 0.30 * u,
                blue: 0.72 - 0.40 * u
            )
            return SunState(xFraction: x, yFraction: y, opacity: opacity, coreColor: core, glowColor: warm)
        }

        // Right side: Sun rises from horizon into morning sky (0.64 -> 1.0)
        if p >= 0.64 {
            let u = (p - 0.64) / 0.36
            let easeOut = 1.0 - (1.0 - u) * (1.0 - u)
            let x = 0.76 + 0.08 * CGFloat(u)
            let y = 0.65 - 0.48 * CGFloat(easeOut)
            let opacity = u < 0.38 ? min(1.0, u / 0.38) : 1.0
            let warm = Color(
                red: 1.0,
                green: 0.46 + 0.42 * u,
                blue: 0.16 + 0.20 * u
            )
            let core = Color(
                red: 1.0,
                green: 0.66 + 0.30 * u,
                blue: 0.32 + 0.42 * u
            )
            return SunState(xFraction: x, yFraction: y, opacity: opacity, coreColor: core, glowColor: warm)
        }

        return SunState(xFraction: 0.5, yFraction: 0.8, opacity: 0.0, coreColor: .clear, glowColor: .clear)
    }

    private var activeScrubMeteor: (trajectory: MeteorTrajectory, progress: CGFloat)? {
        guard isScrubbing, phase != .idle else { return nil }
        let p = clampedProgress
        if p >= 0.37 && p <= 0.49 {
            return (Self.meteorTrajectories[0], CGFloat((p - 0.37) / 0.12))
        }
        if p >= 0.52 && p <= 0.64 {
            return (Self.meteorTrajectories[1], CGFloat((p - 0.52) / 0.12))
        }
        return nil
    }

    public var body: some View {
        let atmosphere = AtmosphericPalette.forProgress(progress, phase: phase)
        let sun = sunState
        let starAlpha = nightVisibility

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                LinearGradient(
                    colors: [atmosphere.topColor, atmosphere.bottomColor],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Celestial Sun (setting left / rising right)
                if sun.opacity > 0.01 {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        sun.glowColor.opacity(0.45),
                                        sun.glowColor.opacity(0.14),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 12,
                                    endRadius: 95
                                )
                            )
                            .frame(width: 190, height: 190)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        sun.coreColor,
                                        sun.glowColor.opacity(0.85),
                                        sun.glowColor.opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: 6,
                                    endRadius: 34
                                )
                            )
                            .frame(width: 68, height: 68)
                    }
                    .opacity(sun.opacity)
                    .position(x: w * sun.xFraction, y: h * sun.yFraction)
                }

                // Full-sky night starfield + shooting stars in a single Canvas pass
                if starAlpha > 0.01 {
                    Canvas { context, size in
                        for star in Self.stars {
                            let sx = size.width * star.x
                            let sy = size.height * star.y
                            let r = star.radius
                            let rect = CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(Color.white.opacity(star.opacity * starAlpha))
                            )
                        }

                        if let scrubMeteor = activeScrubMeteor {
                            drawMeteor(
                                in: &context,
                                size: size,
                                trajectory: scrubMeteor.trajectory,
                                t: scrubMeteor.progress,
                                alpha: starAlpha
                            )
                        } else if liveMeteorActive {
                            let traj = Self.meteorTrajectories[liveMeteorIndex % Self.meteorTrajectories.count]
                            drawMeteor(
                                in: &context,
                                size: size,
                                trajectory: traj,
                                t: liveMeteorProgress,
                                alpha: starAlpha
                            )
                        }
                    }
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .task(id: isNightActive && !isScrubbing) {
            guard isNightActive && !isScrubbing else {
                liveMeteorActive = false
                liveMeteorProgress = 0.0
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7.5))
                if Task.isCancelled { break }
                liveMeteorProgress = 0.0
                liveMeteorActive = true
                withAnimation(.easeOut(duration: 0.95)) {
                    liveMeteorProgress = 1.0
                }
                try? await Task.sleep(for: .seconds(1.05))
                if Task.isCancelled { break }
                liveMeteorActive = false
                liveMeteorIndex += 1
            }
        }
    }

    private func drawMeteor(
        in context: inout GraphicsContext,
        size: CGSize,
        trajectory: MeteorTrajectory,
        t: CGFloat,
        alpha: Double
    ) {
        let clampedT = min(1.0, max(0.0, t))
        guard clampedT > 0.01 && clampedT < 0.99 else { return }

        let p0 = CGPoint(x: size.width * trajectory.startX, y: size.height * trajectory.startY)
        let p1 = CGPoint(x: size.width * trajectory.endX, y: size.height * trajectory.endY)

        let head = CGPoint(
            x: p0.x + (p1.x - p0.x) * clampedT,
            y: p0.y + (p1.y - p0.y) * clampedT
        )
        let tailT = max(0.0, clampedT - 0.24)
        let tail = CGPoint(
            x: p0.x + (p1.x - p0.x) * tailT,
            y: p0.y + (p1.y - p0.y) * tailT
        )

        // Fade smoothly at start and end of streak
        let envelope = sin(Double(clampedT) * .pi) * alpha

        var path = Path()
        path.move(to: tail)
        path.addLine(to: head)

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    Color.clear,
                    Color(red: 0.72, green: 0.92, blue: 1.0).opacity(0.45 * envelope),
                    Color.white.opacity(0.95 * envelope)
                ]),
                startPoint: tail,
                endPoint: head
            ),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
        )

        let headRadius: CGFloat = 2.4
        let headRect = CGRect(
            x: head.x - headRadius,
            y: head.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        )
        context.fill(Path(ellipseIn: headRect), with: .color(Color.white.opacity(envelope)))
    }
}
