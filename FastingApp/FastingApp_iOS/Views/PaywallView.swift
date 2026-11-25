import SwiftUI

/// Elegant paywall presenting the $5 CAD one-time lifetime Pro upgrade.
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storeManager = StoreManager.shared
    @State private var fastingManager = FastingManager.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background dark styling
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.12),
                        Color(red: 0.03, green: 0.03, blue: 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Icon & Title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.00, green: 0.82, blue: 0.28),
                                                Color(red: 0.98, green: 0.45, blue: 0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.orange.opacity(0.4), radius: 16, x: 0, y: 6)

                                Image(systemName: "sparkles")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(Color.black)
                            }
                            .padding(.top, 16)

                            Text("FastSpan Pro")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)

                            Text("Supercharge your fasting journey with pro tools and endless personalization.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Feature Grid / List
                        VStack(spacing: 14) {
                            featureRow(
                                icon: "circle.circle.fill",
                                title: "Smart Dynamic Island",
                                subtitle: "Live lock screen & island tracker at 1h before goal & overtime",
                                color: Color(red: 0.12, green: 0.78, blue: 0.99)
                            )

                            featureRow(
                                icon: "paintpalette.fill",
                                title: "All Premium Themes",
                                subtitle: "Unlock Deep Midnight, Emerald Zen, Sunset Coral, Cyber Neon & more",
                                color: Color(red: 1.00, green: 0.42, blue: 0.52)
                            )

                            featureRow(
                                icon: "chart.bar.xaxis",
                                title: "Unlimited Lifetime History",
                                subtitle: "Access your full fasting archive and long-term metabolic trends",
                                color: Color(red: 0.25, green: 0.88, blue: 0.58)
                            )

                            featureRow(
                                icon: "square.and.arrow.up.fill",
                                title: "Full CSV Data Export",
                                subtitle: "Export all historical logs anytime to Numbers, Excel or iCloud Drive",
                                color: Color(red: 1.00, green: 0.68, blue: 0.18)
                            )
                        }
                        .padding(.horizontal, 20)

                        // Pricing Card
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lifetime Access")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                    Text("Pay once, own forever • No subscriptions")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                }
                                Spacer()
                                Text(storeManager.localizedPrice)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.orange)
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .padding(.horizontal, 20)

                        // Purchase CTA Button
                        VStack(spacing: 12) {
                            Button {
                                Task { @MainActor in
                                    let success = await storeManager.purchasePro()
                                    if success {
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if storeManager.isPurchasing {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Image(systemName: "lock.open.fill")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Unlock Pro • \(storeManager.localizedPrice)")
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                    }
                                }
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
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
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 4)
                            }
                            .disabled(storeManager.isPurchasing)
                            .padding(.horizontal, 20)

                            // Error Message
                            if let error = storeManager.errorMessage {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.red.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }

                            // Restore Purchases & Privacy
                            HStack(spacing: 20) {
                                Button("Restore Purchases") {
                                    Task { @MainActor in
                                        await storeManager.restorePurchases()
                                        if storeManager.isProUnlocked {
                                            dismiss()
                                        }
                                    }
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))

                                Text("•")
                                    .foregroundStyle(Color.white.opacity(0.3))

                                Text("100% Privacy • Private iCloud")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            .padding(.top, 4)
                        }

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if storeManager.proProduct == nil {
                    await storeManager.loadProducts()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
