import CoreLocation

enum LocationError: LocalizedError {
    case denied
    case timedOut
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .denied: return "Location access is off."
        case .timedOut: return "Couldn't determine your location."
        case .notFound(let query): return "Couldn't find \"\(query)\"."
        }
    }
}

/// Wraps CLLocationManager's delegate callbacks in a single async call.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var requestID = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Asks for permission if needed, then returns a one-shot location fix.
    /// Fails if permission is denied or nothing arrives within `timeout` seconds.
    func currentLocation(timeout: TimeInterval = 10) async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.denied
        default:
            break
        }
        // Cancel any request still in flight.
        finish(.failure(LocationError.timedOut))
        requestID += 1
        let id = requestID

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self, self.requestID == id else { return }
                self.finish(.failure(LocationError.timedOut))
            }
        }
    }

    /// Turns a typed place ("Sacramento", "Seattle, WA", "95616") into coordinates.
    func coordinates(for query: String) async throws -> CLLocation {
        let placemarks = try? await geocoder.geocodeAddressString(query)
        guard let location = placemarks?.first?.location else {
            throw LocationError.notFound(query)
        }
        return location
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    // MARK: CLLocationManagerDelegate (delivered on the main thread)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if continuation != nil { manager.requestLocation() }
            case .denied, .restricted:
                finish(.failure(LocationError.denied))
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            if let location = locations.last { finish(.success(location)) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            finish(.failure(error))
        }
    }
}
