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
/// The weight and distance units arrive with their own version (SPEC §15.2); until then a
/// backup carries none.
///
/// The shape, the encoding and the version follow *How does a Chalk library round-trip
/// exactly through a readable backup file?* (https://github.com/hermanno3005/Chalk/issues/128).
struct Backup: Equatable, Sendable {

    /// What the file says it is, so a picker that offers any JSON can tell a backup apart.
    static let format = "Chalk backup"

    /// This Chalk's file version. Version 1 carries no units.
    static let currentVersion = 1

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

    /// A backup read back from a file's bytes.
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
        self = try decoder.decode(Backup.self, from: data)
    }
}

extension Backup: Codable {

    private enum CodingKeys: String, CodingKey {
        case format, version, madeAt, settings, groups, gyms, exercises
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(String.self, forKey: .format)
        version = try container.decode(Int.self, forKey: .version)
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

    private enum CodingKeys: String, CodingKey {
        case heartRateZones
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        heartRateZones = try container.decodeIfPresent([Int].self, forKey: .heartRateZones)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(heartRateZones, forKey: .heartRateZones)
    }
}

extension Backup.Group: Codable {

    private enum CodingKeys: String, CodingKey {
        case id, name, sortIndex, half
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name, default: "")
        sortIndex = try container.decode(Int.self, forKey: .sortIndex, default: 0)
        half = try container.decode(String.self, forKey: .half, default: Half.strength.rawValue)
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

    private enum CodingKeys: String, CodingKey {
        case id, name, isArchived
    }

    init(from decoder: any Decoder) throws {
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

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, unit, group, machines, entries
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name, default: "")
        kind = try container.decode(String.self, forKey: .kind, default: ExerciseKind.freeWeight.rawValue)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
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

    private enum CodingKeys: String, CodingKey {
        case id, manufacturer, label, gym, entries
    }

    init(from decoder: any Decoder) throws {
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
extension Backup.GoalFields: Codable {}

extension Backup.Entry: Codable {

    private enum CodingKeys: String, CodingKey {
        case id, reps, weight, duration, intensity, incline, averageHeartRate, peakHeartRate, date
    }

    init(from decoder: any Decoder) throws {
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
