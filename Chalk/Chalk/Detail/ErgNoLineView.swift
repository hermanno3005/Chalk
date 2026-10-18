import SwiftUI

/// A zone with no line on the erg detail screen (SPEC §13.8): the text where the chart
/// would be, and under it the nearest zones above and below that have one, each behind
/// its zone as a tag — `Z5 3:00 at 16.5 km/h — too hard`.
struct ErgNoLineView: View {
    let noLine: ErgNoLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(noLine.title)
                .font(.title3.weight(.medium))
            Text(noLine.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(noLine.quotes, id: \.zone) { quote in
                HStack(spacing: 6) {
                    Text("Z\(quote.zone)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: .rect(cornerRadius: 4))
                    Text(quote.clause)
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
