import Foundation

/// One row of the 7-day view.
struct DayForecast: Identifiable {
    let id: Int
    let name: String
    let high: Int?
    let low: Int?
    let shortForecast: String
    let isDaytime: Bool
    let precipChance: Int
}

/// Turns a raw `WeatherReport` into the numbers shown on the main screen.
struct ForecastSummary {
    let report: WeatherReport

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = report.timeZone
        return calendar
    }

    var current: ForecastPeriod { report.hourly[0] }

    /// Remaining hours of today. Late at night (fewer than 6 left) this rolls
    /// over to the next 12 hours so the grid is never nearly empty.
    var dayHours: [ForecastPeriod] {
        isLateNight ? next12Hours : hoursLeftToday
    }

    var dayHoursTitle: String {
        isLateNight ? "Next 12 Hours" : "Rest of Today"
    }

    private var hoursLeftToday: [ForecastPeriod] {
        report.hourly.filter { calendar.isDate($0.startTime, inSameDayAs: current.startTime) }
    }

    private var isLateNight: Bool { hoursLeftToday.count < 6 }

    /// The 12 hours the outfit advice is based on.
    var next12Hours: [ForecastPeriod] { Array(report.hourly.prefix(12)) }

    var todayHigh: Int {
        let first = report.daily[0]
        let hourlyMax = dayHours.map(\.temperature).max() ?? current.temperature
        // Once NWS's first period is "Tonight", today's daytime high has passed,
        // so fall back to the warmest remaining hour.
        let high = first.isDaytime ? first.temperature : hourlyMax
        return max(high, current.temperature)
    }

    var todayLow: Int {
        let night = report.daily.first(where: { !$0.isDaytime })
        let low = night?.temperature ?? (dayHours.map(\.temperature).min() ?? current.temperature)
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
