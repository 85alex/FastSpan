import SwiftUI

/// watchOS schedule picker for selecting a preset fasting protocol.
public struct WatchProtocolPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fastingManager = FastingManager.shared

    public init() {}

    public var body: some View {
        List {
            ForEach(FastingProtocol.allPresets) { proto in
                Button {
                    fastingManager.selectProtocol(proto)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proto.formattedRatio)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(proto.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if fastingManager.activeProtocol.id == proto.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Schedule")
    }
}
