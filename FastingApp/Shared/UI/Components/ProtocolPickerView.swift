import SwiftUI

/// Modal selector for preset fasting protocols and custom durations (1h–168h).
public struct ProtocolPickerView: View {
    @Environment(\.dismiss) private var dismiss
    public let currentProtocol: FastingProtocol
    public let onSelect: (FastingProtocol) -> Void

    @State private var customHours: Double

    public init(
        currentProtocol: FastingProtocol,
        onSelect: @escaping (FastingProtocol) -> Void
    ) {
        self.currentProtocol = currentProtocol
        self.onSelect = onSelect
        _customHours = State(initialValue: currentProtocol.fastingHours)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 10) {
                            ForEach(FastingProtocol.allPresets) { proto in
                                protocolRow(proto)
                            }
                        }

                        customDurationCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Fasting Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func protocolRow(_ proto: FastingProtocol) -> some View {
        let isSelected = currentProtocol.id == proto.id
        return Button {
            onSelect(proto)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.orange.opacity(0.22) : Color.white.opacity(0.08))
                        .frame(width: 42, height: 42)
                    Image(systemName: proto.iconName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isSelected ? Color.orange : Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(proto.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(proto.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()

                Text(proto.formattedRatio)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.orange : Color.white.opacity(0.8))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.orange)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.orange.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var customDurationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Duration")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
                Text(FastingProtocol.custom(hours: customHours).formattedRatio)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.orange)
            }

            Slider(value: $customHours, in: 1...168, step: 0.5)
                .tint(Color.orange)

            Button {
                onSelect(.custom(hours: customHours))
                dismiss()
            } label: {
                Text("Use Custom Schedule")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
