import Foundation

// MARK: - Raw National Weather Service (api.weather.gov) responses

/// Response from `GET /points/{lat},{lon}` — tells us which forecast URLs cover a location.
struct NWSPointsResponse: Decodable {
    struct Properties: Decodable {
        let forecast: URL
        let forecastHourly: URL
        let timeZone: String
        let relativeLocation: RelativeLocation
    }

    struct RelativeLocation: Decodable {
        struct Properties: Decodable {
            let city: String
            let state: String
        }
        let properties: Properties
    }

    let properties: Properties
}

/// Response from a `forecast` or `forecastHourly` URL.
struct NWSForecastResponse: Decodable {
    struct Properties: Decodable {
        let periods: [ForecastPeriod]
    }
    let properties: Properties
}

struct ForecastPeriod: Decodable, Identifiable, Hashable {
    struct QuantitativeValue: Decodable, Hashable {
        let value: Double?
    }

    let number: Int
    let name: String
    let startTime: Date
    let endTime: Date
    let isDaytime: Bool
    let temperature: Int
    let temperatureUnit: String
    let probabilityOfPrecipitation: QuantitativeValue?
    let windSpeed: String?
    let shortForecast: String

    var id: Int { number }

    /// Chance of precipitation as a whole percent (0–100).
    var precipChance: Int {
        Int(probabilityOfPrecipitation?.value ?? 0)
    }

    /// Highest wind speed mentioned, in mph (e.g. "10 to 20 mph" -> 20).
    var maxWindMph: Int {
        guard let windSpeed else { return 0 }
        return windSpeed
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
            .max() ?? 0
    }
}

// MARK: - App-level model

/// Everything the UI needs for one location.
struct WeatherReport {
    let city: String
    let state: String
    let timeZone: TimeZone
    /// Hourly periods starting with the current hour.
    let hourly: [ForecastPeriod]
    /// NWS 12-hour periods ("Today", "Tonight", "Monday", ...).
    let daily: [ForecastPeriod]

    var locationName: String { "\(city), \(state)" }
}
