import Foundation

/// A **backup** (ADR-0010): everything Chalk knows, as one readable file. Every entry,
/// exercise, erg, group, gym, machine and goal, plus the heart-rate zones. Made from
/// Settings and handed to the share sheet, and **it round-trips exactly**: every number
/// byte for byte, every date to the bit, every row under its own `id`.
///
/// The file is a tree that mirrors the cascades: an exercise holds its machines, a machine
/// holds the entries logged on it, and the exercise's own `entries` are the ones with no
/// machine. Invariant 1 (`entry.machine?.exercise == entry.exercise`) then cannot be broken
/// by the file, and `group` and `gym` are the only references, by UUID.
///
/// **A key that holds its schema default is left out**, so a lift's entry reads `reps`,
/// `weight` and `date` and nothing else. The same rule is the versioning rule: a reader
/// takes a missing key as the schema default, so a newer Chalk reads every older file.
/// `version` is bumped whenever a writer can emit a key the previous reader does not know.
/// Version 2 added the weight unit (SPEC §15.2), so a version-1 file reads as kg, which is
/// what everything in it was written in. The distance unit will need its own version.
///
/// The shape, the encoding and the version follow *How does a Chalk library round-trip
/// exactly through a readable backup file?* (https://github.com/hermanno3005/Chalk/issues/128).
struct Backup: Equatable, Sendable {

    /// What the file says it is, so a picker that offers any JSON can tell a backup apart.
    static let format = "Chalk backup"

    /// This Chalk's file version. Version 1 carries no units; version 2 adds the weight
    /// unit. `Chalk-backup-1.json` and `Chalk-backup-2.json` in the tests are frozen
    /// copies of each, and every later Chalk restores both.
    static let currentVersion = 2

    var format = Self.format
    var version = Self.currentVersion
    /// When the backup was made: the age a restore states, and the date in its file name.
    var madeAt: Date
    var settings: Settings
    /// Both halves', in each half's order.
    var groups: [Group]
    var gyms: [Gym]
    /// Every exercise and erg, by name.
    var exercises: [Exercise]

    /// The device's settings that are part of the record. The current gym, the half on
    /// screen and the seed flags are device preferences, and stay behind.
    struct Settings: Equatable, Sendable {
        /// The four lower bounds of Z2 to Z5, or `nil` before zones are set.
        var heartRateZones: [Int]?
        /// The weight unit, which a restore sets. An unset unit reads as kg, so it is
        /// written as kg, and left out like any other default.
        var weightUnit = WeightUnit.kg
    }

    struct Group: Equatable, Sendable {
        var id: UUID
        var name: String
        var sortIndex: Int
        var half: String
    }

    struct Gym: Equatable, Sendable {
        var id: UUID
        var name: String
        var isArchived: Bool
    }

    /// A lift or an erg, with the seven goal fields exactly as stored. A partly filled
    /// goal, which invariant 8 calls *no goal*, comes back partly filled, because the file
    /// never interprets one.
    struct Exercise: Equatable, Sendable {
        var id: UUID
        var name: String
        var kind: String
        var unit: String?
        /// The group's id, or `nil` for Ungrouped.
        var group: UUID?
        var goal: GoalFields
        var machines: [Machine]
        /// The entries logged on no machine.
        var entries: [Entry]

        /// Every entry logged on it, on a machine or on none.
        var allEntries: [Entry] { entries + machines.flatMap(\.entries) }
    }

    struct Machine: Equatable, Sendable {
        var id: UUID
        var manufacturer: String?
        var label: String?
        /// The gym's id, or `nil` for a gym-less machine (invariant 3).
        var gym: UUID?
        var goal: GoalFields
        var entries: [Entry]
    }

    /// The goal fields an exercise and a machine both hold, stored flat in the file as in
    /// the store.
    struct GoalFields: Equatable, Sendable {
        var goalReps: Int?
        var goalWeight: Double?
        var goalSetAt: Date?
        var goalZone: Int?
        var goalDuration: Int?
        var goalIntensity: Double?
        var goalIncline: Double?
    }

    struct Entry: Equatable, Sendable {
        var id: UUID
        var reps: Int
        var weight: Double
        var duration: Int
        var intensity: Double
        var incline: Double
        var averageHeartRate: Int
        var peakHeartRate: Int
        var date: Date
    }
}

// MARK: - The file

extension Backup {

    /// The file's bytes: pretty, key-sorted JSON. **Sorted keys are required, not
    /// cosmetic**: without them the key order changes from run to run, and a backup of a
    /// restored backup would not be the same bytes.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(try BackupDate.string(from: date))
        }
        return try encoder.encode(self)
    }

    /// A backup read back from a file's bytes, **checked whole before anything uses it**.
    ///
    /// Throws a `Refusal` for any file Chalk can't restore exactly: one that is not a
    /// backup, one from a newer Chalk, an unknown key at any level (which a newer writer
    /// or a hand edit would otherwise lose without a word), a raw value outside its enum,
    /// zones `HeartRateZones` rejects, a `group` or `gym` the file doesn't hold, two rows
    /// of one entity with one id, and an endurance goal with no zones to read it by.
    init(decoding data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = BackupDate.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "\(string) is not a backup date"
                )
            }
            return date
        }
        do {
            self = try decoder.decode(Backup.self, from: data)
        } catch let refusal as Refusal {
            throw refusal
        } catch DecodingError.dataCorrupted(let context) where context.codingPath.isEmpty {
            // Not JSON at all.
            throw Refusal.notABackup
        } catch {
            throw Refusal.damaged
        }
        try refuseRowsThatDontHangTogether()
    }

    /// Refuses a file whose rows don't hang together: a duplicate id within an entity, a
    /// `group` or `gym` the file doesn't hold, or an endurance goal with no zones.
    private func refuseRowsThatDontHangTogether() throws {
        let machines = exercises.flatMap(\.machines)
        let entries = exercises.flatMap(\.allEntries)
        let ids = [groups.map(\.id), gyms.map(\.id), exercises.map(\.id), machines.map(\.id), entries.map(\.id)]
        guard ids.allSatisfy({ Set($0).count == $0.count }) else { throw Refusal.duplicateID }

        let groupIDs = Set(groups.map(\.id))
        let gymIDs = Set(gyms.map(\.id))
        guard exercises.allSatisfy({ $0.group.map(groupIDs.contains) ?? true }),
              machines.allSatisfy({ $0.gym.map(gymIDs.contains) ?? true })
        else { throw Refusal.missingReference }

        // Chalk never writes a goal zone without zones, and without them it means nothing.
        let goals = exercises.map(\.goal) + machines.map(\.goal)
        if settings.heartRateZones == nil, goals.contains(where: { $0.goalZone != nil }) {
            throw Refusal.enduranceGoalWithoutZones
        }
    }
}

// MARK: - Refusals

extension Backup {

    /// Why a file can't be restored, in plain words. A refused file changes nothing.
    enum Refusal: Error, Equatable {
        /// Not JSON, or JSON without the `format` a backup carries.
        case notABackup
        /// A `version` newer than this Chalk reads.
        case newerVersion
        /// A key this Chalk doesn't know, which it would otherwise drop without a word.
        case unknownKey(String)
        /// A `kind`, `unit`, `half` or `weightUnit` outside its enum.
        case unknownValue(String)
        /// Zones that aren't four rising whole bpm between 40 and 230.
        case invalidZones
        /// A `group` or `gym` the file doesn't hold.
        case missingReference
        /// Two rows of one entity with the same id.
        case duplicateID
        /// A goal zone with no zones to read it by, which Chalk never writes.
        case enduranceGoalWithoutZones
        /// Anything else the file gets wrong: a missing id, a number written as text.
        case damaged

        var message: String {
            switch self {
            case .notABackup:
                "This file isn't a Chalk backup."
            case .newerVersion:
                "This backup was made by a newer version of Chalk. Update Chalk, then restore it."
            case .unknownKey(let word), .unknownValue(let word):
                "This backup holds “\(word)”, which this version of Chalk doesn't know, so it can't be restored exactly."
            case .invalidZones:
                "This backup's heart-rate zones aren't four rising values between 40 and 230 bpm, so it can't be restored."
            case .missingReference:
                "This backup puts an exercise or a machine in a group or gym it doesn't hold, so it can't be restored."
            case .duplicateID:
                "This backup holds the same row twice, so it can't be restored."
            case .enduranceGoalWithoutZones:
                "This backup holds an endurance goal but no heart-rate zones, so it can't be restored."
            case .damaged:
                "This backup is damaged and can't be restored."
            }
        }
    }
}

extension Backup: Codable {

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case format, version, madeAt, settings, groups, gyms, exercises
    }

    /// The header is read first, so a file that isn't a backup, or is from a newer Chalk,
    /// says so rather than whatever else it gets wrong.
    init(from decoder: any Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self),
              let format = try? container.decode(String.self, forKey: .format),
              format == Self.format
        else { throw Refusal.notABackup }
        self.format = format
        version = try container.decode(Int.self, forKey: .version)
        guard version <= Self.currentVersion else { throw Refusal.newerVersion }
        try decoder.refuseUnknownKeys(CodingKeys.names)
        madeAt = try container.decode(Date.self, forKey: .madeAt)
        settings = try container.decode(Settings.self, forKey: .settings, default: Settings())
        groups = try container.decode([Group].self, forKey: .groups, default: [])
        gyms = try container.decode([Gym].self, forKey: .gyms, default: [])
        exercises = try container.decode([Exercise].self, forKey: .exercises, default: [])
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(version, forKey: .version)
        try container.encode(madeAt, forKey: .madeAt)
        try container.encode(settings, forKey: .settings, unless: Settings())
        try container.encode(groups, forKey: .groups, unless: [])
        try container.encode(gyms, forKey: .gyms, unless: [])
        try container.encode(exercises, forKey: .exercises, unless: [])
    }
}

extension Backup.Settings: Codable {

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case heartRateZones, weightUnit
    }

    init(from decoder: any Decoder) throws {
        try decoder.refuseUnknownKeys(CodingKeys.names)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        heartRateZones = try container.decodeIfPresent([Int].self, forKey: .heartRateZones)
        if let heartRateZones, HeartRateZones(lowerBounds: heartRateZones) == nil {
            throw Backup.Refusal.invalidZones
        }
        let rawUnit = try container.decode(String.self, forKey: .weightUnit, default: WeightUnit.kg.rawValue)
        guard let weightUnit = WeightUnit(rawValue: rawUnit) else { throw Backup.Refusal.unknownValue(rawUnit) }
        self.weightUnit = weightUnit
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(heartRateZones, forKey: .heartRateZones)
        try container.encode(weightUnit.rawValue, forKey: .weightUnit, unless: WeightUnit.kg.rawValue)
    }
}

extension Backup.Group: Codable {

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, name, sortIndex, half
    }

    init(from decoder: any Decoder) throws {
        try decoder.refuseUnknownKeys(CodingKeys.names)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name, default: "")
        sortIndex = try container.decode(Int.self, forKey: .sortIndex, default: 0)
        half = try container.decode(String.self, forKey: .half, default: Half.strength.rawValue)
        try Backup.refuseUnknown(half, as: Half.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name, unless: "")
        try container.encode(sortIndex, forKey: .sortIndex, unless: 0)
        try container.encode(half, forKey: .half, unless: Half.strength.rawValue)
    }
}

extension Backup.Gym: Codable {

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, name, isArchived
    }

    init(from decoder: any Decoder) throws {
        try decoder.refuseUnknownKeys(CodingKeys.names)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name, default: "")
        isArchived = try container.decode(Bool.self, forKey: .isArchived, default: false)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name, unless: "")
        try container.encode(isArchived, forKey: .isArchived, unless: false)
    }
}

extension Backup.Exercise: Codable {

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, name, kind, unit, group, machines, entries
    }

    init(from decoder: any Decoder) throws {
        try decoder.refuseUnknownKeys(CodingKeys.names + Backup.GoalFields.CodingKeys.names)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name, default: "")
        kind = try container.decode(String.self, forKey: .kind, default: ExerciseKind.freeWeight.rawValue)
        try Backup.refuseUnknown(kind, as: ExerciseKind.self)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        if let unit { try Backup.refuseUnknown(unit, as: ErgUnit.self) }
        group = try container.decodeIfPresent(UUID.self, forKey: .group)
        goal = try Backup.GoalFields(from: decoder)
        machines = try container.decode([Backup.Machine].self, forKey: .machines, default: [])
        entries = try container.decode([Backup.Entry].self, forKey: .entries, default: [])
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name, unless: "")
        try container.encode(kind, forKey: .kind, unless: ExerciseKind.freeWeight.rawValue)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(group, forKey: .group)
        try goal.encode(to: encoder)
        try container.encode(machines, forKey: .machines, unless: [])
        try container.encode(entries, forKey: .entries, unless: [])
    }
}

extension Backup.Machine: Codable {

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, manufacturer, label, gym, entries
    }

    init(from decoder: any Decoder) throws {
        try decoder.refuseUnknownKeys(CodingKeys.names + Backup.GoalFields.CodingKeys.names)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        gym = try container.decodeIfPresent(UUID.self, forKey: .gym)
        goal = try Backup.GoalFields(from: decoder)
        entries = try container.decode([Backup.Entry].self, forKey: .entries, default: [])
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(manufacturer, forKey: .manufacturer)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(gym, forKey: .gym)
        try goal.encode(to: encoder)
        try container.encode(entries, forKey: .entries, unless: [])
    }
}

/// Written into the exercise's or machine's own object rather than nested, since the store
/// holds them flat.
extension Backup.GoalFields: Codable {

    /// Named so the exercise and machine readers know these keys are theirs too.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case goalReps, goalWeight, goalSetAt, goalZone, goalDuration, goalIntensity, goalIncline
    }
}

extension Backup.Entry: Codable {

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, reps, weight, duration, intensity, incline, averageHeartRate, peakHeartRate, date
    }

    init(from decoder: any Decoder) throws {
        try decoder.refuseUnknownKeys(CodingKeys.names)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reps = try container.decode(Int.self, forKey: .reps, default: 0)
        weight = try container.decode(Double.self, forKey: .weight, default: 0)
        duration = try container.decode(Int.self, forKey: .duration, default: 0)
        intensity = try container.decode(Double.self, forKey: .intensity, default: 0)
        incline = try container.decode(Double.self, forKey: .incline, default: 0)
        averageHeartRate = try container.decode(Int.self, forKey: .averageHeartRate, default: 0)
        peakHeartRate = try container.decode(Int.self, forKey: .peakHeartRate, default: 0)
        date = try container.decode(Date.self, forKey: .date)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reps, forKey: .reps, unless: 0)
        try container.encode(weight, forKey: .weight, unless: 0)
        try container.encode(duration, forKey: .duration, unless: 0)
        try container.encode(intensity, forKey: .intensity, unless: 0)
        try container.encode(incline, forKey: .incline, unless: 0)
        try container.encode(averageHeartRate, forKey: .averageHeartRate, unless: 0)
        try container.encode(peakHeartRate, forKey: .peakHeartRate, unless: 0)
        try container.encode(date, forKey: .date)
    }
}

// MARK: - Defaults left out

private extension KeyedEncodingContainer {

    /// Writes `value` unless it is the schema default, which a reader puts back.
    mutating func encode<T: Encodable & Equatable>(_ value: T, forKey key: Key, unless schemaDefault: T) throws {
        guard value != schemaDefault else { return }
        try encode(value, forKey: key)
    }
}

private extension KeyedDecodingContainer {

    /// The value at `key`, or the schema default when the file leaves it out.
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key, default schemaDefault: T) throws -> T {
        try decodeIfPresent(type, forKey: key) ?? schemaDefault
    }
}

// MARK: - Unknown keys and values

private extension Decoder {

    /// Refuses an object holding a key outside `known`. A keyed container drops the keys
    /// its `CodingKey` doesn't name, so the object is read again by any key at all.
    func refuseUnknownKeys(_ known: [String]) throws {
        let keys = try container(keyedBy: AnyKey.self).allKeys.map(\.stringValue)
        if let unknown = keys.sorted().first(where: { !known.contains($0) }) {
            throw Backup.Refusal.unknownKey(unknown)
        }
    }
}

private extension CaseIterable where Self: CodingKey {
    /// Every key's name.
    static var names: [String] { allCases.map(\.stringValue) }
}

/// Any key an object holds.
private struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private extension Backup {

    /// Refuses a raw value `type` doesn't have.
    static func refuseUnknown<T: RawRepresentable<String>>(_ rawValue: String, as type: T.Type) throws {
        guard T(rawValue: rawValue) != nil else { throw Refusal.unknownValue(rawValue) }
    }
}
