import Foundation

/// One row of the 7-day view.
struct DayForecast: Identifiable, Hashable {
    let id: Int
    let name: String
    /// Any moment on this day (the start of its first NWS period).
    let date: Date
    let high: Int?
    let low: Int?
    let shortForecast: String
    let isDaytime: Bool
    let precipChance: Int
}

/// Turns a raw `WeatherReport` into the numbers shown on the main screen.
struct ForecastSummary {
    let report: WeatherReport

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = report.timeZone
        calendar.locale = .current  // full weekday names like "Wednesday"
        return calendar
    }

    var current: ForecastPeriod { report.hourly[0] }

    private var hoursLeftToday: [ForecastPeriod] {
        report.hourly.filter { calendar.isDate($0.startTime, inSameDayAs: current.startTime) }
    }

    /// The day the main screen plans for: today, or tomorrow if the window says so.
    func plannedDay(for window: TimeWindow) -> Date {
        window.isTomorrow
            ? calendar.date(byAdding: .day, value: 1, to: current.startTime)!
            : current.startTime
    }

    var todayHigh: Int {
        let first = report.daily[0]
        let hourlyMax = hoursLeftToday.map(\.temperature).max() ?? current.temperature
        // Once NWS's first period is "Tonight", today's daytime high has passed,
        // so fall back to the warmest remaining hour.
        let high = first.isDaytime ? first.temperature : hourlyMax
        return max(high, current.temperature)
    }

    var todayLow: Int {
        let night = report.daily.first(where: { !$0.isDaytime })
        let low = night?.temperature ?? (hoursLeftToday.map(\.temperature).min() ?? current.temperature)
        return min(low, current.temperature)
    }

    /// Pairs NWS's day/night periods into up to 7 days of highs and lows.
    var week: [DayForecast] {
        var days: [DayForecast] = []
        var periods = report.daily[...]

        while let period = periods.first, days.count < 7 {
            periods = periods.dropFirst()
            let isFirst = days.isEmpty
            if period.isDaytime {
                let night = periods.first.flatMap { $0.isDaytime ? nil : $0 }
                if night != nil { periods = periods.dropFirst() }
                days.append(DayForecast(
                    id: period.number,
                    name: isFirst ? "Today" : String(period.name.prefix(3)),
                    date: period.startTime,
                    high: isFirst ? todayHigh : period.temperature,
                    low: isFirst ? todayLow : night?.temperature,
                    shortForecast: period.shortForecast,
                    isDaytime: true,
                    precipChance: max(period.precipChance, night?.precipChance ?? 0)
                ))
            } else {
                // Report starts with "Tonight": today's row uses the remaining hours.
                days.append(DayForecast(
                    id: period.number,
                    name: "Today",
                    date: period.startTime,
                    high: todayHigh,
                    low: period.temperature,
                    shortForecast: period.shortForecast,
                    isDaytime: false,
                    precipChance: period.precipChance
                ))
            }
        }
        return days
    }

    func hourLabel(for period: ForecastPeriod) -> String {
        if period == current { return "Now" }
        let formatter = DateFormatter()
        formatter.timeZone = report.timeZone
        formatter.dateFormat = "ha"
        return formatter.string(from: period.startTime)
    }
}
