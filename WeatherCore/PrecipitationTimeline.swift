import Foundation

public struct PrecipitationBucket: Equatable, Sendable, Codable {
    public let date: Date
    public let precipitation: Double

    public init(date: Date, precipitation: Double) {
        self.date = date
        self.precipitation = precipitation
    }

    public var intensity: PrecipitationIntensity {
        PrecipitationIntensity(millimetres: rate)
    }

    public var rate: Double {
        let hours = PrecipitationTimeline.bucketSeconds / 3600
        guard hours > 0 else { return precipitation }
        return precipitation / hours
    }

    public var isWet: Bool { intensity.isMeaningful }
}

public struct PrecipitationTimeline: Equatable, Sendable, Codable {

    public static let bucketCount = 4

    public static var requestedBucketCount: Int { bucketCount + 1 }

    public struct Window: Equatable, Sendable, Codable {
        public let start: Date
        public let end: Date
        public let isWet: Bool
        public let peak: Double

        public var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    public let buckets: [PrecipitationBucket]
    public let start: Date
    public let end: Date

    public init(buckets: [PrecipitationBucket], now: Date) {
        let future = buckets.filter { $0.date >= now }
        self.buckets = future
        self.start = future.first?.date ?? now
        self.end = future.last?.date ?? now
    }

    public static func empty(now: Date) -> PrecipitationTimeline {
        PrecipitationTimeline(buckets: [], now: now)
    }

    public var nextWet: Window? { windows.first(where: \.isWet) }

    public var wetWindows: [Window] { windows.filter(\.isWet) }

    public var nextDry: Window? {
        windows.first { window in
            !window.isWet && window.start >= (nextWet?.start ?? .distantPast)
        }
    }

    public var windows: [Window] {
        var result: [Window] = []
        for bucket in buckets {
            let isWet = bucket.isWet
            let end = bucket.date.addingTimeInterval(Self.bucketSeconds)
            if let last = result.last, last.isWet == isWet {
                result.removeLast()
                result.append(Window(start: last.start, end: end, isWet: isWet,
                                     peak: max(last.peak, bucket.precipitation)))
            } else {
                result.append(Window(start: bucket.date, end: end, isWet: isWet,
                                     peak: bucket.precipitation))
            }
        }
        return result
    }

    public static let bucketSeconds: TimeInterval = 900

    public func minutesUntilNextWet(now: Date) -> Int? {
        guard let nextWet else { return nil }
        let seconds = nextWet.start.timeIntervalSince(now)
        guard seconds > 0 else { return 0 }
        return Int(ceil(seconds / 300)) * 5
    }
}
