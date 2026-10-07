import Foundation

final class ReadingCache: @unchecked Sendable {

    static let shared = ReadingCache()

    static let freshness: TimeInterval = 60 * 60

    private struct Payload: Codable {
        let reading: WeatherReading
        let storedAt: Date
    }

    private let key = "notch.weather.reading.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }


    func recent(now: Date = Date()) -> WeatherReading? {
        guard let data = defaults.data(forKey: key),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              now.timeIntervalSince(payload.storedAt) < Self.freshness
        else { return nil }
        return payload.reading
    }

    func any(now: Date = Date()) -> WeatherReading? {
        guard let data = defaults.data(forKey: key),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              now.timeIntervalSince(payload.storedAt) < Self.freshness * 6
        else { return nil }
        return payload.reading
    }

    func store(_ reading: WeatherReading, now: Date = Date()) {
        let payload = Payload(reading: reading, storedAt: now)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}