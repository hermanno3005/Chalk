import SwiftUI

/// The number at the top of the detail screen: the best weight at the selected rep
/// count, and what stands behind it (SPEC §5.1).
///
/// The `›` is honest about where this is going — tapping it opens the `reps >= N`
/// history sheet (§5.6), the only place an entry can be edited or deleted. **Dead until
/// that ticket lands.**
struct ScrubReadout: View {
    let readout: ExerciseDetailModel.Readout

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(weight)
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .monospacedDigit()
                // The number moves digit by digit as the thumb crosses rep counts,
                // rather than cross-fading whole.
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: readout.weight)
                // An unproven cell has no number to show, and nothing else's number
                // will do (SPEC §4).
                .foregroundStyle(readout.weight == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))

            HStack(spacing: 4) {
                Text("best for \(readout.reps) reps · \(entriesBehind)")
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(weight), best for \(readout.reps) reps, \(entriesBehind)")
    }

    /// Kilograms, always (SPEC §2). Half plates matter; trailing zeroes do not.
    private var weight: String {
        guard let weight = readout.weight else { return "—" }
        return "\(weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    /// `record` is the screen's word, quoted from SPEC §5.1; the thing counted is an
    /// entry, which is what the glossary calls it and what the code calls it.
    private var entriesBehind: String {
        readout.entriesBehind == 1 ? "1 record" : "\(readout.entriesBehind) records"
    }
}

#Preview {
    VStack(spacing: 32) {
        ScrubReadout(readout: .init(reps: 5, weight: 52.5, entriesBehind: 8))
        ScrubReadout(readout: .init(reps: 9, weight: nil, entriesBehind: 0))
    }
    .padding()
}
