import SwiftUI

/// The search field, **pinned in thumb reach** at the foot of the library (SPEC §7.1).
///
/// It filters instantly, and past the grid it is the only way to reach an exercise —
/// there is no browsable list — so it is also the fastest door to creating one.
struct LibrarySearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search or add an exercise", text: $query)
                .submitLabel(.search)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            if !query.isEmpty {
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
    LibrarySearchField(query: .constant(""))
}
