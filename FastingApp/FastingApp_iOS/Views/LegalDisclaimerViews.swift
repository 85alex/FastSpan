import SwiftUI

/// Legal and safety documents accessible from the first-launch modal and Settings.
public enum LegalDocumentType: String, Identifiable {
    case termsOfUse
    case privacyPolicy
    case medicalDisclaimer

    public var id: String { rawValue }
}

/// First-launch modal dialogue requiring users to acknowledge FastSpan's medical disclaimer and legal terms.
public struct FirstLaunchDisclaimerModal: View {
    public let onAccept: () -> Void

    @State private var activeDocument: LegalDocumentType? = nil

    public init(onAccept: @escaping () -> Void) {
        self.onAccept = onAccept
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.76)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header Icon & Title
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 56, height: 56)
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }

                    Text("Medical Disclaimer")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                }

                // Core Disclaimer Copy
                Text("FastSpan is a personal time-tracking tool for intermittent fasting—not medical advice. Fasting isn’t right for everyone. Always consult a qualified healthcare provider before starting a fasting routine, and stop immediately if you feel unwell.")
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)

                // Agreement & Inline Legal Links
                Text(agreementAttributedText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.openURL, OpenURLAction { url in
                        switch url.host {
                        case "terms":
                            activeDocument = .termsOfUse
                            return .handled
                        case "privacy":
                            activeDocument = .privacyPolicy
                            return .handled
                        case "disclaimer":
                            activeDocument = .medicalDisclaimer
                            return .handled
                        default:
                            return .systemAction
                        }
                    })

                // Primary Agree CTA
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    onAccept()
                } label: {
                    Text("I Agree & Continue")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.85, blue: 0.35),
                                    Color(red: 1.00, green: 0.65, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 12)
            .padding(.horizontal, 24)
        }
        .sheet(item: $activeDocument) { document in
            switch document {
            case .medicalDisclaimer:
                MedicalDisclaimerSheet()
            case .privacyPolicy:
                PrivacyPolicySheet()
            case .termsOfUse:
                TermsOfUseSheet()
            }
        }
    }

    private var agreementAttributedText: AttributedString {
        var result = AttributedString("By tapping \"I Agree & Continue,\" you confirm that you are at least 18 years old and agree to our ")
        result.append(styledLink("Terms of Use", urlString: "fastspan://terms"))
        result.append(AttributedString(", "))
        result.append(styledLink("Privacy Policy", urlString: "fastspan://privacy"))
        result.append(AttributedString(", and "))
        result.append(styledLink("Full Medical Disclaimer", urlString: "fastspan://disclaimer"))
        result.append(AttributedString("."))
        return result
    }

    private func styledLink(_ label: String, urlString: String) -> AttributedString {
        var link = AttributedString(label)
        if let url = URL(string: urlString) {
            link.link = url
        }
        link.foregroundColor = .orange
        link.underlineStyle = .single
        return link
    }
}

/// Full Health & Medical Disclaimer sheet presented from Settings or the first-launch dialog.
public struct MedicalDisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    private struct DisclaimerPoint: Identifiable {
        let id: String
        let title: String
        let body: String
    }

    private static let points: [DisclaimerPoint] = [
        DisclaimerPoint(
            id: "wellness",
            title: "General Wellness & Tracking Only",
            body: "FastSpan is a general wellness and time-tracking tool designed solely to help you log fasting windows. It is not a medical device and does not provide medical, nutritional, or clinical advice, nor does it diagnose, treat, cure, or prevent any disease or health condition."
        ),
        DisclaimerPoint(
            id: "timelines",
            title: "Estimated Timelines Only",
            body: "Any visual curves, timelines, or metabolic stage indicators shown in the app (such as digestion, fat burning, ketosis, or autophagy) represent general, educational estimates based on typical fasting timelines. Individual physiology varies widely; the app does not measure or confirm your actual metabolic state."
        ),
        DisclaimerPoint(
            id: "adults",
            title: "Adults 18+ Only",
            body: "FastSpan is intended strictly for adults aged 18 and older."
        ),
        DisclaimerPoint(
            id: "provider",
            title: "Consult a Healthcare Provider & Contraindications",
            body: "Always consult a physician or qualified healthcare provider before starting any fasting routine or changing your diet. Do not use this app if you are pregnant, breastfeeding, under 18, underweight, or have a history of eating disorders, diabetes, or any chronic or metabolic medical condition, unless explicitly directed and supervised by a doctor."
        ),
        DisclaimerPoint(
            id: "listen",
            title: "Listen to Your Body",
            body: "Stop fasting immediately and seek medical attention if you experience dizziness, fainting, confusion, weakness, or any other adverse symptoms. Never disregard or delay professional medical advice because of information displayed in this app."
        ),
        DisclaimerPoint(
            id: "liability",
            title: "Assumption of Risk & Limitation of Liability",
            body: "FastSpan is provided \"as is\" and \"as available\" without warranties of any kind. By using this app, you acknowledge that fasting carries inherent health risks and that you participate voluntarily and entirely at your own risk. To the fullest extent permitted by applicable law, the developer of FastSpan shall not be liable for any direct, indirect, incidental, or consequential injury, loss, or damages arising from your use of, or reliance on, the app."
        )
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Health & Medical Disclaimer")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Self.points) { point in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• \(point.title)")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                    Text(point.body)
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(Color.white.opacity(0.75))
                                        .lineSpacing(3)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Medical Disclaimer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                        .foregroundStyle(Color.orange)
                }
            }
        }
    }
}

/// Privacy Policy & Privacy Manifesto sheet shared by the first-launch modal and Settings.
public struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Privacy by Design")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("We believe health and wellness data is deeply personal. FastSpan was architected from the first line of code with strict privacy principles:")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.7))

                        VStack(alignment: .leading, spacing: 12) {
                            legalCard(
                                title: "Zero Third-Party SDKs",
                                desc: "No Facebook, Google, Amplitude, Mixpanel, or advertising trackers are installed. FastSpan does not collect, sell, or share your personal data."
                            )
                            legalCard(
                                title: "100% Local Notifications",
                                desc: "Your fasting schedule and reminders are scheduled entirely on your device and never touch an external push notification server."
                            )
                            legalCard(
                                title: "Private Apple iCloud Sync",
                                desc: "When enabled, sync between your iPhone and Apple Watch uses your own private Apple iCloud container. You can turn iCloud sync off anytime in Settings."
                            )
                            legalCard(
                                title: "Direct Data Ownership",
                                desc: "Your fasting records remain strictly on your device and private iCloud account, and can be exported to CSV anytime."
                            )
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Privacy Policy")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                        .foregroundStyle(Color.orange)
                }
            }
        }
    }

    private func legalCard(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
            Text(desc)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.65))
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

/// Terms of Use sheet shared by the first-launch modal and Settings.
public struct TermsOfUseSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Use")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("By using FastSpan, you agree to the following terms governing your use of the application:")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.7))

                        VStack(alignment: .leading, spacing: 12) {
                            termsCard(
                                title: "Eligibility (18+)",
                                desc: "FastSpan is intended strictly for adults aged 18 and older. By using the app, you confirm that you meet this age requirement."
                            )
                            termsCard(
                                title: "Personal Wellness Use Only",
                                desc: "FastSpan is provided solely as a personal time-tracking utility for intermittent fasting. It does not provide medical advice, diagnosis, or treatment, and is subject to our Health & Medical Disclaimer."
                            )
                            termsCard(
                                title: "In-App Purchases",
                                desc: "Optional Pro features are available as a one-time non-consumable purchase processed securely through Apple's App Store. All billing, refunds, and purchase restoration are governed by Apple's App Store terms."
                            )
                            termsCard(
                                title: "Disclaimer of Warranties & Liability",
                                desc: "FastSpan is provided \"as is\" and \"as available\" without warranties of any kind. To the fullest extent permitted by applicable law, the developer of FastSpan shall not be liable for any direct, indirect, incidental, or consequential damages arising from your use of the app."
                            )
                            termsCard(
                                title: "Apple Standard EULA",
                                desc: "Your license to use FastSpan is also subject to Apple's Licensed Application End User License Agreement (Standard EULA)."
                            )
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Terms of Use")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                        .foregroundStyle(Color.orange)
                }
            }
        }
    }

    private func termsCard(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
            Text(desc)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.65))
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
