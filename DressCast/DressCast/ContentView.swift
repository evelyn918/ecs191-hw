import SwiftUI

/// The sheets the main screen can show, one at a time.
enum MainSheet: String, Identifiable {
    case search, setup, window
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var model = WeatherViewModel()
    @State private var showingWeek = false
    @State private var sheet: MainSheet?

    /// Personal Setup choices, loaded once and saved whenever they change.
    @State private var settings = UserSettings.load()
    /// False until Personal Setup has been shown once.
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    /// The time window the user picked. nil means "use the default" (see TimeWindow.suggested).
    @State private var window: TimeWindow?
    /// The last activity picked, remembered between launches.
    @AppStorage("activity") private var activity: Activity = .classWork

    var body: some View {
        // The NavigationStack lets 7-day rows push DayDetailView, which gets a back button.
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                switch model.state {
                case .loading:
                    ProgressView("Getting the forecast…")
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await model.refresh() }
                    }
                case .loaded(let report):
                    let summary = ForecastSummary(report: report)
                    WeatherScreen(summary: summary,
                                  notice: model.notice,
                                  settings: settings,
                                  window: resolvedWindow(summary),
                                  activity: $activity,
                                  showingWeek: $showingWeek,
                                  sheet: $sheet)
                        .refreshable { await model.refresh() }
                        .navigationDestination(for: DayForecast.self) { day in
                            DayDetailView(day: day, summary: summary, settings: settings,
                                          window: resolvedWindow(summary), activity: activity)
                        }
                }
            }
            .foregroundStyle(.white)
            // The main screen draws its own top bar, so hide the navigation bar here.
            .toolbar(.hidden, for: .navigationBar)
        }
        // White buttons, menus, spinner, and back button.
        .tint(.white)
        .task { await model.loadCurrentLocation() }
        .onAppear {
            // Show Personal Setup on first launch only.
            if !hasCompletedSetup {
                sheet = .setup
                hasCompletedSetup = true
            }
        }
        .onChange(of: settings) { settings.save() }
        // Sheets come after .tint so their forms keep normal colors.
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .search:
                SearchSheet { query in
                    showingWeek = false
                    Task { await model.search(query) }
                }
                .presentationDetents([.medium])
            case .setup:
                SetupView(settings: $settings)
            case .window:
                // The chip that opens this sheet only exists once the forecast has loaded.
                if case .loaded(let report) = model.state {
                    WindowSheet(window: resolvedWindow(ForecastSummary(report: report))) { window = $0 }
                }
            }
        }
    }

    /// The user's window, or the default: now until 10 PM (tomorrow 8 AM to 5 PM after 8 PM).
    private func resolvedWindow(_ summary: ForecastSummary) -> TimeWindow {
        window ?? TimeWindow.suggested(now: summary.current.startTime, calendar: summary.calendar)
    }

    private var background: LinearGradient {
        if case .loaded(let report) = model.state, let now = report.hourly.first {
            return WeatherStyle.background(for: now.shortForecast, isDaytime: now.isDaytime)
        }
        return WeatherStyle.background(for: "", isDaytime: true)
    }
}

/// The main screen. From top to bottom: location bar, time and activity chips,
/// the DressCast advice (the hero), current conditions, then hours / 7 days.
private struct WeatherScreen: View {
    let summary: ForecastSummary
    let notice: String?
    let settings: UserSettings
    let window: TimeWindow
    @Binding var activity: Activity
    @Binding var showingWeek: Bool
    @Binding var sheet: MainSheet?

    var body: some View {
        let day = summary.plannedDay(for: window)
        let hours = window.hours(from: summary.report.hourly, on: day, calendar: summary.calendar)
        let advice = Advisor.advice(hourly: summary.report.hourly, day: day, window: window,
                                    settings: settings, activity: activity,
                                    timeZone: summary.report.timeZone)

        ScrollView {
            VStack(spacing: 14) {
                topBar
                if let notice {
                    Label(notice, systemImage: "location.slash")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.2), in: Capsule())
                }
                planChips
                AdviceCard(advice: advice)
                currentConditions
                ForecastCard(summary: summary, hours: hours, hoursTitle: window.label,
                             showingWeek: $showingWeek)
                Text("Forecast data: National Weather Service")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    /// Gear (Personal Setup) on the left, city in the middle, search on the right.
    private var topBar: some View {
        HStack {
            Button { sheet = .setup } label: {
                Image(systemName: "gearshape")
                    .font(.title3.weight(.semibold))
                    .padding(8)
            }
            .accessibilityLabel("Personal setup")
            Spacer()
            Button { sheet = .search } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .padding(8)
            }
            .accessibilityLabel("Change location")
        }
        .overlay {
            Text(summary.report.city)
                .font(.title2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 44)
        }
    }

    /// The time-window chip and the activity menu: side by side if they fit, stacked if not.
    private var planChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { windowChip; activityMenu }
            VStack(alignment: .leading, spacing: 8) { windowChip; activityMenu }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var windowChip: some View {
        Button { sheet = .window } label: {
            chip(window.label, symbol: "clock")
        }
        .accessibilityHint("Choose when you leave and come back")
    }

    private var activityMenu: some View {
        Menu {
            Picker("Activity", selection: $activity) {
                ForEach(Activity.allCases) { activity in
                    Label(activity.label, systemImage: activity.symbol).tag(activity)
                }
            }
        } label: {
            chip(activity.label, symbol: activity.symbol)
        }
        .accessibilityHint("Choose what you're doing")
    }

    /// A rounded, tappable label with a small down arrow.
    private func chip(_ text: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Label(text, systemImage: symbol)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white.opacity(0.2), in: Capsule())
    }

    /// Current temperature and condition, smaller than before so the advice leads.
    private var currentConditions: some View {
        HStack(spacing: 14) {
            Text("\(summary.current.temperature)°")
                .font(.system(size: 52, weight: .thin))
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.current.shortForecast)
                    .font(.headline)
                Text("H:\(summary.todayHigh)°  L:\(summary.todayLow)°")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 44))
            Text(message)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
        }
        .padding(32)
    }
}

/// Lets the user type a US city or ZIP, or go back to their current location.
private struct SearchSheet: View {
    let onSubmit: (String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("City, state or ZIP (e.g. Sacramento, CA)", text: $query)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .onSubmit(submit)
                } footer: {
                    Text("Forecasts come from the US National Weather Service. If a place can't be found, DressCast shows Davis, CA.")
                }
                Section {
                    Button {
                        query = ""
                        submit()
                    } label: {
                        Label("Use My Current Location", systemImage: "location.fill")
                    }
                }
            }
            .navigationTitle("Change Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search", action: submit)
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func submit() {
        onSubmit(query)
        dismiss()
    }
}

#Preview {
    ContentView()
}
