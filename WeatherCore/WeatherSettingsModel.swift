import Foundation

@MainActor
@Observable
final class WeatherSettingsModel {

    var locationSource: LocationSource { didSet { store.locationSource.value = locationSource } }
    var units: UnitSystem { didSet { store.units.value = units } }
    var showDetail: Set<TabDetail> { didSet { store.showDetail.value = showDetail } }

    var fixedLatitude: Double { didSet { store.fixedLatitude.value = fixedLatitude } }
    var fixedLongitude: Double { didSet { store.fixedLongitude.value = fixedLongitude } }

    var fixedPlaceName: String? {
        didSet { store.fixedPlaceName.value = fixedPlaceName }
    }


    private(set) var isModified: Bool = false

    @ObservationIgnored
    private var store: WeatherSettings

    init(store: WeatherSettings = WeatherSettings()) {
        self.store = store
        self.locationSource = store.locationSource.value
        self.units = store.units.value
        self.showDetail = store.showDetail.value
        self.fixedLatitude = store.fixedLatitude.value
        self.fixedLongitude = store.fixedLongitude.value
        self.fixedPlaceName = store.fixedPlaceName.value
        self.isModified = store.isModified
    }

    func reload() {
        locationSource = store.locationSource.value
        units = store.units.value
        showDetail = store.showDetail.value
        fixedLatitude = store.fixedLatitude.value
        fixedLongitude = store.fixedLongitude.value
        fixedPlaceName = store.fixedPlaceName.value
        isModified = store.isModified
    }

    func set(_ detail: TabDetail, enabled: Bool) {
        var current = showDetail
        if enabled {
            current.insert(detail)
        } else {
            current.remove(detail)
        }
        showDetail = current
    }

    func isEnabled(_ detail: TabDetail) -> Bool { showDetail.contains(detail) }


    func choose(_ place: Place) {
        fixedLatitude = place.latitude
        fixedLongitude = place.longitude
        fixedPlaceName = place.name
        isModified = store.isModified
    }

    var fixedLocationDescription: String {
        if let fixedPlaceName, !fixedPlaceName.isEmpty {
            return fixedPlaceName
        }
        return String(
            format: "%.2f°, %.2f°",
            fixedLatitude,
            fixedLongitude
        )
    }

    func reset() {
        store.reset()
        reload()
    }
}
