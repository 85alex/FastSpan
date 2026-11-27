import Foundation

/// Represents an intermittent fasting schedule preset or custom fasting duration.
public struct FastingProtocol: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let fastingHours: Double
    public let iconName: String
    public let isCustom: Bool

    public var eatingHours: Double {
        max(0, 24.0 - fastingHours)
    }

    public var fastingDuration: TimeInterval {
        fastingHours * 3600.0
    }

    public var formattedRatio: String {
        if !isCustom {
            let f = Int(fastingHours)
            let e = Int(eatingHours)
            if fastingHours >= 24.0 {
                return "\(f)h"
            }
            return "\(f):\(e)"
        }
        let totalMinutes = Int((fastingHours * 60.0).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }

    public init(
        id: String,
        name: String,
        subtitle: String = "",
        fastingHours: Double,
        iconName: String = "clock.fill",
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.fastingHours = fastingHours
        self.iconName = iconName
        self.isCustom = isCustom
    }

    public static let minFastingHours: Double = 1.0
    public static let maxFastingHours: Double = 20.0

    // MARK: - Presets (6 total, max 20h)

    public static let standard16_8 = FastingProtocol(
        id: "16_8",
        name: "16:8",
        subtitle: "16h fast • 8h eating",
        fastingHours: 16.0,
        iconName: "flame.fill"
    )

    public static let moderate18_6 = FastingProtocol(
        id: "18_6",
        name: "18:6",
        subtitle: "18h fast • 6h eating",
        fastingHours: 18.0,
        iconName: "bolt.fill"
    )

    public static let warrior20_4 = FastingProtocol(
        id: "20_4",
        name: "20:4",
        subtitle: "20h fast • 4h eating",
        fastingHours: 20.0,
        iconName: "shield.fill"
    )

    public static let gentle14_10 = FastingProtocol(
        id: "14_10",
        name: "14:10",
        subtitle: "14h fast • 10h eating",
        fastingHours: 14.0,
        iconName: "leaf.fill"
    )

    public static let circadian13_11 = FastingProtocol(
        id: "13_11",
        name: "13:11",
        subtitle: "13h fast • 11h eating",
        fastingHours: 13.0,
        iconName: "moon.stars.fill"
    )

    public static let circadian12_12 = FastingProtocol(
        id: "12_12",
        name: "12:12",
        subtitle: "12h fast • 12h eating",
        fastingHours: 12.0,
        iconName: "sun.horizon.fill"
    )

    public static let allPresets: [FastingProtocol] = [
        .standard16_8,
        .moderate18_6,
        .warrior20_4,
        .gentle14_10,
        .circadian13_11,
        .circadian12_12
    ]

    public static func custom(hours: Double) -> FastingProtocol {
        let clamped = min(maxFastingHours, max(minFastingHours, hours))
        let totalMinutes = Int((clamped * 60.0).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        let label = m == 0 ? "\(h)h" : "\(h)h \(m)m"
        return FastingProtocol(
            id: "custom_\(totalMinutes)",
            name: label,
            subtitle: "Custom fasting schedule",
            fastingHours: Double(totalMinutes) / 60.0,
            iconName: "slider.horizontal.3",
            isCustom: true
        )
    }
}
