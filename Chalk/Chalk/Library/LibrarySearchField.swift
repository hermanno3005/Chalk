import SwiftUI

/// The search field, **pinned in thumb reach** at the foot of the library (SPEC §7.1).
///
/// It filters instantly, and past the grid it is the only way to reach an exercise —
/// there is no browsable list — so it is also the fastest door to creating one.
///
/// **Focus is the caller's, not the field's** (#56) — see `LibraryView.searchFocused`.
struct LibrarySearchField: View {
    @Binding var query: String
    /// Whether the field is first responder.
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search or add an exercise", text: $query)
                .focused($isFocused)
                // An exit in its own right: submit resigns focus.
                .submitLabel(.search)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            if !query.isEmpty {
                // Clears the text and leaves you typing — what a ✕ in a search field
                // means everywhere else, so it touches focus deliberately not at all.
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: Capsule())
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview {
    @Previewable @FocusState var isFocused: Bool
    LibrarySearchField(query: .constant(""), isFocused: $isFocused)
}
