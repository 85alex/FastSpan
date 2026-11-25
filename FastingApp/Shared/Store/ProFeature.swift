import Foundation

/// Defines all Pro-tier features unlocked via the one-time lifetime purchase.
public enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case smartDynamicIsland = "Smart Dynamic Island"
    case premiumThemes = "Premium Themes"
    case unlimitedHistory = "Unlimited History"
    case csvExport = "CSV Data Export"

    public var id: String { rawValue }
}
