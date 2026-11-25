import SwiftUI

/// Visual theme configuration for FastSpan (2 Free + 5 Pro themes).
public struct AppTheme: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let isPro: Bool
    public let primaryColor: Color
    public let secondaryColor: Color
    public let overtimeColor: Color
    public let backgroundTop: Color
    public let backgroundBottom: Color

    public var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public var ringGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var overtimeGradient: LinearGradient {
        LinearGradient(
            colors: [overtimeColor, primaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static let slateMinimal = AppTheme(
        id: "slate_minimal",
        name: "Slate Minimal",
        subtitle: "Crisp monochrome",
        isPro: false,
        primaryColor: Color(red: 0.85, green: 0.88, blue: 0.94),
        secondaryColor: Color(red: 0.52, green: 0.58, blue: 0.68),
        overtimeColor: Color(red: 1.0, green: 0.78, blue: 0.30),
        backgroundTop: Color(red: 0.10, green: 0.11, blue: 0.14),
        backgroundBottom: Color(red: 0.04, green: 0.05, blue: 0.07)
    )

    public static let solarAmber = AppTheme(
        id: "solar_amber",
        name: "Solar Amber",
        subtitle: "Warm golden glow",
        isPro: false,
        primaryColor: Color(red: 1.00, green: 0.72, blue: 0.20),
        secondaryColor: Color(red: 0.95, green: 0.38, blue: 0.12),
        overtimeColor: Color(red: 1.00, green: 0.88, blue: 0.35),
        backgroundTop: Color(red: 0.14, green: 0.09, blue: 0.05),
        backgroundBottom: Color(red: 0.05, green: 0.03, blue: 0.04)
    )

    public static let deepMidnight = AppTheme(
        id: "deep_midnight",
        name: "Deep Midnight",
        subtitle: "Velvet night sky",
        isPro: true,
        primaryColor: Color(red: 0.55, green: 0.45, blue: 1.00),
        secondaryColor: Color(red: 0.25, green: 0.65, blue: 1.00),
        overtimeColor: Color(red: 0.95, green: 0.75, blue: 0.30),
        backgroundTop: Color(red: 0.08, green: 0.06, blue: 0.18),
        backgroundBottom: Color(red: 0.03, green: 0.02, blue: 0.08)
    )

    public static let emeraldZen = AppTheme(
        id: "emerald_zen",
        name: "Emerald Zen",
        subtitle: "Calm forest energy",
        isPro: true,
        primaryColor: Color(red: 0.22, green: 0.88, blue: 0.58),
        secondaryColor: Color(red: 0.10, green: 0.65, blue: 0.75),
        overtimeColor: Color(red: 1.00, green: 0.82, blue: 0.30),
        backgroundTop: Color(red: 0.04, green: 0.14, blue: 0.11),
        backgroundBottom: Color(red: 0.02, green: 0.06, blue: 0.05)
    )

    public static let sunsetCoral = AppTheme(
        id: "sunset_coral",
        name: "Sunset Coral",
        subtitle: "Warm horizon flare",
        isPro: true,
        primaryColor: Color(red: 1.00, green: 0.42, blue: 0.50),
        secondaryColor: Color(red: 1.00, green: 0.68, blue: 0.25),
        overtimeColor: Color(red: 1.00, green: 0.88, blue: 0.35),
        backgroundTop: Color(red: 0.18, green: 0.06, blue: 0.10),
        backgroundBottom: Color(red: 0.06, green: 0.03, blue: 0.06)
    )

    public static let cyberNeon = AppTheme(
        id: "cyber_neon",
        name: "Cyber Neon",
        subtitle: "Electric synthwave",
        isPro: true,
        primaryColor: Color(red: 0.12, green: 0.92, blue: 0.98),
        secondaryColor: Color(red: 0.92, green: 0.25, blue: 0.88),
        overtimeColor: Color(red: 1.00, green: 0.85, blue: 0.25),
        backgroundTop: Color(red: 0.08, green: 0.05, blue: 0.18),
        backgroundBottom: Color(red: 0.03, green: 0.03, blue: 0.08)
    )

    public static let titaniumFrost = AppTheme(
        id: "titanium_frost",
        name: "Titanium Frost",
        subtitle: "Brushed ice steel",
        isPro: true,
        primaryColor: Color(red: 0.78, green: 0.88, blue: 0.98),
        secondaryColor: Color(red: 0.45, green: 0.68, blue: 0.88),
        overtimeColor: Color(red: 1.00, green: 0.82, blue: 0.35),
        backgroundTop: Color(red: 0.09, green: 0.12, blue: 0.16),
        backgroundBottom: Color(red: 0.04, green: 0.05, blue: 0.08)
    )

    public static let allThemes: [AppTheme] = [
        .slateMinimal,
        .solarAmber,
        .deepMidnight,
        .emeraldZen,
        .sunsetCoral,
        .cyberNeon,
        .titaniumFrost
    ]

    public static func find(by id: String) -> AppTheme {
        allThemes.first(where: { $0.id == id }) ?? .solarAmber
    }
}
