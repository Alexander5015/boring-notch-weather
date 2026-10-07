import AppKit
import SwiftUI

@MainActor
@Observable
final class WeatherModel {

    enum Phase: Equatable {
        case idle
        case loading
        case ready(WeatherReading)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var isRefreshing = false

    let location = LocationProvider()
    private var settings = WeatherSettings()
    private let service: WeatherService

    init(service: WeatherService = WeatherService(), cache: ReadingCache = .shared) {
        self.service = service
        self.cache = cache
        if let cached = cache.recent() {
            phase = .ready(cached)
        }
    }

    private let cache: ReadingCache

    var units: UnitSystem {
        #if DEBUG
        if let forcedUnits { return forcedUnits }
        #endif
        return settings.units.value
    }
    func shows(_ detail: TabDetail) -> Bool { settings.showDetail.value.contains(detail) }

    func start() {
        if settings.locationSource.value == .fixed {
            Task { await load() }
            return
        }
        location.request()
        
        if location.coordinate != nil {
            Task { await load() }
        }
    }

    func load() async {
        guard let coordinate = coordinateToFetch() else {
            if case .ready = phase {} else { isRefreshing = false }
            return
        }
        if case .ready = phase {} else { phase = .loading }
        do {
            let reading = try await service.reading(
                latitude: coordinate.latitude, longitude: coordinate.longitude)
            phase = .ready(reading)
            cache.store(reading)
        } catch {
            if case .ready = phase {} else if let stale = cache.any() {
                phase = .ready(stale)
            } else {
                phase = .failed(error.localizedDescription)
            }
        }
        isRefreshing = false
    }

    func refresh() async {
        isRefreshing = true
        await load()
    }

    private func coordinateToFetch() -> (latitude: Double, longitude: Double)? {
        if let fixed = settings.resolvedCoordinate { return fixed }
        guard let coordinate = location.coordinate else { return nil }
        return (coordinate.latitude, coordinate.longitude)
    }

    func permissionWithdrawn() {
        guard settings.locationSource.value == .automatic else { return }
        if case .denied = location.access, phase != .idle { phase = .idle }
    }

    #if DEBUG
    static func sample(_ reading: WeatherReading, units: UnitSystem = .metric) -> WeatherModel {
        let model = WeatherModel()
        model.phase = .ready(reading)
        model.forcedUnits = units
        return model
    }

    var forcedUnits: UnitSystem?
    #endif
}

struct WeatherPanel: View {

    @State private var model = WeatherModel()

    var body: some View {
        Group {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .task { model.start() }
        .onChange(of: model.location.coordinateKey) { _, _ in Task { await model.load() } }
        .onChange(of: model.location.access) { _, _ in model.permissionWithdrawn() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.location.access {
        case .denied where model.phase == .idle:
            MessageView(
                symbol: "location.slash.fill",
                title: "Location is off",
                detail: "Allow location, or choose a fixed location in Settings.",
                action: ("Open Settings", Self.openLocationSettings))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            reading
        }
    }

    @ViewBuilder
    private var reading: some View {
        switch model.phase {
        case .idle, .loading:
            ProgressView().controlSize(.small)
        case .failed(let why):
            MessageView(symbol: "network.slash", title: "No forecast", detail: why,
                        action: ("Retry", { Task { await model.refresh() } }))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let reading):
            ReadingPanel(reading: reading, model: model)
        }
    }

    private static func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct ReadingPanel: View {
    private static let contentWidth: CGFloat = 578 - 14 * 2

    private static var hourlyHeight: CGFloat {
        ForecastRow.hourlyHeight(for: true)
    }

    let reading: WeatherReading
    @Bindable var model: WeatherModel


    init(reading: WeatherReading, model: WeatherModel) {
        self.reading = reading
        self.model = model
        self.formatter = WeatherFormatter(units: model.units, zone: reading.timeZone)
    }

    private let formatter: WeatherFormatter

    private let conditionsWidth: CGFloat = 145

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 0) {
                conditions
                    .frame(width: conditionsWidth, alignment: .leading)
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 1)
                ForecastRow(hours: reading.hours, days: reading.days,
                            units: model.units, timeZone: reading.timeZone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: Self.hourlyHeight)
            }

            Divider().overlay(.white.opacity(0.12))
            ForecastRow(hours: reading.hours, days: reading.days,
                        units: model.units, timeZone: reading.timeZone,
                        isDaily: true,
                        dailyWidth: Self.contentWidth)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Left column

    private var conditions: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(formatter.temperatureBare(reading.temperature.value))
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: 34)

            HStack(spacing: 4) {
                Image(systemName: reading.condition.symbol)
                    .font(.system(size: 13))
                    .symbolRenderingMode(reading.condition.symbolColoring)
                    .foregroundStyle(.white)
                Text(reading.condition.label)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 15)

            news
                .frame(height: 13)

            HStack(spacing: 9) {
                if model.shows(.wind) {
                    Label(formatter.speed(reading.windSpeed), systemImage: "wind")
                }
                if model.shows(.humidity) {
                    Label(formatter.humidity(reading.humidity), systemImage: "drop.fill")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.6))
            .labelStyle(.titleAndIcon)
            .monospacedDigit()
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var news: some View {
        if let headline = Headline.forTimeline(
            reading.timeline, now: reading.observedAt, units: model.units,
            zone: reading.timeZone) {
            Text(headline.primary)
                .foregroundStyle(Color.rainBlue)
        } else if abs(reading.feelsLike.value - reading.temperature.value) >= 2 {
            Text("Feels like \(formatter.temperatureBare(reading.feelsLike.value))")
                .foregroundStyle(.white.opacity(0.6))
        } else if let sunset = nextSunset {
            Text(sunsetText(sunset))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func sunsetText(_ sunset: Date) -> String {
        let time = "Sunset \(formatter.time(sunset))"
        guard let zone = reading.timeZone, zone != .current else { return time }
        guard let name = formatter.zoneAbbreviation else { return time }
        return "\(time) \(name)"
    }


    private var nextSunset: Date? {
        reading.days.compactMap(\.sunset).filter { $0 >= reading.observedAt }.sorted().first
    }
}

struct MessageView: View {
    let symbol: String
    let title: String
    let detail: String
    let action: (title: String, perform: () -> Void)

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 330, alignment: .leading)

            Spacer(minLength: 12)

            Button(action.title) { action.perform() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.rainBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .fixedSize()
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
