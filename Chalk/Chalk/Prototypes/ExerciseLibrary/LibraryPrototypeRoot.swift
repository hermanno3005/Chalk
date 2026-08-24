// PROTOTYPE — throwaway. Answers https://github.com/hermanno3005/Chalk/issues/8
//
// Three variants of the exercise library screen, switchable from a floating bottom
// bar, over four library sizes — so "empty first launch", "three exercises", and
// "forty-two exercises" are each one tap away.
//
// Judged against the real app, not in a vacuum: a row navigates into the *winning*
// exercise detail screen from https://github.com/hermanno3005/Chalk/issues/7 and the
// log shortcuts open the *winning* log sheet from
// https://github.com/hermanno3005/Chalk/issues/6. So "how many taps from cold launch
// to logged?" can actually be counted rather than argued about.

import SwiftUI

enum LibraryVariant: String, CaseIterable {
    case directory, recency, resume

    var key: String {
        switch self {
        case .directory: "A"
        case .recency: "B"
        case .resume: "C"
        }
    }

    var name: String {
        switch self {
        case .directory: "A — Directory (A–Z)"
        case .recency: "B — Recency + row Log"
        case .resume: "C — Resume, then type"
        }
    }
}

struct ExerciseLibraryPrototypeRoot: View {
    @AppStorage("prototype.library.variant") private var variantKey = LibraryVariant.directory.rawValue
    @AppStorage("prototype.library.size") private var sizeKey = LibrarySize.medium.rawValue

    @State private var store = LibraryStore()
    @State private var path: [ProtoExercise] = []
    /// Set when a variant wants to log straight from the list, bypassing detail.
    @State private var loggingTarget: ProtoExercise?
    @State private var flash: String?
    // Screenshot hooks: `-autoCreate 1` opens the create sheet, `-autoLogFirst 1`
    // opens the log sheet for the most recent exercise.
    @State private var creating = UserDefaults.standard.bool(forKey: "autoCreate")

    private var variant: LibraryVariant { LibraryVariant(rawValue: variantKey) ?? .directory }
    private var size: LibrarySize { LibrarySize(rawValue: sizeKey) ?? .medium }

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $path) {
                screen
                    .navigationDestination(for: ProtoExercise.self) { exercise in
                        // The real destination — the round-two winner, compact curve.
                        DetailVariantACurveFirst(
                            store: store.detailStore(for: exercise),
                            size: .compact,
                            onLog: { loggingTarget = exercise })
                    }
                    .overlay(alignment: .top) { flashBanner }
            }
            switcher
        }
        .task {
            if store.exercises.isEmpty || store.size != size { store.load(size) }
            if UserDefaults.standard.bool(forKey: "autoLogFirst") { loggingTarget = store.byRecency.first }
        }
        .sheet(isPresented: $creating) { CreateExerciseSheet(store: store) { _ in } }
        .sheet(item: $loggingTarget) { exercise in
            VariantAStagedSteppers(store: store.detailStore(for: exercise)) { record in
                store.log(exercise, reps: record.reps, weight: record.weight)
                loggingTarget = nil
                announce("Logged \(record.reps) × \(record.weight.kg) kg · \(exercise.name)")
            }
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch variant {
        case .directory:
            LibraryVariantADirectory(store: store, onOpen: { path.append($0) })
        case .recency:
            LibraryVariantBRecency(store: store,
                                   onOpen: { path.append($0) },
                                   onLog: { loggingTarget = $0 })
        case .resume:
            LibraryVariantCResume(store: store,
                                  onOpen: { path.append($0) },
                                  onLog: { loggingTarget = $0 })
        }
    }

    private func announce(_ text: String) {
        withAnimation { flash = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { flash = nil }
        }
    }

    @ViewBuilder
    private var flashBanner: some View {
        if let flash {
            Text(flash)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.green.opacity(0.9), in: Capsule())
                .foregroundStyle(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// High-contrast, deliberately not part of the design being judged.
    private var switcher: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                arrow("chevron.left", -1)
                VStack(spacing: 0) {
                    Text(variant.name).font(.footnote.weight(.semibold))
                    Text("prototype").font(.system(size: 9)).opacity(0.6)
                }
                .frame(width: 180)
                arrow("chevron.right", 1)
            }
            Button {
                let all = LibrarySize.allCases
                let index = all.firstIndex(of: size) ?? 0
                let next = all[(index + 1) % all.count]
                sizeKey = next.rawValue
                path = []
                store.load(next)
            } label: {
                Text(size.name)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.black, in: RoundedRectangle(cornerRadius: 22))
        .foregroundStyle(.white)
        .shadow(radius: 8)
        .padding(.bottom, 8)
    }

    private func arrow(_ icon: String, _ offset: Int) -> some View {
        Button {
            let all = LibraryVariant.allCases
            let index = all.firstIndex(of: variant) ?? 0
            variantKey = all[(index + offset + all.count) % all.count].rawValue
            path = []
        } label: {
            Image(systemName: icon).font(.body.weight(.bold))
                .frame(width: 38, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExerciseLibraryPrototypeRoot()
}
