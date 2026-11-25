import Foundation

/// Represents the real-time operational state of the fasting tracker.
public enum FastingPhase: String, Codable, Sendable {
    case idle
    case active
    case targetReached
    case overtime
}

public struct FastingSnapshot: Sendable {
    public let phase: FastingPhase
    public let startTime: Date?
    public let targetEndTime: Date?
    public let targetDuration: TimeInterval
    public let elapsedTime: TimeInterval
    public let remainingTime: TimeInterval
    public let overtimeTime: TimeInterval
    public let progressFraction: Double // 0.0 to 1.0 (clamped)
    public let totalProgressFraction: Double // can exceed 1.0
    public let currentProtocol: FastingProtocol
    public let lastCompletedEndTime: Date?
    public let timeSinceLastFast: TimeInterval?

    public init(
        phase: FastingPhase,
        startTime: Date?,
        targetEndTime: Date?,
        targetDuration: TimeInterval,
        elapsedTime: TimeInterval,
        remainingTime: TimeInterval,
        overtimeTime: TimeInterval,
        progressFraction: Double,
        totalProgressFraction: Double,
        currentProtocol: FastingProtocol,
        lastCompletedEndTime: Date? = nil,
        timeSinceLastFast: TimeInterval? = nil
    ) {
        self.phase = phase
        self.startTime = startTime
        self.targetEndTime = targetEndTime
        self.targetDuration = targetDuration
        self.elapsedTime = elapsedTime
        self.remainingTime = remainingTime
        self.overtimeTime = overtimeTime
        self.progressFraction = progressFraction
        self.totalProgressFraction = totalProgressFraction
        self.currentProtocol = currentProtocol
        self.lastCompletedEndTime = lastCompletedEndTime
        self.timeSinceLastFast = timeSinceLastFast
    }

    public static func idle(
        currentProtocol: FastingProtocol = .standard16_8,
        lastCompletedEndTime: Date? = nil,
        at now: Date = Date()
    ) -> FastingSnapshot {
        let sinceLast: TimeInterval? = lastCompletedEndTime != nil ? max(0, now.timeIntervalSince(lastCompletedEndTime!)) : nil

        return FastingSnapshot(
            phase: .idle,
            startTime: nil,
            targetEndTime: nil,
            targetDuration: currentProtocol.fastingDuration,
            elapsedTime: 0,
            remainingTime: currentProtocol.fastingDuration,
            overtimeTime: 0,
            progressFraction: 0,
            totalProgressFraction: 0,
            currentProtocol: currentProtocol,
            lastCompletedEndTime: lastCompletedEndTime,
            timeSinceLastFast: sinceLast
        )
    }

    public static func calculate(
        startTime: Date,
        targetDuration: TimeInterval,
        protocol chosenProtocol: FastingProtocol,
        lastCompletedEndTime: Date? = nil,
        at now: Date = Date()
    ) -> FastingSnapshot {
        let elapsed = max(0, now.timeIntervalSince(startTime))
        let remaining = max(0, targetDuration - elapsed)
        let overtime = max(0, elapsed - targetDuration)
        let totalFraction = targetDuration > 0 ? (elapsed / targetDuration) : 0.0
        let clampedFraction = min(1.0, max(0.0, totalFraction))

        let phase: FastingPhase
        if elapsed >= targetDuration + 3600.0 {
            phase = .overtime
        } else if elapsed >= targetDuration {
            phase = .targetReached
        } else {
            phase = .active
        }

        let targetEndTime = startTime.addingTimeInterval(targetDuration)

        return FastingSnapshot(
            phase: phase,
            startTime: startTime,
            targetEndTime: targetEndTime,
            targetDuration: targetDuration,
            elapsedTime: elapsed,
            remainingTime: remaining,
            overtimeTime: overtime,
            progressFraction: clampedFraction,
            totalProgressFraction: totalFraction,
            currentProtocol: chosenProtocol,
            lastCompletedEndTime: lastCompletedEndTime,
            timeSinceLastFast: nil
        )
    }

    public var formattedElapsedTime: String {
        formatHMS(elapsedTime)
    }

    public var formattedElapsedTimeHM: String {
        formatHM(elapsedTime)
    }

    public var formattedRemainingTime: String {
        formatHMS(remainingTime)
    }

    public var formattedRemainingTimeHM: String {
        formatHM(remainingTime)
    }

    public var formattedOvertimeTime: String {
        "+" + formatHMS(overtimeTime)
    }

    public var formattedOvertimeTimeHM: String {
        "+" + formatHM(overtimeTime)
    }

    public var formattedTimeSinceLastFast: String? {
        guard let since = timeSinceLastFast else { return nil }
        return formatHMS(since)
    }

    public var formattedTimeSinceLastFastHM: String? {
        guard let since = timeSinceLastFast else { return nil }
        return formatHM(since)
    }

    public var formattedTimeSinceLastFastShort: String? {
        guard let since = timeSinceLastFast else { return nil }
        let total = Int(since)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    public var percentageString: String {
        "\(Int(totalProgressFraction * 100))%"
    }

    private func formatHMS(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func formatHM(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }
}
