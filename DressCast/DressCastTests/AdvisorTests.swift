import Foundation
import Testing
@testable import DressCast

/// Tests for Advisor using small, made-up forecasts (no network).
struct AdvisorTests {
    let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    /// Midnight at the start of the test day (Oct 20, 2026, Davis time).
    var midnight: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!
    }

    /// One fake NWS hour. Defaults are a calm, mild, cloudy hour.
    func hour(_ hour: Int, temp: Int = 68, forecast: String = "Cloudy",
              rain: Int = 0, daytime: Bool = true) -> ForecastPeriod {
        let start = midnight.addingTimeInterval(Double(hour) * 3600)
        return ForecastPeriod(number: hour, name: "", startTime: start,
                              endTime: start.addingTimeInterval(3600), isDaytime: daytime,
                              temperature: temp, temperatureUnit: "F",
                              probabilityOfPrecipitation: .init(value: Double(rain)),
                              windSpeed: "5 mph", shortForecast: forecast)
    }

    /// Hours from 6 AM to 11 PM, all mild unless `change` edits one.
    func day(_ change: (Int) -> ForecastPeriod? = { _ in nil }) -> [ForecastPeriod] {
        (6...23).map { change($0) ?? hour($0) }
    }

    let window = TimeWindow(leaveHour: 8, returnHour: 17, isTomorrow: false)

    func advise(_ hourly: [ForecastPeriod], settings: UserSettings = UserSettings(),
                activity: Activity = .outdoors) -> Advice {
        Advisor.advice(hourly: hourly, day: midnight, window: window,
                       settings: settings, activity: activity, timeZone: timeZone)
    }

    func titles(_ advice: Advice) -> [String] {
        (advice.wear + advice.bring).map(\.title)
    }

    /// Hot and sunny all day: sunscreen is useful.
    var sunnyDay: [ForecastPeriod] {
        day { hour($0, temp: 85, forecast: "Sunny") }
    }

    @Test func remindedItemIsSuggested() {
        // Baseline so the next two tests mean something.
        #expect(titles(advise(sunnyDay)).contains("Sunscreen"))
    }

    @Test func alwaysBringItemIsNeverSuggested() {
        var settings = UserSettings()
        settings.items[.sunscreen] = .always
        #expect(!titles(advise(sunnyDay, settings: settings)).contains("Sunscreen"))
    }

    @Test func neverItemIsNeverSuggested() {
        var settings = UserSettings()
        settings.items[.sunscreen] = .never
        #expect(!titles(advise(sunnyDay, settings: settings)).contains("Sunscreen"))
    }

    @Test func coldRunnerGetsWarmerAdviceThanWarmRunner() {
        let chilly = day { hour($0, temp: 58) }
        var cold = UserSettings()
        cold.comfort = .cold
        var warm = UserSettings()
        warm.comfort = .warm

        // 0 = nothing, 1 = light jacket, 2 = jacket, 3 = warm coat.
        func warmth(_ advice: Advice) -> Int {
            let ranks = ["Light jacket": 1, "Jacket": 2, "Warm coat": 3]
            return titles(advice).compactMap { ranks[$0] }.max() ?? 0
        }
        #expect(warmth(advise(chilly, settings: cold)) > warmth(advise(chilly, settings: warm)))
    }

    @Test func rainInsideWindowIsSuggested() {
        let rainAt3PM = day { $0 == 15 ? hour(15, forecast: "Rain Showers", rain: 80) : nil }
        #expect(titles(advise(rainAt3PM)).contains("Umbrella"))
    }

    @Test func rainOutsideWindowIsNotSuggested() {
        let rainAt9PM = day { $0 == 21 ? hour(21, forecast: "Rain Showers", rain: 80, daytime: false) : nil }
        #expect(!titles(advise(rainAt9PM)).contains("Umbrella"))
    }
}
