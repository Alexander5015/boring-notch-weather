import Foundation
import NotchTabSettings


public enum LocationSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case automatic
    case fixed

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .automatic: "My Location"
        case .fixed: "Fixed Location"
        }
    }
}

public enum UnitSystem: String, Codable, Sendable, CaseIterable, Identifiable {
    case metric
    case imperial

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }

    public var displayUnit: UnitTemperature {
        switch self {
        case .metric: .celsius
        case .imperial: .fahrenheit
        }
    }

    public var windUnit: UnitSpeed {
        switch self {
        case .metric: .kilometersPerHour
        case .imperial: .milesPerHour
        }
    }

    public var temperatureSymbol: String {
        switch self {
        case .metric: "C"
        case .imperial: "F"
        }
    }

    public var speedSymbol: String {
        switch self {
        case .metric: "km/h"
        case .imperial: "mph"
        }
    }
}

public enum TabDetail: String, Codable, Sendable, CaseIterable, Identifiable {
    case feelsLike
    case humidity
    case wind
    case precipitation

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .feelsLike: "Feels Like"
        case .humidity: "Humidity"
        case .wind: "Wind"
        case .precipitation: "Precipitation"
        }
    }

    public var symbol: String {
        switch self {
        case .feelsLike: "thermometer.medium"
        case .humidity: "humidity.fill"
        case .wind: "wind"
        case .precipitation: "drop.fill"
        }
    }
}

public struct WeatherSettings: Sendable {

    public var locationSource: Setting<LocationSource>
    public var fixedLatitude: Setting<Double>
    public var fixedLongitude: Setting<Double>
    public var units: Setting<UnitSystem>
    public var showDetail: Setting<Set<TabDetail>>
    public var fixedPlaceName: Setting<String?>

    public init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        func make<T: Codable & Sendable & Equatable>(
            _ name: String, _ fallback: T
        ) -> Setting<T> {
            Setting(name, default: fallback, bundle: bundle, defaults: defaults)
        }

        locationSource = make("locationSource", .automatic)
        fixedLatitude = make("fixedLatitude", 51.5074)
        fixedLongitude = make("fixedLongitude", -0.1278)
        units = make("units", .metric)
        showDetail = make(
            "showDetail",
            Set<TabDetail>([.humidity, .wind, .precipitation])
        )
        fixedPlaceName = make("fixedPlaceName", String?.none)
    }

    public var resolvedCoordinate: (latitude: Double, longitude: Double)? {
        guard locationSource.value == .fixed else { return nil }
        return (fixedLatitude.value, fixedLongitude.value)
    }

    public var isModified: Bool {
        locationSource.isModified
            || fixedLatitude.isModified
            || fixedLongitude.isModified
            || units.isModified
            || showDetail.isModified
            || fixedPlaceName.isModified
    }

    public mutating func reset() {
        locationSource.reset()
        fixedLatitude.reset()
        fixedLongitude.reset()
        units.reset()
        showDetail.reset()
        fixedPlaceName.reset()
    }
}
