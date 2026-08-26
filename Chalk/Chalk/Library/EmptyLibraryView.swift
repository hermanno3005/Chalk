import SwiftUI

/// First launch: **real copy saying what the app is for, and a way in. Not a wordmark**
/// (SPEC §7.1).
struct EmptyLibraryView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Keep the exercises you actually do")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Log what you lifted as plain reps × weight. Chalk works out what you have proven at every rep count, and what to load next time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button(action: onCreate) {
                Text("Add your first exercise")
                    .frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyLibraryView(onCreate: {})
}
