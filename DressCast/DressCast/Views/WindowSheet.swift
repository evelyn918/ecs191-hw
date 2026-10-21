import SwiftUI

/// Picks when the user leaves and comes back. Edits a draft copy and only
/// hands it back when the user taps Done.
struct WindowSheet: View {
    @State var window: TimeWindow
    let onSave: (TimeWindow) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("Day", selection: $window.isTomorrow) {
                    Text("Today").tag(false)
                    Text("Tomorrow").tag(true)
                }
                .pickerStyle(.segmented)

                Picker("Leave", selection: $window.leaveHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(TimeWindow.hourName(hour)).tag(hour)
                    }
                }
                // Only times after leaving are offered (24 is midnight).
                Picker("Return", selection: $window.returnHour) {
                    ForEach(window.leaveHour + 1 ... 24, id: \.self) { hour in
                        Text(TimeWindow.hourName(hour)).tag(hour)
                    }
                }
            }
            // Leaving later than the old return time pushes the return time back.
            .onChange(of: window.leaveHour) {
                if window.returnHour <= window.leaveHour {
                    window.returnHour = window.leaveHour + 1
                }
            }
            .navigationTitle("When are you out?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(window)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    WindowSheet(window: TimeWindow(leaveHour: 8, returnHour: 17, isTomorrow: false)) { _ in }
}
