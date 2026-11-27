import SwiftUI

public enum FastDetailMode: Equatable {
    case startRetroactive
    case editOngoing
    case completeFast
    case completeRemoteFast(protocolName: String, formattedDuration: String, isGoalAchieved: Bool)
}

/// Sheet for editing ongoing fast properties or adding notes and mood upon completion.
public struct FastDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let mode: FastDetailMode
    public let onSaveEdit: ((Date, Double) -> Void)?
    public let onConfirmComplete: ((String?, String?) -> Void)?

    @State private var startTime: Date
    @State private var targetHours: Double
    @State private var notes: String = ""
    @State private var selectedMood: String = "⚡ Energized"

    private let moods = [
        "⚡ Energized",
        "🧘 Calm",
        "🎯 Focused",
        "💪 Strong",
        "😴 Tired",
        "🍽️ Hungry"
    ]

    public init(
        mode: FastDetailMode,
        initialStartTime: Date = Date(),
        initialTargetHours: Double = 16.0,
        onSaveEdit: ((Date, Double) -> Void)? = nil,
        onConfirmComplete: ((String?, String?) -> Void)? = nil
    ) {
        self.mode = mode
        self.onSaveEdit = onSaveEdit
        self.onConfirmComplete = onConfirmComplete
        _startTime = State(initialValue: initialStartTime)
        let clampedHours = min(
            FastingProtocol.maxFastingHours,
            max(FastingProtocol.minFastingHours, initialTargetHours)
        )
        _targetHours = State(initialValue: clampedHours)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()

                Form {
                    if mode == .editOngoing || mode == .startRetroactive {
                        Section("Fast Timing") {
                            DatePicker(
                                "Start Time",
                                selection: $startTime,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )

                            Stepper(
                                value: $targetHours,
                                in: FastingProtocol.minFastingHours...FastingProtocol.maxFastingHours,
                                step: 0.5
                            ) {
                                HStack {
                                    Text("Target Duration")
                                    Spacer()
                                    Text(String(format: "%.1fh", targetHours))
                                        .foregroundStyle(Color.orange)
                                        .bold()
                                }
                            }
                        }
                    } else {
                        if case let .completeRemoteFast(protocolName, formattedDuration, isGoalAchieved) = mode {
                            Section {
                                HStack(spacing: 12) {
                                    Image(systemName: "applewatch")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color.orange)
                                        .frame(width: 36, height: 36)
                                        .background(Color.orange.opacity(0.15))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Completed on Apple Watch")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.white)
                                        Text("\(formattedDuration) • \(protocolName)")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.white.opacity(0.7))
                                    }

                                    Spacer()

                                    if isGoalAchieved {
                                        Text("GOAL MET")
                                            .font(.system(size: 10, weight: .black, design: .rounded))
                                            .foregroundStyle(Color.black)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        Section("How do you feel?") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                                ForEach(moods, id: \.self) { mood in
                                    Button {
                                        selectedMood = mood
                                    } label: {
                                        Text(mood)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                selectedMood == mood ? Color.orange : Color.white.opacity(0.08)
                                            )
                                            .foregroundStyle(selectedMood == mood ? Color.black : Color.white)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Section("Notes & Reflections") {
                            TextField("How was your fast? (Optional)", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isRemoteCompletion ? "Skip" : "Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .startRetroactive ? "Start Fast" : "Save") {
                        if mode == .editOngoing || mode == .startRetroactive {
                            onSaveEdit?(startTime, targetHours)
                        } else {
                            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            onConfirmComplete?(trimmed.isEmpty ? nil : trimmed, selectedMood)
                        }
                        dismiss()
                    }
                    .bold()
                    .foregroundStyle(Color.orange)
                }
            }
        }
        .presentationDetents(isRemoteCompletion ? [.medium, .large] : [.medium])
    }

    private var isRemoteCompletion: Bool {
        if case .completeRemoteFast = mode { return true }
        return false
    }

    private var navigationTitleText: String {
        switch mode {
        case .startRetroactive:
            return "Start Earlier"
        case .editOngoing:
            return "Edit Fast"
        case .completeFast:
            return "Complete Fast"
        case .completeRemoteFast:
            return "Fast Completed"
        }
    }
}
