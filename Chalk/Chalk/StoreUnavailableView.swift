import SwiftUI

/// Shown instead of the app when the store will not open.
///
/// A plain full-screen message naming the store path, and nothing else: no retry, no
/// "reset" button, no automatic repair. The store on disk is left exactly as it was so
/// it can be pulled off the device with Xcode's Download Container (SPEC §2, §3).
struct StoreUnavailableView: View {
    let storePath: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Chalk can't open its store")
                .font(.title2.bold())
            Text("Your history is still on this device and has not been changed.")
                .font(.callout)
                .multilineTextAlignment(.center)
            Text(storePath)
                .font(.footnote.monospaced())
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    StoreUnavailableView(storePath: "/var/mobile/…/Application Support/default.store")
}
