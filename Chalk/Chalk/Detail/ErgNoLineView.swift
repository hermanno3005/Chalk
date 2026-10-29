import SwiftUI

/// A zone with no line on the erg detail screen (SPEC §13.8): the text where the chart
/// would be, and under it the nearest zones above and below that have one, each behind
/// its zone in bold — `Z5 3:00 at 16.5 km/h — too hard`. **The zones take no colour**
/// and no fill, as the tabs above it have none (SPEC §15.4).
struct ErgNoLineView: View {
    let noLine: ErgNoLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(noLine.title)
                .font(.title3.weight(.semibold))
            Text(noLine.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(noLine.quotes, id: \.zone) { quote in
                HStack(spacing: 6) {
                    Text("Z\(quote.zone)")
                        .fontWeight(.bold)
                    Text(quote.clause)
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
