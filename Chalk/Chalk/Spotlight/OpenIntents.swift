import AppIntents

/// What a Spotlight result for an exercise runs, and Shortcuts' *Open Exercise*: Chalk
/// comes forward on that exercise's detail screen, in strength (SPEC §15.5).
struct OpenExerciseIntent: OpenIntent {
    static var title: LocalizedStringResource { "Open Exercise" }

    @Parameter(title: "Exercise") var target: ExerciseEntity
    @Dependency private var router: LibraryRouter

    init() {}

    init(target: ExerciseEntity) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try router.open(target.id)
        return .result()
    }
}

/// What a Spotlight result for an erg runs, and Shortcuts' *Open Erg*: Chalk comes
/// forward on that erg's detail screen, in endurance (SPEC §15.5).
struct OpenErgIntent: OpenIntent {
    static var title: LocalizedStringResource { "Open Erg" }

    @Parameter(title: "Erg") var target: ErgEntity
    @Dependency private var router: LibraryRouter

    init() {}

    init(target: ErgEntity) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try router.open(target.id)
        return .result()
    }
}
