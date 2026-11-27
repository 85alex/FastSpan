import Foundation
#if (os(iOS) || os(watchOS)) && canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity
#endif

/// Payload describing a fast ended on the paired device.
public struct RemoteEndFastPayload: Sendable {
    public let startTime: Date?
    public let endTime: Date
    public let targetDuration: TimeInterval?
    public let protocolId: String?
    public let protocolName: String?
    public let recordID: UUID?
    public let sentAt: Date

    public init(
        startTime: Date? = nil,
        endTime: Date,
        targetDuration: TimeInterval? = nil,
        protocolId: String? = nil,
        protocolName: String? = nil,
        recordID: UUID? = nil,
        sentAt: Date
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.targetDuration = targetDuration
        self.protocolId = protocolId
        self.protocolName = protocolName
        self.recordID = recordID
        self.sentAt = sentAt
    }
}

/// Coordinates real-time state synchronization between iOS and watchOS via WatchConnectivity.
@MainActor
public final class WatchSyncService {
    public static let shared = WatchSyncService()

    public var onReceiveStartFast: (@MainActor (Date, TimeInterval, String, Date) -> Void)?
    public var onReceiveEndFast: (@MainActor (RemoteEndFastPayload) -> Void)?
    public var onReceiveCancelFast: (@MainActor (Date) -> Void)?
    public var onReceiveTimerPreference: (@MainActor (Bool) -> Void)?
    public var onReceiveRequestState: (@MainActor () -> [String: Any])?

    #if (os(iOS) || os(watchOS)) && canImport(WatchConnectivity)
    private struct PendingPayload {
        let payload: [String: Any]
        let isComplicationPriority: Bool
        let useApplicationContext: Bool
        let guaranteeQueuedDelivery: Bool
    }

    private let delegateBridge: WatchSessionDelegateBridge
    private var pendingFastStatePayload: PendingPayload? = nil
    private var pendingPreferencePayload: PendingPayload? = nil
    #endif

    private init() {
        #if (os(iOS) || os(watchOS)) && canImport(WatchConnectivity)
        let bridge = WatchSessionDelegateBridge()
        self.delegateBridge = bridge

        bridge.onPayloadReceived = { [weak self] payload in
            nonisolated(unsafe) let incoming = payload
            Task { @MainActor [weak self] in
                self?.handleIncomingPayload(incoming)
            }
        }

        bridge.onSessionActivated = { [weak self] receivedContext in
            nonisolated(unsafe) let context = receivedContext
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let pendingFast = self.pendingFastStatePayload {
                    self.pendingFastStatePayload = nil
                    self.sendPayload(
                        pendingFast.payload,
                        isComplicationPriority: pendingFast.isComplicationPriority,
                        useApplicationContext: pendingFast.useApplicationContext,
                        guaranteeQueuedDelivery: pendingFast.guaranteeQueuedDelivery
                    )
                }
                if let pendingPref = self.pendingPreferencePayload {
                    self.pendingPreferencePayload = nil
                    self.sendPayload(
                        pendingPref.payload,
                        isComplicationPriority: pendingPref.isComplicationPriority,
                        useApplicationContext: pendingPref.useApplicationContext,
                        guaranteeQueuedDelivery: pendingPref.guaranteeQueuedDelivery
                    )
                }
                if !context.isEmpty {
                    self.handleIncomingPayload(context)
                }
            }
        }

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = bridge
            session.activate()
        }
        #endif
    }

    /// Re-checks the latest received application context (safe to call on foreground; handlers deduplicate by ID & timestamp).
    public func syncPendingReceivedContext() {
        #if (os(iOS) || os(watchOS)) && canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                handleIncomingPayload(context)
            }
        } else {
            session.activate()
        }
        #endif
    }

    private func handleIncomingPayload(_ incoming: [String: Any]) {
        guard let action = incoming["action"] as? String else { return }
        let sentAt = (incoming["sentAt"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()

        switch action {
        case "startFast":
            if let startTimestamp = incoming["startTime"] as? Double,
               let targetDuration = incoming["targetDuration"] as? Double,
               let protocolId = incoming["protocolId"] as? String {
                let start = Date(timeIntervalSince1970: startTimestamp)
                self.onReceiveStartFast?(start, targetDuration, protocolId, sentAt)
            }
        case "endFast":
            let startTime = (incoming["startTime"] as? Double).map { Date(timeIntervalSince1970: $0) }
            let endTime = (incoming["endTime"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? sentAt
            let targetDuration = incoming["targetDuration"] as? Double
            let protocolId = incoming["protocolId"] as? String
            let protocolName = incoming["protocolName"] as? String
            let recordID = (incoming["recordId"] as? String).flatMap { UUID(uuidString: $0) }
            let payload = RemoteEndFastPayload(
                startTime: startTime,
                endTime: endTime,
                targetDuration: targetDuration,
                protocolId: protocolId,
                protocolName: protocolName,
                recordID: recordID,
                sentAt: sentAt
            )
            self.onReceiveEndFast?(payload)
        case "cancelFast":
            self.onReceiveCancelFast?(sentAt)
        case "timerPreference":
            if let countsUp = incoming["countsUp"] as? Bool {
                self.onReceiveTimerPreference?(countsUp)
            }
        default:
            break
        }
    }

    /// Broadcasts active fast start or edit to paired device
    public func sendStartFast(
        startTime: Date,
        targetDuration: TimeInterval,
        protocolId: String,
        sentAt: Date = Date()
    ) {
        let payload: [String: Any] = [
            "action": "startFast",
            "startTime": startTime.timeIntervalSince1970,
            "targetDuration": targetDuration,
            "protocolId": protocolId,
            "sentAt": sentAt.timeIntervalSince1970
        ]
        sendPayload(payload, isComplicationPriority: true)
    }

    /// Broadcasts active fast end (with full completed fast metadata and record ID) to paired device
    public func sendEndFast(
        startTime: Date? = nil,
        endTime: Date = Date(),
        targetDuration: TimeInterval? = nil,
        protocolId: String? = nil,
        protocolName: String? = nil,
        recordID: UUID? = nil,
        sentAt: Date = Date()
    ) {
        var payload: [String: Any] = [
            "action": "endFast",
            "endTime": endTime.timeIntervalSince1970,
            "sentAt": sentAt.timeIntervalSince1970
        ]
        if let startTime {
            payload["startTime"] = startTime.timeIntervalSince1970
        }
        if let targetDuration {
            payload["targetDuration"] = targetDuration
        }
        if let protocolId {
            payload["protocolId"] = protocolId
        }
        if let protocolName {
            payload["protocolName"] = protocolName
        }
        if let recordID {
            payload["recordId"] = recordID.uuidString
        }
        sendPayload(
            payload,
            isComplicationPriority: true,
            useApplicationContext: true,
            guaranteeQueuedDelivery: true
        )
    }

    /// Broadcasts active fast cancellation to paired device
    public func sendCancelFast(sentAt: Date = Date()) {
        let payload: [String: Any] = [
            "action": "cancelFast",
            "sentAt": sentAt.timeIntervalSince1970
        ]
        sendPayload(payload, isComplicationPriority: true)
    }

    /// Broadcasts timer direction preference (counts up vs counts down) to paired device.
    /// Does NOT overwrite `applicationContext` so offline fast start/end/cancel state is preserved.
    public func sendTimerPreference(countsUp: Bool) {
        let payload: [String: Any] = [
            "action": "timerPreference",
            "countsUp": countsUp,
            "sentAt": Date().timeIntervalSince1970
        ]
        sendPayload(payload, isComplicationPriority: false, useApplicationContext: false)
    }

    /// Sends full state snapshot to paired device
    public func sendFullState(snapshot: FastingSnapshot) {
        var payload: [String: Any] = [
            "phase": snapshot.phase.rawValue,
            "targetDuration": snapshot.targetDuration,
            "protocolId": snapshot.currentProtocol.id,
            "protocolName": snapshot.currentProtocol.name,
            "sentAt": Date().timeIntervalSince1970
        ]
        if let start = snapshot.startTime {
            payload["startTime"] = start.timeIntervalSince1970
        }
        sendPayload(payload, isComplicationPriority: false, useApplicationContext: true)
    }

    private func sendPayload(
        _ payload: [String: Any],
        isComplicationPriority: Bool = false,
        useApplicationContext: Bool = true,
        guaranteeQueuedDelivery: Bool = false
    ) {
        #if (os(iOS) || os(watchOS)) && canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            let pending = PendingPayload(
                payload: payload,
                isComplicationPriority: isComplicationPriority,
                useApplicationContext: useApplicationContext,
                guaranteeQueuedDelivery: guaranteeQueuedDelivery
            )
            if useApplicationContext {
                pendingFastStatePayload = pending
            } else {
                pendingPreferencePayload = pending
            }
            return
        }
        nonisolated(unsafe) let safePayload = payload

        if useApplicationContext {
            // Persist latest fast lifecycle state in applicationContext so offline changes survive disconnects
            do {
                try session.updateApplicationContext(safePayload)
            } catch {
                print("[WatchSyncService] App context error: \(error.localizedDescription)")
            }
        }

        #if os(watchOS)
        if guaranteeQueuedDelivery {
            // Hand off synchronously to the system daemon so wrist-down suspension or subsequent
            // fast starts can never drop or overwrite a completed fast record.
            session.transferUserInfo(safePayload)
        }
        #endif

        if session.isReachable {
            // Counterpart is awake and reachable: send directly for immediate delivery
            session.sendMessage(safePayload, replyHandler: nil) { error in
                print("[WatchSyncService] Message send error: \(error.localizedDescription)")
                // Fall back to queued delivery if direct message failed
                #if os(watchOS)
                if !guaranteeQueuedDelivery {
                    session.transferUserInfo(safePayload)
                }
                #else
                if !useApplicationContext || guaranteeQueuedDelivery {
                    session.transferUserInfo(safePayload)
                } else if isComplicationPriority,
                          session.isPaired,
                          session.isWatchAppInstalled,
                          session.isComplicationEnabled,
                          session.remainingComplicationUserInfoTransfers > 0 {
                    session.transferCurrentComplicationUserInfo(safePayload)
                }
                #endif
            }
        } else if !useApplicationContext {
            // Queue non-lifecycle preferences without clobbering applicationContext
            session.transferUserInfo(safePayload)
        } else {
            // Counterpart is not currently reachable
            #if os(iOS)
            if isComplicationPriority,
               session.isPaired,
               session.isWatchAppInstalled,
               session.isComplicationEnabled,
               session.remainingComplicationUserInfoTransfers > 0 {
                session.transferCurrentComplicationUserInfo(safePayload)
            } else if guaranteeQueuedDelivery {
                session.transferUserInfo(safePayload)
            }
            #endif
        }
        #endif
    }
}

#if (os(iOS) || os(watchOS)) && canImport(WatchConnectivity)
/// Non-isolated delegate bridge conforming to WCSessionDelegate in Swift 6 strict concurrency mode.
final class WatchSessionDelegateBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    var onPayloadReceived: (@Sendable ([String: Any]) -> Void)?
    var onSessionActivated: (@Sendable ([String: Any]) -> Void)?

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("[WatchSessionDelegateBridge] Activation error: \(error.localizedDescription)")
            return
        }
        if activationState == .activated {
            nonisolated(unsafe) let receivedContext = session.receivedApplicationContext
            onSessionActivated?(receivedContext)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        nonisolated(unsafe) let safeMsg = message
        onPayloadReceived?(safeMsg)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        nonisolated(unsafe) let safeContext = applicationContext
        onPayloadReceived?(safeContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        nonisolated(unsafe) let safeUserInfo = userInfo
        onPayloadReceived?(safeUserInfo)
    }
}
#endif
