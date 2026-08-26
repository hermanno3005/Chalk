import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var placeholders: [Placeholder]

    var body: some View {
        VStack(spacing: 12) {
            Text("Chalk")
                .font(.largeTitle.bold())
            Text("Skeleton — store opened, \(placeholders.count) rows.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Placeholder.self, inMemory: true)
}
