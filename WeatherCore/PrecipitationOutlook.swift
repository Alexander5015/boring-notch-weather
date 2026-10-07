import Foundation

public struct HourlyForecast: Equatable, Sendable, Codable {

    public let precipitation: Double

    public let probability: Double

    public let temperature: Double

    public let date: Date

    public init(
        precipitation: Double,
        probability: Double,
        temperature: Double,
        date: Date
    ) {
        self.precipitation = precipitation
        self.probability = probability
        self.temperature = temperature
        self.date = date
    }
}

public enum PrecipitationIntensity: Int, Sendable, CaseIterable, Comparable {
    case none = 0
    case light = 1
    case moderate = 2
    case heavy = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public enum Threshold {
        public static let light: Double = 0.1
        public static let moderate: Double = 2.5
        public static let heavy: Double = 7.6
    }

    public init(millimetres: Double) {
        switch millimetres {
        case ..<Threshold.light: self = .none
        case ..<Threshold.moderate: self = .light
        case ..<Threshold.heavy: self = .moderate
        default: self = .heavy
        }
    }

    public var label: String {
        switch self {
        case .none: "None"
        case .light: "Light"
        case .moderate: "Moderate"
        case .heavy: "Heavy"
        }
    }

    public var isMeaningful: Bool { self != .none }

    public var symbol: String {
        switch self {
        case .none: "cloud.sun.fill"
        case .light: "cloud.drizzle.fill"
        case .moderate: "cloud.rain.fill"
        case .heavy: "cloud.heavyrain.fill"
        }
    }
}

public struct PrecipitationOutlook: Equatable, Sendable, Codable {

    public let hours: [HourlyForecast]

    public static let window = 24

    public init(hours: [HourlyForecast]) {
        self.hours = Array(hours.prefix(Self.window))
    }

    public var intensities: [PrecipitationIntensity] {
        hours.map { PrecipitationIntensity(millimetres: $0.precipitation) }
    }

    public var peakProbability: Double {
        hours.map(\.probability).max() ?? 0
    }

    public var isDry: Bool { !intensities.contains { $0.isMeaningful } }

}
