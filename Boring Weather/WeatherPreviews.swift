#if DEBUG
import NotchTabKit
import SwiftUI

struct SamplePanel: View {
    var units: UnitSystem = .metric

    var body: some View {
        ReadingPanel(reading: Self.reading, model: WeatherModel.sample(Self.reading, units: units))
    }

    static let reading: WeatherReading = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Edmonton")!
        let today = calendar.startOfDay(for: Date())
        let now = calendar.date(bySettingHour: 12, minute: 22, second: 0, of: today)!
        let firstBucket = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today)!

        let amounts: [Double] = [0.4, 1.9, 0.8, 0.2]
        let buckets = amounts.enumerated().map { index, amount in
            PrecipitationBucket(
                date: firstBucket.addingTimeInterval(Double(index) * 900),
                precipitation: amount
            )
        }
        let timeline = PrecipitationTimeline(buckets: buckets, now: now)

        let temps: [Double] = [
            13, 15, 16, 17, 18, 17, 16, 14, 12, 11, 10, 9,
            9, 9, 10, 11, 12, 13, 13, 12, 11, 10, 10, 10,
        ]
        let codes = [3, 61, 61, 2, 1, 2, 1, 1, 1, 0, 0, 0,
                     0, 0, 1, 1, 2, 2, 3, 3, 2, 1, 1, 1]
        let sunriseToday = calendar.date(bySettingHour: 7, minute: 45, second: 0, of: now)!
        let sunsetToday = calendar.date(bySettingHour: 19, minute: 4, second: 0, of: now)!
        let hours: [HourlyPoint] = temps.enumerated().map { index, celsius in
            let date = now.addingTimeInterval(Double(index) * 3600)
            let daylight = date >= sunriseToday && date < sunsetToday
            return HourlyPoint(
                date: date,
                temperature: celsius,
                precipitation: index < 2 ? 0.4 : 0,
                probability: index < 2 ? 70 : 10,
                condition: WeatherCondition(wmoCode: codes[index], isDaylight: daylight)
            )
        }
        func rainTotal(_ offset: Int) -> Double {
            let c: Double = chanceFor[offset]
            return c > 50 ? 1.2 : 0.0
        }
        func sunsetOn(_ offset: Int) -> Date? {
            let base = calendar.date(bySettingHour: 19, minute: 4, second: 0, of: now)
            return base?.addingTimeInterval(Double(offset) * 86400)
        }
        let chances: [Double] = [70, 55, 40, 10, 15]
        let chanceFor = chances

        let days: [DailyPoint] = (0..<5).map { offset in
            DailyPoint(
                date: calendar.date(byAdding: .day, value: offset, to: now)!,
                high: 18 - Double(offset), low: 1 + Double(offset),
                precipitationChance: chanceFor[offset],
                precipitationTotal: rainTotal(offset),
                condition: WeatherCondition(
                    wmoCode: codes[min(offset, codes.count - 1)],
                    isDaylight: offset > 0 || now < sunsetToday),
                sunset: sunsetOn(offset)
            )
        }
        return WeatherReading(
            place: "Calgary",
            temperature: .init(value: 13, unit: .celsius),
            feelsLike: .init(value: 10, unit: .celsius),
            high: .init(value: 18, unit: .celsius),
            low: .init(value: 1, unit: .celsius),
            humidity: 66,
            windSpeed: 11,
            precipitation: 0,
            condition: WeatherCondition(wmoCode: 3, isDaylight: now < sunsetToday),
            observedAt: now,
            timeline: timeline,
            hours: hours,
            days: days
        )
    }()
}

#Preview("Weather tab") {
    NotchTabPreview("Weather", icon: "cloud.sun.fill") {
        WeatherPanel()
    }
}

#Preview("Weather tab — sample") {
    NotchTabPreview("Weather", icon: "cloud.sun.fill") {
        SamplePanel()
    }
}

#Preview("Weather tab — states") {
    VStack(spacing: 12) {
        NotchTabPreview("Weather", icon: "cloud.sun.fill", alignment: .center) {
            MessageView(
                symbol: "location.slash.fill",
                title: "Location is off",
                detail: "Allow location, or choose a fixed location in Settings.",
                action: ("Open Settings", {})
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        NotchTabPreview("Weather", icon: "cloud.sun.fill", alignment: .center) {
            MessageView(
                symbol: "network.slash",
                title: "No forecast",
                detail: "The weather service answered HTTP 503.",
                action: ("Retry", {})
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Weather settings") {
    WeatherSettingsScene()
        .frame(width: 460, height: 620)
}
#endif
