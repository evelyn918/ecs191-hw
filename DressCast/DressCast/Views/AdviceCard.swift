import SwiftUI

/// DressCast's "what to wear / what to bring" card: a one-line verdict, then
/// each suggestion with its reason. Used on the main screen and the day detail screen.
struct AdviceCard: View {
    let advice: Advice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "DressCast", symbol: "hanger")
            Text(advice.verdict)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            // Empty groups are hidden, so "Nothing special today." stands alone.
            if !advice.wear.isEmpty {
                group("Wear", items: advice.wear)
            }
            if !advice.bring.isEmpty {
                group("Bring", items: advice.bring)
            }
        }
        .card()
    }

    private func group(_ title: String, items: [Suggestion]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.symbol)
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.reason)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
