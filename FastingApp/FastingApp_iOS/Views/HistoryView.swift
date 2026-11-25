import SwiftUI
#if canImport(SwiftData)
import SwiftData
#endif

/// History log and statistics dashboard with 7-day free window and Pro unlimited lifetime history + CSV export.
public struct HistoryView: View {
    #if canImport(SwiftData)
    @Query(sort: \FastRecord.startTime, order: .reverse) private var allRecords: [FastRecord]
    @Environment(\.modelContext) private var modelContext
    #else
    @State private var allRecords: [FastRecord] = []
    #endif

    @State private var fastingManager = FastingManager.shared
    @State private var storeManager = StoreManager.shared

    @State private var showPaywall: Bool = false
    @State private var selectedRecordForShare: FastRecord? = nil
    @State private var csvExportItem: ShareableURLPayload? = nil

    public init() {}

    private var visibleRecords: [FastRecord] {
        fastingManager.filterRecords(allRecords, isPro: storeManager.isProUnlocked)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                fastingManager.selectedTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Top Stats Cards
                        statsSection

                        // Weekly Breakdown Visual Bars
                        weeklyChartSection

                        // History Records List
                        recordsSection

                        // Free Tier History Lock Banner (if records exist beyond 7 days)
                        if !storeManager.isProUnlocked && hasRecordsBeyond7Days {
                            proHistoryUpgradeBanner
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Fasting History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    exportCSVButton
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(item: $selectedRecordForShare) { record in
                ShareSheetModal(
                    record: record,
                    theme: fastingManager.selectedTheme,
                    streak: fastingManager.currentStreak
                )
            }
            .sheet(item: $csvExportItem) { item in
                ShareActivityView(activityItems: [item.url])
            }
            .onAppear {
                fastingManager.updateStreaks(from: allRecords)
            }
            .onChange(of: allRecords.count) { _, _ in
                fastingManager.updateStreaks(from: allRecords)
            }
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 10) {
            MetricPillView(
                icon: "flame.fill",
                title: "Streak",
                value: "\(fastingManager.currentStreak) Days",
                accentColor: .orange
            )

            MetricPillView(
                icon: "trophy.fill",
                title: "Best Streak",
                value: "\(fastingManager.longestStreak) Days",
                accentColor: Color(red: 1.0, green: 0.85, blue: 0.2)
            )

            MetricPillView(
                icon: "clock.fill",
                title: "Avg Duration",
                value: averageDurationString,
                accentColor: fastingManager.selectedTheme.primaryColor
            )
        }
    }

    // MARK: - Weekly Chart
    private var weeklyChartSection: some View {
        let targetHours = fastingManager.activeProtocol.fastingHours
        let chartData = last7DaysData
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 7 Days")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
                Text("Target: \(Int(targetHours))h")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(chartData) { data in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 32, height: 100)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    data.hours >= targetHours
                                        ? fastingManager.selectedTheme.ringGradient
                                        : LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 32, height: CGFloat(min(100.0, (data.hours / 24.0) * 100.0)))
                        }

                        Text(data.dayLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Records List
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(storeManager.isProUnlocked ? "All Fasting Logs" : "Recent Logs (7 Days)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
                Text("\(visibleRecords.count) logged")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            if visibleRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text("No completed fasts yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visibleRecords) { record in
                        recordCard(record)
                    }
                }
            }
        }
    }

    private func recordCard(_ record: FastRecord) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(record.isGoalAchieved ? fastingManager.selectedTheme.primaryColor.opacity(0.15) : Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)

                Image(systemName: record.isGoalAchieved ? "checkmark" : "flag.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(record.isGoalAchieved ? fastingManager.selectedTheme.primaryColor : Color.white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(record.protocolName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)

                    if let mood = record.mood {
                        Text("• \(mood)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }

                    Spacer()

                    Text(record.formattedDuration)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(record.isGoalAchieved ? fastingManager.selectedTheme.primaryColor : Color.white)
                }

                Text(formatRecordDate(record.startTime))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            // Share Button
            Button {
                selectedRecordForShare = record
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Pro Upgrade Banner for History
    private var proHistoryUpgradeBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Unlock Lifetime History")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                        ProBadgeView(size: 10)
                    }
                    Text("Access all past fasting logs, month-by-month trends & stats.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.orange.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CSV Export Toolbar Button
    private var exportCSVButton: some View {
        Button {
            if storeManager.isProUnlocked {
                do {
                    let url = try CSVExportService.shared.createTemporaryCSVFile(from: allRecords)
                    self.csvExportItem = ShareableURLPayload(url: url)
                } catch {
                    print("[HistoryView] CSV Export error: \(error.localizedDescription)")
                }
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("CSV")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                if !storeManager.isProUnlocked {
                    ProBadgeView(size: 9)
                }
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    // MARK: - Helpers
    private var hasRecordsBeyond7Days: Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        return allRecords.contains { $0.startTime < cutoff }
    }

    private var averageDurationString: String {
        let completed = allRecords.filter(\.isCompleted)
        guard !completed.isEmpty else { return "0h" }
        let totalHours = completed.reduce(0.0) { $0 + $1.actualDurationHours }
        let avg = totalHours / Double(completed.count)
        return String(format: "%.1fh", avg)
    }

    private var last7DaysData: [DailyFastBar] {
        let calendar = Calendar.current
        let today = Date()
        var result: [DailyFastBar] = []

        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let dayStr = date.formatted(.dateTime.weekday(.abbreviated)).prefix(3).uppercased()

            let dayHours = allRecords.filter { record in
                guard record.isCompleted, let end = record.endTime else { return false }
                return end >= dayStart && end < dayEnd
            }.reduce(0.0) { $0 + $1.actualDurationHours }

            result.append(DailyFastBar(id: dayStart, dayLabel: String(dayStr), hours: dayHours))
        }

        return result
    }

    private func formatRecordDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }
}

private struct DailyFastBar: Identifiable {
    let id: Date
    let dayLabel: String
    let hours: Double
}

struct ShareableURLPayload: Identifiable {
    let id = UUID()
    let url: URL
}

// Helper for presenting standard UIKit share sheet for CSV file
struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
