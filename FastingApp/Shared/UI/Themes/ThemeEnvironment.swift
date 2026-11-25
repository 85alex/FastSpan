import SwiftUI

private struct AppThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppTheme = .solarAmber
}

public extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeEnvironmentKey.self] }
        set { self[AppThemeEnvironmentKey.self] = newValue }
    }
}
