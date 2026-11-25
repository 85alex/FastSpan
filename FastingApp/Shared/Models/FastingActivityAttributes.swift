import Foundation
#if os(iOS) && canImport(ActivityKit)
import ActivityKit

public struct FastingActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var startTime: Date
        public var targetEndTime: Date
        public var protocolName: String
        public var themeID: String
        public var isOvertime: Bool
        public var countsUp: Bool

        public init(
            startTime: Date,
            targetEndTime: Date,
            protocolName: String,
            themeID: String,
            isOvertime: Bool = false,
            countsUp: Bool = false
        ) {
            self.startTime = startTime
            self.targetEndTime = targetEndTime
            self.protocolName = protocolName
            self.themeID = themeID
            self.isOvertime = isOvertime
            self.countsUp = countsUp
        }
    }

    public var fastID: String

    public init(fastID: String) {
        self.fastID = fastID
    }
}
#else
public struct FastingActivityAttributes: Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var startTime: Date
        public var targetEndTime: Date
        public var protocolName: String
        public var themeID: String
        public var isOvertime: Bool
        public var countsUp: Bool

        public init(
            startTime: Date,
            targetEndTime: Date,
            protocolName: String,
            themeID: String,
            isOvertime: Bool = false,
            countsUp: Bool = false
        ) {
            self.startTime = startTime
            self.targetEndTime = targetEndTime
            self.protocolName = protocolName
            self.themeID = themeID
            self.isOvertime = isOvertime
            self.countsUp = countsUp
        }
    }

    public var fastID: String

    public init(fastID: String) {
        self.fastID = fastID
    }
}
#endif
