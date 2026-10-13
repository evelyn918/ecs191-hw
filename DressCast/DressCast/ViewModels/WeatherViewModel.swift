import CoreLocation
import Observation

@MainActor
@Observable
final class WeatherViewModel {
    enum State {
        case loading
        case loaded(WeatherReport)
        case failed(String)
    }

    /// Used whenever the user's location or search can't be resolved.
    static let davis = CLLocation(latitude: 38.5449, longitude: -121.7405)

    private(set) var state: State = .loading
    /// Short message explaining a fallback, e.g. "Location off — showing Davis, CA".
    private(set) var notice: String?

    private let weather = WeatherService()
    private let location = LocationProvider()
    private var lastCoordinate: CLLocation?

    /// Weather for the device's location, or Davis, CA if that isn't available.
    func loadCurrentLocation() async {
        state = .loading
        do {
            let here = try await location.currentLocation()
            await load(here, fallbackReason: "Weather unavailable here")
        } catch {
            await loadDavis(reason: error.localizedDescription)
        }
    }

    /// Weather for a typed place. An empty query uses the device location.
    func search(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            await loadCurrentLocation()
            return
        }
        state = .loading
        do {
            let place = try await location.coordinates(for: query)
            await load(place, fallbackReason: "No NWS forecast for \"\(query)\" (US only).")
        } catch {
            await loadDavis(reason: error.localizedDescription)
        }
    }

    func refresh() async {
        guard let lastCoordinate else {
            await loadCurrentLocation()
            return
        }
        await load(lastCoordinate, fallbackReason: nil)
    }

    private func load(_ place: CLLocation, fallbackReason: String?) async {
        do {
            let report = try await weather.fetchReport(latitude: place.coordinate.latitude,
                                                       longitude: place.coordinate.longitude)
            lastCoordinate = place
            notice = nil
            state = .loaded(report)
        } catch WeatherServiceError.unsupportedLocation where fallbackReason != nil {
            await loadDavis(reason: fallbackReason!)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func loadDavis(reason: String) async {
        await load(Self.davis, fallbackReason: nil)
        if case .loaded = state {
            notice = "\(reason) Showing Davis, CA."
        }
    }
}
