import SwiftUI

/// The hourly grid for the user's time window, or the 7-day forecast.
/// The small button in the header switches between them.
struct ForecastCard: View {
    let summary: ForecastSummary
    /// The hours inside the user's time window.
    let hours: [ForecastPeriod]
    /// Shown above the grid, e.g. "Out 8 AM to 5 PM".
    let hoursTitle: String
    @Binding var showingWeek: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: showingWeek ? "7-Day Forecast" : hoursTitle,
                             symbol: showingWeek ? "calendar" : "clock")
                Spacer()
                Button(showingWeek ? "Hourly" : "7-Day") {
                    withAnimation(.easeInOut(duration: 0.25)) { showingWeek.toggle() }
                }
                .font(.caption.weight(.semibold))
                .accessibilityHint(showingWeek ? "Shows your hours" : "Shows the next 7 days")
            }
            Divider().overlay(.white.opacity(0.3))
            if showingWeek {
                WeekList(days: summary.week)
            } else {
                HourGrid(summary: summary, hours: hours)
            }
        }
        .card()
    }
}

/// A compact grid of hours laid out in rows: no horizontal scrolling.
/// Also used by the day detail screen.
struct HourGrid: View {
    let summary: ForecastSummary
    let hours: [ForecastPeriod]

    var body: some View {
        if hours.isEmpty {
            Text("No forecast for these hours.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        } else {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(hours) { hour in
                    VStack(spacing: 3) {
                        Text(summary.hourLabel(for: hour))
                            .font(.caption2.weight(.semibold))
                        Image(systemName: WeatherStyle.symbol(for: hour.shortForecast, isDaytime: hour.isDaytime))
                            .symbolRenderingMode(.multicolor)
                            .font(.body)
                            .frame(height: 18)
                        Text("\(hour.temperature)°")
                            .font(.caption.weight(.medium))
                        Text(hour.precipChance >= 20 ? "\(hour.precipChance)%" : " ")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.6, green: 0.85, blue: 1))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct WeekList: View {
    let days: [DayForecast]

    var body: some View {
        let temps = days.flatMap { [$0.high, $0.low].compactMap { $0 } }
        let weekLow = temps.min() ?? 0
        let weekHigh = temps.max() ?? 100

        VStack(spacing: 6) {
            ForEach(days) { day in
                // Tapping a row opens DayDetailView (see navigationDestination in ContentView).
                NavigationLink(value: day) {
                    HStack(spacing: 10) {
                        Text(day.name)
                            .font(.body.weight(.semibold))
                            .frame(width: 56, alignment: .leading)
                        VStack(spacing: 0) {
                            Image(systemName: WeatherStyle.symbol(for: day.shortForecast, isDaytime: day.isDaytime))
                                .symbolRenderingMode(.multicolor)
                                .font(.title3)
                            if day.precipChance >= 20 {
                                Text("\(day.precipChance)%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.6, green: 0.85, blue: 1))
                            }
                        }
                        .frame(width: 34, height: 36)
                        Text(day.low.map { "\($0)°" } ?? "–")
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 38, alignment: .trailing)
                        TemperatureBar(low: day.low ?? day.high ?? weekLow, high: day.high ?? weekHigh,
                                       weekLow: weekLow, weekHigh: weekHigh)
                        Text(day.high.map { "\($0)°" } ?? "–")
                            .frame(width: 38, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .font(.body)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Shows this day's details")
                if day.id != days.last?.id {
                    Divider().overlay(.white.opacity(0.2))
                }
            }
        }
    }
}

/// Apple-Weather-style bar showing where a day's range sits within the week's range.
private struct TemperatureBar: View {
    let low: Int
    let high: Int
    let weekLow: Int
    let weekHigh: Int

    var body: some View {
        GeometryReader { geo in
            let span = max(Double(weekHigh - weekLow), 1)
            let start = Double(low - weekLow) / span * geo.size.width
            let end = Double(high - weekLow) / span * geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(end - start, 6))
                    .offset(x: start)
            }
        }
        .frame(height: 5)
    }
}
