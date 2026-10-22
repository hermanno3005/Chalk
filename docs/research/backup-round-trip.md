# How a backup round-trips exactly

**Date:** 2026-10-23
**Question:** [#128](https://github.com/hermanno3005/Chalk/issues/128). How does a Chalk library
round-trip *exactly* through a readable backup file, on iOS 18 with SwiftData at schema `3.0.0`?
Part of map [#127](https://github.com/hermanno3005/Chalk/issues/127).
**Scope:** encoding, versioning, the file type and share sheet, reading a file back, the
all-or-nothing replace, and where the confirmation's numbers come from.
[ADR-0010](../adr/0010-chalk-makes-and-restores-backups.md) has already decided *what* a backup
is (one readable file, a replace and never a merge, no automatic backup, the share sheet), and
none of that is reopened here.
**Status:** findings only. Nothing is built.

**Sources.** The primary sources are Apple's developer documentation, the
[swift-foundation](https://github.com/swiftlang/swift-foundation) source that Apple's
`JSONEncoder` and `JSONDecoder` are built from, and the Swift runtime's float printer. Where the
documentation is silent or wrong, the claim was **run**: a small SwiftData and `JSONEncoder` probe
ran on the **iOS 18.5 simulator** (`xcrun simctl spawn`, binary built for
`arm64-apple-ios18.0-simulator`) and on macOS 27, and both gave the same results. Its output is
quoted where it settles a point, and §8 lists what is still unverified.

## Bottom line

1. **Encoding.** Use `JSONEncoder` with `[.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]`.
   Every `Double` round-trips bit for bit: the encoder writes Swift's shortest exact
   `description`, and the probe found no failure in 200,000 random bit patterns. **No built-in
   date strategy is both readable and exact.** `.iso8601` drops the fraction (it was out by
   0.78 s on `Date.now`), and `.secondsSince1970` corrupts about 40 % of dates. Write dates with a
   small custom strategy, `2026-10-22T21:59:55.521741Z`, whose fractional digits are taken from
   `timeIntervalSinceReferenceDate.description`. It is readable, and it was exact on 200,000 of
   200,000 dates. Keep every row's own `id` UUID; no ids local to the file. Lay the file out as a
   tree: groups and gyms first, then each exercise or erg with its machines nested inside it and
   its entries nested under the machine they were logged on. Nesting makes invariant 1 structural,
   and the only cross-references left are `group` and `gym`, by UUID.
2. **Versioning.** The file carries `"format": "Chalk backup"` and an integer `"version"`. Bump
   the version whenever a writer can emit a key the previous reader does not know. A missing key
   always means the attribute's schema default, so a newer Chalk reads every older file, and a
   `bar` from a 1-version file arrives as `nil`, as SwiftData's in-place migration gives it to
   existing rows. An **older Chalk refuses a newer file** outright, and also rejects any unknown
   key. The probe shows that synthesized `Decodable` drops `"bar": 20` without a word, and a
   silent drop is exactly the inexact restore ADR-0010 rules out.
3. **The file type.** Plain JSON: `UTType.json`, extension `.json`, a name like
   `Chalk backup 2026-03-12.json`, and **no exported type**. Apple says not to redeclare a type
   the system already provides, and `.json` opens in any text viewer, which is the point of a
   readable file. Share through `ShareLink` with a `Transferable` whose `FileRepresentation`
   writes into `tmp/`. Apple's `ShareLink` documentation says Mail, Messages, Notes and AirDrop
   want a file. Chalk empties its own export folder at launch and before each export, and the
   system purges `tmp/` anyway.
4. **Reading one back.** Use `.fileImporter(allowedContentTypes: [.json])`. Call
   `startAccessingSecurityScopedResource()`, read through `NSFileCoordinator` (which fetches an
   iCloud Drive file that is not downloaded yet), then call `stop…`. An AirDropped file is saved
   to Files and picked from there. Chalk declares no document types, so it is never offered
   *Open in Chalk*.
5. **Replacing everything.** Use **one fresh `ModelContext` with `autosaveEnabled = false` set
   explicitly**. Fetch and `delete(_:)` every row of all five entities, insert the new graph, and
   call one `save()`. On iOS 18.5 that is a single `BEGIN EXCLUSIVE … COMMIT`, and a throw before
   the save followed by `rollback()` left the store exactly as it was. **Never use
   `delete(model:where:)`.** It is documented as acting "during the next save", but it runs and
   commits immediately as a batch `DELETE`, and `rollback()` does not bring the rows back.
   Swapping the store file is rejected, because SwiftData gives no way to close a container or
   reach `replacePersistentStore`. The zones and units in `UserDefaults` join afterwards: decode
   and validate everything before touching anything, commit the store, and only then write the
   defaults, which cannot fail. Last, reopen the container and rebuild the root, as a relaunch
   would.
6. **The confirmation's numbers.** Count on decode. *1,240* is a `fetchCount` of entries that
   have an exercise. *980* is the number of entries in the decoded file, which has to be decoded
   and validated before the question is asked anyway. *12 Mar 2026* is the file's `madeAt`
   header. A stored count would be a second fact that could disagree with the body.

---

## 1. Encoding

### 1.1 Doubles round-trip exactly

`weight`, `intensity`, `incline`, `goalWeight`, `goalIntensity` and `goalIncline` are `Double`s.

- **The encoder writes `description`.** In swift-foundation's `JSONWriter` (release/6.0, the
  iOS 18 generation), a finite float becomes `float.description`, with a trailing `.0` stripped,
  so `60.0` is written `60`. NaN and ±infinity throw under the default
  `nonConformingFloatEncodingStrategy`, which is what a backup wants. A NaN in the store would
  fail the backup loudly rather than write something that cannot come back.
  ([JSONWriter.swift, release/6.0, lines 110–125](https://github.com/swiftlang/swift-foundation/blob/release/6.0/Sources/FoundationEssentials/JSON/JSONWriter.swift);
  the same code is on `main` in `JSONEncoder.swift`, `finiteNumberString`)
- **`description` is shortest and exact.** The Swift runtime's printer promises: *"Always
  Accurate. Converting the decimal form back to binary will always yield exactly the same value.
  For the IEEE 754 formats, the round-trip will produce exactly the same bit pattern in memory"*,
  and *"Always Short… the minimum number of significant digits."*
  ([SwiftDtoa.cpp, release/6.0](https://github.com/swiftlang/swift/blob/release/6.0/stdlib/public/runtime/SwiftDtoa.cpp))
  It writes decimal rather than exponential form for magnitudes from 10⁻⁴ up to 2⁵⁴
  (`finishFormatting`, same file), which covers every number Chalk holds.
- **The decoder parses with `strtod_l` in the C locale**
  ([JSONScanner.swift, release/6.0](https://github.com/swiftlang/swift-foundation/blob/release/6.0/Sources/FoundationEssentials/JSON/JSONScanner.swift)).
  Neither Apple nor swift-foundation documents that Darwin's `strtod` is correctly rounded, so
  this was run. On the iOS 18.5 simulator, 200,000 random finite bit patterns went through
  `JSONEncoder` and back with **0 failures**. Chalk's own values print as people write them:
  `57.5`, `60`, `15.1`, `0.1`, `72.5`, `102.3`.
- **That this is the code Apple ships** rests on Swift.org's statement that *"Foundation has a
  brand-new Swift implementation for `JSONDecoder` and `JSONEncoder`"*
  ([Foundation preview](https://www.swift.org/blog/foundation-preview-now-available/)), on the
  `#if FOUNDATION_FRAMEWORK` branches in that source, and on Tony Parker's
  [Swift Forums announcement](https://forums.swift.org/t/swift-foundation-now-available/73530)
  that the release *"aligns with macOS 15 and iOS 18"*. The probe on iOS 18.5 behaved exactly as
  the source reads, trimmed `.0` included.

`Int`s (`reps`, `duration`, both heart rates, `sortIndex`, the goal ints and the zones) are
written as integer text and are exact by construction.

**Strings** (`name`, `manufacturer`, `label`, the raw values of `kind`, `unit` and `half`) are
written as their UTF-8 bytes with JSON escapes, and nothing normalises them. Add
`.withoutEscapingSlashes`, or a group named `Push/Pull` reads `Push\/Pull` in the file.

### 1.2 Dates: no built-in strategy is both readable and exact

`Entry.date` and `goalSetAt` are `Date`s, and a `Date` is a `Double` of seconds since
2001-01-01. `Date.now` carries sub-microsecond bits, and exactness matters to Chalk. Lap-list
intervals saved together differ by microseconds, so history order depends on those bits, and a
goal's origin is *entries dated before `goalSetAt`*, so an entry and a goal in the same second
must stay on the right sides of each other.

| Strategy | Readable | Exact | Evidence |
|---|---|---|---|
| `.iso8601` | yes | **no**, drops the fraction | Apple: *"The default ISO8601FormatStyle includes the time but not the fractional seconds"* ([time(includingFractionalSeconds:)](https://developer.apple.com/documentation/foundation/date/iso8601formatstyle/time(includingfractionalseconds:))). The probe: `Date.now` came back 0.78 s early. With fractional seconds it keeps only milliseconds (`…09.274` in Apple's own example). |
| `.secondsSince1970` / `.millisecondsSince1970` | no | **no** | Converting to 1970 adds 978,307,200 s in floating point. The probe: **39,680 of 100,000** random 2023–2033 dates came back different on iOS 18.5. |
| `.deferredToDate` | no (`795000069.12345672`) | yes | `Date.encode` writes `timeIntervalSinceReferenceDate`. 0 failures in 100,000. |
| **Custom, recommended** | yes | yes | 0 failures in 200,000, on iOS 18.5 and on macOS 27. |

**The recommended strategy.** Take `t = date.timeIntervalSinceReferenceDate` and its
`t.description`, for example `"814399195.521741"`. Format the whole seconds (the part before the
`.`) with `Date.ISO8601FormatStyle` in GMT, and splice the digits after the `.` in as the
fraction: `2026-10-22T21:59:55.521741Z`. A whole second stays `2023-11-14T22:13:20Z`. To decode,
parse the part before the `.` as an ISO date, take its whole `timeIntervalSinceReferenceDate`,
rebuild the string `"<whole>.<digits>"` and parse it as a `Double`. That is the same decimal text
`description` produced, so by §1.1 it is the same bits.

This is valid ISO 8601 and RFC 3339, both of which allow any number of fractional digits. It is
about twenty lines in `.custom` encode and decode closures. One limit: `description` truncates
toward zero, so a date in the second before 2001-01-01 loses its sign. Chalk never holds one,
since every date is `Date.now` or later. The writer asserts `t >= 0`, and a test pins it.

*Considered:* writing both a readable `"date"` and an exact `"t"` number. Rejected, because two
fields that must agree will stop agreeing after a hand edit, and the reader then has to choose
one.

### 1.3 Relationships and identity

**Keep the store's own `id: UUID` on every row.** `id` is a stored attribute, so an exact
round-trip includes it. Keeping it also means `currentGymID` in `UserDefaults` still resolves
after you restore your own backup, and if it does not, it already reads as *no gym selected*
(SPEC §3). Ids local to the file would rebuild the graph just as well, but they would change every
`id` on restore, so the restore would not be exact.

**Shape the file as a tree that mirrors the cascade rules.**

```json
{
  "format": "Chalk backup",
  "version": 1,
  "madeAt": "2026-03-12T07:41:09.1234567Z",
  "settings": { "heartRateZones": [128, 145, 160, 172], "weightUnit": "kg", "distanceUnit": "km" },
  "groups": [ { "id": "6F1C…", "half": "strength", "name": "Push", "sortIndex": 0 } ],
  "gyms":   [ { "id": "0B7E…", "name": "Fitness X" } ],
  "exercises": [
    {
      "id": "A2D4…", "name": "Chest Press", "kind": "gymBound", "group": "6F1C…",
      "machines": [
        {
          "id": "C9E0…", "label": "Plate-loaded", "gym": "0B7E…",
          "goalReps": 8, "goalWeight": 72.5, "goalSetAt": "2023-11-17T05:46:40Z",
          "entries": [ { "id": "E115…", "reps": 8, "weight": 60, "date": "2023-11-14T22:13:20Z" } ]
        }
      ],
      "entries": []
    }
  ]
}
```

- **`Exercise` holds its `machines`, and a `Machine` holds its `entries`.** The exercise's own
  `entries` list holds only the entries with no machine. An entry's exercise is the one it is
  nested in, so **invariant 1 (`entry.machine?.exercise == entry.exercise`) cannot be broken by
  the file**. If a store ever held a row that broke it, the file would carry it as the machine's
  exercise. The invariant says that row is never produced, so this is accepted rather than
  modelled.
- **`group` and `gym` are the only references**, written as the target's UUID. A `null` or
  missing `gym` is invariant 3's gym-less machine and round-trips as one. A missing `group` is
  Ungrouped.
- **What is not written.** An entry with a nil `exercise` (invariant 2: *treated as
  non-existent*) and a machine with a nil `exercise` are not written. Neither is anything derived.
- **Every attribute is written by its stored name and raw value.** That means `kind`, `unit` and
  `half` as their strings, the flat goal fields (`goalReps`, `goalWeight`, `goalSetAt`,
  `goalZone`, `goalDuration`, `goalIntensity`, `goalIncline`) rather than a `Goal` value, and
  `isArchived`. A partly filled goal, which invariant 8 calls *no goal*, still round-trips
  exactly, because the file never interprets it.
- **A key that holds its schema default is left out.** That is a nil optional, `0` on an
  interval field of a lift (or on `reps` and `weight` of an interval), `false` for `isArchived`,
  and `strength` for `half`. A lift entry then reads `reps`, `weight` and `date` and nothing else.
  `id` and `date` are always written. The rule *absent means the schema default* is also the
  versioning rule in §2, so it costs nothing extra.
- **Sort every array**: groups by `half` and then `sortIndex`, gyms and exercises by `name` and
  then `id`, machines by `id`, and entries by `date` and then `id`. `.sortedKeys` is **required,
  not cosmetic**. swift-foundation holds a JSON object as `[String: JSONEncoderValue]`
  ([JSONEncoder.swift](https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/JSON/JSONEncoder.swift),
  `case object`), and Swift's hash seed changes per process, so without sorting the key order
  changes from run to run. With both in place, **backup → restore → backup gives the same
  bytes**, and that is the test (§7).

The entities and attributes at schema `3.0.0`, all of which the file carries:

| Entity | Attributes | References |
|---|---|---|
| `ExerciseGroup` | `id`, `name`, `sortIndex`, `half` | none |
| `Gym` | `id`, `name`, `isArchived` | none |
| `Exercise` | `id`, `name`, `kind`, `unit`, the seven goal fields | `group` (by id); owns `machines`, `entries` |
| `Machine` | `id`, `manufacturer`, `label`, the seven goal fields | `gym` (by id); owns `entries` |
| `Entry` | `id`, `reps`, `weight`, `duration`, `intensity`, `incline`, `averageHeartRate`, `peakHeartRate`, `date` | nested, so implied |
| `UserDefaults` | `heartRateZones` (four `Int`s), the weight unit and the distance unit (keys to be named by the §15.2 build) | none |

**Not in the file**, because CONTEXT.md's *Backup* lists only the zones and both units:
`currentGymID`, the remembered half (`com.hermannaust.Chalk.half`), the plate-breakdown switch,
and the suggested-groups seed flags. These are device preferences.

## 2. Versioning

- **The header** is `"format": "Chalk backup"`, which identifies the file when the picker offers
  any JSON, plus `"version": <Int>` and `"madeAt"`. Use an integer of its own rather than the
  schema version: the zones and units change the file without touching the schema, and
  `VersionedSchema` already numbers the store (SPEC §3).
- **A newer Chalk reading an older file.** Decode every key with `decodeIfPresent` and fall back
  to the schema default. When `Exercise` gains `bar: Double?`, a version-1 file has no `bar`, so
  every exercise comes back with no bar. That is the same value SwiftData's in-place additive
  migration gives existing rows, so a restored old backup and an upgraded old store agree. The
  probe confirms that `decodeIfPresent` on a missing key gives `nil`. **Keep every version's
  reader.** In practice the same `decodeIfPresent` code covers them, and a frozen fixture file per
  version proves it (§7).
- **An older Chalk reading a newer file.** It must **refuse**, saying *This backup was made by a
  newer version of Chalk*, and leave the library alone. The probe:
  `old reader on newer file: Bench Press (bar silently dropped)`. Synthesized `Decodable` ignores
  keys it does not know, so a version-1 reader would restore every bar as nil and call it a
  success. Use two guards:
  1. `version > Self.currentVersion` → refuse before decoding the body.
  2. **Reject unknown keys at every level**, by comparing each keyed container's `allKeys`
     against the known set. This also catches a hand edit that misspells `weight`, which would
     otherwise come back as the default `0`, and it catches a future writer that forgot to bump
     the version.
- **Bump rule:** bump whenever a writer can emit a key the previous reader does not know: a new
  attribute, a new setting, or a new raw value of `kind`, `unit` or `half`. Additive store
  changes and additive file changes then move together.

## 3. The file type and the share sheet

**Plain JSON, with no exported type.** Apple: *"If your app uses a type that this framework
provides, don't redeclare it in your app's bundle"*, and an exported type is for *"your app's
proprietary data formats"*
([Defining file and data types for your app](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app)).
A backup is ordinary JSON whose whole purpose is to be readable, and `.json` opens in any
editor and in Quick Look. Name the file `Chalk backup 2026-03-12.json`.

*Considered:* an exported `com.hermannaust.Chalk.backup` conforming to `public.json`, with a
`.chalkbackup` extension. It would let the picker show only backups, and with
`CFBundleDocumentTypes` added, offer *Open in Chalk* from Files and AirDrop. It costs an
`Info.plist` file beside the generated one (the target uses `GENERATE_INFOPLIST_FILE = YES` and
has none today), it makes the file opaque to a double-click on a Mac, and the spec asks for no
*Open in*. It stays available later: the format key does not change, and the importer would then
accept both types.

**The share sheet.** `ShareLink(item: BackupFile(…), preview: SharePreview("Chalk backup"))`,
where `BackupFile: Transferable` has
`FileRepresentation(exportedContentType: .json) { … SentTransferredFile(url) }`.

- **A file, not data.** Apple: *"some applications offer their sharing service for files, but
  not for a wide range of different data types, for example, Mail.app, Notes.app, Messages.app
  or AirDrop. If you don't see a particular sharing service in the presented `ShareLink`, try
  adding a `FileRepresentation`"* ([ShareLink](https://developer.apple.com/documentation/swiftui/sharelink)).
  A `DataRepresentation` with `.suggestedFileName` would write nothing to disk, but it risks
  exactly those targets.
- **It is lazy.** The exporting closure is `@Sendable (Item) async throws -> SentTransferredFile`
  ([init(exportedContentType:shouldAllowToOpenInPlace:exporting:)](https://developer.apple.com/documentation/coretransferable/filerepresentation/init(exportedcontenttype:shouldallowtoopeninplace:exporting:))),
  so the backup is built only when a destination asks for it, not each time Settings draws.
  Under Swift 6 the item can hold the `ModelContainer`, which is `Sendable`
  ([ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)). The
  closure takes a snapshot on the main actor from `mainContext` into a `Sendable` `Backup` value,
  so unsaved edits are included, and encodes it off the main actor.
- **Chalk keeps no file.** The closure writes `tmp/ChalkBackup/<name>.json`.
  `SentTransferredFile(_:allowAccessingOriginalFile:)` defaults to `false`, so receivers are not
  handed Chalk's own file
  ([SentTransferredFile](https://developer.apple.com/documentation/coretransferable/senttransferredfile)).
  There is no completion callback to delete it, so Chalk empties `tmp/ChalkBackup/` at launch and
  before each export. Apple, on `tmp/`: *"Your app should remove files from this directory when
  they are no longer needed; however, the system may purge this directory when your app is not
  running. The contents of this directory are not backed up"*
  ([File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html)).
  The export directory lives only between a share and the next launch.

## 4. Reading one back

- **`.fileImporter(isPresented:allowedContentTypes: [.json])`**, from Settings and from
  onboarding's *Restore from a backup*. Apple: *"This dialog provides security-scoped URLs. Call
  the `startAccessingSecurityScopedResource` method to access or bookmark the URLs, and the
  `stopAccessingSecurityScopedResource` method to release the access"*
  ([fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:))).
  Balance every `start` with a `stop` in a `defer`. An unbalanced `start` *"leaks kernel
  resources"*
  ([startAccessingSecurityScopedResource()](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource())).
  Chalk reads the file once, so it keeps no bookmark.
- **Read inside `NSFileCoordinator().coordinate(readingItemAt:)`.** Apple's document-picker
  guidance says to *"use a file coordinator to perform read or write operations on the URL's
  contents"*
  ([Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories)).
  Coordination is what makes a file provider (iCloud Drive, or a third-party provider)
  materialise a file that is not local yet. Read it into `Data` inside the accessor, then decode
  outside it.
- **Where files come from.** Files and iCloud Drive come straight through the picker. An
  **AirDropped** `.json` arrives on the phone. Chalk declares no document types, so iOS offers to
  save it rather than *Open in Chalk*, and you pick it from Files. **Unverified on a device**; see
  §8.
- **Everything is decided before anything is touched.** Read, decode and validate the whole file
  first. That covers the format string, a version no newer than this Chalk's, no unknown keys,
  every `group` and `gym` reference resolving, unique ids per entity, every raw value parsing as
  its enum (`ExerciseKind`, `ErgUnit`, `Half`), the zones satisfying `HeartRateZones(lowerBounds:)`,
  and the units parsing. Any failure ends in one plain message, with the library and settings
  untouched.

## 5. Replacing everything

### 5.1 Delete-all and insert in one save, in a context of its own

On the iOS 18.5 simulator with `-com.apple.CoreData.SQLDebug 1`, a context that deleted five
fetched rows, inserted three and called `save()` once wrote:

```
BEGIN EXCLUSIVE
DELETE FROM ZTHING WHERE Z_PK = ? AND Z_OPT = ?   (×5)
INSERT INTO ZTHING(…) VALUES(…)                   (×3)
COMMIT
```

One SQLite transaction is all-or-nothing by SQLite's own design. Apple's documentation never
says that a `save()` is one transaction. Neither
[ModelContext.save()](https://developer.apple.com/documentation/swiftdata/modelcontext/save())
nor [NSManagedObjectContext.save()](https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext/save())
mentions it, and the
[Core Data Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/PersistentStoreFeatures.html)
reserves *atomic* for the XML and binary stores. **So the restore test must prove it in Chalk's
own suite (§7), not assume it.**

A replace that **failed halfway**, where every row was deleted and a new one inserted and then a
throw came before `save()`, followed by `rollback()`, left the store with exactly its old rows.
`hasChanges` was `false` after the rollback
([rollback()](https://developer.apple.com/documentation/swiftdata/modelcontext/rollback()):
*"Discards pending inserts and deletes"*).

The procedure:

1. Make a new `ModelContext(container)` and **set `autosaveEnabled = false` explicitly.** Apple
   says *"The default value is `false`"*
   ([autosaveEnabled](https://developer.apple.com/documentation/swiftdata/modelcontext/autosaveenabled)),
   but on iOS 18.5 and macOS 27 the probe printed `autosaveEnabled on new context: true`. An
   autosave between the deletes and the inserts would commit an empty library.
2. Fetch every row of **all five** entities and `delete(_:)` each one. Do not rely on the
   cascades: that also removes orphans that hang off nothing, such as an entry with a nil
   exercise, so the result is exactly the file and nothing more.
3. Build the new graph from the validated value. Insert the groups and gyms first, then each
   exercise with its machines and entries (inserting a root inserts its graph, per
   [ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)).
4. `try save()` once. On any throw from steps 2 to 4, call `rollback()` and report. The library
   is as it was.

**Never `delete(model:where:)`.** Apple says it removes models *"during the next save
operation"*
([delete(model:where:includeSubclasses:)](https://developer.apple.com/documentation/swiftdata/modelcontext/delete(model:where:includesubclasses:))).
On iOS 18.5 it ran at once as its own transaction
(`BEGIN EXCLUSIVE; DELETE FROM ZTHING WHERE Z_PK IN (SELECT …); COMMIT`). A second container saw
0 rows before any `save()`, and **`rollback()` did not bring them back**. A restore built on it
loses the library if anything after it fails.

**Also rejected:** `ModelContainer.deleteAllData()`, which *"immediately deletes all data… This
deletion is permanent and cannot be undone"*
([deleteAllData()](https://developer.apple.com/documentation/swiftdata/modelcontainer/deletealldata())),
and `erase()`. Both happen outside the transaction.

### 5.2 Swapping the store file: rejected

The idea is to build the backup into a new store at a temporary URL and rename it over
`default.store`. A rename is atomic, but the live `ModelContainer` holds `default.store` and its
`-wal`/`-shm` open, and SwiftData has no API to close a container. Core Data's
`replacePersistentStore(at:…)` exists for this, but SwiftData does not expose its coordinator.
Replacing an open SQLite file under a live connection invites corruption, and SPEC §2 treats
the store file as the one thing never to gamble with. Option 5.1 is atomic without it.

### 5.3 Bringing the `UserDefaults` in

The zones (and, after §15.2, the two units) live in `UserDefaults` (ADR-0008), which cannot join
an SQLite transaction. Order the steps so that the one step that can fail decides everything:

1. Validate the whole file (§4). Nothing has been written.
2. Commit the store (§5.1). If it fails, roll back and stop. Nothing has been written.
3. Write the defaults: the zones (`removeObject` when the backup has none, because a replace
   holds exactly what the backup held), both units, and **both suggested-groups seed flags set to
   `true`**, so the first-launch seed never adds *Push, Pull…* on top of a restored library. This
   matters on the onboarding path in particular. `UserDefaults.set` does not throw.
4. Rebuild the app's root: reopen the store with `ChalkStore.open()` and make a new
   `LibraryModel`, as a relaunch would. This avoids depending on how `mainContext` and the
   view models handle rows that another context deleted (§8).

The remaining window is a crash between steps 2 and 3, two adjacent statements on the main actor.
It would leave the restored library under this device's old zones and units. Nothing is lost,
since the backup file is still in hand, and restoring again repairs it. No marker file is worth
adding for that.

## 6. The confirmation's numbers

`This replaces 1,240 entries with 980 from 12 Mar 2026`:

- **1,240** is `fetchCount` of `Entry` where `exercise != nil`. Invariant 2 says an orphan is
  never counted. Both halves count.
- **980** is the number of entries in the decoded and validated file. The file has to be fully
  decoded before the question is asked anyway (§4), and counting a few thousand values is free.
- **12 Mar 2026** is the header's `madeAt`, formatted in the device's calendar. The file's
  modification date does not survive AirDrop and copies reliably, and the newest entry's date
  says when you last trained, not how stale the backup is.

*Rejected:* a count stored in the header. It would be a second fact that a hand edit, or a
writer bug, can make disagree with the body, and it saves nothing.

## 7. The tests, shaped like `SchemaMigrationTests`

1. **Round trip.** Build a fixed library in a `TemporaryStore`, with every attribute of every
   entity at a non-default value on at least one row. Include both halves, both kinds of goal on
   an exercise and on a machine, a gym-less machine, an archived gym, an Ungrouped erg, and dates
   with sub-second fractions (`Date(timeIntervalSinceReferenceDate: 795_000_069.123_456_7)`).
   Back it up, restore into a second `TemporaryStore`, and back up again. **The two files are
   byte-identical**, and a field-by-field check confirms it.
2. **Coverage.** For each entity in `Schema(versionedSchema: ChalkSchemaV1.self).entities`, the
   set of `attributes` names equals the keys the backup writes for that entity
   ([Schema.Entity](https://developer.apple.com/documentation/swiftdata/schema/entity)). When
   `bar` lands, this test fails until the backup carries it and the version is bumped.
3. **Frozen fixtures.** `Fixtures/Chalk-backup-1.json` is written by the app when version 1
   ships, as `Chalk-2.0.0.store` was. Every later Chalk must restore it, with new fields at their
   defaults.
4. **Refusals leave everything alone.** A newer `version`, an unknown key, a dangling `gym`, or a
   duplicate id is refused, and the store and defaults are byte-for-byte unchanged.
5. **Halfway.** A restore that throws after its deletes and before `save()` leaves every original
   row in place. This is the test that proves §5.1's single transaction in Chalk's own suite.
6. **Dates.** Random `Date`s in 2001–2100 survive the custom strategy exactly, and a negative
   interval is refused.

## 8. Unverified, and how to settle it

- **AirDrop, Mail and Save to Files with the `FileRepresentation`** (file name kept, offered as
  a file): try it on the phone once the share row exists.
- **An iCloud Drive file that is not downloaded**, picked in `fileImporter`: `NSFileCoordinator`
  should download it. Try it with an evicted file (*Remove Download* in Files).
- **That a `save()` is one transaction** in every case, rather than in the probe's: test 5 above.
- **The `autosaveEnabled` default** contradicts Apple's documentation on iOS 18.5. Setting it
  explicitly makes the question moot.
- **How `mainContext` and Chalk's view models react** when another context deletes the rows they
  hold: not tested, and avoided by rebuilding the root (§5.3 step 4).

## Appendix: the probe

A command-line Swift file with one `@Model` (`id: UUID`, `value: Double`, `date: Date`), built
with `swiftc -target arm64-apple-ios18.0-simulator` and run with
`xcrun simctl spawn <iPhone 16, iOS 18.5> exp-ios -com.apple.CoreData.SQLDebug 1`. Its output:

```
autosaveEnabled on new context: true
hasChanges after rollback: false
values after failed replace: [0.0, 100.0, 200.0]
count seen by another container after delete(model:) before save: 0
count after rollback, no save: 0
{"d":0.30000000000000004,"t":"2026-10-22T21:59:37Z"}
iso8601 date equal: false delta: -0.14374196529388428
random double failures: 0
57.5 -> [57.5]   60.0 -> [60]   15.1 -> [15.1]   72.5 -> [72.5]   -0.0 -> [-0]
deferredToDate failures: 0
secondsSince1970 failures: 39680 of 100000
exact readable format failures: 0 sample: 2027-01-18T03:25:36.8973856Z
old reader on newer file: Bench Press (bar silently dropped)
new reader on older file: bar = nil
OS: Version 18.5 (Build 22F77)
```
