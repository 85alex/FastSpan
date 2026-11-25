import SwiftUI

/// Presents a live preview of the FastSpan share card in Story (9:16) or Square (1:1) format
/// and exports a rendered PNG via `ImageRenderer`.
public struct ShareSheetModal: View {
    @Environment(\.dismiss) private var dismiss
    public let record: FastRecord
    public let theme: AppTheme
    public let streak: Int

    @State private var selectedFormat: ShareCardFormat = .story
    #if canImport(UIKit)
    @State private var renderedImage: UIImage? = nil
    #endif

    public init(record: FastRecord, theme: AppTheme, streak: Int) {
        self.record = record
        self.theme = theme
        self.streak = streak
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Picker("Card Format", selection: $selectedFormat) {
                        ForEach(ShareCardFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    Spacer()

                    FastShareCardView(
                        record: record,
                        theme: theme,
                        streak: streak,
                        format: selectedFormat
                    )
                    .scaleEffect(selectedFormat == .story ? 0.65 : 0.85)
                    .frame(height: 390)

                    Spacer()

                    #if canImport(UIKit)
                    if let image = renderedImage {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("FastSpan Summary", image: Image(uiImage: image))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Share Card")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                    }
                    #endif
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Share Your Fast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { renderCard() }
            .onChange(of: selectedFormat) { _, _ in renderCard() }
        }
    }

    @MainActor
    private func renderCard() {
        #if canImport(UIKit)
        let card = FastShareCardView(
            record: record,
            theme: theme,
            streak: streak,
            format: selectedFormat
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        self.renderedImage = renderer.uiImage
        #endif
    }
}
