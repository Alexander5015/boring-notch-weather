import Foundation
import SwiftUI

public extension Color {
    static let rainBlue = Color(red: 0.2353, green: 0.8235, blue: 0.9961)
}

public struct WeatherCondition: Equatable, Sendable, Codable {

    public let symbol: String
    public let label: String
    public let isDaylight: Bool

    public let isPrecipitation: Bool

    public init(
        symbol: String,
        label: String,
        isDaylight: Bool,
        isPrecipitation: Bool = false
    ) {
        self.symbol = symbol
        self.label = label
        self.isDaylight = isDaylight
        self.isPrecipitation = isPrecipitation
    }

    public var symbolColoring: SymbolRenderingMode { .multicolor }

    public init(wmoCode: Int, isDaylight: Bool) {
        var wet = false

        switch wmoCode {
        case 0:
            symbol = isDaylight ? "sun.max.fill" : "moon.stars.fill"
            label = "Clear"
        case 1:
            symbol = isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
            label = "Mainly clear"
        case 2:
            symbol = isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
            label = "Partly cloudy"
        case 3:
            symbol = "cloud.fill"
            label = "Overcast"
        case 45, 48:
            symbol = "cloud.fog.fill"
            label = "Fog"
        case 51, 53, 55:
            wet = true
            symbol = isDaylight ? "cloud.drizzle.fill" : "cloud.moon.rain.fill"
            label = "Drizzle"
        case 56, 57:
            wet = true
            symbol = "cloud.sleet.fill"
            label = "Freezing drizzle"
        case 61:
            wet = true
            symbol = isDaylight ? "cloud.rain.fill" : "cloud.moon.rain.fill"
            label = "Light rain"
        case 63:
            wet = true
            symbol = isDaylight ? "cloud.rain.fill" : "cloud.moon.rain.fill"
            label = "Rain"
        case 65:
            wet = true
            symbol = "cloud.heavyrain.fill"
            label = "Heavy rain"
        case 66, 67:
            wet = true
            symbol = "cloud.sleet.fill"
            label = "Freezing rain"
        case 71, 73, 75, 77:
            wet = true
            symbol = "cloud.snow.fill"
            label = "Snow"
        case 80, 81, 82:
            wet = true
            symbol = isDaylight ? "cloud.rain.fill" : "cloud.moon.rain.fill"
            label = "Showers"
        case 85, 86:
            wet = true
            symbol = "cloud.snow.fill"
            label = "Snow showers"
        case 95, 96, 99:
            wet = true
            symbol = "cloud.bolt.rain.fill"
            label = "Thunderstorm"
        default:
            symbol = isDaylight ? "sun.max.fill" : "moon.stars.fill"
            label = "Unknown"
        }

        self.isDaylight = isDaylight
        self.isPrecipitation = wet
    }
}

public struct WeatherReading: Equatable, Sendable, Codable {
    public let place: String
    public let temperature: Measurement<UnitTemperature>
    public let feelsLike: Measurement<UnitTemperature>
    public let high: Measurement<UnitTemperature>
    public let low: Measurement<UnitTemperature>
    public let humidity: Double
    public let windSpeed: Double
    public let precipitation: Double
    public let condition: WeatherCondition
    public let observedAt: Date

    public let timeZone: TimeZone?


    public let outlook: PrecipitationOutlook


    public let timeline: PrecipitationTimeline


    public let hours: [HourlyPoint]
    public let days: [DailyPoint]

    public init(
        place: String,
        temperature: Measurement<UnitTemperature>,
        feelsLike: Measurement<UnitTemperature>,
        high: Measurement<UnitTemperature>,
        low: Measurement<UnitTemperature>,
        humidity: Double,
        windSpeed: Double,
        precipitation: Double,
        condition: WeatherCondition,
        observedAt: Date,
        timeZone: TimeZone? = nil,
        outlook: PrecipitationOutlook = PrecipitationOutlook(hours: []),
        timeline: PrecipitationTimeline = .empty(now: Date()),
        hours: [HourlyPoint] = [],
        days: [DailyPoint] = []
    ) {
        self.place = place
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.high = high
        self.low = low
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.precipitation = precipitation
        self.condition = condition
        self.observedAt = observedAt
        self.timeZone = timeZone
        self.outlook = outlook
        self.timeline = timeline
        self.hours = hours
        self.days = days
    }
}
