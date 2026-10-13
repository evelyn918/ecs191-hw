import Foundation

/// A single "wear" or "bring" suggestion.
struct AdviceItem: Identifiable, Hashable {
    let symbol: String
    let title: String
    let detail: String

    var id: String { title }
}

struct OutfitAdvice {
    let wear: [AdviceItem]
    let bring: [AdviceItem]
}

/// DressCast's signature feature: turns the next 12 hours of forecast into
/// what to wear and what to bring.
enum OutfitAdvisor {
    static func advice(for hours: [ForecastPeriod], timeZone: TimeZone) -> OutfitAdvice {
        guard let first = hours.first else { return OutfitAdvice(wear: [], bring: []) }

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "h a"
        func time(_ period: ForecastPeriod) -> String { formatter.string(from: period.startTime) }

        let warmest = hours.max(by: { $0.temperature < $1.temperature })!
        let coolest = hours.min(by: { $0.temperature < $1.temperature })!
        let daytime = hours.filter(\.isDaytime)
        // Dress for the hours you're likely out: daytime if any remain, otherwise the average.
        let baseTemp = daytime.map(\.temperature).max()
            ?? hours.map(\.temperature).reduce(0, +) / hours.count

        var wear: [AdviceItem] = []
        var bring: [AdviceItem] = []

        // Base outfit.
        switch baseTemp {
        case 75...:
            wear.append(AdviceItem(symbol: "figure.walk", title: "Shorts & T-shirt", detail: "Warm, up to \(warmest.temperature)°"))
        case 65..<75:
            wear.append(AdviceItem(symbol: "tshirt.fill", title: "T-shirt & pants", detail: "Mild, around \(baseTemp)°"))
        case 55..<65:
            wear.append(AdviceItem(symbol: "jacket.fill", title: "Light jacket", detail: "Cool, around \(baseTemp)°"))
        case 40..<55:
            wear.append(AdviceItem(symbol: "coat.fill", title: "Jacket", detail: "Chilly, around \(baseTemp)°"))
        default:
            wear.append(AdviceItem(symbol: "coat.fill", title: "Heavy coat", detail: "Cold, around \(baseTemp)°"))
            wear.append(AdviceItem(symbol: "hand.raised.fill", title: "Hat & gloves", detail: "Low of \(coolest.temperature)°"))
        }

        // Temperature swings: an extra layer if it gets cooler later, layers if it warms up.
        let swing = warmest.temperature - coolest.temperature
        if coolest.startTime > warmest.startTime, swing >= 12 || (baseTemp >= 65 && coolest.temperature < 60) {
            wear.append(AdviceItem(symbol: "jacket.fill", title: "Extra layer", detail: "Cools to \(coolest.temperature)° by \(time(coolest))"))
        } else if coolest.startTime < warmest.startTime, swing >= 15 {
            wear.append(AdviceItem(symbol: "square.stack.3d.up.fill", title: "Dress in layers", detail: "\(first.temperature)° now, \(warmest.temperature)° by \(time(warmest))"))
        }

        // Wind.
        if let windy = hours.first(where: { $0.maxWindMph >= 20 }) {
            wear.append(AdviceItem(symbol: "wind", title: "Windbreaker", detail: "Winds up to \(windy.maxWindMph) mph"))
        }

        // Precipitation.
        let snowy = hours.first { mentions($0, ["snow", "sleet", "flurries", "ice"]) && $0.precipChance >= 30 }
        // Snow-only hours call for boots, not an umbrella.
        let rainy = hours.filter { !mentions($0, ["snow", "flurries"]) || mentions($0, ["rain"]) }
        let wet = rainy.first { $0.precipChance >= 40 || (mentions($0, ["rain", "showers", "thunder", "drizzle"]) && $0.precipChance >= 30) }
        let maybeWet = rainy.first { $0.precipChance >= 20 }
        if let snowy {
            wear.append(AdviceItem(symbol: "shoe.fill", title: "Waterproof boots", detail: "Snow around \(time(snowy))"))
        }
        if wet != nil {
            let peak = rainy.max(by: { $0.precipChance < $1.precipChance })!
            bring.append(AdviceItem(symbol: "umbrella.fill", title: "Umbrella", detail: "\(peak.precipChance)% rain chance at \(time(peak))"))
        } else if let maybeWet {
            bring.append(AdviceItem(symbol: "umbrella", title: "Compact umbrella", detail: "\(maybeWet.precipChance)% chance at \(time(maybeWet))"))
        }

        // Sun and heat (NWS has no UV index, so use sunny daytime hours + temperature).
        let sunnyWarm = daytime.first { mentions($0, ["sunny", "clear"]) && !mentions($0, ["partly sunny"]) && $0.temperature >= 65 }
        let hot = daytime.first { $0.temperature >= 80 }
        if let sun = hot ?? sunnyWarm {
            bring.append(AdviceItem(symbol: "sun.max.fill", title: "Sunscreen", detail: "\(sun.shortForecast), \(sun.temperature)° at \(time(sun))"))
        }
        if sunnyWarm != nil {
            bring.append(AdviceItem(symbol: "sunglasses.fill", title: "Sunglasses", detail: "Bright skies today"))
        }
        if warmest.temperature >= 80 {
            bring.append(AdviceItem(symbol: "waterbottle.fill", title: "Water bottle", detail: "Up to \(warmest.temperature)° at \(time(warmest))"))
        }

        if bring.isEmpty {
            bring.append(AdviceItem(symbol: "checkmark.circle.fill", title: "Nothing extra", detail: "Travel light today"))
        }
        return OutfitAdvice(wear: wear, bring: bring)
    }

    private static func mentions(_ period: ForecastPeriod, _ words: [String]) -> Bool {
        let text = period.shortForecast.lowercased()
        return words.contains { text.contains($0) }
    }
}
