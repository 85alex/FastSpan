import SwiftUI

/// Compact "PRO" pill badge for gated themes and tools.
public struct ProBadgeView: View {
    public let size: CGFloat

    public init(size: CGFloat = 10) {
        self.size = size
    }

    public var body: some View {
        Text("PRO")
            .font(.system(size: size, weight: .black, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Color.black)
            .padding(.horizontal, max(5, size * 0.6))
            .padding(.vertical, max(2, size * 0.25))
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.85, blue: 0.35),
                        Color(red: 1.00, green: 0.62, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
    }
}
