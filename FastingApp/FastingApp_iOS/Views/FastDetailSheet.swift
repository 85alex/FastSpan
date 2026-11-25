import SwiftUI

public enum FastDetailMode {
    case startRetroactive
    case editOngoing
    case completeFast
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
        _targetHours = State(initialValue: initialTargetHours)
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
                                in: 1.0...72.0,
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
            .navigationTitle(
                mode == .startRetroactive ? "Start Earlier" : (mode == .editOngoing ? "Edit Fast" : "Complete Fast")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
        .presentationDetents([.medium])
    }
}
