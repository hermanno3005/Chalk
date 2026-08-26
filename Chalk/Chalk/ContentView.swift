import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var exercises: [Exercise]

    var body: some View {
        VStack(spacing: 12) {
            Text("Chalk")
                .font(.largeTitle.bold())
            Text("Store opened — \(exercises.count) exercises.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Exercise.self, inMemory: true)
}
