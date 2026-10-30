import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// A backup as the share sheet hands it on: a plain `.json` file named for the day it was
/// made, `Chalk backup 2026-03-12.json`, offered to *Save to Files*, AirDrop, Mail and the
/// rest (SPEC §15.1).
///
/// **A file, not data**: Mail, Messages, Notes and AirDrop offer themselves only for a
/// file. **Plain JSON with no type of Chalk's own**, because the point of a backup is that
/// any text editor opens it, and Chalk declares no document type, so it is never offered
/// *Open in Chalk*.
///
/// **Built lazily**, only when a destination asks, from the main context so unsaved edits
/// are included. **Chalk keeps no file of its own afterwards**: the file is written into a
/// folder of Chalk's in `tmp/`, emptied before each share, whenever Settings closes and
/// at launch. There is no callback for the share sheet finishing, and the sheet is gone
/// once Settings is.
struct BackupFile: Transferable, Sendable {

    let container: ModelContainer
    /// Read when Settings opens rather than at the share: Settings' own Save closes it, so
    /// they cannot change while the share row is on screen.
    let settings: Backup.Settings

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            SentTransferredFile(try await file.write())
        }
    }

    /// Where a shared backup waits for its destination to copy it.
    static let directory = URL.temporaryDirectory.appending(path: "ChalkBackup")

    @MainActor
    private func write() throws -> URL {
        try Self.write(Backup(of: container.mainContext, settings: settings))
    }

    /// Writes `backup` into `directory`, emptied first, and returns the file. The name's
    /// day is the day in `timeZone`, the device's own.
    @discardableResult
    static func write(_ backup: Backup, into directory: URL = directory, timeZone: TimeZone = .current) throws -> URL {
        let data = try backup.encoded()
        clear(directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let day = backup.madeAt.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
        let url = directory.appending(path: String(localized: "Chalk backup \(day)") + ".json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The bytes of a file picked to restore. The importer hands a security-scoped URL,
    /// and the read is coordinated so a file provider fetches a file that isn't on the
    /// phone yet, such as an evicted iCloud Drive file. Chalk reads it once and keeps no
    /// bookmark.
    static func read(_ url: URL) throws -> Data {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var contents: Result<Data, any Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            contents = Result { try Data(contentsOf: url) }
        }
        if let coordinationError { throw coordinationError }
        return try contents.get()
    }

    /// Removes every shared file. A folder that is not there is already clear.
    static func clear(_ directory: URL = directory) {
        try? FileManager.default.removeItem(at: directory)
    }
}
