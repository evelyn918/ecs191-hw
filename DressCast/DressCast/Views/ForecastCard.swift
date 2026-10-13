import SwiftUI

/// The hourly grid for the rest of today. Tapping flips it to the 7-day forecast and back.
struct ForecastCard: View {
    let summary: ForecastSummary
    @Binding var showingWeek: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: showingWeek ? "7-Day Forecast" : summary.dayHoursTitle,
                             symbol: showingWeek ? "calendar" : "clock")
                Spacer()
                Text(showingWeek ? "Tap for hourly" : "Tap for 7-day")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Divider().overlay(.white.opacity(0.3))
            if showingWeek {
                WeekList(days: summary.week)
            } else {
                HourGrid(summary: summary)
            }
        }
        .card()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) { showingWeek.toggle() }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(showingWeek ? "Shows today's hours" : "Shows the next 7 days")
    }
}

/// Every remaining hour of the day laid out in rows — no horizontal scrolling.
private struct HourGrid: View {
    let summary: ForecastSummary

    var body: some View {
        let hours = summary.dayHours
        // Up to 24 hours fits in 4 rows of 6; short days use bigger cells.
        let columnCount = hours.count > 12 ? 6 : 4
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount)

        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(hours) { hour in
                VStack(spacing: 4) {
                    Text(summary.hourLabel(for: hour))
                        .font(.caption.weight(.semibold))
                    Image(systemName: WeatherStyle.symbol(for: hour.shortForecast, isDaytime: hour.isDaytime))
                        .symbolRenderingMode(.multicolor)
                        .font(.title3)
                        .frame(height: 22)
                    Text("\(hour.temperature)°")
                        .font(.subheadline.weight(.medium))
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

private struct WeekList: View {
    let days: [DayForecast]

    var body: some View {
        let temps = days.flatMap { [$0.high, $0.low].compactMap { $0 } }
        let weekLow = temps.min() ?? 0
        let weekHigh = temps.max() ?? 100

        VStack(spacing: 6) {
            ForEach(days) { day in
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
                }
                .font(.body)
                .accessibilityElement(children: .combine)
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
