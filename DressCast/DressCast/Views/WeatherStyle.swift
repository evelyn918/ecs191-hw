import SwiftUI

/// Maps NWS's free-text forecasts ("Mostly Sunny", "Chance Rain Showers", ...) to visuals.
enum WeatherStyle {
    static func symbol(for forecast: String, isDaytime: Bool) -> String {
        let text = forecast.lowercased()
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        if has("thunder") { return "cloud.bolt.rain.fill" }
        if has("snow", "flurries", "blizzard") { return "cloud.snow.fill" }
        if has("sleet", "freezing", "ice") { return "cloud.sleet.fill" }
        if has("drizzle") { return "cloud.drizzle.fill" }
        if has("rain", "showers") { return "cloud.rain.fill" }
        if has("fog", "mist") { return "cloud.fog.fill" }
        if has("smoke", "haze", "dust") { return isDaytime ? "sun.haze.fill" : "moon.haze.fill" }
        if has("partly", "mostly sunny", "mostly clear") { return isDaytime ? "cloud.sun.fill" : "cloud.moon.fill" }
        if has("cloudy", "overcast") { return "cloud.fill" }
        if has("wind", "breezy", "blustery") { return "wind" }
        return isDaytime ? "sun.max.fill" : "moon.stars.fill"
    }

    static func background(for forecast: String, isDaytime: Bool) -> LinearGradient {
        let text = forecast.lowercased()
        let colors: [Color]
        if !isDaytime {
            colors = [Color(red: 0.06, green: 0.09, blue: 0.22), Color(red: 0.19, green: 0.22, blue: 0.40)]
        } else if ["rain", "showers", "thunder", "drizzle", "snow", "cloudy", "fog"].contains(where: text.contains)
                    && !text.contains("partly") {
            colors = [Color(red: 0.36, green: 0.43, blue: 0.53), Color(red: 0.55, green: 0.62, blue: 0.70)]
        } else {
            colors = [Color(red: 0.20, green: 0.48, blue: 0.85), Color(red: 0.47, green: 0.71, blue: 0.95)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

/// Translucent rounded card used for each section.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct SectionLabel: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text.uppercased(), systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
    }
}
