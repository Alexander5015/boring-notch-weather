import Foundation

public final class WeatherFormatter: @unchecked Sendable {

    private let units: UnitSystem
    private let zone: TimeZone?

    private let clock: DateFormatter
    private let hourOnly: DateFormatter

    public init(units: UnitSystem, zone: TimeZone? = nil) {
        self.units = units
        self.zone = zone

        let clock = DateFormatter()
        clock.setLocalizedDateFormatFromTemplate("j:mm")
        clock.timeZone = zone ?? .current
        self.clock = clock

        let hourOnly = DateFormatter()
        hourOnly.setLocalizedDateFormatFromTemplate("j a")
        hourOnly.timeZone = zone ?? .current
        self.hourOnly = hourOnly
    }

    public func temperatureBare(_ celsius: Double) -> String {
        "\(rounded(celsius))°"
    }

    private func rounded(_ celsius: Double) -> Int {
        let converted = Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: units.displayUnit)
        return Int(converted.value.rounded())
    }

    public func speed(_ kilometresPerHour: Double) -> String {
        let converted = Measurement(value: kilometresPerHour, unit: UnitSpeed.kilometersPerHour)
            .converted(to: units.windUnit)
        return "\(Int(converted.value.rounded())) \(units.speedSymbol)"
    }

    public func humidity(_ fraction: Double) -> String {
        "\(Int(fraction.rounded()))%"
    }

    public func percent(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded >= 100 ? "100" : "\(rounded)%"
    }

    public func time(_ date: Date) -> String { clock.string(from: date) }

    public func hour(_ date: Date) -> String { hourOnly.string(from: date) }

    public var zoneAbbreviation: String? {
        guard let zone else { return nil }
        if let name = zone.abbreviation(for: Date()), !name.isEmpty, name != "GMT" {
            return name
        }
        return String(format: "GMT%+d", zone.secondsFromGMT(for: Date()) / 3600)
    }
}