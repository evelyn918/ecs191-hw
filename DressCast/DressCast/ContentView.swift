import SwiftUI

struct ContentView: View {
    @State private var model = WeatherViewModel()
    @State private var showingWeek = false
    @State private var showingSearch = false

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            switch model.state {
            case .loading:
                ProgressView("Getting the forecast…")
                    .tint(.white)
            case .failed(let message):
                ErrorView(message: message) {
                    Task { await model.refresh() }
                }
            case .loaded(let report):
                WeatherScreen(summary: ForecastSummary(report: report),
                              notice: model.notice,
                              showingWeek: $showingWeek,
                              onSearch: { showingSearch = true })
                    .refreshable { await model.refresh() }
            }
        }
        .foregroundStyle(.white)
        .task { await model.loadCurrentLocation() }
        .sheet(isPresented: $showingSearch) {
            SearchSheet { query in
                showingWeek = false
                Task { await model.search(query) }
            }
            .presentationDetents([.medium])
        }
    }

    private var background: LinearGradient {
        if case .loaded(let report) = model.state, let now = report.hourly.first {
            return WeatherStyle.background(for: now.shortForecast, isDaytime: now.isDaytime)
        }
        return WeatherStyle.background(for: "", isDaytime: true)
    }
}

private struct WeatherScreen: View {
    let summary: ForecastSummary
    let notice: String?
    @Binding var showingWeek: Bool
    let onSearch: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if let notice {
                    Label(notice, systemImage: "location.slash")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.2), in: Capsule())
                }
                AdviceCard(advice: OutfitAdvisor.advice(for: summary.next12Hours, timeZone: summary.report.timeZone))
                ForecastCard(summary: summary, showingWeek: $showingWeek)
                Text("Forecast data: National Weather Service")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            HStack {
                Spacer()
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.semibold))
                        .padding(8)
                }
                .accessibilityLabel("Change location")
            }
            .overlay {
                Text(summary.report.city)
                    .font(.title.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 44)
            }
            Text("\(summary.current.temperature)°")
                .font(.system(size: 76, weight: .thin))
            Text(summary.current.shortForecast)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
            Text("H:\(summary.todayHigh)°  L:\(summary.todayLow)°")
                .font(.title3.weight(.medium))
        }
        .accessibilityElement(children: .contain)
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
