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

    // MARK: - Presets (8 total)

    public static let standard16_8 = FastingProtocol(
        id: "16_8",
        name: "16:8 LeanGains",
        subtitle: "Gold standard daily fast",
        fastingHours: 16.0,
        iconName: "flame.fill"
    )

    public static let moderate18_6 = FastingProtocol(
        id: "18_6",
        name: "18:6 Moderate",
        subtitle: "Extended fat-burning window",
        fastingHours: 18.0,
        iconName: "bolt.fill"
    )

    public static let warrior20_4 = FastingProtocol(
        id: "20_4",
        name: "20:4 Warrior Diet",
        subtitle: "Deep metabolic reset",
        fastingHours: 20.0,
        iconName: "shield.fill"
    )

    public static let omad23_1 = FastingProtocol(
        id: "23_1",
        name: "23:1 OMAD",
        subtitle: "One Meal A Day",
        fastingHours: 23.0,
        iconName: "star.fill"
    )

    public static let gentle14_10 = FastingProtocol(
        id: "14_10",
        name: "14:10 Gentle",
        subtitle: "Easy sustainable start",
        fastingHours: 14.0,
        iconName: "leaf.fill"
    )

    public static let circadian13_11 = FastingProtocol(
        id: "13_11",
        name: "13:11 Circadian",
        subtitle: "Overnight digestive rest",
        fastingHours: 13.0,
        iconName: "moon.stars.fill"
    )

    public static let circadian12_12 = FastingProtocol(
        id: "12_12",
        name: "12:12 Circadian Rhythm",
        subtitle: "Balanced 12-hour rhythm",
        fastingHours: 12.0,
        iconName: "sun.horizon.fill"
    )

    public static let monk36 = FastingProtocol(
        id: "36h",
        name: "36h Monk Fast",
        subtitle: "Full-day cellular renewal",
        fastingHours: 36.0,
        iconName: "sparkles"
    )

    public static let allPresets: [FastingProtocol] = [
        .standard16_8,
        .moderate18_6,
        .warrior20_4,
        .omad23_1,
        .gentle14_10,
        .circadian13_11,
        .circadian12_12,
        .monk36
    ]

    public static func custom(hours: Double) -> FastingProtocol {
        let clamped = min(168.0, max(1.0, hours))
        let totalMinutes = Int((clamped * 60.0).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        let label = m == 0 ? "\(h)h Custom" : "\(h)h \(m)m Custom"
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
