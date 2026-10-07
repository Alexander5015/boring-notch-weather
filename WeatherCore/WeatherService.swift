import Foundation

public struct WeatherService: Sendable {

    public enum ServiceError: Error, LocalizedError, Equatable {
        case badStatus(Int)
        case malformedResponse
        case unavailable

        public var errorDescription: String? {
            switch self {
            case .badStatus(let code): "The weather service answered HTTP \(code)."
            case .malformedResponse: "The weather service returned something unreadable."
            case .unavailable: "No forecast is available for this location yet."
            }
        }
    }

    static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func reading(
        latitude: Double,
        longitude: Double,
        place: String? = nil
    ) async throws -> WeatherReading {
        let lat = Self.rounded(latitude)
        let lon = Self.rounded(longitude)

        guard let url = Self.forecastURL(latitude: lat, longitude: lon) else {
            throw ServiceError.malformedResponse
        }

        let forecast: Forecast
        do {
            forecast = try await decode(Forecast.self, from: url)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.malformedResponse
        }

        guard let current = forecast.current,
              let high = forecast.daily?.temperatureMax?.first,
              let low = forecast.daily?.temperatureMin?.first
        else { throw ServiceError.unavailable }

        let resolvedPlace: String
        if let place, !place.isEmpty {
            resolvedPlace = place
        } else if let name = try? await placeName(latitude: lat, longitude: lon),
                  !name.isEmpty {
            resolvedPlace = name
        } else {
            resolvedPlace = Self.coordinateLabel(latitude: lat, longitude: lon)
        }

        return WeatherReading(
            place: resolvedPlace,
            temperature: .init(value: current.temperature, unit: .celsius),
            feelsLike: .init(value: current.apparentTemperature, unit: .celsius),
            high: .init(value: high, unit: .celsius),
            low: .init(value: low, unit: .celsius),
            humidity: current.humidity,
            windSpeed: current.windSpeed,
            precipitation: current.precipitation,
            condition: WeatherCondition(
                wmoCode: current.weatherCode,
                isDaylight: current.isDay == 1
            ),
            observedAt: Date(timeIntervalSince1970: current.time),
            timeZone: Self.zone(named: forecast.timezone, offset: forecast.utcOffsetSeconds),
            outlook: PrecipitationOutlook(hours: forecast.hourlyForecast),
            timeline: PrecipitationTimeline(buckets: forecast.timelineBuckets, now: Date()),
            hours: forecast.hourlyPoints,
            days: forecast.dailyPoints
        )
    }

    static func zone(named identifier: String?, offset: Int?) -> TimeZone? {
        if let identifier, let zone = TimeZone(identifier: identifier) { return zone }
        if let offset { return TimeZone(secondsFromGMT: offset) }
        return nil
    }

    static func coordinateLabel(latitude: Double, longitude: Double) -> String {
        String(format: "%.1f°, %.1f°", latitude, longitude)
    }

    private static func forecastURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,sunrise,sunset"),
            .init(name: "hourly", value: "temperature_2m,precipitation,precipitation_probability,weather_code"),
            .init(name: "minutely_15", value: "precipitation"),
            .init(name: "forecast_minutely_15", value: "\(PrecipitationTimeline.requestedBucketCount)"),
            .init(name: "forecast_hours", value: "\(PrecipitationOutlook.window)"),
            .init(name: "forecast_days", value: "7"),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime")
        ]
        return components?.url
    }

    private func placeName(latitude: Double, longitude: Double) async throws -> String {
        var components = URLComponents(string: "https://api.bigdatacloud.net/data/reverse-geocode-client")
        components?.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "localityLanguage", value: "en")
        ]
        guard let url = components?.url else { throw ServiceError.malformedResponse }

        let geocoded = try await decode(Geocoded.self, from: url)
        return geocoded.city
            ?? geocoded.locality
            ?? geocoded.principalSubdivision
            ?? geocoded.countryName
            ?? ""
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ServiceError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Wire format

private struct Forecast: Decodable {
    let timezone: String?
    let utcOffsetSeconds: Int?

    struct Current: Decodable {
        let temperature: Double
        let apparentTemperature: Double
        let humidity: Double
        let isDay: Int
        let precipitation: Double
        let weatherCode: Int
        let windSpeed: Double
        let time: Double

        private enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case humidity = "relative_humidity_2m"
            case isDay = "is_day"
            case precipitation
            case weatherCode = "weather_code"
            case windSpeed = "wind_speed_10m"
            case time
        }
    }

    struct Daily: Decodable {
        let time: [Double]?
        let temperatureMax: [Double]?
        let temperatureMin: [Double]?
        let precipitationSum: [Double]?
        let precipitationProbabilityMax: [Double]?
        let weatherCode: [Int]?
        let sunrise: [Double]?
        let sunset: [Double]?

        private enum CodingKeys: String, CodingKey {
            case time
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
            case precipitationSum = "precipitation_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case weatherCode = "weather_code"
            case sunrise
            case sunset
        }

        var daylight: [(start: Date, end: Date)] {
            let rises = sunrise ?? []
            let sets = sunset ?? []
            return zip(rises, sets).map {
                (Date(timeIntervalSince1970: $0), Date(timeIntervalSince1970: $1))
            }
        }
    }

    struct Hourly: Decodable {
        let time: [Double]?
        let temperature: [Double]?
        let precipitation: [Double]?
        let precipitationProbability: [Double]?
        let weatherCode: [Int]?

        private enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case precipitation
            case precipitationProbability = "precipitation_probability"
            case weatherCode = "weather_code"
        }
    }

    let current: Current?
    let daily: Daily?
    let hourly: Hourly?

    private enum CodingKeys: String, CodingKey {
        case current
        case daily
        case hourly
        case minutely15 = "minutely_15"
        case timezone
        case utcOffsetSeconds = "utc_offset_seconds"
    }

    struct Minutely: Decodable {
        let time: [Double]?
        let precipitation: [Double]?

        private enum CodingKeys: String, CodingKey {
            case time
            case precipitation
        }
    }

    let minutely15: Minutely?

    var timelineBuckets: [PrecipitationBucket] {
        guard let minutely15 else { return [] }
        let times = minutely15.time ?? []
        let amounts = minutely15.precipitation ?? []
        let count = min(times.count, amounts.count)
        return (0..<count).map { index in
            PrecipitationBucket(
                date: Date(timeIntervalSince1970: times[index]),
                precipitation: amounts[index]
            )
        }
    }

    var daylightIntervals: [(start: Date, end: Date)] {
        daily?.daylight ?? []
    }

    var hourlyPoints: [HourlyPoint] {
        guard let hourly else { return [] }
        let times = hourly.time ?? []
        let temperatures = hourly.temperature ?? []
        let amounts = hourly.precipitation ?? []
        let chances = hourly.precipitationProbability ?? []
        let codes = hourly.weatherCode ?? []
        let daylight = daily?.daylight ?? []

        let count = min(times.count, temperatures.count, amounts.count, chances.count, codes.count)
        return (0..<count).map { index in
            let date = Date(timeIntervalSince1970: times[index])
            return HourlyPoint(
                date: date,
                temperature: temperatures[index],
                precipitation: amounts[index],
                probability: chances[index],
                condition: WeatherCondition(
                    wmoCode: codes[index],
                    isDaylight: daylight.contains { date >= $0.start && date < $0.end }
                )
            )
        }
    }

    var dailyPoints: [DailyPoint] {
        guard let daily else { return [] }
        let times = daily.time ?? []
        let highs = daily.temperatureMax ?? []
        let lows = daily.temperatureMin ?? []
        let totals = daily.precipitationSum ?? []
        let chances = daily.precipitationProbabilityMax ?? []
        let codes = daily.weatherCode ?? []

        let rises = daily.sunrise ?? []
        let sets = daily.sunset ?? []

        let count = min(times.count, highs.count, lows.count, chances.count, codes.count)
        return (0..<count).map { index in
            DailyPoint(
                date: Date(timeIntervalSince1970: times[index]),
                high: highs[index],
                low: lows[index],
                precipitationChance: chances[index],
                precipitationTotal: index < totals.count ? totals[index] : 0,
                condition: WeatherCondition(
                    wmoCode: codes[index],
                    isDaylight: index > 0 || daylightIntervals.contains {
                        Date(timeIntervalSince1970: times[index]) >= $0.start
                            && Date(timeIntervalSince1970: times[index]) < $0.end
                    }),
                sunrise: index < rises.count ? Date(timeIntervalSince1970: rises[index]) : nil,
                sunset: index < sets.count ? Date(timeIntervalSince1970: sets[index]) : nil
            )
        }
    }

    var hourlyForecast: [HourlyForecast] {
        guard let hourly else { return [] }
        let times = hourly.time ?? []
        let temperatures = hourly.temperature ?? []
        let amounts = hourly.precipitation ?? []
        let chances = hourly.precipitationProbability ?? []

        let count = min(times.count, temperatures.count, amounts.count, chances.count)
        return (0..<count).map { index in
            HourlyForecast(
                precipitation: amounts[index],
                probability: chances[index],
                temperature: temperatures[index],
                date: Date(timeIntervalSince1970: times[index])
            )
        }
    }
}

private struct Geocoded: Decodable {
    let city: String?
    let locality: String?
    let principalSubdivision: String?
    let countryName: String?
}
