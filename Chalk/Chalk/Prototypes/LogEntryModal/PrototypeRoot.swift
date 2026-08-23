// PROTOTYPE — throwaway.

import SwiftUI

enum LogVariant: String, CaseIterable {
    case a, b, c

    var key: String { rawValue.uppercased() }

    var name: String {
        switch self {
        case .a: "Staged steppers"
        case .b: "One-screen wheels"
        case .c: "Repeat-first"
        }
    }
}

/// Root of the log-entry-modal prototype. The variant is persisted so it survives
/// a relaunch — the iOS equivalent of the skill's reload-stable `?variant=` param.
struct LogEntryPrototypeRoot: View {
    @AppStorage("prototype.logEntry.variant") private var variantKey = LogVariant.a.rawValue
    @State private var store = ProtoStore()

    private var variant: LogVariant {
        LogVariant(rawValue: variantKey) ?? .a
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PrototypeHostScreen(store: store, variant: variant)
            PrototypeVariantSwitcher(current: variant) { variantKey = $0.rawValue }
                .padding(.bottom, 8)
        }
    }
}

/// High-contrast pill, deliberately not part of the design being judged.
struct PrototypeVariantSwitcher: View {
    let current: LogVariant
    let onChange: (LogVariant) -> Void

    var body: some View {
        HStack(spacing: 14) {
            button("chevron.left", offset: -1)
            VStack(spacing: 0) {
                Text("\(current.key) — \(current.name)")
                    .font(.footnote.weight(.semibold))
                Text("prototype")
                    .font(.system(size: 9))
                    .opacity(0.6)
            }
            .frame(width: 160)
            button("chevron.right", offset: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black, in: Capsule())
        .foregroundStyle(.white)
        .shadow(radius: 8)
    }

    private func button(_ icon: String, offset: Int) -> some View {
        Button {
            let all = LogVariant.allCases
            let i = all.firstIndex(of: current) ?? 0
            onChange(all[(i + offset + all.count) % all.count])
        } label: {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LogEntryPrototypeRoot()
}
