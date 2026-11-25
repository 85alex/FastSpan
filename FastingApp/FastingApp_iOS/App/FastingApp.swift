import SwiftUI
#if canImport(SwiftData)
import SwiftData
#endif

@main
struct FastSpanApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var fastingManager = FastingManager.shared
    @State private var storeManager = StoreManager.shared
    @State private var didEnterBackground: Bool = false
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
            // When CloudKit actually activated, it syncs the Watch's SwiftData record automatically.
            // If CloudKit is opted out OR fell back to local storage, persist the Watch record directly.
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
            MainTrackerView()
                .preferredColorScheme(.dark)
                .task {
                    let authorized = await NotificationManager.shared.requestAuthorization()
                    fastingManager.syncNotifications(force: authorized)
                    fastingManager.syncLiveActivity()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        didEnterBackground = true
                    case .active:
                        if didEnterBackground {
                            didEnterBackground = false
                            fastingManager.syncNotifications()
                            fastingManager.syncLiveActivity()
                        }
                    default:
                        break
                    }
                }
        }
        #if canImport(SwiftData)
        .modelContainer(modelContainer)
        #endif
    }
}
