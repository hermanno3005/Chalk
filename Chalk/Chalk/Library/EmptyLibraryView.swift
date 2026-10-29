import SwiftUI

/// First launch: **real copy saying what the app is for, and a way in. Not a wordmark**
/// (SPEC §7.1) — in the words of the half on screen (§13.5).
struct EmptyLibraryView: View {
    var half: Half = .strength
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(spokenDetail)
                .padding(.horizontal, 36)
            Button(action: onCreate) {
                Text(button)
                    .frame(maxWidth: 260)
                    .foregroundStyle(Color.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var title: String {
        switch half {
        case .strength: "Keep the exercises you actually do"
        case .endurance: "Calibrate the machines you train on"
        }
    }

    private var detail: String {
        switch half {
        case .strength:
            "Log what you lifted as plain reps × weight. Chalk works out what you have proven at every rep count, and what to load next time."
        case .endurance:
            "Log an interval as time, what you set and the heart rate it cost. Chalk works out what to set on this machine to hit a zone."
        }
    }

    /// `detail` as VoiceOver says it: the `×` as the word it stands for.
    private var spokenDetail: String {
        switch half {
        case .strength:
            "Log what you lifted as plain reps times weight. Chalk works out what you have proven at every rep count, and what to load next time."
        case .endurance: detail
        }
    }

    private var button: String {
        switch half {
        case .strength: "Add your first exercise"
        case .endurance: "Add your first erg"
        }
    }
}

#Preview("Strength") {
    EmptyLibraryView(onCreate: {})
}

#Preview("Endurance") {
    EmptyLibraryView(half: .endurance, onCreate: {})
}
