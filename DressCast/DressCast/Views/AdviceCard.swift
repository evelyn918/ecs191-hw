import SwiftUI

/// DressCast's "what to wear / what to bring" card, based on the next 12 hours.
struct AdviceCard: View {
    let advice: OutfitAdvice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "DressCast · Next 12 hours", symbol: "hanger")
            HStack(alignment: .top, spacing: 12) {
                column("Wear", items: advice.wear)
                Divider().overlay(.white.opacity(0.3))
                column("Bring", items: advice.bring)
            }
        }
        .card()
    }

    private func column(_ title: String, items: [AdviceItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.symbol)
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
