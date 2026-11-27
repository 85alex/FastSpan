import SwiftUI
#if canImport(SwiftData)
import SwiftData
#endif

/// Settings, notification controls, Pro management, theme personalization, and VoltSlide-style About section.
public struct SettingsThemeView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if canImport(SwiftData)
    @Query(sort: \FastRecord.startTime, order: .reverse) private var allRecords: [FastRecord]
    #else
    @State private var allRecords: [FastRecord] = []
    #endif
    @State private var fastingManager = FastingManager.shared
    @State private var storeManager = StoreManager.shared

    @State private var showPaywall: Bool = false
    @State private var activeLegalDocument: LegalDocumentType? = nil
    @State private var csvExportItem: ShareableURLPayload? = nil
    @State private var notificationsDenied: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                fastingManager.selectedTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Pro Membership Banner
                        if !storeManager.isProUnlocked {
                            proUpgradeCard
                        } else {
                            proActiveBadge
                        }

                        // Theme Selection Section
                        themeSelectionSection

                        // Notifications Section
                        notificationsSection

                        // Dynamic Island & Live Activity Section
                        dynamicIslandSection

                        // Privacy & Data Export Section
                        dataPrivacySection

                        // Health & Medical Disclaimer Section
                        legalDisclaimerSection

                        // VoltSlide-Style About Section
                        aboutVoltSlideSection

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(item: $csvExportItem) { item in
                ShareActivityView(activityItems: [item.url])
            }
            .sheet(item: $activeLegalDocument) { document in
                switch document {
                case .medicalDisclaimer:
                    MedicalDisclaimerSheet()
                case .privacyPolicy:
                    PrivacyPolicySheet()
                case .termsOfUse:
                    TermsOfUseSheet()
                }
            }
            .task {
                notificationsDenied = await NotificationManager.shared.isNotificationsDenied()
                if storeManager.proProduct == nil {
                    await storeManager.loadProducts()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        let wasDenied = notificationsDenied
                        let isNowDenied = await NotificationManager.shared.isNotificationsDenied()
                        notificationsDenied = isNowDenied
                        if wasDenied && !isNowDenied {
                            fastingManager.syncNotifications(force: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pro Upgrade Card
    private var proUpgradeCard: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("FastSpan Pro Lifetime")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("Unlock all themes, Smart Dynamic Island & unlimited history")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }

                    Spacer()

                    Text(storeManager.localizedPrice ?? "Upgrade")
                        .font(.system(size: storeManager.localizedPrice != nil ? 15 : 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.25), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var proActiveBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.orange)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Pro Lifetime Unlocked")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                    ProBadgeView(size: 10)
                }
                Text("All premium themes and pro tools are active.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Theme Selection
    private var themeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Design Themes")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
                Text("\(AppTheme.allThemes.count) Themes")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(AppTheme.allThemes) { theme in
                        themeCard(theme)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func themeCard(_ theme: AppTheme) -> some View {
        let isSelected = fastingManager.selectedTheme.id == theme.id
        let isLocked = theme.isPro && !storeManager.isProUnlocked

        return Button {
            if isLocked {
                showPaywall = true
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    fastingManager.selectTheme(theme)
                }
            }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    // Mini Ring Preview
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0.0, to: 0.75)
                        .stroke(theme.ringGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 60, height: 60)

                    if isLocked {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 26, height: 26)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.orange)
                        }
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(theme.primaryColor)
                    }
                }
                .padding(.top, 8)

                VStack(spacing: 2) {
                    Text(theme.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(theme.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                }

                if theme.isPro {
                    ProBadgeView(size: 8)
                } else {
                    Text("FREE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .frame(width: 120)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? theme.primaryColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Notifications")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)

            if notificationsDenied {
                HStack(spacing: 10) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.orange)
                    Text("Notifications are turned off in iOS Settings.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                    Spacer(minLength: 4)
                    #if os(iOS)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange)
                    #endif
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }

            VStack(spacing: 0) {
                toggleRow(
                    title: "1 Hour Before Goal",
                    subtitle: "Get a friendly heads-up as your fast completes",
                    isOn: Binding(
                        get: { fastingManager.notifyOneHourBefore },
                        set: { fastingManager.setNotifyOneHourBefore($0) }
                    )
                )

                Divider().background(Color.white.opacity(0.08))

                toggleRow(
                    title: "Goal Reached",
                    subtitle: "Immediate celebration alert when you hit 100%",
                    isOn: Binding(
                        get: { fastingManager.notifyTargetReached },
                        set: { fastingManager.setNotifyTargetReached($0) }
                    )
                )

                Divider().background(Color.white.opacity(0.08))

                toggleRow(
                    title: "1 Hour Overtime",
                    subtitle: "Gentle reminder if you've surpassed your target",
                    isOn: Binding(
                        get: { fastingManager.notifyOneHourPast },
                        set: { fastingManager.setNotifyOneHourPast($0) }
                    )
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .tint(fastingManager.selectedTheme.primaryColor)
        .padding(16)
    }

    // MARK: - Dynamic Island Section
    private var dynamicIslandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dynamic Island & Live Activity")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
            }

            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { fastingManager.liveActivitiesEnabled },
                    set: { newValue in
                        fastingManager.setLiveActivitiesEnabled(newValue)
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Fast Timer")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("Shows your fasting timer on the Lock Screen and Dynamic Island while a fast is active.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .tint(fastingManager.selectedTheme.primaryColor)
                .padding(16)

                if fastingManager.liveActivitiesEnabled {
                    Divider().background(Color.white.opacity(0.08))

                    Toggle(isOn: Binding(
                        get: { fastingManager.liveActivityCountsUp },
                        set: { newValue in
                            fastingManager.setLiveActivityCountsUp(newValue)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Count Up (Elapsed Time)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text("Count up from 0:00 instead of counting down to your goal.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                    .tint(fastingManager.selectedTheme.primaryColor)
                    .padding(16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - Data & Privacy Section
    private var dataPrivacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data & Privacy")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: Binding(
                        get: { fastingManager.iCloudSyncEnabled },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                fastingManager.setICloudSyncEnabled(newValue)
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill((fastingManager.iCloudSyncEnabled ? Color.blue : Color.white).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: fastingManager.iCloudSyncEnabled ? "icloud.fill" : "icloud.slash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(fastingManager.iCloudSyncEnabled ? Color.cyan : Color.white.opacity(0.45))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Private iCloud Sync")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                Text(
                                    fastingManager.iCloudSyncEnabled
                                        ? "Syncs fasting history to your private iCloud container"
                                        : "Off — fasting history stays on this device only"
                                )
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                    }
                    .tint(fastingManager.selectedTheme.primaryColor)

                    if fastingManager.iCloudSyncNeedsRestart {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(fastingManager.selectedTheme.primaryColor)
                            Text("Restart FastSpan to apply this change. Your local history won't be deleted.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.65))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.08))

                Button {
                    if storeManager.isProUnlocked {
                        do {
                            let url = try CSVExportService.shared.createTemporaryCSVFile(from: allRecords)
                            self.csvExportItem = ShareableURLPayload(url: url)
                        } catch {
                            print("[SettingsThemeView] CSV Export error: \(error.localizedDescription)")
                        }
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "tablecells.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Export Fasting History (.CSV)")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                if !storeManager.isProUnlocked {
                                    ProBadgeView(size: 9)
                                }
                            }
                            Text("Export all logs for Numbers, Excel, or backups")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - Health & Legal Disclaimer Section
    private var legalDisclaimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health & Legal")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)

            VStack(spacing: 0) {
                Button {
                    activeLegalDocument = .medicalDisclaimer
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Health & Medical Disclaimer")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text("Tap to review medical, safety & liability information")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)

                Divider().background(Color.white.opacity(0.08))

                Button {
                    activeLegalDocument = .termsOfUse
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Terms of Use")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text("Eligibility, wellness scope & purchase terms")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - VoltSlide-Style About Section
    private var aboutVoltSlideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)

            VStack(spacing: 16) {
                // Hero Brand Card
                VStack(spacing: 4) {
                    Text("FASTSPAN")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(Color.white)

                    Text("Minimalist • Privacy-Focused Tracker")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))

                    Text("Version \(appVersionString) (Build \(appBuildString))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Manifesto Highlights
                VStack(spacing: 10) {
                    manifestoPill(
                        icon: "lock.shield.fill",
                        title: "100% On-Device Privacy",
                        subtitle: "No trackers, no ad networks, no analytics SDKs",
                        color: Color(red: 0.25, green: 0.88, blue: 0.58)
                    )

                    manifestoPill(
                        icon: "icloud.fill",
                        title: "Private iCloud Sync",
                        subtitle: "Your data stays in your personal Apple cloud account",
                        color: Color(red: 0.12, green: 0.78, blue: 0.99)
                    )

                    manifestoPill(
                        icon: "sparkles",
                        title: "Honest Software",
                        subtitle: storeManager.localizedPrice.map { "One-time \($0) lifetime purchase. Zero subscriptions" }
                            ?? "One-time lifetime purchase. Zero subscriptions",
                        color: Color(red: 1.00, green: 0.68, blue: 0.18)
                    )
                }

                // Interactive Links / Actions
                VStack(spacing: 0) {
                    ShareLink(
                        item: URL(string: "https://apps.apple.com")!,
                        subject: Text("FastSpan • Privacy-Focused Tracker"),
                        message: Text("Check out FastSpan — a super clean, privacy-first intermittent fasting tracker for iOS and Apple Watch!")
                    ) {
                        aboutActionRow(
                            icon: "square.and.arrow.up",
                            title: "Share FastSpan",
                            subtitle: "Recommend to friends and family"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().background(Color.white.opacity(0.08))

                    Button {
                        if let url = URL(string: "mailto:alex.pandelidis@gmail.com?subject=FastSpan%20Feedback") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #endif
                        }
                    } label: {
                        aboutActionRow(
                            icon: "envelope.fill",
                            title: "Send Feedback",
                            subtitle: "Feature requests, ideas & support"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().background(Color.white.opacity(0.08))

                    Button {
                        activeLegalDocument = .privacyPolicy
                    } label: {
                        aboutActionRow(
                            icon: "hand.raised.fill",
                            title: "Privacy Policy",
                            subtitle: "Read our zero-data collection guarantee"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

                // Creator Signature
                VStack(spacing: 4) {
                    Text("Crafted with focus by Alex Pandelidis")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))

                    Text("Designed in Canada • Made for iOS & watchOS")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                .padding(.top, 4)
            }
        }
    }

    private var appVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }

    private var appBuildString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "3"
    }

    private func manifestoPill(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func aboutActionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(12)
    }
}
