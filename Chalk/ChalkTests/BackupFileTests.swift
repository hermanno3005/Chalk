import Foundation
import Testing

@testable import Chalk

/// The file a backup is handed to the share sheet as (SPEC §15.1). **Chalk keeps no file
/// of its own afterwards**: it writes one only when a destination asks, into a folder of
/// its own that it empties before every export and whenever Settings closes.
@Suite("Backup file")
struct BackupFileTests {

    private let directory = URL.temporaryDirectory.appending(path: "chalk-tests-\(UUID().uuidString)")

    private func backup(madeAt interval: TimeInterval) -> Backup {
        Backup(
            madeAt: Date(timeIntervalSinceReferenceDate: interval),
            settings: Backup.Settings(heartRateZones: [117, 140, 158, 170]),
            groups: [],
            gyms: [],
            exercises: []
        )
    }

    private func files() throws -> [String] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
    }

    @Test("A backup is written as a JSON file named for the day it was made")
    func theFileIsNamedForItsDay() throws {
        // 2026-10-24 23:30 UTC is already the 25th in Berlin.
        let made = backup(madeAt: 814_577_400)

        let url = try BackupFile.write(made, into: directory, timeZone: TimeZone(identifier: "Europe/Berlin")!)

        #expect(url.lastPathComponent == "Chalk backup 2026-10-25.json")
        #expect(try Backup(decoding: Data(contentsOf: url)) == made)
    }

    @Test("Each export replaces the one before, so the folder never holds more than one")
    func eachExportReplacesTheLast() throws {
        try BackupFile.write(backup(madeAt: 814_500_000), into: directory, timeZone: .gmt)
        try BackupFile.write(backup(madeAt: 814_600_000), into: directory, timeZone: .gmt)

        #expect(try files() == ["Chalk backup 2026-10-25.json"])
    }

    @Test("Clearing leaves no backup file behind")
    func clearingLeavesNoFile() throws {
        try BackupFile.write(backup(madeAt: 814_500_000), into: directory, timeZone: .gmt)

        BackupFile.clear(directory)

        #expect(try files().isEmpty)
    }
}
