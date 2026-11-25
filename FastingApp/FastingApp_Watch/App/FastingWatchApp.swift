import SwiftUI
#if canImport(SwiftData)
import SwiftData
#endif

@main
struct FastSpanWatchApp: App {
    @State private var fastingManager = FastingManager.shared
    #if canImport(SwiftData)
    private let modelContainer: ModelContainer

    init() {
        _ = NotificationManager.shared
        let (container, isCloudKitActive) = FastRecord.makeModelContainerWithStatus(
            iCloudSyncEnabled: FastingManager.shared.iCloudSyncEnabled
        )
        self.modelContainer = container
        FastingManager.shared.isCloudKitActive = isCloudKitActive
        FastingManager.shared.onRemoteFastCompleted = { record in
            guard !FastingManager.shared.isCloudKitActive else { return }
            let recordID = record.id
            let descriptor = FetchDescriptor<FastRecord>(predicate: #Predicate { $0.id == recordID })
            let existingCount = (try? container.mainContext.fetchCount(descriptor)) ?? 0
            guard existingCount == 0 else { return }
            container.mainContext.insert(record)
            try? container.mainContext.save()
        }
    }
    #else
    init() {
        _ = NotificationManager.shared
    }
    #endif

    var body: some Scene {
        WindowGroup {
            WatchTrackerView()
                .task {
                    let authorized = await NotificationManager.shared.requestAuthorization()
                    fastingManager.syncNotifications(force: authorized)
                }
        }
        #if canImport(SwiftData)
        .modelContainer(modelContainer)
        #endif
    }
}
