import Foundation

// MARK: - Choices made on the Personal Setup screen

/// Items the user can opt in to or out of. Weather-driven essentials
/// (umbrella, coats, boots, windbreaker) are not listed here: they're always on.
enum PersonalItem: String, CaseIterable, Identifiable, Codable {
    case layer, sunscreen, sunglasses, water, hat

    var id: String { rawValue }

    var name: String {
        switch self {
        case .layer: return "Extra layer"
        case .sunscreen: return "Sunscreen"
        case .sunglasses: return "Sunglasses"
        case .water: return "Water bottle"
        case .hat: return "Hat"
        }
    }
}

/// How the user wants DressCast to treat one personal item.
enum ItemPreference: String, CaseIterable, Identifiable, Codable {
    case remind   // suggest it when the forecast makes it useful
    case always   // the user always carries it, so never suggest it
    case never    // the user never wants it, so never suggest it

    var id: String { rawValue }

    var label: String {
        switch self {
        case .remind: return "Remind me"
        case .always: return "I always bring it"
        case .never: return "Never"
        }
    }
}

/// "Do you run cold, normal, or warm?"
enum Comfort: String, CaseIterable, Identifiable, Codable {
    case cold, normal, warm

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Added to the real temperature to get how warm it feels to this person.
    /// A cold runner feels 5° colder, so they get a jacket sooner.
    var offset: Int {
        switch self {
        case .cold: return -5
        case .normal: return 0
        case .warm: return 5
        }
    }
}

/// How the user gets around.
enum Commute: String, CaseIterable, Identifiable, Codable {
    case walk, bike, bus, drive

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Walking and biking leave you out in the rain and wind.
    var isExposed: Bool { self == .walk || self == .bike }
}

/// What the user is doing today. Chosen on the main screen, not in setup.
enum Activity: String, CaseIterable, Identifiable {
    case classWork, outdoors, evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classWork: return "Class/Work"
        case .outdoors: return "Outdoors"
        case .evening: return "Evening out"
        }
    }

    var symbol: String {
        switch self {
        case .classWork: return "graduationcap.fill"
        case .outdoors: return "figure.hiking"
        case .evening: return "moon.stars.fill"
        }
    }
}

// MARK: - Saved settings

/// Everything from the Personal Setup screen, saved to UserDefaults as JSON.
struct UserSettings: Codable, Equatable {
    /// Items missing from this dictionary use the default, `.remind`.
    var items: [PersonalItem: ItemPreference] = [:]
    var comfort: Comfort = .normal
    var commute: Commute = .walk

    func preference(for item: PersonalItem) -> ItemPreference {
        items[item] ?? .remind
    }

    /// True only when the user asked to be reminded about this item.
    func wantsReminder(for item: PersonalItem) -> Bool {
        preference(for: item) == .remind
    }

    private static let key = "userSettings"

    /// Reads saved settings, or returns the defaults if nothing is saved yet.
    static func load() -> UserSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// MARK: - Time window

/// The hours the user is out, e.g. 8 AM to 5 PM, today or tomorrow.
struct TimeWindow: Equatable {
    var leaveHour: Int    // 0–23
    var returnHour: Int   // 1–24 (24 means midnight)
    var isTomorrow: Bool  // which day the main screen plans for

    /// Default: now until 10 PM. After 8 PM, plan for tomorrow 8 AM to 5 PM instead.
    static func suggested(now: Date, calendar: Calendar) -> TimeWindow {
        let hour = calendar.component(.hour, from: now)
        if hour >= 20 {
            return TimeWindow(leaveHour: 8, returnHour: 17, isTomorrow: true)
        }
        return TimeWindow(leaveHour: hour, returnHour: 22, isTomorrow: false)
    }

    /// The forecast hours on `day` that start after leaving and before returning.
    func hours(from hourly: [ForecastPeriod], on day: Date, calendar: Calendar) -> [ForecastPeriod] {
        hourly.filter { period in
            let hour = calendar.component(.hour, from: period.startTime)
            return calendar.isDate(period.startTime, inSameDayAs: day)
                && hour >= leaveHour && hour < returnHour
        }
    }

    /// "Out 8 AM to 5 PM", or "Tomorrow, out 8 AM to 5 PM".
    var label: String {
        isTomorrow ? "Tomorrow, out \(times)" : "Out \(times)"
    }

    /// "8 AM to 5 PM"
    var times: String {
        "\(Self.hourName(leaveHour)) to \(Self.hourName(returnHour))"
    }

    /// 0 -> "12 AM", 9 -> "9 AM", 12 -> "12 PM", 17 -> "5 PM", 24 -> "12 AM".
    static func hourName(_ hour: Int) -> String {
        switch hour {
        case 0, 24: return "12 AM"
        case 12: return "12 PM"
        case 13...: return "\(hour - 12) PM"
        default: return "\(hour) AM"
        }
    }
}
