import Foundation

/// One "wear" or "bring" suggestion, with a reason taken from the forecast.
struct Suggestion: Identifiable, Hashable {
    let symbol: String
    let title: String
    let reason: String

    var id: String { title }
}

/// Everything the advice card shows.
struct Advice {
    /// One line, e.g. "Light jacket and umbrella today."
    let verdict: String
    let wear: [Suggestion]
    let bring: [Suggestion]
}

/// DressCast's signature feature: turns the forecast for the hours you're out
/// into what to wear and what to bring.
enum Advisor {
    /// - Parameters:
    ///   - hourly: every hourly period in the report (the window picks the ones that matter)
    ///   - day: the day being planned (today, tomorrow, or a day tapped in the 7-day list)
    ///   - window: when the user leaves and returns
    ///   - settings: choices from the Personal Setup screen
    ///   - activity: Class/Work, Outdoors, or Evening out
    static func advice(hourly: [ForecastPeriod],
                       day: Date,
                       window: TimeWindow,
                       settings: UserSettings,
                       activity: Activity,
                       timeZone: TimeZone) -> Advice {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = .current  // full weekday names like "Wednesday"

        let hours = window.hours(from: hourly, on: day, calendar: calendar)
        guard let first = hours.first, let last = hours.last else {
            return Advice(verdict: "No forecast for these hours.", wear: [], bring: [])
        }

        // MARK: Which hours and limits matter

        // In class or at work you're inside, so only the trips there and back count.
        // For the other activities you're out the whole time.
        let outside = activity == .classWork ? [first, last] : hours

        // Being outdoors, walking, or biking makes rain and wind matter more.
        let exposed = activity == .outdoors || settings.commute.isExposed
        let rainLimit = exposed ? 30 : 50   // % chance of rain worth an umbrella
        let windLimit = exposed ? 15 : 25   // mph worth a windbreaker

        // Sun and heat matter more when you're outdoors all day.
        let sunLimit = activity == .outdoors ? 60 : 70   // ° for sunscreen
        let hotLimit = activity == .outdoors ? 75 : 80   // ° for a sun hat and water

        let coldest = outside.min { $0.temperature < $1.temperature }!
        let warmest = outside.max { $0.temperature < $1.temperature }!
        // How cold the coldest hour feels to this person (cold runners feel it 5° colder).
        let feelsLike = coldest.temperature + settings.comfort.offset
        let sunnyHours = outside.filter { $0.isDaytime && isSunny($0) }
        let sunniest = sunnyHours.max { $0.temperature < $1.temperature }

        // "3 PM"
        func time(_ period: ForecastPeriod) -> String {
            TimeWindow.hourName(calendar.component(.hour, from: period.startTime))
        }
        // " on your way out" / " on your way home" when only the commute counts.
        func trip(_ period: ForecastPeriod) -> String {
            guard activity == .classWork, first != last else { return "" }
            return period == first ? " on your way out" : " on your way home"
        }

        var coldReason = "\(coldest.temperature)° at \(time(coldest))\(trip(coldest))"
        if settings.comfort == .cold { coldReason += ", and you run cold" }

        // MARK: Wear

        var wear: [Suggestion] = []

        // Essential: a coat or jacket for the coldest hour you're outside.
        if feelsLike < 40 {
            wear.append(Suggestion(symbol: "thermometer.snowflake", title: "Warm coat", reason: coldReason))
        } else if feelsLike < 55 {
            wear.append(Suggestion(symbol: "thermometer.low", title: "Jacket", reason: coldReason))
        } else if feelsLike < 63 {
            wear.append(Suggestion(symbol: "thermometer.medium", title: "Light jacket", reason: coldReason))
        }

        // Personal: an extra layer when the temperature swings 15° or more.
        if settings.wantsReminder(for: .layer), warmest.temperature - coldest.temperature >= 15 {
            let reason: String
            if coldest.startTime < warmest.startTime {
                reason = "\(coldest.temperature)° at \(time(coldest)) but \(warmest.temperature)° by \(time(warmest)), so wear layers you can take off"
            } else {
                reason = "\(warmest.temperature)° at \(time(warmest)) but \(coldest.temperature)° by \(time(coldest)), so bring a layer for later"
            }
            wear.append(Suggestion(symbol: "square.stack.3d.up.fill", title: "Extra layer", reason: reason))
        }

        // Essential: a windbreaker for the windiest hour you're outside.
        if let windiest = outside.max(by: { $0.maxWindMph < $1.maxWindMph }), windiest.maxWindMph >= windLimit {
            var reason = "Winds up to \(windiest.maxWindMph) mph at \(time(windiest))\(trip(windiest))"
            if settings.commute == .bike { reason += ", tough on a bike" }
            wear.append(Suggestion(symbol: "wind", title: "Windbreaker", reason: reason))
        }

        // Essential: boots when snow is likely.
        if let snowy = outside.first(where: { isSnow($0) && $0.precipChance >= 30 }) {
            wear.append(Suggestion(symbol: "shoe.fill", title: "Waterproof boots",
                                   reason: "\(snowy.shortForecast) at \(time(snowy))\(trip(snowy))"))
        }

        // Personal: a warm hat when it's cold, or a sun hat when it's sunny and hot.
        if settings.wantsReminder(for: .hat) {
            if feelsLike < 40 {
                wear.append(Suggestion(symbol: "snowflake", title: "Warm hat", reason: coldReason))
            } else if let sun = sunniest, sun.temperature >= hotLimit {
                wear.append(Suggestion(symbol: "sun.horizon.fill", title: "Sun hat",
                                       reason: "\(sun.shortForecast) and \(sun.temperature)° at \(time(sun))\(trip(sun))"))
            }
        }

        // MARK: Bring

        var bring: [Suggestion] = []

        // Essential: an umbrella for the rainiest hour you're outside (snow gets boots instead).
        let rainyHours = outside.filter { !isSnow($0) }
        if let wettest = rainyHours.max(by: { $0.precipChance < $1.precipChance }), wettest.precipChance >= rainLimit {
            bring.append(Suggestion(symbol: "umbrella.fill", title: "Umbrella",
                                    reason: "\(wettest.precipChance)% chance of rain at \(time(wettest))\(trip(wettest))"))
        }

        // Personal: sunscreen and sunglasses. NWS has no UV index, so use sunny daytime hours.
        if settings.wantsReminder(for: .sunscreen), let sun = sunniest, sun.temperature >= sunLimit {
            bring.append(Suggestion(symbol: "sun.max.fill", title: "Sunscreen",
                                    reason: "\(sun.shortForecast) and \(sun.temperature)° at \(time(sun))\(trip(sun))"))
        }
        if settings.wantsReminder(for: .sunglasses), let sun = sunnyHours.first {
            bring.append(Suggestion(symbol: "sunglasses.fill", title: "Sunglasses",
                                    reason: "\(sun.shortForecast) at \(time(sun))\(trip(sun))"))
        }

        // Personal: water when it gets hot.
        if settings.wantsReminder(for: .water), warmest.temperature >= hotLimit {
            bring.append(Suggestion(symbol: "waterbottle.fill", title: "Water bottle",
                                    reason: "Up to \(warmest.temperature)° at \(time(warmest)), so stay hydrated"))
        }

        // MARK: Verdict

        // `hours` came from `hourly`, so `hourly[0]` exists and is the current hour.
        let when = dayWord(for: day, today: hourly[0].startTime, calendar: calendar)
        let titles = (wear + bring).map(\.title)
        let verdict: String
        if titles.isEmpty {
            verdict = "Nothing special \(when)."
        } else {
            // "Jacket, umbrella, and sunscreen today." Only the first word stays capitalized.
            let names = [titles[0]] + titles.dropFirst().map { $0.lowercased() }
            verdict = "\(ListFormatter.localizedString(byJoining: names)) \(when)."
        }

        return Advice(verdict: verdict, wear: wear, bring: bring)
    }

    // MARK: Helpers

    /// "today", "tomorrow", or "on Wednesday".
    private static func dayWord(for day: Date, today: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: today) { return "today" }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        if calendar.isDate(day, inSameDayAs: tomorrow) { return "tomorrow" }
        return "on " + calendar.weekdaySymbols[calendar.component(.weekday, from: day) - 1]
    }

    private static func mentions(_ period: ForecastPeriod, _ words: [String]) -> Bool {
        let text = period.shortForecast.lowercased()
        return words.contains { text.contains($0) }
    }

    /// Snow without rain ("Light Snow", "Flurries"). A rain/snow mix still gets an umbrella.
    private static func isSnow(_ period: ForecastPeriod) -> Bool {
        mentions(period, ["snow", "flurries", "sleet"]) && !mentions(period, ["rain"])
    }

    /// "Sunny", "Mostly Sunny", "Clear", but not "Partly Sunny".
    private static func isSunny(_ period: ForecastPeriod) -> Bool {
        mentions(period, ["sunny", "clear"]) && !mentions(period, ["partly sunny"])
    }
}
