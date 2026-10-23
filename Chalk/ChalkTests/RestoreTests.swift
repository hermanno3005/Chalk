import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Restoring a backup (SPEC §15.1, ADR-0010): a replace, never a merge. The file is read,
/// checked and counted before anything is touched, and then everything Chalk holds is
/// swapped for it in one save, the zones included. A file Chalk can't restore exactly is
/// refused in plain words, and a restore that fails leaves the library as it was.
@Suite("Restore")
struct RestoreTests {

    // MARK: - Replacing

    @Test("The fixed library's file, restored over a different library, gives back exactly the fixed library")
    func restoresExactlyTheFixedLibrary() throws {
        let file = try Self.fixedLibraryFile()
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)

        let restore = try Restore(reading: file, over: phone.store.container, defaults: phone.defaults)
        try restore.replace()

        let restored = try phone.afterRelaunch()
        let backup = try Backup(of: restored, defaults: phone.defaults, madeAt: BackupTests.madeAt)
        #expect(try backup.encoded() == file)
        try BackupTests.expect(try Backup(decoding: file), holdsExactly: restored)
        #expect(phone.heldZones()?.lowerBounds == [117, 140, 158, 170])
    }

    // MARK: - Version 1, frozen

    /// `Fixtures/Chalk-backup-1.json` is the fixed library's backup at version 1, written
    /// once by this suite before the units bump the version, as `Chalk-2.0.0.store` was
    /// for the store. The phone's own backup is a version-1 file, so **every later Chalk
    /// must still restore this one**, with keys added since at their schema defaults.
    @Test("The frozen version-1 backup restores")
    func theFrozenVersion1BackupRestores() throws {
        let url = try #require(Bundle(for: LibraryFixture.self).url(forResource: "Chalk-backup-1", withExtension: "json"))
        let file = try Data(contentsOf: url)
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)

        try Restore(reading: file, over: phone.store.container, defaults: phone.defaults).replace()

        let restored = try phone.afterRelaunch()
        try BackupTests.expect(try Backup(decoding: file), holdsExactly: restored)
        let exercises = try restored.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        #expect(exercises.map(\.name) == ["Bench Press", "Chest Press", "Curved Treadmill", "Rower", "Treadmill"])
        #expect(exercises.first?.goalWeight == 102.3)
        #expect(try restored.fetchCount(FetchDescriptor<Entry>()) == 8)
        #expect(try restored.fetchCount(FetchDescriptor<Machine>()) == 4)
        #expect(try restored.fetch(FetchDescriptor<Gym>()).filter(\.isArchived).map(\.name) == ["Old Gym"])
        #expect(phone.heldZones()?.lowerBounds == [117, 140, 158, 170])
    }

    // MARK: - The confirmation

    @Test("Over a library with entries, it counts the entries on each side and dates the backup")
    func confirmationCountsEntries() throws {
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)

        let restore = try Restore(reading: try Self.fixedLibraryFile(), over: phone.store.container, defaults: phone.defaults)

        // Three entries on the phone, the orphan not among them; eight in the file.
        #expect(restore.confirmation(locale: Self.britain, timeZone: .gmt) == "This replaces 3 entries with 8 from 29 Oct 2026")
    }

    @Test("Thousands are grouped, and one entry is an entry")
    func confirmationReadsLargeAndSingleCounts() throws {
        let phone = try LibraryFixture()
        phone.log(phone.exercise("Squat"), reps: 5, weight: 100)
        try phone.save()
        let squat = Backup.Exercise(
            id: UUID(), name: "Squat", kind: ExerciseKind.freeWeight.rawValue, unit: nil, group: nil,
            goal: Backup.GoalFields(), machines: [],
            entries: (0..<1_240).map { day in
                Backup.Entry(id: UUID(), reps: 5, weight: 100, duration: 0, intensity: 0, incline: 0,
                             averageHeartRate: 0, peakHeartRate: 0, date: Date(timeIntervalSinceReferenceDate: Double(day) * 86_400))
            }
        )
        let file = try Backup(madeAt: Self.twelfthOfMarch, settings: .init(), groups: [], gyms: [], exercises: [squat]).encoded()

        let restore = try Restore(reading: file, over: phone.store.container, defaults: phone.defaults)

        #expect(restore.confirmation(locale: Self.britain, timeZone: .gmt) == "This replaces 1 entry with 1,240 from 12 Mar 2026")
    }

    @Test("A side with no entries is counted by its exercises, ergs and gyms")
    func confirmationFallsBackToExercisesErgsAndGyms() throws {
        let phone = try LibraryFixture()
        phone.exercise("Squat")
        phone.exercise("Bench Press")
        phone.erg("Rower", unit: .split, kind: .freeWeight)
        phone.gym("Home")
        try phone.save()

        let restore = try Restore(reading: try Self.fixedLibraryFile(), over: phone.store.container, defaults: phone.defaults)

        #expect(restore.confirmation(locale: Self.britain, timeZone: .gmt) == "This replaces 2 exercises, 1 erg and 1 gym with 8 entries from 29 Oct 2026")
    }

    @Test("A backup holding exercises but no entries is counted by them too")
    func confirmationCountsABackupWithoutEntries() throws {
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)
        let made = try LibraryFixture()
        made.exercise("Squat")
        made.gym("Home")
        made.zones(117, 140, 158, 170)
        try made.save()
        let file = try Backup(of: made.context, defaults: made.defaults, madeAt: Self.twelfthOfMarch).encoded()

        let restore = try Restore(reading: file, over: phone.store.container, defaults: phone.defaults)

        #expect(restore.confirmation(locale: Self.britain, timeZone: .gmt) == "This replaces 3 entries with 1 exercise and 1 gym from 12 Mar 2026")
    }

    @Test("An empty backup over a phone with zones replaces it with nothing, and says it clears the zones")
    func confirmationNamesNothingAndTheZonesClear() throws {
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)
        let file = try Self.emptyFile()

        let restore = try Restore(reading: file, over: phone.store.container, defaults: phone.defaults)

        #expect(restore.confirmation(locale: Self.britain, timeZone: .gmt) == "This replaces 3 entries with nothing from 12 Mar 2026, and clears your heart-rate zones")
    }

    @Test("A backup without zones, over a phone without zones, clears nothing to name")
    func confirmationOmitsTheZonesClearWithoutZones() throws {
        let phone = try LibraryFixture()
        phone.exercise("Squat")
        try phone.save()

        let restore = try Restore(reading: try Self.emptyFile(), over: phone.store.container, defaults: phone.defaults)

        #expect(restore.confirmation(locale: Self.britain, timeZone: .gmt) == "This replaces 1 exercise with nothing from 12 Mar 2026")
    }

    @Test("A library holding only groups, zones and an orphan is empty, so nothing is asked")
    func anEmptyLibraryIsNotAsked() throws {
        let phone = try LibraryFixture()
        phone.group("Push", sortIndex: 0)
        phone.enduranceGroup("Bikes", sortIndex: 0)
        phone.context.insert(Entry(reps: 1, weight: 1))
        phone.zones(110, 130, 150, 165)
        try phone.save()

        let restore = try Restore(reading: try Self.emptyFile(), over: phone.store.container, defaults: phone.defaults)

        #expect(restore.confirmation() == nil)
    }

    // MARK: - Zones

    @Test("A backup without zones, restored over a phone with zones, clears them")
    func aBackupWithoutZonesClearsThem() throws {
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)

        try Restore(reading: try Self.emptyFile(), over: phone.store.container, defaults: phone.defaults).replace()

        #expect(phone.heldZones() == nil)
        #expect(phone.defaults.object(forKey: HeartRateZones.key) == nil)
        #expect(try phone.afterRelaunch().fetchCount(FetchDescriptor<Entry>()) == 0)
    }

    @Test("A restore sets both seed flags, so the suggested groups never land on top of it")
    func aRestoreSetsTheSeedFlags() throws {
        let phone = try LibraryFixture()

        // A backup with no groups, which the seed's own count would otherwise read as
        // never seeded.
        try Restore(reading: try Self.emptyFile(), over: phone.store.container, defaults: phone.defaults).replace()
        _ = phone.libraryModel()

        #expect(try phone.afterRelaunch().fetchCount(FetchDescriptor<ExerciseGroup>()) == 0)
    }

    // MARK: - All or nothing

    @Test("A restore that fails after its deletes and before the commit leaves the library as it was")
    func aFailureBeforeTheCommitChangesNothing() throws {
        let file = try Self.fixedLibraryFile()
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)
        let before = try Self.snapshot(of: phone)

        let restore = try Restore(reading: file, over: phone.store.container, defaults: phone.defaults)
        #expect(throws: Halfway.self) {
            try restore.replace { throw Halfway() }
        }

        #expect(try Self.snapshot(of: phone) == before)
    }

    @Test("A file that fails partway through decoding leaves the library untouched")
    func aFileThatFailsPartwayChangesNothing() throws {
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)
        let before = try Self.snapshot(of: phone)
        // The very last entry in the file can't be read, after every row before it was.
        let file = try Self.fixedLibraryFile { json in
            json[path: "exercises", 4, "machines", 0, "entries", 1, "intensity"] = "9.5"
        }

        #expect(throws: Backup.Refusal.damaged) {
            try Restore(reading: file, over: phone.store.container, defaults: phone.defaults)
        }
        #expect(try Self.snapshot(of: phone) == before)
    }

    // MARK: - Refusals

    @Test("A file Chalk can't restore exactly is refused in plain words, with nothing changed", arguments: [
        Refused("Not JSON", .notABackup) { _ in Data("Bench Press 5 × 57.5".utf8) },
        Refused("JSON that isn't an object", .notABackup) { _ in Data("[1, 2, 3]".utf8) },
        Refused("Some other JSON", .notABackup) { json in json["format"] = "Strong export"; return nil },
        Refused("No format at all", .notABackup) { json in json["format"] = nil; return nil },
        Refused("From a newer Chalk", .newerVersion) { json in json["version"] = Backup.currentVersion + 1; return nil },
        Refused("An unknown key at the top", .unknownKey("units")) { json in json["units"] = "kg"; return nil },
        Refused("An unknown key on an entry", .unknownKey("wieght")) { json in
            json[path: "exercises", 0, "entries", 0, "wieght"] = 60
            return nil
        },
        Refused("An unknown key on a machine", .unknownKey("bar")) { json in
            json[path: "exercises", 1, "machines", 0, "bar"] = 20
            return nil
        },
        Refused("An unknown setting", .unknownKey("weightUnit")) { json in
            json[path: "settings", "weightUnit"] = "kg"
            return nil
        },
        Refused("A group that isn't in the file", .missingReference) { json in
            json[path: "exercises", 0, "group"] = UUID().uuidString
            return nil
        },
        Refused("Two exercises with one id", .duplicateID) { json in
            json[path: "exercises", 1, "id"] = json[path: "exercises", 0, "id"]
            return nil
        },
        Refused("Two entries with one id, on different exercises", .duplicateID) { json in
            json[path: "exercises", 1, "machines", 0, "entries", 0, "id"] = json[path: "exercises", 0, "entries", 0, "id"]
            return nil
        },
        Refused("A kind Chalk doesn't know", .unknownValue("bench")) { json in
            json[path: "exercises", 0, "kind"] = "bench"
            return nil
        },
        Refused("An erg unit Chalk doesn't know", .unknownValue("furlongs")) { json in
            json[path: "exercises", 3, "unit"] = "furlongs"
            return nil
        },
        Refused("A half Chalk doesn't know", .unknownValue("cardio")) { json in
            json[path: "groups", 0, "half"] = "cardio"
            return nil
        },
        Refused("Zones out of order", .invalidZones) { json in
            json[path: "settings", "heartRateZones"] = [140, 117, 158, 170]
            return nil
        },
        Refused("Three zones", .invalidZones) { json in
            json[path: "settings", "heartRateZones"] = [117, 140, 158]
            return nil
        },
        Refused("An endurance goal with no zones", .enduranceGoalWithoutZones) { json in
            json["settings"] = nil
            return nil
        },
        Refused("An entry with no id", .damaged) { json in
            json[path: "exercises", 0, "entries", 0, "id"] = nil
            return nil
        },
        Refused("A weight written as text", .damaged) { json in
            json[path: "exercises", 0, "entries", 0, "weight"] = "57.5"
            return nil
        },
    ])
    func refusals(_ refused: Refused) throws {
        let phone = try LibraryFixture()
        try Self.differentLibrary(in: phone)
        let before = try Self.snapshot(of: phone)

        #expect(throws: refused.refusal) {
            try Restore(reading: try refused.file(), over: phone.store.container, defaults: phone.defaults)
        }
        #expect(try Self.snapshot(of: phone) == before)
        #expect(!refused.refusal.message.isEmpty)
    }

    /// One file a restore refuses, made by editing the fixed library's file. `edit`
    /// changes the JSON in place, or returns other bytes to use instead.
    struct Refused: CustomTestStringConvertible, Sendable {
        let name: String
        let refusal: Backup.Refusal
        let edit: @Sendable (inout [String: Any]) -> Data?

        init(_ name: String, _ refusal: Backup.Refusal, edit: @escaping @Sendable (inout [String: Any]) -> Data?) {
            self.name = name
            self.refusal = refusal
            self.edit = edit
        }

        var testDescription: String { name }

        func file() throws -> Data {
            var replacement: Data?
            let file = try RestoreTests.fixedLibraryFile { replacement = edit(&$0) }
            return replacement ?? file
        }
    }

    // MARK: - Helpers

    private struct Halfway: Error {}

    /// The spec's date format, `12 Mar 2026`, and its grouping, `1,240`.
    static let britain = Locale(identifier: "en_GB")

    /// 12 March 2026, at noon in Greenwich.
    static let twelfthOfMarch = Date(timeIntervalSinceReferenceDate: 795_009_600)

    /// A backup of a library holding nothing, not even zones, made on 12 March 2026.
    static func emptyFile() throws -> Data {
        try Backup(madeAt: twelfthOfMarch, settings: .init(), groups: [], gyms: [], exercises: []).encoded()
    }

    /// Everything a restore could change, as bytes: the store as a second container reads
    /// it, and the zones.
    static func snapshot(of fixture: LibraryFixture) throws -> Data {
        try Backup(of: fixture.afterRelaunch(), defaults: fixture.defaults, madeAt: BackupTests.madeAt).encoded()
    }

    /// The fixed library's backup, with `edit` applied to its JSON.
    static func fixedLibraryFile(editing edit: (inout [String: Any]) -> Void) throws -> Data {
        var json = try #require(try JSONSerialization.jsonObject(with: fixedLibraryFile()) as? [String: Any])
        edit(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }

    /// The fixed library's backup, made at `BackupTests.madeAt`.
    static func fixedLibraryFile() throws -> Data {
        let fixture = try LibraryFixture()
        try BackupTests.fixedLibrary(in: fixture)
        return try Backup(of: fixture.context, defaults: fixture.defaults, madeAt: BackupTests.madeAt).encoded()
    }

    /// A library that shares nothing with the fixed one: other rows, other ids, other zones,
    /// and an orphaned entry that hangs off nothing.
    static func differentLibrary(in fixture: LibraryFixture) throws {
        let legs = fixture.group("Legs", sortIndex: 0)
        let home = fixture.gym("Home")
        let squat = fixture.exercise("Squat", group: legs)
        squat.goalReps = 3
        squat.goalWeight = 140
        squat.goalSetAt = .days(ago: 3)
        fixture.log(squat, reps: 5, weight: 120, on: .days(ago: 2))
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let sled = fixture.machine(for: legPress, at: home, label: "Sled")
        fixture.log(sled, reps: 10, weight: 200, on: .days(ago: 1))
        fixture.interval(fixture.erg("Bike", unit: .watts, kind: .freeWeight), duration: 600, intensity: 210)
        fixture.context.insert(Entry(reps: 1, weight: 1))
        fixture.zones(110, 130, 150, 165)
        try fixture.save()
    }
}

private extension Dictionary where Key == String, Value == Any {

    /// The value down `path` through nested objects (by key) and arrays (by index), as
    /// JSON reads, or `nil` to remove it.
    subscript(path path: Any...) -> Any? {
        get { Self.value(at: path[...], in: self) }
        set { self = Self.setting(newValue, at: path[...], in: self) as! [String: Any] }
    }

    private static func value(at path: ArraySlice<Any>, in node: Any?) -> Any? {
        guard let step = path.first else { return node }
        switch step {
        case let key as String: return value(at: path.dropFirst(), in: (node as? [String: Any])?[key])
        case let index as Int: return value(at: path.dropFirst(), in: (node as? [Any])?[index])
        default: return nil
        }
    }

    private static func setting(_ newValue: Any?, at path: ArraySlice<Any>, in node: Any) -> Any? {
        guard let step = path.first else { return newValue }
        switch step {
        case let key as String:
            var object = node as! [String: Any]
            object[key] = setting(newValue, at: path.dropFirst(), in: object[key] as Any)
            return object
        case let index as Int:
            var array = node as! [Any]
            array[index] = setting(newValue, at: path.dropFirst(), in: array[index]) as Any
            return array
        default:
            return node
        }
    }
}
