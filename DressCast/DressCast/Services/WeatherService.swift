import Foundation

enum WeatherServiceError: LocalizedError {
    case unsupportedLocation
    case badResponse(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .unsupportedLocation:
            return "The National Weather Service only covers US locations."
        case .badResponse(let code):
            return "The weather service returned an error (\(code))."
        case .noData:
            return "No forecast data is available right now."
        }
    }
}

/// Fetches forecasts from the National Weather Service API (https://www.weather.gov/documentation/services-web-api).
/// The API is free and keyless, but asks every client to send an identifying User-Agent.
struct WeatherService {
    private let session: URLSession = .shared
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func fetchReport(latitude: Double, longitude: Double) async throws -> WeatherReport {
        // NWS wants at most 4 decimal places; more triggers a redirect.
        let pointsURL = URL(string: String(format: "https://api.weather.gov/points/%.4f,%.4f", latitude, longitude))!
        let points: NWSPointsResponse
        do {
            points = try await get(pointsURL)
        } catch WeatherServiceError.badResponse(404) {
            throw WeatherServiceError.unsupportedLocation
        }

        async let hourly: NWSForecastResponse = get(points.properties.forecastHourly)
        async let daily: NWSForecastResponse = get(points.properties.forecast)
        let (hourlyPeriods, dailyPeriods) = try await (hourly.properties.periods, daily.properties.periods)

        // Drop any hours that have already ended.
        let now = Date()
        let upcoming = hourlyPeriods.filter { $0.endTime > now }
        guard !upcoming.isEmpty, !dailyPeriods.isEmpty else { throw WeatherServiceError.noData }

        let location = points.properties.relativeLocation.properties
        return WeatherReport(
            city: location.city,
            state: location.state,
            timeZone: TimeZone(identifier: points.properties.timeZone) ?? .current,
            hourly: upcoming,
            daily: dailyPeriods
        )
    }

    /// GET + decode, retrying a couple of times because NWS forecast endpoints
    /// occasionally return transient 5xx errors.
    private func get<T: Decodable>(_ url: URL, attempts: Int = 3) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("DressCast/1.0 (ECS 191 student iOS app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")

        var lastError: Error = WeatherServiceError.noData
        for attempt in 1...attempts {
            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200..<300).contains(status) else {
                    throw WeatherServiceError.badResponse(status)
                }
                return try decoder.decode(T.self, from: data)
            } catch WeatherServiceError.badResponse(let code) where code < 500 {
                throw WeatherServiceError.badResponse(code)
            } catch {
                lastError = error
                if attempt < attempts {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 700_000_000)
                }
            }
        }
        throw lastError
    }
}
