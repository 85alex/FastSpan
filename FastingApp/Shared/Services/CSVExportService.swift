import Foundation

/// RFC 4180 compliant CSV exporter for FastSpan fasting records.
@MainActor
public final class CSVExportService {
    public static let shared = CSVExportService()

    private init() {}

    /// Generates an RFC 4180 compliant CSV string for the supplied fasting records.
    public func generateCSVString(from records: [FastRecord]) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines: [String] = [
            "ID,Start Time,End Time,Target Hours,Actual Hours,Status,Protocol Name,Notes,Mood"
        ]

        let sorted = records.sorted { $0.startTime > $1.startTime }
        for record in sorted {
            let startStr = isoFormatter.string(from: record.startTime)
            let endStr = record.endTime.map { isoFormatter.string(from: $0) } ?? ""
            let targetStr = String(format: "%.2f", record.targetDurationHours)
            let actualStr = String(format: "%.2f", record.actualDurationHours)
            let statusStr = record.isCompleted
                ? (record.isGoalAchieved ? "Goal Met" : "Completed")
                : "In Progress"

            let fields = [
                record.id.uuidString,
                startStr,
                endStr,
                targetStr,
                actualStr,
                statusStr,
                record.protocolName,
                record.notes ?? "",
                record.mood ?? ""
            ]
            lines.append(fields.map(escapeCSVField).joined(separator: ","))
        }

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Writes the generated CSV to a temporary file URL ready for sharing.
    public func createTemporaryCSVFile(from records: [FastRecord]) throws -> URL {
        let csv = generateCSVString(from: records)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let filename = "FastSpan_History_\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func escapeCSVField(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        guard needsQuotes else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
