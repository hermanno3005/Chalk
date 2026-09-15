import SwiftUI

// PROTOTYPE — the app root while this prototype is checked out. Four variants of the
// goal on the exercise detail screen, switchable from the floating bottom bar.
struct GoalsPrototypeRoot: View {
    @State private var model = GoalsPrototypeModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                body(for: model.variant)
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle("Bench Press")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Rename", systemImage: "pencil") {}
                        Button("Change kind", systemImage: "arrow.left.arrow.right") {}
                        Button("Delete exercise", systemImage: "trash", role: .destructive) {}
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            // The real Log bar, so every variant is judged with the thing it is
            // competing with for thumb space actually on screen.
            .safeAreaInset(edge: .bottom) { logBar }
        }
        .overlay(alignment: .bottom) { switcher }
    }

    @ViewBuilder
    private func body(for variant: PrototypeVariant) -> some View {
        switch variant {
        case .a: GoalVariantA(model: model)
        case .b: GoalVariantB(model: model)
        case .c: GoalVariantC(model: model)
        case .d: GoalVariantD(model: model)
        }
    }

    private var logBar: some View {
        Button {} label: {
            Text("Log")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        // Clear of the switcher pill, which is prototype chrome and not part of the
        // design being judged.
        .padding(.bottom, 74)
    }

    /// Deliberately high-contrast and obviously not part of the design.
    private var switcher: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button { model.cycleVariant(-1) } label: { Image(systemName: "chevron.left") }
                Text("\(model.variant.rawValue) — \(model.variant.name)")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 190)
                Button { model.cycleVariant(1) } label: { Image(systemName: "chevron.right") }
            }
            HStack(spacing: 8) {
                pill(model.dataset.rawValue) {
                    model.dataset = GoalsPrototypeModel.cycle(model.dataset, 1)
                }
                pill(model.goalState.rawValue) {
                    model.goalState = GoalsPrototypeModel.cycle(model.goalState, 1)
                }
                pill(model.reachedStyle.rawValue) {
                    model.reachedStyle = GoalsPrototypeModel.cycle(model.reachedStyle, 1)
                }
                pill(model.showGhost ? "ghost on" : "ghost off") {
                    model.showGhost.toggle()
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.85), in: .capsule)
        .padding(.bottom, 6)
    }

    private func pill(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: .capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}
