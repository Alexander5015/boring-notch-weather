import CoreLocation
import Foundation


public enum LocationAccess: Equatable, Sendable {
    case notRequested
    case pending
    case denied
    case authorized
    case searching
    case failed(String)

    public var isUsable: Bool {
        self == .authorized || self == .searching
    }
}

@MainActor
@Observable
public final class LocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate {

    public private(set) var access: LocationAccess = .notRequested
    public private(set) var coordinate: CLLocationCoordinate2D?


    public var coordinateKey: String? {
        guard let coordinate else { return nil }
        return "\(WeatherService.rounded(coordinate.latitude)),\(WeatherService.rounded(coordinate.longitude))"
    }

    private let manager = CLLocationManager()

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            access = .pending
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            if coordinate == nil { access = .searching }
            manager.requestLocation()
        case .denied, .restricted:
            access = .denied
        @unknown default:
            access = .failed("Unrecognized authorization status.")
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        request()
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        coordinate = latest.coordinate
        access = .authorized
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let failure = error as? CLError
        if failure?.code == .locationUnknown { return }
        access = .failed(error.localizedDescription)
    }
}
