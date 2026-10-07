import Foundation

public struct HourlyPoint: Equatable, Sendable, Identifiable, Codable {
    public let date: Date
    public let temperature: Double
    public let precipitation: Double
    public let probability: Double
    public let condition: WeatherCondition

    public var id: Date { date }

    public init(
        date: Date,
        temperature: Double,
        precipitation: Double,
        probability: Double,
        condition: WeatherCondition
    ) {
        self.date = date
        self.temperature = temperature
        self.precipitation = precipitation
        self.probability = probability
        self.condition = condition
    }

    public var intensity: PrecipitationIntensity {
        PrecipitationIntensity(millimetres: precipitation)
    }
}

public struct DailyPoint: Equatable, Sendable, Identifiable, Codable {
    public let date: Date
    public let high: Double
    public let low: Double
    public let precipitationChance: Double
    public let precipitationTotal: Double
    public let condition: WeatherCondition

    public let sunrise: Date?
    public let sunset: Date?

    public var id: Date { date }

    public init(
        date: Date,
        high: Double,
        low: Double,
        precipitationChance: Double,
        precipitationTotal: Double,
        condition: WeatherCondition,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) {
        self.date = date
        self.high = high
        self.low = low
        self.precipitationChance = precipitationChance
        self.precipitationTotal = precipitationTotal
        self.condition = condition
        self.sunrise = sunrise
        self.sunset = sunset
    }

    public func label(calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        return date.formatted(.dateTime.weekday(.abbreviated).locale(calendar.locale ?? .current))
    }

    public func isToday(calendar: Calendar = .current) -> Bool {
        calendar.isDateInToday(date)
    }
}

public struct ForecastHeadline: Equatable, Sendable, Codable {

    public let primary: String
    public let symbol: String
    public let windows: [PrecipitationTimeline.Window]

    public init(
        primary: String,
        symbol: String,
        windows: [PrecipitationTimeline.Window] = []
    ) {
        self.primary = primary
        self.symbol = symbol
        self.windows = windows
    }
}
