import Testing
import Foundation
@testable import FastingAppCore

struct CSVExportTests {

    @Test func testCSVExportFormattingAndEscaping() {
        let service = CSVExportService.shared

        let start = Date(timeIntervalSince1970: 1700000000)
        let end = Date(timeIntervalSince1970: 1700057600) // 16h later

        let record1 = FastRecord(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            startTime: start,
            endTime: end,
            targetDurationHours: 16.0,
            protocolName: "16:8",
            isCompleted: true,
            notes: "Felt great, had black coffee",
            mood: "⚡ Energized"
        )

        let record2 = FastRecord(
            id: UUID(uuidString: "66666666-7777-8888-9999-000000000000")!,
            startTime: start,
            endTime: end,
            targetDurationHours: 18.0,
            protocolName: "18:6",
            isCompleted: true,
            notes: "Note with, comma and \"quotes\"",
            mood: "🧘 Calm"
        )

        let csvString = service.generateCSVString(from: [record1, record2])

        // Verify CSV header
        #expect(csvString.contains("ID,Start Time,End Time,Target Hours,Actual Hours,Status,Protocol Name,Notes,Mood"))

        // Verify record 1 contents
        #expect(csvString.contains("11111111-2222-3333-4444-555555555555"))
        #expect(csvString.contains("16:8"))
        #expect(csvString.contains("\"Felt great, had black coffee\""))
        #expect(csvString.contains("⚡ Energized"))

        // Verify record 2 quotes escaping
        #expect(csvString.contains("\"Note with, comma and \"\"quotes\"\"\""))
    }
}
