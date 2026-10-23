import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Making a backup (SPEC §15.1, ADR-0010): one readable file holding every entry,
/// exercise, erg, group, gym, machine and goal, plus the heart-rate zones. **It must
/// round-trip exactly**, every number byte for byte and every date exact, so its tests
/// have the same shape as `SchemaMigrationTests`: a fixed library goes out to a file and
/// comes back identical.
@Suite("Backup")
struct BackupTests {

    // MARK: - Reading by eye

    @Test("A small library writes a file that reads by eye")
    func aSmallLibraryReadsByEye() throws {
        let fixture = try LibraryFixture()
        let push = ExerciseGroup(id: Self.uuid(1), name: "Push", sortIndex: 0)
        let fitnessX = Gym(id: Self.uuid(2), name: "Fitness X")
        let chestPress = Exercise(id: Self.uuid(3), name: "Chest Press", kind: .gymBound, group: push)
        let plateLoaded = Machine(id: Self.uuid(4), label: "Plate-loaded", exercise: chestPress, gym: fitnessX)
        plateLoaded.goalReps = 8
        plateLoaded.goalWeight = 72.5
        plateLoaded.goalSetAt = Date(timeIntervalSinceReferenceDate: 814_500_000)
        let entry = Entry(
            id: Self.uuid(5),
            reps: 8,
            weight: 60,
            date: Date(timeIntervalSinceReferenceDate: 814_990_000.123_456_7),
            exercise: chestPress,
            machine: plateLoaded
        )
        try fixture.store.insertAll([push, fitnessX, chestPress, plateLoaded, entry], into: fixture.context)
        fixture.zones(117, 140, 158, 170)

        let backup = try Backup(
            of: fixture.context,
            defaults: fixture.defaults,
            madeAt: Date(timeIntervalSinceReferenceDate: 815_000_000.25)
        )

        let text = String(decoding: try backup.encoded(), as: UTF8.self)
        #expect(text == """
        {
          "exercises" : [
            {
              "group" : "00000000-0000-0000-0000-000000000001",
              "id" : "00000000-0000-0000-0000-000000000003",
              "kind" : "gymBound",
              "machines" : [
                {
                  "entries" : [
                    {
                      "date" : "2026-10-29T18:06:40.1234567Z",
                      "id" : "00000000-0000-0000-0000-000000000005",
                      "reps" : 8,
                      "weight" : 60
                    }
                  ],
                  "goalReps" : 8,
                  "goalSetAt" : "2026-10-24T02:00:00Z",
                  "goalWeight" : 72.5,
                  "gym" : "00000000-0000-0000-0000-000000000002",
                  "id" : "00000000-0000-0000-0000-000000000004",
                  "label" : "Plate-loaded"
                }
              ],
              "name" : "Chest Press"
            }
          ],
          "format" : "Chalk backup",
          "groups" : [
            {
              "id" : "00000000-0000-0000-0000-000000000001",
              "name" : "Push"
            }
          ],
          "gyms" : [
            {
              "id" : "00000000-0000-0000-0000-000000000002",
              "name" : "Fitness X"
            }
          ],
          "madeAt" : "2026-10-29T20:53:20.25Z",
          "settings" : {
            "heartRateZones" : [
              117,
              140,
              158,
              170
            ]
          },
          "version" : 1
        }
        """)
    }

    // MARK: - Round trip

    @Test("A fixed library goes out to a file and decodes identical, byte for byte")
    func aFixedLibraryRoundTrips() throws {
        let fixture = try LibraryFixture()
        try Self.fixedLibrary(in: fixture)

        let backup = try Backup(of: fixture.context, defaults: fixture.defaults, madeAt: Self.madeAt)
        let file = try backup.encoded()
        let decoded = try Backup(decoding: file)

        #expect(decoded == backup)
        #expect(try decoded.encoded() == file)
        try Self.expect(decoded, holdsExactly: fixture.context)
        #expect(decoded.settings.heartRateZones == [117, 140, 158, 170])
        #expect(decoded.madeAt == Self.madeAt)
    }

    @Test("Every attribute of every entity is written, so nothing stored is left behind")
    func everyAttributeIsWritten() throws {
        let fixture = try LibraryFixture()
        try Self.fixedLibrary(in: fixture)
        let file = try Backup(of: fixture.context, defaults: fixture.defaults).encoded()
        let json = try #require(try JSONSerialization.jsonObject(with: file) as? [String: Any])

        // The keys written for each entity, across every row of it in the file.
        var written: [String: Set<String>] = [:]
        func collect(_ rows: Any?, as entity: String) {
            for row in rows as? [[String: Any]] ?? [] {
                written[entity, default: []].formUnion(row.keys)
                collect(row["machines"], as: "Machine")
                collect(row["entries"], as: "Entry")
            }
        }
        collect(json["groups"], as: "ExerciseGroup")
        collect(json["gyms"], as: "Gym")
        collect(json["exercises"], as: "Exercise")

        // The fixed library sets every attribute away from its default on some row, so
        // every attribute's key turns up. Relationships are the nesting and the two
        // references, never a key of their own beyond those.
        for entity in Schema(versionedSchema: ChalkSchemaV1.self).entities {
            let attributes = Set(entity.attributes.map(\.name))
            let relationships = Set(entity.relationships.map(\.name))
            let keys = written[entity.name] ?? []
            #expect(attributes.subtracting(keys).isEmpty, "\(entity.name) leaves out \(attributes.subtracting(keys))")
            #expect(keys.subtracting(attributes).isSubset(of: relationships), "\(entity.name) writes \(keys.subtracting(attributes))")
        }
    }

    // MARK: - Dates

    @Test("Any date from 2001 to 2100 reads back to the same bits")
    func datesAreExact() throws {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<20_000 {
            let date = Date(timeIntervalSinceReferenceDate: .random(in: 0..<3_155_760_000, using: &generator))
            let text = try BackupDate.string(from: date)
            let read = try #require(BackupDate.date(from: text), "\(text)")
            #expect(read.timeIntervalSinceReferenceDate.bitPattern == date.timeIntervalSinceReferenceDate.bitPattern, "\(text)")
        }
    }

    @Test("A whole second is written with no fraction, and a fraction with every digit", arguments: [
        (814_500_000.0, "2026-10-24T02:00:00Z"),
        (814_500_000.5, "2026-10-24T02:00:00.5Z"),
        (814_500_000.000_001, "2026-10-24T02:00:00.000001Z"),
        (0.25, "2001-01-01T00:00:00.25Z"),
    ])
    func datesReadAsWritten(interval: Double, text: String) throws {
        #expect(try BackupDate.string(from: Date(timeIntervalSinceReferenceDate: interval)) == text)
        #expect(BackupDate.date(from: text) == Date(timeIntervalSinceReferenceDate: interval))
    }

    @Test("A date before 2001 is refused rather than written wrong")
    func aDateBefore2001IsRefused() {
        #expect(throws: EncodingError.self) {
            try BackupDate.string(from: Date(timeIntervalSinceReferenceDate: -0.5))
        }
    }

    // MARK: - The fixed library

    static let madeAt = Date(timeIntervalSinceReferenceDate: 815_000_000.987_654_3)

    /// Both halves, with every attribute of every entity away from its default on at least
    /// one row: a free-weight lift with a goal, a gym-bound lift with machines at two gyms
    /// (one archived) and a gym-less one, a transferable erg with a goal and no group, a
    /// gym-bound erg whose machine holds a goal, groups in both halves, the zones, and
    /// dates with sub-second fractions.
    static func fixedLibrary(in fixture: LibraryFixture) throws {
        let push = fixture.group("Push/Pull", sortIndex: 2)
        fixture.group("Legs", sortIndex: 0)
        let treadmills = fixture.enduranceGroup("Treadmills", sortIndex: 1)
        let fitnessX = fixture.gym("Fitness X")
        let oldGym = fixture.gym("Old Gym", isArchived: true)

        let bench = fixture.exercise("Bench Press", group: push)
        bench.goalReps = 5
        bench.goalWeight = 102.3
        bench.goalSetAt = Date(timeIntervalSinceReferenceDate: 795_000_069.123_456_7)
        fixture.log(bench, reps: 5, weight: 57.5, on: Date(timeIntervalSinceReferenceDate: 795_000_000.000_001))
        fixture.log(bench, reps: 3, weight: 0.1, on: Date(timeIntervalSinceReferenceDate: 795_100_000.3))

        let chestPress = fixture.exercise("Chest Press", kind: .gymBound, group: push)
        let plateLoaded = fixture.machine(for: chestPress, at: fitnessX, manufacturer: "Hammer Strength", label: "Plate-loaded")
        plateLoaded.goalReps = 8
        plateLoaded.goalWeight = 72.5
        plateLoaded.goalSetAt = Date(timeIntervalSinceReferenceDate: 795_200_000.5)
        fixture.log(plateLoaded, reps: 8, weight: 60, on: Date(timeIntervalSinceReferenceDate: 795_300_000.25))
        let selectorised = fixture.machine(for: chestPress, at: oldGym, manufacturer: "Technogym")
        fixture.log(selectorised, reps: 12, weight: 41.25, on: Date(timeIntervalSinceReferenceDate: 795_400_000))
        let gymless = fixture.machine(for: chestPress, at: nil, label: "By the window")
        fixture.log(gymless, reps: 10, weight: 45, on: Date(timeIntervalSinceReferenceDate: 795_500_000.75))

        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        rower.goalZone = 3
        rower.goalDuration = 1_200
        rower.goalIntensity = 118.4
        rower.goalSetAt = Date(timeIntervalSinceReferenceDate: 795_600_000.1)
        fixture.interval(rower, duration: 1_210, intensity: 118.9, average: 151, peak: 163, on: Date(timeIntervalSinceReferenceDate: 795_700_000.2))

        let curved = fixture.erg("Curved Treadmill", unit: .speed, kind: .freeWeight, group: treadmills)
        curved.goalZone = 2
        curved.goalDuration = 1_800
        curved.goalIntensity = 10.2
        curved.goalIncline = 0
        curved.goalSetAt = Date(timeIntervalSinceReferenceDate: 795_650_000.9)

        let treadmill = fixture.erg("Treadmill", unit: .speed, group: treadmills)
        let technogym = fixture.machine(for: treadmill, at: fitnessX, label: "Technogym Excite")
        technogym.goalZone = 4
        technogym.goalDuration = 360
        technogym.goalIntensity = 15.1
        technogym.goalIncline = 1.5
        technogym.goalSetAt = Date(timeIntervalSinceReferenceDate: 795_800_000.33)
        // Saved together from the lap list, microseconds apart.
        fixture.interval(treadmill, machine: technogym, duration: 362, intensity: 15.1, incline: 1, average: 164, peak: 171, on: Date(timeIntervalSinceReferenceDate: 795_900_000.000_001))
        fixture.interval(treadmill, machine: technogym, duration: 90, intensity: 9.5, incline: 0.5, average: 121, peak: 130, on: Date(timeIntervalSinceReferenceDate: 795_900_000.000_002))

        fixture.zones(117, 140, 158, 170)
        try fixture.save()
    }

    /// Checks `backup` against the store row by row, by id: every group, gym, exercise,
    /// machine and entry is in the file once, under the right parent, with every field
    /// equal to the stored one.
    static func expect(_ backup: Backup, holdsExactly context: ModelContext) throws {
        let groups = try context.fetch(FetchDescriptor<ExerciseGroup>())
        #expect(Set(backup.groups.map(\.id)) == Set(groups.map(\.id)))
        for group in groups {
            let row = try #require(backup.groups.first { $0.id == group.id })
            #expect(row == Backup.Group(id: group.id, name: group.name, sortIndex: group.sortIndex, half: group.half))
        }

        let gyms = try context.fetch(FetchDescriptor<Gym>())
        #expect(Set(backup.gyms.map(\.id)) == Set(gyms.map(\.id)))
        for gym in gyms {
            let row = try #require(backup.gyms.first { $0.id == gym.id })
            #expect(row.name == gym.name)
            #expect(row.isArchived == gym.isArchived)
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(Set(backup.exercises.map(\.id)) == Set(exercises.map(\.id)))
        for exercise in exercises {
            let row = try #require(backup.exercises.first { $0.id == exercise.id })
            #expect(row.name == exercise.name)
            #expect(row.kind == exercise.kind)
            #expect(row.unit == exercise.unit)
            #expect(row.group == exercise.group?.id)
            #expect(row.goal.goalReps == exercise.goalReps)
            #expect(row.goal.goalWeight == exercise.goalWeight)
            #expect(row.goal.goalSetAt == exercise.goalSetAt)
            #expect(row.goal.goalZone == exercise.goalZone)
            #expect(row.goal.goalDuration == exercise.goalDuration)
            #expect(row.goal.goalIntensity == exercise.goalIntensity)
            #expect(row.goal.goalIncline == exercise.goalIncline)
            #expect(Set(row.machines.map(\.id)) == Set((exercise.machines ?? []).map(\.id)))
            expect(row.entries, equal: (exercise.entries ?? []).filter { $0.machine == nil })

            for machine in exercise.machines ?? [] {
                let machineRow = try #require(row.machines.first { $0.id == machine.id })
                #expect(machineRow.manufacturer == machine.manufacturer)
                #expect(machineRow.label == machine.label)
                #expect(machineRow.gym == machine.gym?.id)
                #expect(machineRow.goal.goalReps == machine.goalReps)
                #expect(machineRow.goal.goalWeight == machine.goalWeight)
                #expect(machineRow.goal.goalSetAt == machine.goalSetAt)
                #expect(machineRow.goal.goalZone == machine.goalZone)
                #expect(machineRow.goal.goalDuration == machine.goalDuration)
                #expect(machineRow.goal.goalIntensity == machine.goalIntensity)
                #expect(machineRow.goal.goalIncline == machine.goalIncline)
                expect(machineRow.entries, equal: machine.entries ?? [])
            }
        }

        let entries = try context.fetch(FetchDescriptor<Entry>())
        let written = backup.exercises.flatMap { $0.entries + $0.machines.flatMap(\.entries) }
        #expect(written.count == entries.count)
    }

    private static func expect(_ rows: [Backup.Entry], equal entries: [Entry]) {
        #expect(Set(rows.map(\.id)) == Set(entries.map(\.id)))
        for entry in entries {
            guard let row = rows.first(where: { $0.id == entry.id }) else { continue }
            #expect(row.reps == entry.reps)
            #expect(row.weight.bitPattern == entry.weight.bitPattern)
            #expect(row.duration == entry.duration)
            #expect(row.intensity.bitPattern == entry.intensity.bitPattern)
            #expect(row.incline.bitPattern == entry.incline.bitPattern)
            #expect(row.averageHeartRate == entry.averageHeartRate)
            #expect(row.peakHeartRate == entry.peakHeartRate)
            #expect(row.date.timeIntervalSinceReferenceDate.bitPattern == entry.date.timeIntervalSinceReferenceDate.bitPattern)
        }
    }

    // MARK: - Helpers

    /// A fixed id, so a file's text can be written out in full.
    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }
}
