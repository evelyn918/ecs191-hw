import SwiftUI

/// The one-screen Personal Setup. Shown on first launch and from the gear button.
/// Changes are saved as soon as they're made (see ContentView).
struct SetupView: View {
    @Binding var settings: UserSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(PersonalItem.allCases) { item in
                        Picker(item.name, selection: preference(for: item)) {
                            ForEach(ItemPreference.allCases) { preference in
                                Text(preference.label).tag(preference)
                            }
                        }
                    }
                } header: {
                    Text("Your items")
                } footer: {
                    Text("“Remind me” means DressCast suggests it when the forecast makes it useful. Umbrella and coat reminders are always on.")
                }

                Section("Do you run cold, normal, or warm?") {
                    Picker("I run", selection: $settings.comfort) {
                        ForEach(Comfort.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("I get around by", selection: $settings.commute) {
                        ForEach(Commute.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("How do you get around?")
                } footer: {
                    Text("Walking and biking make rain and wind matter more.")
                }
            }
            .navigationTitle("Personal Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Reads and writes one item's choice inside `settings.items`.
    private func preference(for item: PersonalItem) -> Binding<ItemPreference> {
        Binding(
            get: { settings.preference(for: item) },
            set: { settings.items[item] = $0 }
        )
    }
}

#Preview {
    SetupView(settings: .constant(UserSettings()))
}
