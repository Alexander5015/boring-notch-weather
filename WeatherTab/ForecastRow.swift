import AppKit
import SwiftUI

private struct ChanceSizing: ViewModifier {
    let width: CGFloat?
    func body(content: Content) -> some View {
        if width == nil {
            content.fixedSize()
        } else {
            content.minimumScaleFactor(0.75)
        }
    }
}

struct ForecastRow: View {

    private let hours: [HourlyPoint]
    private let days: [DailyPoint]
    let units: UnitSystem

    var timeZone: TimeZone? = nil

    private var calendar: Calendar {
        var c = Calendar.current
        if let timeZone { c.timeZone = timeZone }
        return c
    }

    var isDaily: Bool = false

    var dailyWidth: CGFloat = 550

    static let perRow = 8

    static let iconSize: CGFloat = 21
    static let labelSize: CGFloat = 12
    static let tempSize: CGFloat = 20

    init(
        hours: [HourlyPoint],
        days: [DailyPoint],
        units: UnitSystem,
        timeZone: TimeZone? = nil,
        isDaily: Bool = false,
        dailyWidth: CGFloat = 550
    ) {
        self.hours = Array(hours.prefix(ForecastRow.perRow))
        self.days = Array(days.prefix(ForecastRow.dayCount))
        self.units = units
        self.timeZone = timeZone
        self.isDaily = isDaily
        self.dailyWidth = dailyWidth
        self.formatter = WeatherFormatter(units: units, zone: timeZone)
    }

    static let dayCount = 5

    private var shownHours: [HourlyPoint] { hours }

    @ViewBuilder
    var body: some View {
        if isDaily {
            daily(width: dailyWidth)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            GeometryReader { proxy in
                hourly(width: proxy.size.width)
                    .frame(height: hourRowHeight, alignment: .top)
                    .padding(.bottom, max(0, proxy.size.height - hourRowHeight))
            }
            .frame(height: hourRowHeight)
        }
    }

    static func hourlyHeight(for chance: Bool) -> CGFloat {
        Self.labelSize + Self.iconSize + Self.tempSize + 5 + (chance ? 14 : 0)
    }

    private var hourRowHeight: CGFloat { Self.hourlyHeight(for: needsChance) }

    private var needsChance: Bool {
        shownHours.contains { $0.condition.isPrecipitation }
    }

    // MARK: - Hourly

    private func hourly(width: CGFloat) -> some View {
        let slot = width / CGFloat(Self.perRow)
        return hourRow(shownHours, slot: slot)
    }

    private func hourRow(_ row: [HourlyPoint], slot: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { index, hour in
                VStack(spacing: 0) {
                    Text(index == 0 ? "Now" : hourLabel(hour.date))
                        .font(.system(size: Self.labelSize, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: slot, height: 14)

                    Image(systemName: hour.condition.symbol)
                        .font(.system(size: Self.iconSize))
                        .symbolRenderingMode(hour.condition.symbolColoring)
                        .frame(width: slot, height: 23)

                    Text(formatter.temperatureBare(hour.temperature))
                        .font(.system(size: Self.tempSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: slot, height: 24)
                        .padding(.top, 2)

                    chance(hour.condition, hour.probability)
                        .padding(.top, 2)
                }
                .frame(width: slot)
            }
        }
    }

    @ViewBuilder
    private func chance(
        _ condition: WeatherCondition,
        _ percent: Double,
        width: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {
        if condition.isPrecipitation {
            Text(formatter.percent(percent))
                .font(.system(size: Self.dailyChanceSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.rainBlue)
                .lineLimit(1)
                .modifier(ChanceSizing(width: width))
                .frame(width: width, alignment: alignment)
                .frame(height: 13)
        } else {
            Color.clear.frame(width: width, height: 13, alignment: alignment)
        }
    }

    private func hourLabel(_ date: Date) -> String {
        formatter.hour(date)
    }

    // MARK: - Daily

    private func daily(width: CGFloat) -> some View {
        let shown = days
        let slot = width / CGFloat(max(shown.count, 1))
        let cell = max(0, slot - 8)
        let metrics = dailyMetrics(width: width)

        return HStack(alignment: .center, spacing: 0) {
            ForEach(shown) { day in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .top, spacing: 4) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(day.label(calendar: calendar))
                                .font(.system(size: Self.dailyLabelSize, weight: day.isToday(calendar: calendar) ? .bold : .regular))
                                .foregroundStyle(day.isToday(calendar: calendar) ? .white : .white.opacity(0.55))
                                .lineLimit(1)

                            if Self.showsChance(day) {
                                Text(formatter.percent(day.precipitationChance))
                                    .font(.system(size: Self.dailyChanceSize, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.rainBlue)
                                    .lineLimit(1)
                                    .frame(height: Self.dailyChanceSize + 1)
                            } else {
                                Color.clear.frame(height: Self.dailyChanceSize + 1)
                            }
                        }
                        .frame(width: metrics.leadWidth, alignment: .leading)

                        Image(systemName: day.condition.symbol)
                            .font(.system(size: dailyIconSize))
                            .symbolRenderingMode(day.condition.symbolColoring)
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 4) {
                        Text(formatter.temperatureBare(day.low))
                            .font(.system(size: metrics.size, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.55))

                        DailyRangeBar(day: day, scale: metrics.scale)
                        .frame(height: 4)

                        Text(formatter.temperatureBare(day.high))
                            .font(.system(size: metrics.size, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .lineLimit(1)
                }
                .frame(width: cell, alignment: .leading)
                .frame(width: slot, alignment: .leading)
                .clipped()
            }
        }
        .frame(height: metrics.height, alignment: .top)
    }


    private var widestLabel: String {
        let labels = days.map { $0.label(calendar: calendar) }
        return labels.max { measure($0, Self.dailyLabelSize, .bold) < measure($1, Self.dailyLabelSize, .bold) }
            ?? "Today"
    }

    static let dailyLabelSize: CGFloat = 10
    private let dailyIconSize: CGFloat = 15

    static let dailyChanceSize: CGFloat = 9

    static func showsChance(_ day: DailyPoint) -> Bool {
        day.condition.isPrecipitation
    }


    private struct DailyMetrics {
        let size: CGFloat
        let height: CGFloat
        let leadWidth: CGFloat
        let scale: ClosedRange<Double>

        init(size: CGFloat, scale: ClosedRange<Double>, leadWidth: CGFloat) {
            self.size = size
            self.scale = scale
            self.leadWidth = leadWidth
            self.height = ForecastRow.dailyLabelSize + ForecastRow.dailyChanceSize + size + 2
        }
    }

    private func dailyMetrics(width: CGFloat) -> DailyMetrics {
        let slot = width / CGFloat(max(days.count, 1))
        let cell = max(0, slot - 8)

        let widestLow = days.map { measure(formatter.temperatureBare($0.low), 15, .semibold) }.max() ?? 0
        let widestHigh = days.map { measure(formatter.temperatureBare($0.high), 15, .semibold) }.max() ?? 0

        let barFloor = cell * 0.34

        var size: CGFloat = 9
        for candidate in [15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0] {
            let scale = candidate / 15
            let bar = cell - (widestLow + widestHigh) * scale - 6
            if bar >= barFloor { size = candidate; break }
        }

        let lows = days.map(\.low)
        let highs = days.map(\.high)
        let floor = (lows.min() ?? 0) - 2
        let ceiling = max((highs.max() ?? 1) + 2, floor + 1)
        let chanceText = days
            .filter { Self.showsChance($0) }
            .map { measure(formatter.percent($0.precipitationChance), Self.dailyChanceSize, .semibold) }
            .max() ?? 0
        let leadWidth = max(measure(widestLabel, Self.dailyLabelSize, .bold), chanceText)

        return DailyMetrics(size: size, scale: floor...ceiling, leadWidth: leadWidth)
    }

    private func measure(_ string: String, _ size: CGFloat, _ weight: NSFont.Weight) -> CGFloat {
        (string as NSString).size(withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        ]).width
    }

    // MARK: - Shared

    private let formatter: WeatherFormatter
}

private struct DailyRangeBar: View {
    let day: DailyPoint
    let scale: ClosedRange<Double>

    private static let track = Color.white.opacity(0.10)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let span = scale.upperBound - scale.lowerBound
            let start = (day.low - scale.lowerBound) / span
            let end = (day.high - scale.lowerBound) / span
            let x = max(0, min(start, 1)) * width
            let barWidth = max(end - start, 0) * width

            ZStack(alignment: .leading) {
                Capsule().fill(Self.track)
                Capsule()
                    .fill(LinearGradient(
                        colors: [color(for: day.low), color(for: day.high)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(barWidth, 4))
                    .offset(x: min(x, max(width - 4, 0)))
            }
        }
    }

    private func color(for celsius: Double) -> Color {
        switch celsius {
        case ..<4: Color(red: 0.42, green: 0.68, blue: 0.90)
        case ..<11: Color(red: 0.36, green: 0.76, blue: 0.72)
        case ..<17: Color(red: 0.55, green: 0.83, blue: 0.44)
        case ..<23: Color(red: 0.98, green: 0.84, blue: 0.24)
        default: Color(red: 0.96, green: 0.55, blue: 0.24)
        }
    }
}
