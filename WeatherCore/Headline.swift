import Foundation

public enum Headline {

    public static func forTimeline(
        _ timeline: PrecipitationTimeline,
        now: Date,
        units: UnitSystem,
        zone: TimeZone? = nil
    ) -> ForecastHeadline? {
        let windows = timeline.wetWindows
        guard !windows.isEmpty else { return nil }

        let underWay = windows.first { $0.start <= now && $0.end > now }

        let primary: String
        if let underWay {
            primary = "Rain until \(WeatherFormatter(units: units, zone: zone).time(underWay.end))"
        } else if let minutes = timeline.minutesUntilNextWet(now: now) {
            primary = minutes <= 0 ? "Rain starting now" : "Light rain in \(minutes) min"
        } else {
            primary = "Rain soon"
        }

        return ForecastHeadline(primary: primary, symbol: "cloud.rain.fill", windows: windows)
    }
}