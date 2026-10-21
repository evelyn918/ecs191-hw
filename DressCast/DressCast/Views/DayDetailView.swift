import SwiftUI

/// Opened by tapping a day in the 7-day list. Shows that day's high and low,
/// its advice, and its hours, using the same settings, window, and activity
/// as the main screen. The navigation bar's back button returns to the main screen.
struct DayDetailView: View {
    let day: DayForecast
    let summary: ForecastSummary
    let settings: UserSettings
    let window: TimeWindow
    let activity: Activity

    var body: some View {
        let hours = window.hours(from: summary.report.hourly, on: day.date, calendar: summary.calendar)
        let advice = Advisor.advice(hourly: summary.report.hourly, day: day.date, window: window,
                                    settings: settings, activity: activity,
                                    timeZone: summary.report.timeZone)

        ZStack {
            WeatherStyle.background(for: day.shortForecast, isDaytime: true)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    AdviceCard(advice: advice)
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Out \(window.times)", symbol: "clock")
                        Divider().overlay(.white.opacity(0.3))
                        HourGrid(summary: summary, hours: hours)
                    }
                    .card()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .foregroundStyle(.white)
        .navigationTitle(dayName)
        .navigationBarTitleDisplayMode(.inline)
        // White title text over the dark background.
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(day.shortForecast)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
            Text("H:\(day.high.map { "\($0)°" } ?? "–")  L:\(day.low.map { "\($0)°" } ?? "–")")
                .font(.title.weight(.medium))
            Label(activity.label, systemImage: activity.symbol)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 8)
    }

    /// "Today", or the full weekday name like "Wednesday".
    private var dayName: String {
        if day.name == "Today" { return "Today" }
        let calendar = summary.calendar
        return calendar.weekdaySymbols[calendar.component(.weekday, from: day.date) - 1]
    }
}
