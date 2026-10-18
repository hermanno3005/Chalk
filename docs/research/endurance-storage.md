# How an endurance record is stored

**Date:** 2026-10-18
**Question:** [#100](https://github.com/hermanno3005/Chalk/issues/100): how is an endurance
record stored, in SwiftData, under [ADR-0001](../adr/0001-local-swiftdata-with-cloudkit-shaped-schema.md)'s
CloudKit-shaped rules? Part of map [#88](https://github.com/hermanno3005/Chalk/issues/88).
**Scope:** whether an interval is an `Entry` or an entity of its own, whether an erg is an
`Exercise` and its machine a `Machine`, how an intensity and its unit are stored, where the
heart-rate zones live, how an endurance goal's fields sit beside ADR-0004's, and the `3.0.0`
migration and its test.
**Status:** findings only, on the never-merged `research/endurance-storage` branch. The
decision they recommend is drafted as
[ADR-0008](../adr/0008-endurance-adds-attributes-not-entities.md), **for review, not adopted**.

**Primary sources** are Apple's developer documentation, the SwiftData module interface in the
Xcode 27.1 SDK, Apple Frameworks Engineer replies on the developer forums, and one experiment
run for this ticket (§6.2). Developer forum posts by people who are not Apple engineers are
marked **secondary**. One claim stays **UNVERIFIED** on iOS, and §6 says which test settles it.

## Bottom line

1. **Endurance adds no entity.** An interval is an `Entry`, an erg is an `Exercise` with a
   unit, an erg's machine is a `Machine`, and an endurance group is an `ExerciseGroup` with a
   half. `3.0.0` is fifteen new attributes on four existing entities: no new entity, no new
   relationship, no new delete rule. The deciding argument is about relationships, not tidiness.
   Every repair Chalk has (merge, move to another gym, kind change) and every cascade works by
   re-pointing `Entry.machine` and `Machine.exercise`, and #93, #99 and #101 carry all of them
   over to ergs unchanged. A second entity would mean a second set of relationships that each of
   those paths has to remember. If one path forgets, the cascade deletes the history without
   saying anything, which is the failure ADR-0002's ordering rule exists to prevent.
2. **An `Exercise` is an erg exactly when its `unit` is set.** `unit: String?` is nil on every
   strength exercise, so all existing rows migrate as strength with nothing written. It is one
   of `speed`, `watts`, `split` or `level` on an erg. The unit is the discriminator, so no
   second field (`half`) has to agree with it. Transferable and gym-bound reuse `kind` as is.
3. **Intensity is a `Double` in the erg's unit, stored as typed.** A split is stored as
   seconds per 500 m. `Double` cannot hold 0.1 km/h exactly the way it holds a 2.5 kg plate,
   so every derived comparison (a mean rounded to the step, reached, the gap) is done in whole
   steps of the unit, behind one helper.
4. **The zones are one `UserDefaults` key holding four `Int`s.** They are not a SwiftData row
   and not `@AppStorage` on its own (that is a view-side wrapper over the same store). A
   singleton row is the one shape ADR-0001 cannot express, because there is no `.unique`. The
   zones sit inside the app container beside the store, so Download Container takes both. Even
   where they are lost, the only effect is ADR-0005's gate: no wrong number is ever shown.
5. **An endurance goal is four more optional fields on `Exercise` and `Machine`:**
   `goalZone`, `goalDuration`, `goalIntensity` and `goalIncline`. It **shares `goalSetAt`**.
   One row is never both halves, so the two halves' goals never meet on a row, and sharing the
   field keeps `MachineGoals`' "most recently set wins" reading one field for both halves.
6. **Migration:** bump `versionIdentifier` to `3.0.0` in place with `stages` still empty, as
   2.0.0 was. I ran an experiment: an in-place bump with no stage adds **defaulted
   non-optional** attributes to existing rows and writes the default into them on disk. That
   was on macOS 27 and is still unverified on iOS. The required test reopens a real
   `Chalk-2.0.0.store`. Capture that file from the app **before** the schema is touched.

---

## 1. One entity or two for the record

### 1.1 The two shapes

**Option A: `Entry` carries both payloads.**

```swift
@Model final class Entry {
    // …2.0.0, unchanged: id, reps, weight, date, exercise, machine…
    var duration: Int = 0            // whole seconds, > 0 on an interval
    var intensity: Double = 0        // in the erg's unit, as typed, > 0 on an interval
    var averageHeartRate: Int = 0    // whole bpm
    var peakHeartRate: Int = 0       // whole bpm, >= averageHeartRate
    var incline: Double = 0          // percent, 0.5 steps; read on speed ergs only
}
```

**Option B: an entity of its own** (`EnduranceEntry`, still *Entry* in the glossary, the way
`ExerciseGroup` is *Group*). It has the same five attributes plus `date`, and to-one links to its
owner and its machine. Each owner gets a second to-many relationship with its own cascade:

```swift
@Relationship(deleteRule: .cascade, inverse: \EnduranceEntry.machine)
var enduranceEntries: [EnduranceEntry]? = []      // on Machine, and again on the owner
```

### 1.2 What each one adds to SPEC §3's list of invariants the schema cannot express

Neither option is free. The question is what kind of thing each one makes representable.

| | A: one `Entry` | B: two entities |
|---|---|---|
| Representable but meaningless | a lift row with zero interval fields, and an interval row with zero `reps`/`weight` | none inside a row |
| New invariants | *an entry has its owner's shape* (absorbed at a reader seam, §1.3) | *a machine's `entries` and `enduranceEntries` match its owner's half*; invariant 1 restated for the second entity; invariant 2 restated |
| Relationships per owner | one, unchanged | two, both cascading |
| What a missed case does | an interval is not read as a lift, so it is **absent** from the curve | a merge, move or kind change that re-points `entries` and forgets `enduranceEntries` has the cascade **delete** those entries when the emptied machine goes |

The last row decides it. ADR-0002 already names the hazard: *"reassign and flush before
deleting, or the cascade from `Machine` takes the entries with it."* Today there is one
relationship to reassign. Under B every repair path (`MachineMerge`, *Move to another gym…*,
`KindChange`'s pool and its move, `ExerciseDetailModel`'s delete flow) has two, and a missed one
is silent history loss in the paths the dev runs least often. Under A those paths need no change
to carry intervals, because an interval is an `Entry` on `Machine.entries`. This is the
**absent versus silently wrong** asymmetry `goal-storage.md` §1.2 used to choose fields over a
`Goal` entity, and it points the same way.

### 1.3 The cost of A, and the seam that absorbs it

A's cost is the half-filled row. The codebase already has the idiom for it: every `Entry`
attribute is defaulted for CloudKit, a zeroed row is representable, and `Entry.isALift`
(`reps >= 1 && weight > 0`) is the one place that decides whether a row counts
(`Chalk/Chalk/Model/Entry.swift`). An interval row keeps `reps == 0`, so **`isALift` is
already false for every interval**. `RepMaxCurve`, `LastEntry`, `Machine.lastLogged`,
`Gym.lastLogged` and `MachineHint` all filter through it, so none of them can pick up an
interval even when one is passed in. A sibling seam does the same job from the other side:

```swift
/// Whether this row is an interval: a duration, an intensity and both heart rates, peak
/// never below average. App-level, as `isALift` is (ADR-0001): a lift row is not one.
var isAnInterval: Bool {
    duration >= 1 && intensity > 0 && averageHeartRate > 0 && peakHeartRate >= averageHeartRate
}
```

### 1.4 `RepMaxCurve` stays pure

ADR-0002's bar is *"a plain struct built from `[Entry]` with no SwiftData dependency"*, and
callers do the scoping. Under A that holds unchanged. A strength caller passes a strength
scope, and even a mixed array derives correctly because the loop's first line is
`guard entry.isALift`. ADR-0006's zone line is a second plain struct over `[Entry]` plus the
zones, reading `isAnInterval`. Under B the type system would keep the two arrays apart, which is
real but small: `isALift` already gives that protection at the read side, and B pays for its
type safety with the doubled relationships.

### 1.5 How the names ticket answered *is it an entry?*

[#89](https://github.com/hermanno3005/Chalk/issues/89) decided on meaning that an interval
**is an Entry**: the atomic, session-less, mutable record, with two shapes (`CONTEXT.md`,
*Entry*). A matches the glossary one to one. B would need a `_Note_` to explain why the
glossary's one word is two Swift types. That is a tiebreaker only. §1.2 decides the question
without it.

**Verdict: A.**

---

## 2. Ergs: `Exercise` and `Machine`, or entities of their own

### 2.1 What the tickets already carried over

Resolutions on #88 that read *carried over*, *reused verbatim* or *unchanged*:

- **Scope and kind** ([#93](https://github.com/hermanno3005/Chalk/issues/93)): transferable is
  free-weight's counterpart, gym-bound is gym-bound, *"`Machine` is reused verbatim"*, the
  kind change is §8 *"carried over to ergs"*, and the hint carries over.
- **Library** ([#96](https://github.com/hermanno3005/Chalk/issues/96)): the endurance side is
  *"§7's screen over ergs, groups included"*, with §7.2's mechanics *"unchanged"*.
- **Goals** ([#99](https://github.com/hermanno3005/Chalk/issues/99)): stored *"as in
  ADR-0004"*, with merge and kind change keeping the most recently set goal.
- **Repair** ([#101](https://github.com/hermanno3005/Chalk/issues/101), open): applies the
  merge and kind-change rules to ergs.

All of those are written against `Exercise` today: `MachineScope`, `GoalScope`,
`MachineGoals`, `KindChange`, `MachineMerge`, `MachineHint`, `LibraryLayout`, `GroupsModel`,
`CreateExerciseSheet` and `ResumeCard`. If an erg is an `Exercise`, *carried over* is true
because the code is literally the same. If it is an `Erg` entity, each of them is either copied
or rewritten generically over a protocol. Either way that means rewriting shipped strength code
for a feature that never touches strength.

### 2.2 A separate `Erg` would add exactly the invariants ADR-0001 cannot express

With `Erg` as its own entity and `Machine` and `Entry` shared, as the glossary has them:

- `Machine` needs `erg: Erg?` beside `exercise: Exercise?`, which brings the invariant
  *exactly one of the two is set*. ADR-0001 rule 2 makes both optional, and nothing can say
  "exactly one".
- `Entry` needs the same `erg` beside `exercise`, the same XOR, and invariant 2 ("a nil
  `exercise` is non-existent") rewritten.
- `Gym.machines` is unchanged, but each machine row is now one of two things.

Giving ergs their own `ErgMachine` and `ErgEntry` too would remove the XORs. It would also break
#93's *"`Machine` reused verbatim"*, double `Gym`'s relationships, and multiply §1.2's
two-cascade hazard by every entity involved.

### 2.3 Reuse, and what it costs

**The mixing risk.** Every fetch of `Exercise` or `ExerciseGroup` now sees both halves. There
are few such sites, and they are easy to find:

| Site | Change |
|---|---|
| `LibraryModel.refresh` (`FetchDescriptor<Exercise>()`) | filter to the half on screen |
| `LibraryModel` lookup by id | none (an id is an id) |
| `GroupsModel.refresh`, `LibraryView` preview | filter groups to the half |
| `SuggestedGroups.seedIfNeeded` | count only its own half's groups, and give endurance its own flag key |
| `Machine.lastLogged`, `Gym.lastLogged`, `LastEntry`, `MachineHint` | read *a lift or an interval*, not `isALift`, wherever an erg's machine is asked (otherwise an erg machine never has a last-logged date and `MachineScope.opening` falls through to the name) |

Relationship traversals need no filter, because what they reach is one half by construction: a
group holds one half, an exercise's machines and entries are its own, and a machine's entries
are its exercise's. I checked that SwiftData filters both discriminators with plain predicates
on rows migrated from 2.0.0: `#Predicate { $0.unit == nil }` and
`#Predicate { $0.half == "strength" }` both match the migrated rows (§6.2).

**The new invariants under reuse** (to add to SPEC §3):

- *An exercise's `unit` is set at create on an erg, never cleared, and changed only while it
  has no entries.* Clearing it would turn an erg into a lift, so no path offers it.
- *An exercise sits only in a group of its own half* (`exercise.group?.half` matches
  `exercise.isErg`). This is the glossary's *"each half keeps its own groups"*. Create and
  Arrange only ever offer that half's groups.
- *A row's goal fields are its own half's* (§5).

Separate entities would add the two XORs and the restated invariants 1 and 2, so the count comes
out about even. What does differ is what happens when an invariant is broken. Under reuse, an erg
filed in a strength group shows on the wrong shelf and can be re-filed. Under separate
entities, a machine with both owners set, or neither, has no sensible reading at all.

### 2.4 The discriminator: `unit`, not a `half` field

An erg is defined by speaking a unit (*"It speaks one unit"*, `CONTEXT.md`, *Erg*), and a lift
never has one, because SPEC §11 rules out unit settings for strength. So `unit != nil` **is**
*this is an erg*:

```swift
/// The unit an erg's intensity is written in, or nil on a lift: **an exercise is an erg
/// exactly when this is set** (ADR-0008). Stored as the raw value, as `kind` is.
var unit: String?
var isErg: Bool { unit != nil }
```

A separate `half: String` on `Exercise` would be a second field that has to agree with the
first. Inferring the half from the unit means the two can never disagree. It also makes the
migration the proven-safe kind: an optional attribute added to existing rows, all of which read
nil and so read as strength. **`ExerciseGroup` still needs `half`**, because a group has no
unit: `half: String = Half.strength.rawValue`. The same `Half` enum backs the sticky segmented
control, `@AppStorage`, device-local like `currentGymID`, which #96 calls *sticky across
launches*.

**`kind` is reused as stored.** A transferable erg stores `ExerciseKind.freeWeight.rawValue`,
so a downloaded store reads `freeWeight` on a rower. Renaming raw values would need a custom
stage that rewrites rows, and that is not worth it to rename a label. A doc comment on
`ExerciseKind` says *free-weight on a lift, transferable on an erg*, and `isGymBound` keeps
working on both.

**The Swift name.** `Exercise` now holds ergs, while the glossary's *Exercise* narrows to
strength. `CONTEXT.md` already handles this kind of gap for *Group*, and the same `_Note_` works
here: *the Swift type for both is `Exercise`; an erg is an `Exercise` with a unit.* Renaming the
entity is technically lightweight-eligible (*"Renaming an entity or property"*,
[Migrating your data model automatically](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically)),
but it would ripple through every file for a name.

**Verdict: reuse `Exercise`, `Machine` and `ExerciseGroup`.**

---

## 3. Intensity, unit and incline

Decided by [#94](https://github.com/hermanno3005/Chalk/issues/94): stored as typed in the erg's
unit, never converted. The unit lives on the erg and is fixed once the erg has entries. Incline
is recorded on speed entries only.

| Field | Type | Stored as | Default |
|---|---|---|---|
| `Exercise.unit` | `String?` | raw value of `enum ErgUnit: String { case speed, watts, split, level }` | nil (a lift) |
| `Entry.duration` | `Int` | whole seconds | 0 |
| `Entry.intensity` | `Double` | **speed:** km/h, 0.1 steps (`15.0`). **Watts:** whole W (`220`). **Split:** **seconds per 500 m**, 0.1 steps (`105.3` is `1:45.3`). **Level:** whole (`12`) | 0 |
| `Entry.averageHeartRate` | `Int` | whole bpm | 0 |
| `Entry.peakHeartRate` | `Int` | whole bpm | 0 |
| `Entry.incline` | `Double` | percent, 0.5 steps; **read only when the erg's unit is speed** | 0 |

- **A raw `String`, not the enum and not `Codable`.** That is the house rule
  (`ExerciseKind.swift`: *"CloudKit mirroring wants a defaulted scalar attribute, and a `String`
  is readable in `sqlite3`"*). It also avoids SwiftData's composite attributes
  (`Schema.CompositeAttribute` in the SwiftData module interface), whose CloudKit behaviour
  `swiftdata-cloudkit.md` §1.2 found **no primary statement** for.
- **One `intensity` column, not one per unit.** The unit is fixed once the erg has entries, so
  a column per unit would be three always-zero columns on every row and would buy nothing.
- **Incline is defaulted, not optional.** Optional would make *absent on a non-speed erg*
  explicit. But a speed entry with a nil incline would then be a new broken state, while a
  defaulted 0 on a watts entry is never read, which is the same idiom as `reps == 0` on an
  interval. #94's *"0 % is a value, not a blank"* is about what you type, and the seeding (from
  your last entry, never a default) is the log sheet's job, not the schema's.
- **`Double` and the step.** SPEC §3 points out that 2.5 and 1.25 kg are exact in binary
  floating point, so `max()` and equality do not drift. 0.1 km/h is **not** exact. A typed
  `15.1` parses to the same `Double` every time and round-trips through the store unchanged, so
  equality between two typed values holds. But a **mean** of `15.1`s need not compare equal to
  `15.1`. ADR-0006 already rounds every point to its unit's step, so the rule to write down is:
  **every derived comparison goes through whole steps**, e.g.
  `ErgUnit.steps(_ value: Double) -> Int` (`Int((value / step).rounded())`). That covers the
  zone line's rounding, *reached* (ADR-0007's `≥`, or `≤` on a split), the gap in steps and the
  ring. Storing integer steps instead (150 for 15.0 km/h) was rejected. The step differs by unit,
  so the bare column would be ambiguous in a downloaded store, and #94's *"as typed"* reads most
  plainly as the number itself.
- **Pace is never stored** (#94). The split's `1/split³` line is computed at read time
  (ADR-0006).

---

## 4. The zone setting

ADR-0005: four whole-bpm lower bounds for Z2 to Z5, strictly rising, each 40 to 230, one set for
the app, edited but never cleared, read live, with a save needing all four.

### 4.1 `@AppStorage` is not a third option

`@AppStorage` is *"a property wrapper type that reflects a value from UserDefaults and
invalidates a view on a change in value in that user default"*
([AppStorage](https://developer.apple.com/documentation/swiftui/appstorage)). It is a view-side
way to read `UserDefaults`, not a separate store. Chalk's own precedent uses both over one key:
`GymsModel` holds `currentGymKey` *"so the views that read it through `@AppStorage` and the
models that read it through `UserDefaults` cannot drift"*. The zone line is built in a model,
not a view, so the zones need a model-side reader whatever a view does. The real choice is
**`UserDefaults` versus a SwiftData row**.

### 4.2 A SwiftData singleton is the one shape ADR-0001 cannot express

A `Settings` entity with four `Int?` columns would need *exactly one row*. ADR-0001 rule 4 bans
`.unique`, and Apple is plain about what that means under sync:

> "NSPersistentCloudKitContainer never supported unique constraints."
> "You can use the persistent history to de-dupe whenever you import new changes."
> — Apple Frameworks Engineer, [Developer Forums thread 656380](https://developer.apple.com/forums/thread/656380)

Two devices that each save zones before they first sync produce two rows. A singleton row
therefore brings an invariant (*at most one*), a rule for which row wins, and a dedupe pass. That
is the machinery `goal-storage.md` §1.2 refused for a `Goal` entity, for the same reason. It
would also put a sixth entity in every future CloudKit mirror, the cost `SuggestedGroups.swift`
already refused for its seed flag (*"adding a sixth entity to hold one boolean would put it in
every CloudKit mirror later"*).

The one thing a row would buy is that **the zones would follow you to a second device once sync
is on**, because they belong to your heart rather than to the device, unlike the current gym.
Under `UserDefaults` they would not: *"Because the data is device-specific, you don't use the
defaults system to share data between devices. To share data between someone's devices, use the
`NSUbiquitousKeyValueStore` instead"*
([UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)), and
key-value storage needs the paid programme, as CloudKit does (`swiftdata-cloudkit.md`, bottom
line). The cost of that is bounded. A second device opens with no zones, so ADR-0005's gate
shows a row that opens Settings, and logging works as normal. Nothing wrong is ever displayed.
The cost lands on the day ADR-0001's tripwire is crossed, which is also the day sync work gets
written anyway.

### 4.3 Survival across the Download Container escape hatch

- **The zones are in the container.** `UserDefaults.standard` writes the app's preferences
  plist under `Library/Preferences/`: *"This directory contains app-specific preference files.
  […] use the `NSUserDefaults` class or CFPreferences API"*, and *"the contents of the `Library`
  directory (with the exception of the `Caches` subdirectory) are backed up"*
  ([File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html),
  archived). Download Container pulls the app container, and Apple's walkthrough goes
  *"Download Container … Show Package Contents, and go into the App Data folder"*
  ([Tech Talk 204](https://developer.apple.com/videos/play/tech-talks/204/)). So the zones
  arrive beside `Library/Application Support/default.store`. I found no Apple page that names
  `Library/Preferences` inside an `.xcappdata` explicitly. That follows from the two sources
  above but is not stated by either.
- **They stay readable.** The plist opens with `plutil -p`, which meets ADR-0001's
  readability rule as `sqlite3` does for the store. Apple warns not to edit the live defaults
  files (*"Don't access the files of the defaults database directly"*). Reading a downloaded
  copy is not that.
- **A write lags slightly.** *"[UserDefaults] writes the value to disk asynchronously."* A
  container downloaded the instant after a save could miss it. Nothing depends on that window.
- **Losing them is safe by construction.** ADR-0001's recovery is *"a one-off import written at
  that moment against a store still in hand"*. If only the `.store` were carried across, the
  zones would be missing, and that is ADR-0005's not-yet-set state. No entry stores a zone,
  nothing caches a boundary, and an endurance goal stores a zone number, not a bpm
  (ADR-0007). The ticket's condition, *"it must survive … if derived numbers depend on it"*,
  holds both ways: the zones survive, and if they did not, every derived number would be gated
  rather than wrong.
- **Sensitivity.** Apple says not to keep *"personal or sensitive information"* in defaults,
  since they are stored unencrypted. Zone boundaries are personal physiology. But every
  interval's average and peak heart rate already sit unencrypted in the store, and ADR-0001
  forbids encrypting it so it stays readable. The zones add no exposure the store does not
  already have.

### 4.4 The shape

```swift
/// Your five heart-rate zones, as the four lower bounds you typed (ADR-0005), or nil
/// before the first save. **The only door**: a missing, short or out-of-order value is
/// not-yet-set, never a broken set of zones.
struct HeartRateZones: Equatable {
    static let key = "heartRateZones"          // one key: a save needs all four
    let lowerBounds: [Int]                     // Z2, Z3, Z4, Z5: strictly rising, 40...230
    init?(defaults: UserDefaults)              // reads `[Int]` under `key`
    func zone(of averageHeartRate: Int) -> Int // 1...5, on a boundary in the upper zone (ADR-0006)
}
```

**One key holding a four-element array**, a plist type `UserDefaults` stores natively (*"Int …
Array"*, [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)),
rather than four keys. The write is one call, so a half-written set cannot happen, which is
ADR-0005's *"a save needs all four numbers"* written into the storage. A failable reader
absorbs anything malformed, as `Goal.init?` does. Tests inject `UserDefaults(suiteName:)` as
`LibraryModel` and `CreateExerciseSheet`'s previews already do. `@AppStorage` has no array
initialiser, so a view that wants live updates observes the model, which re-reads on
`UserDefaults.didChangeNotification` or simply on appear. Zones change about once a season.

**Verdict: `UserDefaults`, one key, read through `HeartRateZones`.**

---

## 5. Endurance goals beside ADR-0004

ADR-0007's tuple is zone (1 to 5), duration (to the second), intensity (in the erg's unit, as
typed), incline (on speed ergs, required there and absent elsewhere) and `setAt`. They are
optional fields on the scope: the erg while it is transferable, the machine while it is
gym-bound. A partial set is no goal.

### 5.1 Fields

On **both `Exercise` and `Machine`**, beside the strength trio:

```swift
var goalZone: Int?          // 1...5
var goalDuration: Int?      // whole seconds
var goalIntensity: Double?  // in the erg's unit, as typed (§3)
var goalIncline: Double?    // percent; set on a speed erg's goal, nil on any other
// var goalSetAt: Date?     // existing; shared with the strength goal (§5.2)
```

All four are optional, so they are the same kind of addition the 1.0.0 → 2.0.0 test already
proved, and ADR-0004's reasons (one goal per scope is structural, no orphan, the fields ride the
scope's CloudKit record) carry over word for word.

### 5.2 Side by side, or shared `goalSetAt`: shared

The question #100's comment leaves open is whether `Machine` carries both halves' goal fields
side by side with two set-moments, or shares `goalSetAt`.

**One row is never both halves.** Under §2 an `Exercise` is a lift or an erg, never both, and a
`Machine` belongs to one `Exercise`. A row therefore holds at most one goal, and only one
set-moment ever means anything on it. So:

- **Shared `goalSetAt`.** A strength goal is `goalReps + goalWeight + goalSetAt`. An endurance
  goal is `goalZone + goalDuration + goalIntensity (+ goalIncline on speed) + goalSetAt`. The
  half is read off the owner (`isErg`), never off which fields happen to be set.
- **`MachineGoals` keeps reading one field.** *"The most recently set goal wins"* (ADR-0004,
  #99 for ergs) sorts machines by `goalSetAt`. With the field shared, the same sort serves both
  halves, and only the value struct it builds differs. A separate `enduranceGoalSetAt` would
  make that rule branch on the half, and would add a field that is nil on every row of the other
  half.
- **Clearing nils all seven fields.** `GoalScope.clear()` already nils its trio. Widened to
  nil both halves' fields, it also sweeps up any stray value, so *"a row's goal fields are its
  own half's"* (§2.3) is maintained by the one write path rather than by care.

### 5.3 The rest is ADR-0004's machinery, widened

- A Foundation-only `EnduranceGoal` value struct in `Derivation/`, beside the zone line, with a
  failable initialiser over the fields, the scope's entries, the zones and the unit. It is the
  only door, so a partial set (including a speed goal with no incline) is no goal. Reached, the
  gap and the origin are computed there (ADR-0007), in whole steps (§3).
- `GoalScope` grows an endurance read and write, and stays the one place the raw fields are
  touched.
- **Invariant 8 widens** to *goal fields of both halves are nil on an `Exercise` while it is
  gym-bound*.
- **A unit change clears the goal** (ADR-0007), through `GoalScope.clear()`. It is possible
  only while the erg has no entries.

---

## 6. Migration to `3.0.0`

### 6.1 The change

Fifteen attributes, every one optional or defaulted, on four entities that already exist:

| Entity | Added | Type | Default |
|---|---|---|---|
| `Exercise` | `unit` | `String?` | nil |
| | `goalZone`, `goalDuration` | `Int?` | nil |
| | `goalIntensity`, `goalIncline` | `Double?` | nil |
| `Machine` | `goalZone`, `goalDuration` | `Int?` | nil |
| | `goalIntensity`, `goalIncline` | `Double?` | nil |
| `Entry` | `duration`, `averageHeartRate`, `peakHeartRate` | `Int` | 0 |
| | `intensity`, `incline` | `Double` | 0 |
| `ExerciseGroup` | `half` | `String` | `Half.strength.rawValue` |
| `Gym` | — | | |

No entity, relationship or delete rule is added, and SPEC §3's delete-rule table is unchanged.
**Bump in place**: `ChalkSchemaV1.versionIdentifier = Schema.Version(3, 0, 0)`, with `stages`
still `[]` and `models` still the five classes. This matches ADR-0004's 2.0.0 and
`goal-storage.md` §3.2's rule that the first change that *rewrites* data is the one that earns
a frozen V2 and a stage. This change rewrites nothing.

### 6.2 What is verified, and where

- **Additive attributes are inferred.** Core Data, which SwiftData sits on, lists *"Addition of
  an attribute"* and, for a non-optional one, *"defining a default value"*
  ([Migrating your data model automatically](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically)).
  The SwiftData module interface (Xcode 27.1 SDK) shows where a Swift initialiser's value
  goes: `Schema.Attribute` carries `public var defaultValue: Any?`, and the `@Model` macro's
  `Schema.PropertyMetadata.init(name:keypath:defaultValue:metadata:)` passes it in. Apple's
  page for `PropertyMetadata` has no discussion of what `defaultValue` is used for
  ([docs](https://developer.apple.com/documentation/swiftdata/schema/propertymetadata)).
- **Secondary reports conflict on defaulted non-optional additions.** One developer reports
  a crash, *"Passed nil for a non-optional keypath"*, adding a defaulted enum property under
  CloudKit with a custom stage, and a second-hand claim that Apple support called this
  intended
  ([thread 764236](https://developer.apple.com/forums/thread/764236), **no Apple engineer
  reply**). Other write-ups say it just works.
- **Experiment, run for this ticket** (macOS 27.0.1, Xcode 27.1 toolchain, `swiftc`, two
  separate processes so no two `@Model` classes share a name in one run, the collision the
  1.0.0 fixture comment describes). Run 1 wrote a 2.0.0-shaped store (`Exercise` with
  `goalReps: Int?`, `Entry` with `reps`/`weight`) through a `VersionedSchema` at 2.0.0 and an
  empty plan. Run 2 opened the same file against a 3.0.0 `VersionedSchema` bumped in place with
  `stages: []`. That schema added defaulted non-optional attributes (`half: String =
  "strength"`, `duration: Int = 0`), optional ones (`unit`, `goalZone`, `avgHR`), a new
  to-many relationship and two new entities. Results:
  - the store opened, and every row survived with its relationships;
  - `sqlite3` shows **`ZHALF = 'strength'` and `ZDURATION = 0` written into the pre-existing
    rows**, so the default is materialised on disk and not only filled in on read, while
    `ZUNIT` and `ZGOALZONE` are `NULL`;
  - `#Predicate { $0.half == "strength" }`, `{ $0.duration == 0 }`, `{ $0.unit == nil }` and
    `{ $0.unit != nil }` all return the right counts over migrated rows;
  - the upgraded store took new rows of the new entity and saved them.

  This settles the question **for macOS on this SDK**, with no CloudKit and no custom stage.
  It is the same framework on iOS, but **the app's own test on the iOS simulator is the
  evidence that counts**. If it fails there, the fallback is to make the five `Entry` fields
  and `ExerciseGroup.half` optional (nil read as 0 and strength): a one-line change each, and
  exactly the shape 1.0.0 → 2.0.0 already proved.
- **CloudKit later.** Nothing is promoted yet, so these fields simply belong to the first
  schema ever initialised. After promotion, *"you can add new record types, and additional
  fields to existing record types"*
  ([Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)).
  Additive is the supported direction.

### 6.3 The test to add (ADR-0004's requirement, extended)

1. **Capture `ChalkTests/Fixtures/Chalk-2.0.0.store` first**, from the app at `main` 35ec78a
   (schema 2.0.0), **before any model file changes**, as `Chalk-1.0.0.store` was captured at
   7c66782. It is a single checkpointed file, so it opens without a `-wal`. Contents: *Bench
   Press* (free-weight, entry 5 × 100, **goal 5 × 140** set at a fixed date), *Chest Press*
   (gym-bound, machine *Plate-loaded* at *Fitness X*, entry 8 × 60, **machine goal 8 × 72.5**),
   both in *Push*, every date fixed.
2. **`SchemaMigrationTests`, a new test: "A store written with the 2.0.0 schema reopens with
   every row, its goals, and no endurance."** Copy the fixture into place and open it through
   `ChalkStore.open`. Then assert:
   - names, kinds, group, gym, machine, entries and relationships match the fixture;
   - **both strength goals survive intact** (reps, weight, `goalSetAt`); this is the new part
     2.0.0 could not test;
   - every new field is at its default: `unit == nil` (so `isErg == false`), the four
     endurance goal fields nil on both exercises and the machine, every entry with `duration`,
     `intensity`, `averageHeartRate`, `peakHeartRate` and `incline` at 0, `isALift` true and
     `isAnInterval` false, and `Push.half == "strength"`;
   - the strength library's predicate (`unit == nil`) returns both exercises, and the
     strength group filter returns *Push*.

   Then write: a gym-bound erg (`unit = speed`) with a machine at *Fitness X* holding a speed
   goal (zone, duration, intensity, incline and set-at), and one interval entry on it. Save,
   reopen, reread, and check that both the strength goal and the endurance goal are there
   alongside each other on one gym.
3. **The existing 1.0.0 test stays** and gains the same new-default assertions. A 1.0.0 store
   upgraded straight to 3.0.0 is the path a stale install would take.
4. **`SchemaRoundTripTests`**: one erg with every new field set, a machine with an endurance
   goal, an interval entry and an endurance-half group, all round-tripped.
   `schemaListsFiveEntities` becomes *"The schema is 3.0.0 and names all five entities"*,
   with `stages` still empty.
5. **`HeartRateZones`**, against an injected `UserDefaults(suiteName:)`: absent → nil; three
   values, out of order or out of 40...230 → nil; four rising → zones; and the boundary
   reading, where a heart rate exactly on a bound is the upper zone (ADR-0006).

**Download the container before the first launch of the 3.0.0 build on the phone** (SPEC §3,
as for 2.0.0). See §7 for why that step needs checking this time.

---

## 7. Hand-offs and questions storage does not settle

- **Does Download Container still work?** Developers report that Xcode 26's Devices window
  fails to download a container, with *"Cannot open destination file … AppData/Library/Caches/
  com.apple.dyld/… Permission denied"* (CoreDeviceError 7000), from 26.0 through 26.4 in April
  2026, calling it *"a regression in Xcode 26 + Tahoe"*. There is no Apple reply and no fix named
  ([thread 801165](https://developer.apple.com/forums/thread/801165), **secondary**). This
  machine has Xcode 27.1, and whether it is fixed there is **UNVERIFIED**. ADR-0001's escape
  hatch and SPEC §3's *download before the first launch of a new schema* both depend on it.
  **Only the dev can check this, on the phone**, before 3.0.0 ships.
- **Should gym recency count intervals?** `Gym.lastLogged` orders the current-gym picker and
  counts *lifts* only (§7.4). The current gym is shared by both halves (#93), so a gym visited
  only for endurance would sink in the picker. Counting intervals is the likely answer, but it
  is a behaviour question for the spec, possibly for #101.
- **The zones would not follow a second device once sync exists** (§4.2). That is acceptable
  under ADR-0005's gate, but it is a deliberate consequence the dev should accept knowingly.
- **#104** (*Does the endurance library start empty?*) decides whether a seeded erg's unit
  comes preset. Storage is indifferent. A seeded erg is an `Exercise` with a unit.
- **#101 and #103** (repair, history and edit): under §1 and §2 they reuse strength's paths
  over the same entities. The one storage-level rule for them is the one already in ADR-0002:
  reassign `Entry.machine` and flush before deleting a machine.

## 8. Sources

Primary (Apple):

- [Migrating your data model automatically — Core Data](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically)
- [Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)
- [Syncing model data across a person's devices — SwiftData](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [`Schema.PropertyMetadata`](https://developer.apple.com/documentation/swiftdata/schema/propertymetadata),
  [`MigrationStage`](https://developer.apple.com/documentation/swiftdata/migrationstage),
  [`SchemaMigrationPlan`](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- SwiftData module interface, Xcode 27.1 SDK (`SwiftData.swiftmodule/arm64e-apple-ios.swiftinterface`):
  `Schema.Attribute.defaultValue`, `Schema.PropertyMetadata.init(name:keypath:defaultValue:metadata:)`,
  `Schema.CompositeAttribute`, `MigrationStage.lightweight` / `.custom`
- [UserDefaults — Foundation](https://developer.apple.com/documentation/foundation/userdefaults)
- [AppStorage — SwiftUI](https://developer.apple.com/documentation/swiftui/appstorage)
- [File System Programming Guide — File System Basics](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html) (archived)
- [Tech Talk 204 — Download Container walkthrough](https://developer.apple.com/videos/play/tech-talks/204/)
- [Developer Forums thread 656380](https://developer.apple.com/forums/thread/656380) — Apple
  Frameworks Engineer on unique constraints and de-duplication under CloudKit

Secondary, flagged as such in text:

- [Developer Forums thread 764236](https://developer.apple.com/forums/thread/764236) — defaulted
  non-optional property and a custom stage under CloudKit; no Apple engineer reply.
- [Developer Forums thread 801165](https://developer.apple.com/forums/thread/801165) — Download
  Container failing in Xcode 26.x; no Apple engineer reply.

Experiment: two `swiftc`-built processes over one store file, as described in §6.2; not
committed.

In-repo:

- `CONTEXT.md`, `SPEC.md` §3, §4, §7.5, §8, §12; ADR-0001, 0002, 0004, 0005, 0006, 0007
- [`docs/research/goal-storage.md`](goal-storage.md), [`docs/research/swiftdata-cloudkit.md`](swiftdata-cloudkit.md)
- Issues #88, #89, #93, #94, #96, #99, #100
- `Chalk/Chalk/Model/*.swift`, `Chalk/Chalk/Store/ChalkSchema.swift`,
  `Chalk/Chalk/Derivation/RepMaxCurve.swift`, `Chalk/Chalk/Derivation/Goal.swift`,
  `Chalk/Chalk/Goals/GoalScope.swift`, `Chalk/Chalk/Goals/MachineGoals.swift`,
  `Chalk/Chalk/Gyms/MachineScope.swift`, `Chalk/Chalk/Gyms/GymsModel.swift`,
  `Chalk/Chalk/Library/SuggestedGroups.swift`, `Chalk/Chalk/Library/LastEntry.swift`,
  `Chalk/Chalk/History/HistorySheetModel.swift`, `Chalk/ChalkTests/SchemaMigrationTests.swift`,
  `Chalk/ChalkTests/SchemaRoundTripTests.swift`, `Chalk/ChalkTests/TemporaryStore.swift`
