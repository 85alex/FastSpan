import SwiftUI

/// Compact elevated metric pill displaying an icon, uppercase title, and primary value.
public struct MetricPillView: View {
    public let icon: String
    public let title: String
    public let value: String
    public let accentColor: Color

    public init(
        icon: String,
        title: String,
        value: String,
        accentColor: Color = .orange
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
