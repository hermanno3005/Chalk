# Chalk v1 — build specification

This is the build-ready spec. It is the output of [the wayfinding map](https://github.com/hermanno3005/Chalk/issues/1)
and every decision ticket under it; each section names the ticket it came from so the reasoning
is one click away. **The reasoning is not repeated here — the decisions are.**

Read `CONTEXT.md` first: it is the glossary, and this document uses its words exactly
(**Entry**, **rep-max**, **monotonic backfill**, **strength curve**, **ghost curve**,
**free-weight**, **gym-bound**, **Group**, **Ungrouped**, **Gym**, **Machine**, **Merge**,
**current gym**,
**Archived**, **Hint**, **Scope**, **Goal**, **Reached**, **Gap**, **Setting a goal**,
**Clearing a goal**, **Goal sheet**, and endurance's words, listed in §13). Read `docs/adr/0001`
and `docs/adr/0002` before touching persistence or the derivation — they record the two decisions
most likely to be "helpfully" undone. Read `docs/adr/0004` before touching how a goal is stored,
and `docs/adr/0005` to `0008` before touching endurance (§13).

Build it in the order of §10. Where this document says **must**, it is closing a hole an
implementer would otherwise fill by invention.

---

## 1. What Chalk is

A personal training-record tracker for iOS, in two halves. In **strength** you keep a library of
the exercises you actually do, log what you lifted as plain `reps × weight` **entries**, and the
app tells you what to load at the rack. In **endurance** (§13) you keep a library of the indoor
ergs you train on, log each interval with the heart rate it cost you, and the app tells you what
to set on the machine.

It is **not** a workout logger. There are no sessions, no sets, no routines, no rest timers.
The unit of record is one entry. Every "best" number is derived at read time and never stored.

**The plan lives somewhere else.** Chalk is what you consult to carry out a training plan kept
in another app: the plan names the reps, the reps in reserve, the duration and the zone, and
Chalk turns them into the number to load on the bar or set on the console. For `8 @ RIR 2` you
read `best[10]`. That translation is yours, and Chalk never takes it over (§15).

Single user. One device. No backend, no accounts, no sharing. Sideloaded from Xcode, and built
so that a paid developer account is the only thing between it and the App Store (§15).

---

## 2. Project setup

From [#5](https://github.com/hermanno3005/Chalk/issues/5) (measured, not assumed) and
[#4](https://github.com/hermanno3005/Chalk/issues/4).

| | |
|---|---|
| Xcode | 26.6 (17F113) |
| iOS SDK | 26.5 |
| iOS deployment target | **18.0** |
| Swift version | 6.0 |
| Bundle id | **`com.hermannaust.Chalk`** |
| Signing | Automatic, `DEVELOPMENT_TEAM = P9J393594X` (Hermann Aust — Personal Team) |
| Device family | iPhone only |
| Capabilities | **none** — no iCloud, no Push, no App Groups |
| UI | SwiftUI + Swift Charts + SwiftData |

The skeleton is on `main`, landed by [#19](https://github.com/hermanno3005/Chalk/issues/19):
`Chalk/Chalk.xcodeproj` plus the sources under `Chalk/Chalk/`.

The `.xcodeproj` is hand-written in the synchronized-folder format (`objectVersion = 77`), so
**new source files dropped into `Chalk/Chalk/` are picked up without editing the project file**.
It has survived a GUI round-trip. If it ever misbehaves, regenerate from Xcode's template and
move the sources across.

### Getting it on the phone, and keeping it there

Free provisioning mints a **7-day** profile. The weekly ritual, confirmed by measurement in
[#12](https://github.com/hermanno3005/Chalk/issues/12):

1. Rebuild from Xcode (mints a fresh 7-day profile automatically).
2. **Settings → General → VPN & Device Management → Trust the developer team.** Required every
   time, even though the signing certificate is unchanged and Developer Mode stays enabled.
3. Open Chalk. History intact.

A lapsed app is **not** reaped by iOS: the icon stays, the container stays, only launching is
blocked with the *Untrusted Developer* alert. **Standing rule: never delete Chalk to fix a
signing problem — rebuild and re-trust.** Deleting is the one action that takes the history
with it.

### Durability

_Reversed 2026-10-22: Chalk makes and restores backups from Settings (§15,
[ADR-0010](docs/adr/0010-chalk-makes-and-restores-backups.md)). The rest of this section
describes v1 as it shipped._

Chalk ships **no export and no import** — no share sheet, no file writer
([#17](https://github.com/hermanno3005/Chalk/issues/17)). **Settings** (§13.3) holds heart-rate
zones and nothing about durability: no export row, no import row
([ADR-0005](docs/adr/0005-heart-rate-zones-are-five-typed-boundaries-on-a-settings-screen.md)).
Sync-later is the whole durability story; entries are re-derivable by training again, and what
the app is worth is the derivation.

The escape hatch is **Xcode's Download Container** (Devices & Simulators → Installed Apps),
used **on demand** — deliberately not pinned to the weekly ritual. This makes the store's
readability load-bearing: **no encrypted store, and no opaque `Transformable` attributes.**
Pull a container before doing anything irreversible (see the merge in §7.5). The container
carries the heart-rate zones too: they live beside the store, not in it (§13.3).

---

## 3. Domain model and schema

From [#9](https://github.com/hermanno3005/Chalk/issues/9), amended by
[#14](https://github.com/hermanno3005/Chalk/issues/14) and, for the goal fields,
[#66](https://github.com/hermanno3005/Chalk/issues/66), and for endurance by
[#100](https://github.com/hermanno3005/Chalk/issues/100). Governed by ADR-0001, ADR-0004 and
ADR-0008.

Five entities. **Endurance adds fifteen attributes to them at schema `3.0.0`, and nothing else**
— no entity, relationship or delete rule (§13.1). The code below is strength's shape. Every attribute optional or defaulted; every relationship optional with an
explicit inverse; no `.unique`; no `.deny`. **These are CloudKit-mirroring rules obeyed under a
local-only store — they are not sloppiness, and tightening them breaks sync on the day it is
switched on.** See ADR-0001 before changing anything here.

```swift
enum ExerciseKind: String, Codable { case freeWeight, gymBound }

@Model final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var kind: String = ExerciseKind.freeWeight.rawValue
    var group: ExerciseGroup?                                    // nil = Ungrouped
    @Relationship(deleteRule: .cascade, inverse: \Entry.exercise)
    var entries: [Entry]? = []
    @Relationship(deleteRule: .cascade, inverse: \Machine.exercise)
    var machines: [Machine]? = []
    var goalReps: Int?                   // goal (§12): all three set, or none
    var goalWeight: Double?              // kilograms
    var goalSetAt: Date?                 // nil while gym-bound (invariant 8)
}

@Model final class Entry {
    var id: UUID = UUID()
    var reps: Int = 0                    // >= 1, no upper bound
    var weight: Double = 0               // kilograms, always. > 0
    var date: Date = Date.now            // immutable after creation
    var exercise: Exercise?              // always set in practice
    var machine: Machine?                // gym-bound only
}

@Model final class Gym {
    var id: UUID = UUID()
    var name: String = ""
    var isArchived: Bool = false
    @Relationship(deleteRule: .nullify, inverse: \Machine.gym)
    var machines: [Machine]? = []
}

@Model final class Machine {
    var id: UUID = UUID()
    var manufacturer: String?            // editable later; never a key
    var label: String?
    var exercise: Exercise?
    var gym: Gym?
    @Relationship(deleteRule: .cascade, inverse: \Entry.machine)
    var entries: [Entry]? = []
    var goalReps: Int?                   // goal (§12): all three set, or none
    var goalWeight: Double?              // kilograms
    var goalSetAt: Date?
}

@Model final class ExerciseGroup {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0
    @Relationship(deleteRule: .nullify, inverse: \Exercise.group)
    var exercises: [Exercise]? = []
}
```

### Delete rules

```
Exercise      --cascade--> Entry
Exercise      --cascade--> Machine --cascade--> Entry
ExerciseGroup --nullify --> Exercise          (falls back to Ungrouped)
Gym           --nullify --> Machine
```

`.deny` is unsupported under CloudKit, so anything stricter is an **app-level guard**, never a
schema rule. Gym is the one that matters: cascading from a gym would reach every entry ever
logged there. Nullify instead — a gym-less machine is recoverable by reassignment, deleted
history is not.

**A goal adds no row.** It is three fields on its **scope**, not an entity, so it dies with its
scope and a gym-less machine keeps its goal (ADR-0004).

### Invariants the schema cannot express

Every one of these must be maintained in app code. They are listed because this is exactly where
an implementer invents behaviour.

1. **`entry.machine?.exercise == entry.exercise`.** Maintained at write time, on log and on edit.
2. **An entry with a nil `exercise` is treated as non-existent** — unreachable from every screen,
   never repaired, never surfaced, never counted. It is not an error state; it is an impossibility
   the type system cannot express.
3. **`machine.gym == nil` is representable but never intentionally produced.** It can only arise
   from a gym deletion. Such a machine still derives normally; it simply renders as `label` with
   no gym suffix.
4. **A gym-bound exercise must resolve a machine at log time.** Unscoped entries are not allowed
   ([#2](https://github.com/hermanno3005/Chalk/issues/2)) — an "unknown machine" bucket pollutes
   the derivation and never gets tidied. `Entry.machine == nil` on a gym-bound exercise must not
   be producible by any UI path.
5. **Rep-maxes are recomputed after every edit and every delete. Nothing caches them.**
6. **`Entry.date` is immutable after creation.** No screen offers to change it.
7. **Gyms and groups are held explicitly on the store, never derived from the machines or
   exercises that happen to exist.** A newly created empty gym or group must survive the sheet
   closing. (The library prototype hit this bug for real.)
8. **Goal fields — either half's — are nil on an `Exercise` while it is gym-bound.** A gym-bound
   exercise's or erg's goals live on its machines, one per machine; the kind change moves them
   (§8, §13.11). A partly filled set is **no goal**, and nothing reads the raw fields except
   through `GoalScope`, into `Goal` (§12.2) or `EnduranceGoal` (§13.10).
9. **An erg's `unit` is set at create, never cleared, and changed only while the erg has no
   entries.** A lift's `unit` is always nil; that is what makes it a lift (§13.1, §13.6).
10. **An exercise or erg sits only in a group of its own half.** An erg never sits in *Push*, a
    lift never in *Bikes* (§13.5).
11. **A row's goal fields are its own half's.** A lift's exercise or machine holds only
    `goalReps` and `goalWeight`, an erg's only the four endurance fields; `goalSetAt` is shared.
    `GoalScope.clear()` nils all seven (§13.1).

### Storage details

- **Weight is a `Double`, always kilograms** — storage, entry, display, verdict line. No unit
  setting, no conversion, no lb ([#15](https://github.com/hermanno3005/Chalk/issues/15)). Plate
  steps 2.5 and 1.25 are exactly representable in binary floating point, so `max()` and equality
  do not drift. **Display trims the trailing zero: `60`, not `60.0`; `57.5` stays `57.5`.**
- **The current gym is `@AppStorage("currentGymID")`**, holding a `Gym.id` UUID string — device
  local by construction. A stale or missing UUID resolves to *no gym selected*.
- **Identity is `var id: UUID = UUID()` on every entity.** No `.unique`, no `#Unique`.
  App-level uniqueness only.
- **No `createdAt` anywhere except `Entry.date`.** The library sorts by last-logged, which derives
  from entries; group order is `sortIndex`. Nothing else has a reader. `goalSetAt` is not a
  creation date: every **setting a goal** rewrites it, and the ring's origin is measured from it
  (§12.2).
- **`ExerciseGroup.sortIndex` is a real field, not array position** — relationship arrays are not
  order-preserving when mirrored. `Gym` deliberately has **no** `sortIndex`: gyms order by
  usage recency, which they already know (§7.4).

### Persistence setup and versioning

```swift
enum ChalkSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Exercise.self, Entry.self, Gym.self, Machine.self, ExerciseGroup.self]
    }
}

enum ChalkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ChalkSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
```

The container is `ModelConfiguration(cloudKitDatabase: .none)`, built against
`ChalkMigrationPlan`. Do **not** add a `schemaVersion: Int` attribute — `VersionedSchema`
already carries the version.

**The goal fields bumped the schema to `2.0.0` in place** (ADR-0004). The change is additive, so
`stages` stays empty and no frozen copy of V1 is kept in the app. **SwiftData infers that
migration with no stage listed**: `SchemaMigrationTests` copies a store the app wrote at `1.0.0`
(`ChalkTests/Fixtures/Chalk-1.0.0.store`) into place, opens it through `ChalkStore.open`, and
asserts every row survives with nil goal fields. The fixture is a real file, not a test-only
copy of the old `@Model` classes: two classes with one entity name in the same test process
collide in SwiftData while suites run in parallel. The round-trip test covers the goal fields on both `Exercise` and `Machine`. Download
the container (§2) before the first launch of that build on the phone.

**Endurance bumps it to `3.0.0` the same way**, in place and with no stage, tested against a
real `Chalk-2.0.0.store` (§13.1).

**If the container fails to open**, present a plain full-screen message naming the store path
and stop. Do **not** delete or recreate the store, and do not retry in a loop: deleting is the
one action that loses history irrecoverably (§2).

---

## 4. The derivation

From [#3](https://github.com/hermanno3005/Chalk/issues/3). Governed by ADR-0002.

```
best[n] = max(weight) over all entries with reps >= n
```

A `5 × 55 kg` proves 55 kg at 1, 2, 3, 4 and 5 reps, so it **floors** all of them. Nothing is
inferred beyond what the lift physically demonstrates. No Epley, no Brzycki, no cell fabricated
from another, anywhere in the derivation.

- **Always the all-time maximum.** No decay, no rolling window, no staleness marker. The number
  never moves on its own — only a new entry, an edit, or a delete changes it.
- **Backfilled cells are not marked** on the curve. The flat run reads as a floor on its own.
- **Entries above 12 reps are stored and still floor everything up to 12** — a `25 × 30 kg` sets
  a 30 kg floor across the whole axis. They simply get no point of their own.
- **Deleting an entry can lower a rep-max. That is the derivation working, not data loss.**

### Scoping is the caller's job

- **Free-weight**: pass every entry for the exercise, gym-agnostic.
- **Gym-bound**: pass **one machine's** entries only.
- **Hints never enter the derivation** (§5.3, §6.5).

### `RepMaxCurve`

```swift
struct RepMaxCurve {
    let best: [Int: Double]      // 1...12, absent where no entry reaches that rep count
    let ghost: [Int: Double]     // Epley, guidance only
    init(entries: [Entry])
}
```

A plain struct over `[Entry]` with **no SwiftData dependency**, so backfill, the `reps > 12`
flooring rule and the ghost are unit-testable without a `ModelContainer`. These three rules are
the part an implementer gets subtly wrong; they get tests.

**One fetch, one O(n) pass produces all twelve cells. Do not write twelve `reps >= n` predicates.**

### The ghost curve

Epley (`w × (1 + reps/30)`) applied to every entry; take the **single** entry with the highest
resulting estimated 1RM; project that estimate back across 1–12 (`ghost[n] = e1RM / (1 + n/30)`).

The ghost is **guidance only**: never a rep-max, never persisted, never presented as a number you
have lifted. It is drawn **unconditionally whenever the curve is drawn at all**
([#16](https://github.com/hermanno3005/Chalk/issues/16)) — including against a single entry,
where it floats far above a flat line. Suppressing it on a threshold was offered and declined; a
chart element that appears and disappears is its own kind of confusing. The zero-entry case is
handled by drawing no chart (§5.4).

---

## 5. Exercise detail screen

From [#7](https://github.com/hermanno3005/Chalk/issues/7), completed by
[#16](https://github.com/hermanno3005/Chalk/issues/16). Prototype:
[`docs/prototypes/exercise-detail/`](docs/prototypes/exercise-detail/README.md).

**The curve is primary. A rep-max table does not appear on this screen at all.**

### 5.1 Layout

Top to bottom:

1. **The scrub readout.** One large number — the best weight at the selected rep count — with
   `best for N reps · M entries ›` beneath it. `M` is the count of entries with `reps >= N` in
   scope. The number animates on change (`.contentTransition(.numericText())`).
   **The goal line** sits directly under that subhead when the scope has a goal (§12.4), and
   nothing takes its place when it has none.
2. **The strength curve**, **150 pt tall**. Full-bleed was tried and rejected as making the screen
   read as a chart rather than as an exercise.
3. **Empty space.** It ships empty and that is deliberate
   ([#16](https://github.com/hermanno3005/Chalk/issues/16)): it keeps the Log bar high and
   thumb-reachable. Do not fill it with a recent-entries list or a rep-max strip — or with the
   goal, which lives in the goal line and never on the chart (§12.4).
4. **Log bar** — full width, pinned at the bottom. Opens the log sheet (§6).

**Toolbar:** back to the library (supplied by `NavigationStack`, not hand-drawn); the machine
qualifier menu (§5.3, gym-bound only); an overflow menu (§5.5).

### 5.2 The curve

- Swift Charts line over a **fixed 1–12 rep x axis**, identical for every exercise so shapes are
  comparable. Leading y axis visible.
- **Y axis framed to the data, not anchored at 0** — real strength curves are shallow and a
  zero-based axis flattens them into the top third.
- **Stepped interpolation, with a point mark on every rep count.** Monotonic backfill means every
  untrained rep count repeats the value above it, so the curve is a **staircase, not a slope**.
  Do not smooth it: the staircase is the honest picture of the derivation.
- **The ghost curve sits behind it**, dashed and visibly see-through. It must be legible as
  guidance and impossible to mistake for the solid curve — the first scaffolding failed both
  halves by drawing both as thin dashed grey.

**Scrubbing** uses Charts' own `chartXSelection` — do **not** hand-roll a `DragGesture` in a
`chartOverlay` with a tap gesture layered on top; they fight and the drag does nothing. Dragging
moves the selection; a rule mark plus an enlarged point track the thumb.

**The selection is sticky:** it stays where you lifted your finger. `chartXSelection` clears its
binding on lift, so hold the last non-nil value in your own state — otherwise the readout snaps
back and no other rep count can be held. Default selection is **5 reps**.

### 5.3 The machine qualifier — gym-bound only

A nav-bar menu listing **every machine for this exercise**, flat, sectioned by gym, each row
reading `label · gym`. Switching it re-scopes the screen and **re-derives the whole curve**,
and the goal line with it: each machine's goal is measured only against that machine's curve.

This is the app's **one machine picker**, shared with the log sheet (§6.4) — one behaviour,
learned once.

**Free-weight exercises show no qualifier at all** — not a disabled one, not a placeholder. The
screen has two shapes.

Which machine the screen opens on: the machine at the **current gym** for this exercise if there
is exactly one; if the current gym holds several, the one most recently logged on; if the current
gym holds none (or no gym is selected), the machine most recently logged on overall; if the
exercise has no machines at all, the screen is in the empty state (§5.4) and the qualifier reads
as unset until the first log creates a machine (§6.4).

### 5.4 Zero entries

A newly created exercise, or a machine you have never logged on, draws **no chart at all** — no
axes, no flat line at zero, no ghost. Short text where the chart would be, and the Log bar
beneath it. A chart frame with no data implies numbers that do not exist.

There is no scrub readout in this state.

**The empty state carries the machine hint.** For a **gym-bound** exercise whose currently
scoped machine has no entries, when a sibling machine has usable history, one **dimmed line**
sits under the text:

> `No entries here — 55 kg × 5 on Hammer Strength`

- The sibling is the **most recently used** one (`max(by:)` over `Entry.date` across the other
  machines for this exercise). **Nothing in this spec ever ranks siblings beyond that** — the
  screen shows one hint, never a list.
- **It quotes that sibling's `best[5]`, and shows nothing at all if the sibling has no `best[5]`.**
  Backfill floors downward, so a machine you have only ever done triples on has no `best[5]`.
  Do not fall back to `best[3]`: the hint keeps a fixed rep count so it agrees with the log
  sheet's cold start, and where it cannot back that up it stays silent.
- **Text, never a dimmed curve.** A shape on the chart that is not yours is exactly what the
  never-mistakable-for-a-record rule forbids.
- Free-weight exercises, and gym-bound ones with no usable sibling, get **bare text**.

This hint is **the only thing on the detail screen that reads another machine's entries.** Treat
it as a distinct lookup, not part of `RepMaxCurve` over the machine in view.

**A goal still shows here.** A goal can be set on a scope with nothing logged, so when the scope
has one, the goal line (§12.4) sits under the text, and under the hint if there is one. The prompt
to go and log still comes first. With nothing logged the **gap** is the whole goal weight.

### 5.5 The overflow menu

- **Rename** — an inline field or one-field alert. Cosmetic; identity is the UUID.
- **Change kind** — the free-weight ↔ gym-bound flip (§8).
- **`Set a goal…`**, or **`Change goal…`** once the scope has a goal — opens the goal sheet
  (§12.3) on the scope the screen is showing, seeded with the selected rep count. **On a
  gym-bound exercise with no machine yet there is no scope, so the item is absent, not
  disabled** — §7.5's rule for dead verbs. There is no clear item: clearing a goal lives in the
  goal sheet, and the overflow keeps lifetime operations only.
- **Delete exercise** — cascades to its entries and machines (§3), and their goals with them.
  Confirm destructively, phrased as the outcome with the count: *"Delete Bench Press and its 84
  entries?"* No undo.

There is deliberately **no "edit entries" item**: the curve is how you find a bad entry
([#11](https://github.com/hermanno3005/Chalk/issues/11)), and no all-entries log screen exists.

### 5.6 History — the `reps >= n` sheet

Tapping `best for N reps ›` on the readout opens it. This is the **only** entry point to raw
history and the **only** place an entry can be edited or deleted.

- Lists **every entry with `reps >= N`** in the current scope, **newest first**, showing date,
  `reps × weight`, and the machine where the exercise is gym-bound.
- **The entry currently setting `best[N]` is flagged.**
- It mirrors the derivation rule exactly, which is what makes it sufficient: the entries it lists
  are precisely the ones that can determine that cell. A backfilled cell shows the higher-rep
  lifts that floored it; a 25-rep set appears under every cell it touches; a sub-best entry is
  visible, confirming the log landed.
- **Tap a row → edit** (§6.6).
- **Swipe left → Delete**, with **full-swipe disabled**, so deleting always takes two deliberate
  gestures. No confirmation alert, no undo. The cost is bounded: you just read the numbers, and
  re-logging is two taps.
- **No entry is a special case.** Delete needs no guard for "the only entry" or "the one seeding
  the ghost curve".

Two behaviours that must **not** be special-cased:

- **Editing reps can drop a row out of the sheet it was opened from.** Change 5 reps to 3 inside
  the 5-rep history and the row vanishes. That is the filter behaving correctly. Do not try to
  keep it visible.
- **Deleting the last entry returns the exercise to its empty state** (§5.4). The exercise
  survives; the curve and ghost simply have nothing to draw.

---

## 6. The log sheet

From [#6](https://github.com/hermanno3005/Chalk/issues/6),
[#13](https://github.com/hermanno3005/Chalk/issues/13),
[#15](https://github.com/hermanno3005/Chalk/issues/15). Prototype:
[`docs/prototypes/log-entry-modal/`](docs/prototypes/log-entry-modal/README.md)
(variant A).

A sheet over the calling screen, **two stages**: reps, then weight. One giant number on screen at
a time. The size and the staging are the point — a single unmissable digit and two thumb-sized
targets is what survives sweaty hands.

### 6.1 Structure

- **Stage one: reps.** Stage two: weight.
- The **stage-two header carries an `N reps` button** back to stage one, so the earlier answer is
  always visible and correctable without cancelling.
- **Animate the stage change and the digit** (`.contentTransition(.numericText())`) — the motion
  is what makes staging read as progress rather than a detour.
- Cancel dismisses without writing. **Save** commits.

### 6.2 The two input modes, on both stages

- **Steppers** for nudges: **±1 rep**, **±2.5 kg**.
- **Tapping the giant number swaps the steppers for a keypad** for jumps (5 → 12 reps was seven
  taps; 20 → 60 kg was sixteen). Same control on both stages, with the **decimal key dead on the
  reps stage**. The typed value flows into reps/weight **as you type**, so the verdict line stays
  live. Tapping the number again returns to the steppers.

**Weight stepping snaps to the 2.5 kg grid** — it moves to the next multiple of 2.5 in the
direction tapped, it does **not** add 2.5 to the current value. From a keypad-typed 57 kg:
`+` → 57.5 → 60 → 62.5; `−` → 55 → 52.5. On-grid values are indistinguishable from plain
arithmetic, which is the common case.

- **2.5 kg is a UI constant, global and hard-coded.** Not per-exercise, not per-machine, not a
  setting. No schema field, and nothing new is asked at create time.
- `−` **clamps at 0** for weight and **at 1** for reps. Never negative.
- **Tap only. No hold-to-repeat, no acceleration** — auto-repeat on a thumb target overshoots,
  and the correction overshoots back. Any distance worth accelerating is keypad distance.

### 6.3 Seeding

- **Reps** seed from your **most recent entry for this exercise on any machine** — rep counts
  transfer between machines in a way loads do not. **Cold start: 5 reps.**
- **Weight is pre-filled only if you proved it on this exact machine** — the most recent entry on
  the machine in scope. For free-weight exercises this is simply your most recent entry for the
  exercise.
- **Otherwise the weight stage opens blank with the keypad already up.** Not a new control — the
  sheet already has that mode, chosen automatically at the one moment it is obviously right.
  A new machine is a type-it-in moment: the load does not transfer and you set the pin from
  scratch anyway.
- **Never seed a weight from another machine.** It puts a number you have never lifted *there*
  one tap from Save. **The app never guesses a load it cannot back up** — there is no arbitrary
  `20 kg` default anywhere.
- With the seed usually already correct, the common log is **two taps: Next, Save.** The known
  cost is accepted: after a deload or a one-off heavy single the seed misleads and you pay the
  correction. Seeding from the *current best* is rejected — it quietly encourages logging a
  rep-max you did not hit.

### 6.4 The machine caption — gym-bound only

**The sheet never resolves a machine. Its caller does.** The sheet receives a machine, displays
it, and lets you correct it. Resolution therefore costs **zero taps** and there is no third stage.

| Caller | Machine comes from |
|---|---|
| Detail screen Log bar | the screen's own machine qualifier (§5.3) |
| Library resume card *Log again* | the entry being resumed |
| History row → edit | the entry being edited |

The **sticky current gym's job is upstream** — it decides which machine the detail screen opens
scoped to (§5.3). **It is never consulted inside the sheet.**

**The caption line:** one quiet, **tappable** line above the giant number — `Hammer Strength ·
Fitness X` — present on **both stages**. It reads as a caption, not a control; the number stays
the only thing on screen with weight. Both stages, because the failure this exists to catch is
the **mislabelled-by-stale-sticky-gym** entry, and that is only caught if the machine is on screen
at commit time. Do not hide it "unless something is odd" — a strip that comes and goes shifts the
layout and stops being trusted.

**Free-weight sheets carry no machine row at all** — not a disabled one, not a placeholder.

**Tapping the caption opens the same flat machine menu the detail screen uses** (§5.3), plus two
rows the nav-bar menu does not need:

- **`New machine here`, one per gym section.** The gym is implied by the section, so there is no
  gym picker and no second decision. A one-field alert (`Name this machine — optional`, with
  Skip), then the machine is created and the sheet resolves to it. **Always ask** — you cannot
  know at creation time whether a second machine is coming.
- **`New gym…`** at the bottom. Standing in an unfamiliar gym is exactly when you need one.

This closes the only hole in the caller-resolves framing: the first gym-bound log at a gym with
no machine for that exercise, where no caller *can* supply one.

**Stickiness splits by mode.** Picking a machine at another gym while **logging** silently moves
the current gym — that is what makes "changeable in one tap" mean anything. While **editing** it
**never** touches the current gym: fixing a three-week-old entry from your couch must not
relabel what you log next.

### 6.5 The verdict line — weight stage only

Under the number, one line with six states:

| Condition | Line |
|---|---|
| Saving would reach the goal (below) | `Reaches your goal of 140 × 5` |
| Beats `best[reps]` | `Beats your 5-rep best by 2.5 kg` |
| Equals `best[reps]` | `Matches your 5-rep best` |
| Below `best[reps]` | `Your 5-rep best is 55 kg` |
| No entry at that rep count, no usable sibling | `First entry at 5 reps` |
| No entry at that rep count, sibling has history | `No history here — 55 kg × 5 on Hammer Strength` |

The fifth state is the **hint** — the same sentence and the same most-recently-used sibling as
§5.4, in **secondary colour, visibly softer than a real verdict**. Zero new layout: it is a fifth
state of a line that already reserves that space. It replaces nothing of value — at a brand-new
machine `First entry at 5 reps` is true and tells you nothing at precisely the moment you most
need a number.

The first state is the **crossing**, from [#71](https://github.com/hermanno3005/Chalk/issues/71).
It shows only when **all** of these hold:

- the sheet's current scope has a goal, and the entries in that scope do **not** already reach it;
- `reps >= goal.reps` — monotonic backfill counts here too, so a 6-rep entry at a 5-rep goal's
  weight crosses it;
- `weight >= goal.weight`.

- **It takes over from *Beats*, *First entry* and the hint.** At the crossing the goal is the
  news. By construction it can only ever replace those three.
- **The ordinary line returns** as soon as the weight steps below the goal. The line stays live
  under the steppers.
- It is drawn with a **full donut in the goal colour** in front of the words — the only full
  coloured ring in the app, so *about to reach* reads differently from *reached* (§12.5). The
  `Verdict` enum gains a goal case for this.
- **No haptic.** Stepping back and forth across the goal weight must not buzz.
- **Changing the machine caption** (§6.4) re-reads that machine's goal along with its entries, so
  the verdict always matches the scope the entry will land in.
- **There is no gap line in ordinary logging.** Below the goal the verdict is the ordinary one,
  and nothing about the goal shows.
- **After Save, nothing new** — §6.7 is unchanged. The only acknowledgement is the greyed goal
  line you land on.

**Stage one stays silent.** The line is meaningless until both numbers exist, and showing the
target on the reps stage would turn the log sheet into a lookup surface — the detail screen's job.
That includes the goal: no goal text on the reps stage.

### 6.6 Edit mode

Tapping a row in the history sheet (§5.6) **reopens this same sheet**, seeded from **that entry**
rather than from your most recent one, presented as an edit. **No new sheet is designed.**

- **Reps, weight and machine are editable. The date is not.**
- Save **writes back in place**.
- **Changing the machine moves the entry silently** — it leaves the history list you are looking
  at and both curves change. No confirmation, no toast: mistakes here are cheap (move it back),
  and *move* and *delete* are already distinct gestures on that row.
- Editing never moves the current gym (§6.4).
- **The crossing (§6.5) is judged against every other entry in scope**, the one being edited
  excluded — the same rule the verdict already uses. Raising an old entry past the goal says so,
  and reopening the entry that reached it still says so. **There is no "un-reaches your goal"
  state** when you lower it: the goal quietly becoming unreached is the derivation working.

### 6.7 Validation and commit

- **Save is enabled only for `reps >= 1` and `weight > 0`.** No upper bound, no outlier
  confirmation, no hard ceiling — every threshold eventually blocks a real lift, and a heavy leg
  press clears any plausible cap. **A typo is corrected, not prevented**, which is what makes
  §5.6 load-bearing rather than optional.
- 0 kg is displayable but **not savable**.
- **After saving, the sheet closes**, the detail screen flashes a brief confirmation, and the
  curve updates behind it. The sheet never stays open to log again. **In strength there is no run
  of entries to batch**: an entry is typed at the rack, one lift at a time, and sessions are not
  modelled. **This holds for strength only.** An endurance block is typed afterwards from the
  watch's lap list, which is a run, so endurance's sheet takes the whole block as a grid — and
  still writes one entry per row, with nothing wrapping them (§13.7).

---

## 7. Exercise library — the home screen

From [#8](https://github.com/hermanno3005/Chalk/issues/8) (variant C1), with gym administration
from [#14](https://github.com/hermanno3005/Chalk/issues/14) and
[#18](https://github.com/hermanno3005/Chalk/issues/18). Prototype:
[`docs/prototypes/exercise-library/`](docs/prototypes/exercise-library/README.md).

The root of the `NavigationStack`. **A sectioned tile grid under a resume card, with search
pinned in thumb reach.**

**There is no "Chalk" title. A `Strength | Endurance` segmented control takes its place**
([#96](https://github.com/hermanno3005/Chalk/issues/96)): sticky across launches, Strength on
first launch, and on the home screen only. Each half has its own home screen. This section is the
strength half's; endurance's is the same screen over ergs (§13.5). The Gym menu, `Manage gyms…`
and a `Settings…` row (§13.3) sit in both halves' overflow.

### 7.1 Layout

1. **Resume card**, top. The last thing you logged: exercise name, `8 × 52.5 kg · today`, a
   one-tap **Log again** (opens the log sheet, machine taken from that entry — §6.4) and a tap
   through to its detail screen. It is the single likeliest thing you want, so it gets the
   biggest target on the screen.
   **It carries the goal donut** ([#70](https://github.com/hermanno3005/Chalk/issues/70)) — 18 pt,
   leading the last-entry line, with **no words**. Three states: **none**, with the slot still
   reserved, so every card's subtitle is indented and the card never changes shape; **partial**;
   and **reached**, a full grey ring rather than nothing, so success never looks like "no goal".
   - **Only a goal at the resumed entry's own scope** — the entry's machine for a gym-bound
     exercise, the exercise for a free-weight one. **There is no fallback to a sibling machine's
     goal**, so a log at a holiday gym never shows your home machine's goal.
   - **The donut is inert.** Taps pass through to the card body; it is not a target between
     *Log again* and the card.
2. **Search field, pinned in thumb reach.** Filters instantly. **A name matching nothing offers
   *Create it* as the last result** — find and create are the same gesture.
3. **Tiles, grouped into sections** — one section per group in **your** order (`sortIndex`),
   **Ungrouped last**. Each tile shows the exercise name and what you last did
   (`8 × 52.5 kg · today`). **Tiles within a group order by recency** of last entry. **Tiles carry
   no goal in any form**: a tile would have to guess a scope via the current gym.
4. **No browsable list.** Past the grid, you type.

**Empty state** (no exercises): real copy saying what the app is for, plus a primary button that
opens the create sheet. Not a wordmark.

### 7.2 Groups

**User-owned ordered buckets, not a taxonomy.** `Compound / Legs / Push / Pull / Core` ships as a
**suggestion**, seeded on first launch, fully renameable and deletable. "Compound" beside "Legs"
is incoherent as a classification and entirely fine as a shelf you arranged yourself.

**The grouping's job is structure, not navigation** — that is what makes it cheap. It never has
to beat typing three letters, so it does not need to be fast, only legible. It does nothing at
three exercises and starts paying at roughly twenty.

- **The group is asked for at create time** (§7.3), defaulting to **Ungrouped** — filing an
  exercise is one step, not two. Ungrouped stays a free answer: you often meet a machine before
  you know which shelf it belongs on (ADR-0003).
- **Re-filing happens after the fact, two ways:** drag a tile into a section (the fast path for
  a nearby group), or **Arrange mode** — overflow → *Arrange*, exited by a visible **Done** that
  replaces the overflow button — which puts a `•••` group picker on every tile. **The menu is the
  path that always works**; dragging the length of a 42-tile scroll to reach Ungrouped never will
  be pleasant. **Arrange is the periodic re-shelving pass**, not the primary way an exercise
  reaches a group — you open it every few months to look over the whole library at once.
- **Edit groups** (overflow) is a sheet: reorder — which *is* the section order on this screen —
  rename, delete, add. **Deleting a group never deletes exercises**; they fall back to Ungrouped.

Three SwiftUI hazards the prototype hit for real, all of which cost a round:

1. **`.draggable` and `.contextMenu` on the same view fight** — both are long-press driven and
   the context menu wins every time. Do not put both on a tile.
2. **`.draggable` on a `Button` rarely fires** — the button's gesture claims the press. Tiles are
   plain views with `.onTapGesture`.
3. **Do not sort the library in a computed property.** The drop-target highlight is observable
   state, so every frame of a drag re-ran a full sort once per group. Cache the ordering and
   refresh it on mutation.

Also: **a Debug build of SwiftUI is far slower than Release** — switch schemes before concluding
anything about perceived performance.

### 7.3 Creating an exercise

A sheet: **a name field, a `Group` menu row beside it, and a two-way segmented control,
Free weight / Gym machine.** Progressive disclosure — **the gym and make fields do not exist
until you pick *Gym machine***. Each kind option carries a one-line footer stating the test:
**does the load transfer between gyms?**

**The group row sits in the first section, with the name**, which keeps the reveal
**append-only** — picking *Gym machine* appends the machine section and moves nothing above it —
and splits the sheet along its real seam: name and group are library concerns, kind and machine
are derivation concerns.

**It lists the groups in `sortIndex` order with `Ungrouped` last and selected by default.** It
says *Ungrouped*, not *None*, and sorts it last, so the picker reads as a small map of the
library screen the exercise is about to land on (§7.1). This deliberately differs from the `Gym`
picker below it, which says `None`: a machine with no gym is not somewhere called None, it does
not exist yet. **There is no `New group…` row** — a missing group has a correct answer, Ungrouped,
where a missing gym does not; new shelves are made in *Edit groups* (§7.2, ADR-0003).

No increment is asked for. Nothing else.

### 7.4 Gyms

The overflow carries a **Gym menu**: the current-gym picker, plus **`Manage gyms…`** at its foot —
a direct sibling of *Edit groups*, symmetric on purpose.

**The current-gym picker orders by recency** — when you last logged an entry there, most recent
first, with the current gym pinned to the top. **Derived from entries: no stored index, no
maintenance.** The two or three gyms you actually use float; the holiday gym sinks on its own.
There is no auto-archive rule.

**Archive is the removal primitive.** Archiving **hides, never destroys** — the gym keeps its
machines and every entry they hold, and its rep-maxes stay derivable forever. **Archive is a
display concept and nothing more: the derivation never sees `isArchived`.**

- An archived gym **leaves the current-gym picker** and leaves the top of the machine menu, but
  that menu keeps **one `Archived` section at the very end**. **Picking a machine there logs the
  entry and un-archives its gym as a side effect.** There is deliberately **no `restore` verb** —
  the one moment you need a gym back is the moment you are standing in it.
- **Archiving the gym you are standing in clears the current-gym setting** rather than leaving it
  pointed at something hidden.
- **Hard delete exists only for a gym with no machines** — the typo you just made, where there is
  nothing to lose. "Delete" and "lose history" never share a tap.

**Rename is cosmetic**, because identity is `Gym.id` and the current-gym setting holds that UUID,
not the name.

**Duplicates are prevented, not merged.** A **near-name match warns at gym creation** (all three
creation doors: the library Gym menu, the create-exercise sheet, and the log sheet's `New gym…`).
The repair for a duplicate that slipped through is `Move to another gym…` on each machine, then
archive the husk. **There is no gym merge.**

**`Manage gyms…`** is the one admin surface. Gyms in recency order:

- **tap** to rename
- **swipe** to archive
- **full-swipe** to delete a gym with no machines
- **archived gyms** in a section at the bottom
- **tap through a gym** to its machines, in Strength and Endurance sections (§13.11), where each
  machine row offers §7.5's three verbs

**Log-time menus stay pure pickers — they resolve, they never administer.** Nothing destructive
belongs one slip away from the two-tap log path. This is why the destructive verbs are not
long-presses in the picker.

### 7.5 Machine repair: `Rename…`, `Move to another gym…` and `Merge into…`

All three live on a machine row inside `Manage gyms…` → gym → machine, in both halves, and
**nowhere else**.

**`Rename…`** ([#101](https://github.com/hermanno3005/Chalk/issues/101)) edits the machine's
label without merging. It is cosmetic, as a gym's rename is: identity is `Machine.id`, so nothing
derived moves. **A blank name leaves the label unchanged.** On an erg's machine the label is its
model, so renaming runs the erg near-name check, and a same-gym match offers `Merge into…` that
sibling (§13.11).

**`Move to another gym…`** repoints `machine.gym`. It fixes the commoner mistake — filing a
machine under the wrong gym — and is half the duplicate-gym repair. **Its goal rides along
untouched**: the goal is three fields on the machine, and Move never pools two machines.

**`Merge into…`** re-points **every** entry from this machine onto a sibling and then
**hard-deletes** the loser. It exists because the real failure is **late relabelling**: ten
entries on the unlabelled default machine, then a month later you notice the stack says *Hammer
Strength* and create a machine for it. Same physical machine, two curves, and the number you
trust has silently halved. **No creation-time warning can catch that** — which is why, unlike
gyms, **strength machine creation gets no near-name warning.**

**Erg machines do get one**, for a different reason: an erg's label is its model, and the hint
prefers the same model at another gym by label, so model spellings must converge across gyms. It
runs on create, `Rename…` and Move, warns and never blocks (§13.11). It does not catch late
relabelling either; Merge still does.

- **Targets are same-gym siblings of the same exercise or erg only** — exactly the sibling set
  the hints draw from. Merging across gyms is incoherent by construction.
- **When the sibling set is empty, `Merge into…` is absent from the row — not disabled, not
  greyed.** A dead verb on a rare admin screen is a puzzle.
- **One destructive confirmation, phrased as the outcome and carrying counts:**
  *"Move 8 entries to Hammer Strength and delete Unlabelled?"* This breaks the app's
  no-confirmation posture deliberately: it is the only action irreversible *in principle* —
  once entries are re-pointed, nothing records that they were ever separate — and the direction
  is the thing people get wrong. **No undo.**
- **Hard delete, not archive.** After a merge the loser holds zero entries by construction, so
  archiving preserves nothing and leaves an empty husk forever. **Machines gain no archived
  state** — `Archived` is a gym concept.

> **Implementation hazard — the one genuinely dangerous line in the app.** Deletion **cascades
> from `Machine` to its entries** (§3). The merge **must reassign every entry and flush the
> context *before* deleting the loser.** Invert that order, or delete on a context where the
> reassignment has not landed, and the cascade eats exactly the history the merge existed to
> save.

**Goals on a merge** ([#68](https://github.com/hermanno3005/Chalk/issues/68)): **the most recently
set goal wins**, the same rule as a kind change (§8). The goal with the later `goalSetAt` ends up
on the survivor and keeps its own `goalSetAt`; its ring origin recomputes over the pooled entries
dated before it. **The outcome does not depend on which way you merge** — direction is the thing people
get wrong, and getting it wrong must not cost you your only goal. (*Survivor keeps its own* was
rejected: in late relabelling the goal usually sits on the old machine, the one being deleted.)

The confirmation changes only when a goal is lost:

| Loser | Survivor | Text |
|---|---|---|
| no goal | no goal | unchanged |
| goal | no goal | unchanged — the loser's goal moves across |
| no goal | goal | unchanged |
| goal | goal | gains the lost-goal clause: *"Move 8 entries to Hammer Strength and delete Unlabelled? Your goal of 140 × 5 is kept; 1 other goal is cleared."* |

**The lost-goal clause is one string, shared word for word with §8.** It names the survivor, not
the goal being cleared.

**When the loser has zero entries** — possible now, since a goal can be set with nothing
logged — there is no entry sentence to carry the move, so the confirmation names what moves:

- the loser's goal survives: *"Move your goal of 140 × 5 to Unlabelled and delete Hammer
  Strength?"*
- nothing of the loser survives: *"Delete Hammer Strength?"*, plus the lost-goal clause if one
  applies.

> **The same hazard, for goals.** Write the winning goal onto the survivor **in the same save as
> the entry reassignment, before deleting the loser.** The cascade takes the loser's goal fields
> with it.

**Merge is all-or-nothing.** Every loser entry moves. Re-pointing only some of them — both
machines genuinely used — is served by §6.6's per-entry machine edit. **Do not build a
checkbox-select merge.**

Merge is affordable at all only because ADR-0002 stores no rep-max: it is a relationship edit and
nothing more, and the curve is simply correct on the next read. A goal is the one stored thing a
merge has to make a choice about, and the rule above is that choice (ADR-0004).

**Accepted cost, stated rather than hidden:** the repair is undiscoverable from where the problem
is noticed. You spot the split on a curve on the detail screen; the fix is four taps away behind a
gym admin sheet. That is the right trade for a rare repair. What it does **not** buy: merging two
machines that were genuinely different leaves the curve silently wrong with no recovery. The
tripwire is §2's — pull a container with Xcode's Download Container before doing something
irreversible.

### The complete repair map

| Wrong | Fix |
|---|---|
| Value on one entry | Edit it in the history sheet (§5.6, §6.6) |
| Machine on one entry | Edit it in the history sheet (§6.6) |
| Machine on **all** an entry set's entries | `Merge into…` (§7.5) |
| Label of a machine | `Rename…` (§7.5) |
| Gym of a machine | `Move to another gym…` (§7.5) |
| Kind of an exercise | Change kind (§8) |
| Gym you no longer visit | Archive (§7.4) |

---

## 8. Changing an exercise's kind

From [#2](https://github.com/hermanno3005/Chalk/issues/2) and
[#9](https://github.com/hermanno3005/Chalk/issues/9). Reached from the detail screen's overflow
(§5.5). Both directions exist; **each is one decision, with no orphans and no permanent null
case.**

**Free-weight → gym-bound.** Prompt once for **which machine the existing entries belong to**
(picking or creating one, at a gym), then move them wholesale. Every existing entry gets that
machine. **The exercise's goal moves onto that machine too**, keeping its `goalSetAt`, and is
nilled on the exercise in the same save as the entry move (§3 invariant 8). The prompt appears
when there are entries **or** a goal, so its copy must make sense with zero entries (e.g. *"Which
machine is this on?"* — final wording is the build's).

**Gym-bound → free-weight.** **Pool everything, behind one confirmation that names the
consequence out loud:** *"Bench Press has entries on 3 machines. They'll merge into one curve."*
Entries keep their exercise and **nullify their machine link**; the now-meaningless `Machine`
rows are deleted.

**Goals: the most recently set wins** ([#67](https://github.com/hermanno3005/Chalk/issues/67)).
The machine goal with the latest `goalSetAt` is copied onto
the exercise, keeping its own `goalSetAt`, **before any machine is deleted**; every other goal dies
with its machine. The confirmation appears whenever there is a consequence to name — entries on
more than one machine, **or a goal being cleared** — and when a goal is lost it gains the
lost-goal clause shared with §7.5:

> *"Bench Press has entries on 3 machines. They'll merge into one curve. Your goal of 140 × 5 is
> kept; 1 other goal is cleared."*

The clause names the survivor; the count covers the losers. With zero or one goal the confirmation
is unchanged. **With zero entries the sentences about entries are dropped** and the clause
stands alone (*"Your goal of 140 × 5 is kept; 1 other goal is cleared."*), so no goal disappears
unannounced.

This merges numbers from separate machines into one curve — the pollution the model otherwise
forbids — except that here **you are asserting that the load transfers**, which is what makes it
legitimate. Keeping the machines around for a possible flip-back is rejected: it creates machines
belonging to a free-weight exercise, which the model says cannot exist.

Not offering the flip at all is also rejected: a genuine misclassification would then be
unfixable without deleting the exercise and losing its history.

---

## 9. Navigation map

```
NavigationStack
└── Home (§7, §13.5)                   root; one per half
    ├── Strength | Endurance           segmented control in the title; sticky; switches in place
    │
    ├── Strength half = Library (§7)
    │   ├── search field (pinned)      filters in place; "Create it" as last result
    │   ├── resume card
    │   │   ├── Log again    → Log sheet (§6)             sheet
    │   │   └── card body    → Exercise detail            push
    │   ├── tile             → Exercise detail            push
    │   ├── + / "Create it"  → Create exercise (§7.3)     sheet
    │   └── overflow
    │       ├── Arrange                                   in-place mode, exit via Done
    │       ├── Edit groups (§7.2)                        sheet, strength groups
    │       ├── Gym ▸                                     shared (below)
    │       └── Settings… (§13.3)                         shared (below)
    │
    ├── Endurance half = Erg library (§13.5)
    │   ├── search field (pinned)      "Search or add an erg"; "Create it" as last result
    │   ├── resume card
    │   │   ├── Log again    → Lap-list sheet (§13.7)     sheet
    │   │   └── card body    → Erg detail                 push
    │   ├── tile             → Erg detail                 push
    │   ├── + / "Create it" / Add your first erg
    │   │                    → Create erg (§13.6)         sheet
    │   └── overflow
    │       ├── Arrange                                   in-place mode, exit via Done
    │       ├── Edit groups (§7.2)                        sheet, endurance groups
    │       ├── Gym ▸                                     shared (below)
    │       └── Settings… (§13.3)                         shared (below)
    │
    └── shared by both overflows
        ├── Gym ▸
        │   ├── current-gym picker (§7.4)                 menu
        │   └── Manage gyms… (§7.4)                       sheet
        │       └── gym → machines, Strength and Endurance sections (§13.11)
        │           ├── Rename… (§7.5)                    erg: near-name check, may offer Merge into
        │           ├── Move to another gym… (§7.5)       erg: may ask Merge · Move anyway · Cancel
        │           └── Merge into…          (§7.5)       confirmation alert
        └── Settings… (§13.3)                             sheet; heart-rate zones only

Exercise detail (§5)
├── machine qualifier (gym-bound only)  → machine menu (§5.3)     menu
├── overflow → Rename / Change kind (§8) / Set a goal… / Delete exercise
│   └── Set a goal… / Change goal…      → Goal sheet (§12.3)      sheet
├── readout `best for N reps ›`         → History sheet (§5.6)    sheet
│   ├── row tap                         → Log sheet, edit mode    sheet
│   └── swipe                           → Delete (full-swipe off)
├── goal line (no ›)                    → Goal sheet (§12.3)      sheet
└── Log bar                             → Log sheet (§6)          sheet

Log sheet (§6)                          stage 1 reps ⇄ stage 2 weight
└── caption line (gym-bound only)       → machine menu + New machine here / New gym…

Goal sheet (§12.3)                      stage 1 reps ⇄ stage 2 weight
├── Set goal                            → closes
└── Clear goal (only with a goal)       → closes, no confirmation

Erg detail (§13.8)
├── machine qualifier (gym-bound only)  → machine menu (§5.3)     menu
├── zone buttons Z1–Z5                                            in place
├── incline menu (speed only)                                     menu
├── overflow → Rename / Change unit… (no entries only) / Change kind (§13.11) /
│              Set a goal… (zones set) / Delete erg
│   ├── Set a goal… / Change goal…      → Endurance goal sheet (§13.10)   sheet
│   └── Change unit…                    → unit choice; names a goal it clears
├── Set your heart-rate zones (no zones)→ Settings (§13.3)
├── readout `N entries ›`               → Point sheet (§13.9)     sheet
│   ├── row tap                         → Lap-list sheet, edit mode       sheet
│   └── swipe                           → Delete (full-swipe off)
├── `N entries over 20:00 ›`            → Over-20:00 list (§13.9) sheet
│   ├── row tap                         → Lap-list sheet, edit mode       sheet
│   └── swipe                           → Delete (full-swipe off)
├── goal line (no ›)                    → Endurance goal sheet    sheet
└── Log bar                             → Lap-list sheet (§13.7)  sheet

Lap-list sheet (§13.7)                  one row per entry; keypad always up
├── caption line (gym-bound only)       → machine menu + New machine here / New gym…
├── Next / New row
├── row minus (not on the last row)     → removes the row
└── Cancel (once touched)               → Discard N entries? / Discard changes?

Endurance goal sheet (§13.10)           zone · duration · incline (speed only) · intensity
├── Set goal                            → closes
└── Clear goal (only with a goal)       → closes, no confirmation

Settings (§13.3)                        Z2–Z5 lower bounds
└── Save (all four valid)               → closes
```

**Every screen state to build**, so none is invented at the keyboard:

| Screen | States |
|---|---|
| Library | empty (first launch) · normal · searching, with results · searching, no match (*Create it*) · Arrange mode |
| Resume card | no goal (slot reserved) · goal, partial ring · goal reached (full grey ring) |
| Exercise detail | zero entries, free-weight (bare text) · zero entries, gym-bound with usable sibling (text + hint) · zero entries, gym-bound with no usable sibling (bare text) · one entry (flat curve, ghost far above) · normal · gym-bound with no machine yet (no *Set a goal…*) |
| Goal line | absent (no goal) · gap (`Goal 140 × 5 · 40 kg to go`) · reached (grey) · under the zero-entry text · under the zero-entry text and hint |
| Log sheet | stage 1 steppers · stage 1 keypad · stage 2 steppers · stage 2 keypad · stage 2 blank + keypad (unproven machine) · edit mode · Save disabled |
| Verdict line | six states (§6.5) |
| Goal sheet | stage 1 steppers · stage 1 keypad · stage 2 blank + keypad · stage 2 steppers · goal line: above best · already reached (grey) · first goal · *Set goal* disabled · *Clear goal* present (a goal exists) |
| History sheet | populated (always — it is only reachable from a cell that exists) |
| Manage gyms | no gyms · gyms · archived section · gym with no machines (delete available) · machine with no sibling (no *Merge into…*) |
| Merge confirmation | the four goal rows of §7.5 · loser with zero entries, its goal moving · loser with zero entries, nothing moving |
| Kind-change confirmation | entries on several machines · plus the lost-goal clause · zero entries, clause alone |
| Home | Strength · Endurance (each half above its own library) |
| Erg library | empty (no ergs; seeded groups hidden) · normal · searching, with results · searching, no match (*Create it*) · Arrange mode |
| Endurance resume card | absent (nothing logged) · no goal · goal, partial ring · goal reached (full grey ring) |
| Create erg | no unit (Save disabled) · unit chosen · gym-bound (default) · transferable |
| Settings | zones not set · incomplete or invalid (Save disabled) · set (edit only) |
| Erg detail | zones not set (*Set your heart-rate zones*) · nothing logged on the scope, bare text · nothing logged, gym-bound with hint · normal · zone with no line (text, up to two quotes) · zone with only entries over 20:00 (text and caption) · over-20:00 caption · gym-bound with no machine yet (no *Set a goal…*) · *Change unit…* present (no entries) |
| Endurance goal line | absent (no goal) · gap · reached (grey) · `not held yet` |
| Lap-list sheet | first-ever block (blank) · seeded · several rows · zone line blank (no zones) · peak below average (red cells) · *Save N* disabled · gym-bound caption · Cancel confirmation · edit mode (one row, date in title, plain *Save*) |
| Point sheet | window only · with divider · emptied (open and empty) |
| Over-20:00 list | populated |
| Endurance goal sheet | live line: above · already reached (grey) · not held yet · *Set goal* disabled · *Clear goal* present |
| Manage gyms → gym | Strength section · Endurance section · empty section hidden |
| Erg near-name check | other-gym match warns · same-gym match picks on create · same-gym match offers *Merge into* on rename · Move onto a gym with a match (Merge · Move anyway · Cancel) |
| Unit change | no goal · goal cleared, named |

There is no error state beyond §3's container failure. There is no network, so there is nothing
to fail.

---

## 10. Build order

Each step leaves the app runnable on the phone.

1. **Schema and container** (§3) — five entities, `ChalkSchemaV1`, local-only configuration.
2. **`RepMaxCurve`** (§4) with unit tests: backfill, the `reps > 12` flooring rule, the ghost.
   No `ModelContainer` in these tests.
3. **Library screen** (§7.1–7.3) — tiles, sections, search, create sheet, empty state. Groups
   seeded.
4. **Exercise detail** (§5.1–5.2) — curve, ghost, scrub readout, Log bar. Free-weight only.
5. **Log sheet** (§6.1–6.3, 6.5, 6.7) — two stages, steppers, keypad, verdict, save.
   Free-weight only. **The app is now useful.**
6. **History sheet and editing** (§5.6, §6.6).
7. **Gyms and machines** (§3, §5.3, §6.4) — the machine qualifier, the caption line, the shared
   machine menu, the current gym, hints (§5.4, §6.5's fifth state).
8. **Arrange mode and Edit groups** (§7.2).
9. **`Manage gyms…`** (§7.4) — rename, archive, delete-empty, move, merge (§7.5).
10. **Change kind** (§8).

Goals ([#72](https://github.com/hermanno3005/Chalk/issues/72)) build on top, in this order:

11. **Storage and `Goal`** (§3, §12.1–12.2) — the goal fields, the `2.0.0` schema and the
    required migration test, the `Goal` value with its unit tests (no `ModelContainer`).
12. **Goal sheet and the detail screen's goal line** (§5.5, §12.3–12.5).
13. **The log sheet's crossing** (§6.5, §6.6).
14. **The resume card's donut** (§7.1).
15. **Goals under kind change and merge** (§8, §7.5).

Endurance ([#107](https://github.com/hermanno3005/Chalk/issues/107)) builds on top, once its docs
are on `main` ([#122](https://github.com/hermanno3005/Chalk/issues/122)), in this order:

16. **Storage** (§13.1) — schema `3.0.0` and its migration test against a `Chalk-2.0.0.store`
    captured **before any model file changes**, the valid-interval check
    ([#108](https://github.com/hermanno3005/Chalk/issues/108)).
17. **The two halves and the erg library** (§13.5–13.6) — the segmented control, half-scoped
    library, per-half group seed, empty state, create-erg sheet, the unit lock, a bare erg
    detail ([#109](https://github.com/hermanno3005/Chalk/issues/109)).
18. **Settings and `HeartRateZones`** (§13.3), with unit tests against an injected
    `UserDefaults` suite ([#110](https://github.com/hermanno3005/Chalk/issues/110)).
19. **The lap-list sheet on a transferable erg** (§13.7), and the written form on tiles and the
    resume card (§13.2) ([#111](https://github.com/hermanno3005/Chalk/issues/111)).
20. **Gym-bound ergs and recency** (§13.7, §13.12) — the machine caption, the qualifier, the
    once-per-Save un-archive, intervals in gym recency
    ([#112](https://github.com/hermanno3005/Chalk/issues/112)). **Endurance is now useful for
    logging.**
21. **`ZoneLine`** (§13.4) with unit tests, no `ModelContainer`
    ([#113](https://github.com/hermanno3005/Chalk/issues/113)).
22. **Erg detail** (§13.8) — zone buttons, incline menu, readout, zone line, the zones gate, the
    over-20:00 caption ([#114](https://github.com/hermanno3005/Chalk/issues/114)). **Endurance is
    now useful at the machine.**
23. **Zones with no line, and the hint** (§13.8)
    ([#115](https://github.com/hermanno3005/Chalk/issues/115)).
24. **History, edit and delete** (§13.9, §13.7's edit mode)
    ([#116](https://github.com/hermanno3005/Chalk/issues/116)).
25. **Machine repairs** (§7.5, §13.11) — Manage gyms' sections, `Rename…`, the erg near-name
    check, Merge and Move on ergs ([#117](https://github.com/hermanno3005/Chalk/issues/117)).
26. **Change kind on ergs** (§13.11) ([#118](https://github.com/hermanno3005/Chalk/issues/118)).
27. **Endurance goals** (§13.10) — `EnduranceGoal` with unit tests, the goal sheet, the goal line,
    the unit change clearing a goal ([#119](https://github.com/hermanno3005/Chalk/issues/119)).
28. **The endurance resume card's ring** (§13.5)
    ([#120](https://github.com/hermanno3005/Chalk/issues/120)).
29. **Endurance goals under merge and kind change** (§13.11)
    ([#121](https://github.com/hermanno3005/Chalk/issues/121)).

---

## 11. Out of scope

Carried from the map's Out of scope. These are **decided**, not deferred by accident.

- **App Store distribution.** Sideloading from Xcode with free provisioning is the v1 delivery.
  _Amended 2026-10-22:_ Chalk is now designed for a release, so that paying for the membership
  is the only step left (§15). Shipping one is still out of scope.
- **iCloud sync.** Gated behind a paid Apple Developer Program membership. The schema is built to
  CloudKit's rules so sync becomes a capability change plus one line — shipping it is not part of
  v1. See ADR-0001, including the one unverified claim it rests on.
- ~~**Export and import.**~~ _Reversed 2026-10-22:_ backup and restore, §15.
- **Apple Watch app.**
- **Workout and program planning** — routines, planned sessions, rest timers. Sessions are not
  part of this domain model at all.
- **Outdoor cardio, body metrics and measurements** — GPS runs and rides, bodyweight,
  measurements. Indoor ergs are endurance (§13); outdoor cardio has no machine to calibrate.
- **Sharing, social, multi-user.** No backend of any kind.
- ~~**Pounds, and any unit setting**~~ _Reversed 2026-10-22:_ a weight unit and a distance unit,
  app-wide, §15 ([ADR-0009](docs/adr/0009-units-are-rewritten-never-converted-for-display.md)).
  Each further setting is still its own decision, never a row added in passing. An erg's unit
  is still chosen per erg at create, and Chalk still converts nothing between an erg's units.
- **A trend over time** — no "5RM this year" chart anywhere ([#16](https://github.com/hermanno3005/Chalk/issues/16)).
  Backfill makes such a chart a guaranteed-rising staircase, and the dated history sheet already
  answers "when".
- **Undo, tombstones, retraction entities, audit trails** ([#11](https://github.com/hermanno3005/Chalk/issues/11)).
- **An all-entries log screen.** The curve is how you reach history.
- **Materialised rep-maxes.** See ADR-0002 — the obvious optimisation, explicitly rejected.
- **Weight prescription** — pace, progression, "lift 130 today", or anything that plans a
  session. A goal is a number you name; Chalk never tells you what to lift (§12).
- **A history of goals reached** — no trophy shelf, no `reachedAt`, no record of past goals.
  Setting a goal replaces the old one and nothing remembers it (§12).

## 12. Goals

From [#72](https://github.com/hermanno3005/Chalk/issues/72), built from the map
[#62](https://github.com/hermanno3005/Chalk/issues/62) and its eight resolved tickets.
Storage is governed by ADR-0004. Prototype:
[`docs/prototypes/goals/`](docs/prototypes/goals/README.md) (R2, the donut).

On each **scope** you can name one **goal**: a weight at a rep count you have not lifted yet. A
free-weight exercise has one scope; a gym-bound exercise has one per machine. Chalk shows the goal
quietly, never tells you what to lift, never celebrates, and keeps no record of past goals.

### 12.1 What is stored

- **Three optional fields on the scope, not an entity** (§3, ADR-0004): `goalReps: Int?`,
  `goalWeight: Double?`, `goalSetAt: Date?` — on `Exercise` while free-weight, on `Machine` for
  gym-bound. One goal per scope holds by structure. **A partly filled set of three is no goal.**
- **Setting a goal** writes all three, with `goalSetAt = now`. That one write replaces whatever
  goal was there and is also what restarts the ring. **Clearing a goal** sets all three to nil.
  **There is no other write.**
- **Nothing else is stored.** No `reachedAt`, no origin number, no history of goals. **Reached**,
  the **gap** and the ring's origin are all derived, so ADR-0002 stands untouched: there is no
  stale state to repair.
- A goal at more than 12 reps is an ordinary goal. A 1-rep goal is an ordinary goal with
  `reps = 1` — there is no one-rep-max concept.

### 12.2 The `Goal` value

A Foundation-only struct beside `RepMaxCurve` (§4), and **the only way to build a goal** from the
three fields: it is nil unless all three are set. It is built from the goal fields plus the
scope's `[Entry]`:

| Member | Meaning |
|---|---|
| `reps`, `weight` | the goal |
| `current` | `RepMaxCurve.best(atLeast: reps, in: entries)` — off the drawn axis, so `reps > 12` works, and monotonic backfill applies: a `5 × 95` reaches a 1-rep goal of 95 |
| `isReached` | `current >= weight` |
| `gap` | `weight − (current ?? 0)`, or zero when reached — the whole goal weight with nothing logged |
| `origin` | `best(atLeast: reps)` over the scope's entries dated **strictly before** `setAt`, else zero. An entry at the same instant does not count. Sound because `Entry.date` is immutable (§3 invariant 6) |
| `progress` | the donut's fill, `(current − origin) / (weight − origin)`, clamped to 0…1, and 1 when reached |

`current >= origin` holds by construction — the current best is taken over a superset of the
origin's entries — so the ring never reads negative. Correcting or deleting an entry recomputes
everything: a goal it was reaching silently becomes unreached, and an origin it set drops.

**Scoping stays the caller's job**, exactly as for `RepMaxCurve`: every entry for a free-weight
exercise, one machine's entries for a gym-bound one. A small read/write helper resolves the goal
fields for a scope, so **screens never touch the three raw fields directly.**

### 12.3 The goal sheet

From [#65](https://github.com/hermanno3005/Chalk/issues/65). Opened from the detail screen's
overflow (`Set a goal…` / `Change goal…`, §5.5) or by tapping the goal line.

- **The log sheet's two-stage giant number, borrowed whole** — reps, then weight — with the same
  steppers, keypad, 2.5 kg snapping and clamps (§6.1–6.2). **Share that input logic with the log
  sheet; do not copy it.**
- **Nothing else of the log sheet:** no machine caption, because the caller supplies the scope
  (the one the detail screen is showing); no seeded weight, because a goal is by definition one
  you have not lifted; no verdict line.
- **Reps start at the detail screen's selected rep count**, or at 5 when there is no scrub readout
  (§5.4) — the log sheet's and the hint's cold start.
- **The weight stage opens blank with the keypad up.** The app never suggests a load it cannot
  back up.
- **The commit button reads `Set goal`, never `Save`**, and is enabled for any `reps >= 1` and
  `weight > 0`. No ceiling. A goal can be set on a scope with zero entries.
- **One line under the weight**, live as you type, in the goal colour — grey in its
  already-reached state — with **no donut**, since there is no goal yet for a ring to fill toward:

  | Condition | Line |
  |---|---|
  | weight > `best[reps]` | `40 kg above your 5-rep best` |
  | weight ≤ `best[reps]` | `Already reached — your 5-rep best is 115 kg` |
  | no entry reaches `reps` | `First goal at 5 reps` |

  An already-reached value is shown, not blocked. With the weight still blank the line is
  silent, except `First goal at 5 reps`, which does not depend on the weight.
- **`Clear goal`** sits at the foot of the sheet, only when the scope has a goal. **No
  confirmation**; the sheet closes. It is the only way a goal leaves a scope without naming
  another, and it lives nowhere else.
- **Replacing a reached goal is the same act as naming the first one** — tap the line, type,
  `Set goal`. The detail screen refreshes after a set or a clear.

### 12.4 The goal line on the detail screen

From [#64](https://github.com/hermanno3005/Chalk/issues/64).

- **One line directly under the scrub readout's subhead** (§5.1): `Goal 140 × 5 · 40 kg to go`,
  led by the donut. On the zero-entry screen it sits under §5.4's text, and under the hint.
- **Reached, the whole line and donut go grey**: `Goal 140 × 5 · reached`. The goal you crossed
  stays visible; nothing celebrates.
- **No line at all when the scope has no goal.** On a gym-bound exercise, one machine's goal never
  appears under another machine's curve; switching the qualifier switches the line (§5.3).
- **The line is tappable and opens the goal sheet, and carries no `›`** — unlike the history row
  above it, so the two stacked tappable rows stay distinguishable.
- **The goal is never drawn on the chart.** No marker, no rule, no change to the ghost curve or
  the y-axis framing; §5.1's empty space stays empty.
- `ExerciseDetailModel` exposes the scope's `Goal?` and the line's text and state, re-derived on
  every refresh and every qualifier switch, and hands the goal sheet its scope and selected reps.

### 12.5 Presentation

- **One goal colour, orange** — a named colour used by every goal surface and nothing else: the
  goal line and its donut, the resume card's ring, the goal sheet's line, and the crossing
  verdict.
- **A reached goal is always grey.**
- **The donut is 18 pt**, always leading its words (or the last-entry line, on the resume card),
  and is **one shared view** drawn in all three places. The only full *coloured* ring in the app
  is the crossing verdict (§6.5).
- Where it appears: the goal line (§12.4), the resume card (§7.1) and the log sheet's crossing
  (§6.5). Nowhere else.
- Views, colour and the donut drawing are not unit-tested. Check them on the phone, starting with
  the resume card's leading gutter — no prototype ever showed a ring on that card.

### 12.6 Out of scope for goals

Beyond §11's two:

- **More than one goal per scope**, and goal ladders per rep count.
- **Goals on library tiles**, or on any surface that would have to resolve a scope via the current
  gym. **Borrowing another machine's goal** anywhere, the resume card included.
- **Drawing the goal on the chart**, and any change to the ghost curve.
- **Celebration** — prompts, animations, haptics, or a post-Save message on reaching a goal.
- **A gap line in ordinary logging**, and any goal text on the reps stage.
- **An "un-reaches your goal" state** when editing.
- **A goal at a not-yet-created machine.** A gym-bound exercise with no machine offers no
  `Set a goal…` (§5.5). Decided in [#72](https://github.com/hermanno3005/Chalk/issues/72) rather
  than in a ticket; reopen it if that turns out to matter.

## 13. Endurance

From [#107](https://github.com/hermanno3005/Chalk/issues/107), built from the map
[#88](https://github.com/hermanno3005/Chalk/issues/88) and its eighteen resolved tickets. Governed
by ADR-0005 (zones), ADR-0006 (the zone line), ADR-0007 (the endurance goal) and ADR-0008
(storage); **where this section and an ADR disagree, the ADR wins.** Prototypes:
[`docs/prototypes/endurance-home/`](docs/prototypes/endurance-home/README.md),
[`docs/prototypes/endurance-log/`](docs/prototypes/endurance-log/README.md) and
[`docs/prototypes/endurance-detail/`](docs/prototypes/endurance-detail/README.md). Their
screenshots are the reference for layout and copy.

Chalk's second half. Strength answers *what do I load at the rack*; endurance answers **what do
I set on this machine to hit this effort** — Z4 for six minutes on this treadmill. You keep a
library of **ergs**, type the watch's lap list into a grid after a block, and the erg's detail
screen reads back, per **heart-rate zone**, the **intensity** you held at each duration over your
last ten **visits**. The motivating fact is that the same treadmill speed costs a very different
heart rate from one gym to the next, so the job is **calibrating a machine against your heart
rate**, not logging workouts. §1's *no sessions, no sets* stands: four intervals are four
**entries**, and nothing wraps them.

This section uses `CONTEXT.md`'s endurance words exactly (**Strength**, **Endurance**, **Erg**,
**Transferable**, **Unit**, **Intensity**, **Incline**, **Average heart rate**, **Peak heart
rate**, **Heart-rate zone**, **Zone line**, **Visit**, **Settings**, **Origin**). What you log is
an **entry**: *interval* is what the watch timed, never a stored thing of its own, and the code's
*valid interval* (§13.1) is an entry that counts. *Set* (the noun) stays on the _Avoid_ line. Read
ADR-0008 before touching storage — it records the decision a future reader will most want to
"fix" — and ADR-0006 before touching the derivation.

**Everything strength already does carries over to ergs unless this section says otherwise**:
scope (§4), gyms, machines, the current gym and archive (§7.4), the shared machine menu (§5.3,
§6.4), the hint (§5.4), history, edit and delete (§5.6, §6.6), goal storage (§12.1), Merge and
Move (§7.5) and the kind change (§8). They carry over because they are the same code (§13.1).
Each subsection below names only what differs.

### 13.1 Storage — schema `3.0.0`

From [#100](https://github.com/hermanno3005/Chalk/issues/100) and
[#105](https://github.com/hermanno3005/Chalk/issues/105). Governed by ADR-0008.

**No new entity, relationship or delete rule.** Endurance is fifteen attributes on §3's five
entities, every one optional or defaulted:

- An entry is an **`Entry`**.
- An erg is an **`Exercise` whose `unit` is set** — `isErg` is `unit != nil`. The Swift type
  stays `Exercise`; `CONTEXT.md` carries the note.
- An erg's machine is a **`Machine`**.
- An endurance group is an **`ExerciseGroup` with `half` set to endurance**.

| Entity | Added | Type | Default |
|---|---|---|---|
| `Exercise` | `unit` — raw value of `speed` / `watts` / `split` / `level`; nil on a lift | `String?` | nil |
| `Exercise`, `Machine` | `goalZone` (1…5), `goalDuration` (whole s) | `Int?` | nil |
| `Exercise`, `Machine` | `goalIntensity` (the erg's unit), `goalIncline` (% on speed, nil otherwise) | `Double?` | nil |
| `Entry` | `duration` (whole s), `averageHeartRate`, `peakHeartRate` (whole bpm) | `Int` | 0 |
| `Entry` | `intensity` (as typed; a split as seconds per 500 m), `incline` (%, read on speed ergs only) | `Double` | 0 |
| `ExerciseGroup` | `half` | `String` | strength |

> **The tempting fix, and why not.** Splitting out an `Erg` entity, or an entity of its own for
> endurance entries, so each row holds only meaningful fields. Every repair Chalk has works by
> re-pointing `Entry.machine` and `Machine.exercise`, and §7.5's hazard guards **one** cascading
> relationship. A second entity doubles it, and a path that remembers one but not the other
> silently deletes history. With one entity, every repair carries ergs with no change.

- **A transferable erg stores `kind` as `freeWeight`**, raw value and Swift case alike. A doc
  comment on `ExerciseKind` says *free-weight on a lift, transferable on an erg*, and code reads
  `isGymBound` in both halves. **Do not rename the case**: strength code would then call a
  barbell `.transferable`, and renaming the raw value needs a stage that rewrites rows.
- **`goalSetAt` is shared** by both halves' goal fields. A row is a lift's or an erg's, never
  both, so it holds at most one goal, and *the most recently set goal wins* (§7.5, §8) keeps
  reading one field. `GoalScope.clear()` nils **all seven** goal fields. The half is read from
  the owner, never from which goal fields happen to be set.
- **A valid interval** — duration > 0, intensity > 0, average heart rate set — is the endurance
  twin of `isALift`. Use it wherever recency, seeding or the derivation reads an entry.
  `isALift` is already false for every interval, so `RepMaxCurve`, `LastEntry` and every lift
  reader ignore intervals unchanged.
- **Intensity is a `Double` as typed, and every derived comparison goes through whole unit
  steps**: `Int((value / step).rounded())`. 0.1 km/h is not exact in binary floating point the
  way 2.5 kg is (§3). This covers point rounding, reached, the gap and the ring.
- **Fetches filter by half; relationships do not need to.** The library fetch filters on
  `unit`, and the group fetch and the group seed on `half`. Traversals stay one half by
  construction.
- **The zones are not in the store** (§13.3).
- §3's invariants 9–11 are endurance's, and invariant 8 covers both halves' goal fields.

**Versioning.** Bump `versionIdentifier` to **`3.0.0` in place, with `stages` still empty**, as
`2.0.0` was (§3). The migration test reopens a real `ChalkTests/Fixtures/Chalk-2.0.0.store`,
**captured from the app at `2.0.0` before any model file changes**. It holds *Bench Press*
(free-weight, `5 × 100`, goal `5 × 140`) and *Chest Press* (gym-bound, machine *Plate-loaded* at
*Fitness X*, `8 × 60`, machine goal `8 × 72.5`), both in *Push*, with every date fixed. Through
`ChalkStore.open` it asserts every row, both strength goals, and every new field at its default
(`unit == nil`, endurance goal fields nil, entry fields 0, `isALift` true, not a valid interval,
`Push.half == strength`). It then writes a gym-bound speed erg with a machine goal and an entry
at *Fitness X*, saves, reopens, and asserts both goals coexist on one gym. The `1.0.0` test stays
and gains the same default assertions; the round-trip test covers every new field; the schema
test asserts `3.0.0`, five entities and no stages.

Download the container (§2) before the first launch of the `3.0.0` build on the phone — and
first check that Download Container works on Xcode 27.1, which the storage research left
unverified.

### 13.2 Units, and how an entry is written

From [#94](https://github.com/hermanno3005/Chalk/issues/94).

An erg speaks **one unit**, chosen at create (§13.6). Chalk knows four:

| Unit | Accepts | Written | Harder is | Averaged as |
|---|---|---|---|---|
| Speed | 0.1 km/h | `15.0 km/h (4:00 /km)` | higher | itself |
| Watts | whole W | `220 W` | higher | itself |
| Split | 0.1 s per 500 m | `1:45 /500 m`, `1:45.3 /500 m` | **lower** | through `1/split³` and back |
| Level | whole | `Level 12` (`L12` on the goal line) | higher | mean, rounded to a whole level |

- **A speed's pace is `60 / km/h`, to the whole second, for display only.** It is the one number
  ever worked out from an intensity. Nothing is stored about it.
- **A speed keeps its tenth** (`15.0 km/h`), unlike a weight's trimmed zero (§3). **A split
  trims a trailing `.0`.**
- **No mph, no steps/min, no /1000 m.** Chalk converts nothing between units and knows no brands
  — a *Concept2 RowErg* is an erg you named that way. _Amended 2026-10-22:_ a speed is written
  in the app-wide distance unit, km/h with min/km or mph with min/mile (§15). That is a scale,
  not a fifth unit.
- **The written form of an entry:** `6:00 at 15.0 km/h (4:00 /km) · 1 % · 168/174 bpm`. Average
  before peak. Incline is left out at 0 % (the log grid still shows it). Durations are `m:ss`, or
  `h:mm:ss` from an hour.
- **The word is *harder*, never *better*.**

### 13.3 Heart-rate zones and Settings

From [#92](https://github.com/hermanno3005/Chalk/issues/92). Governed by ADR-0005.

**Five zones, typed in.** You type **four whole-bpm lower bounds, Z2 to Z5**. Z1 has no floor and
Z5 no ceiling. **Chalk owns no zone model and computes no boundary** — never from an age, never
from a max, never seeded from your logged peaks. You work the numbers out from your watch or a
lactate test, so Chalk and the source you trust always agree. **No boundary is ever called a
threshold**: which one that is depends on a zone model, and Chalk owns none.

- **One set, shared by every erg**, so Z4 is the same heart rate on the rower and the treadmill.
  You can move the boundaries, never the count.
- **Read live.** No entry stores a zone and nothing caches a boundary, so moving one changes every
  zone line on the next read, with nothing to migrate.
- **Held per device, beside the store** — one `UserDefaults` key holding four `Int`s, as
  `currentGymID` is held (§3). It sits in the app container's `Library/Preferences`, so Download
  Container carries it; a recovered `.store` alone leaves only the lookup gated, never wrong.
  Once sync exists, a second device starts gated.
- **A Foundation-only `HeartRateZones` value is the only way in.** Its failable reader treats a
  missing, short, out-of-order or out-of-range value as *not yet set*. `zone(of:)` returns 1…5,
  **with a heart rate exactly on a boundary in the upper zone**, since zones are stored as lower
  bounds. The zones are injected as `UserDefaults`, as `LibraryModel`'s are, so tests use a
  suite of their own.

**The Settings screen** is Chalk's first, reached from a **`Settings…` row in the home screen's
overflow, in both halves**. It sits outside either half.

- Four whole-bpm fields, Z2 to Z5. **Each is 40–230 and strictly higher than the one below.**
- **Save needs all four**, and is disabled otherwise, so a half-typed set never exists.
- **Edited, never cleared.** Once set, nothing that depends on zones is ever gated again.
- **It holds the zones and nothing else** — no export, no import, no share row (§2). Each further
  setting is its own decision, never a row added in passing.

**Logging never needs zones.** Before the first save you log as normal; only the lookup is gated
(§13.8), and entries logged before zones were set join the lines the moment they are.

### 13.4 The zone line

From [#95](https://github.com/hermanno3005/Chalk/issues/95), with the ghost settled by
[#102](https://github.com/hermanno3005/Chalk/issues/102) and
[#98](https://github.com/hermanno3005/Chalk/issues/98). Governed by ADR-0006.

For one zone, on one scope, at one incline:

```
point[d] = mean(intensity) over entries on the scope
           whose average heart rate is in the zone,
           whose incline is this incline,
           whose duration is exactly d,
           on the last 10 visits that hold one
```

- **Membership is the average heart rate's alone.** Peak heart rate is not read. A heart rate on a
  boundary goes to the upper zone (§13.3).
- **Durations group exactly as typed.** A `6:02` is its own point and never joins `6:00`. This is
  what makes a one-minute entry as honest as a twenty-minute one: a short rep's lagging heart
  rate is only ever compared with another rep of the same length, so there is no duration floor.
- **The window is the last ten visits** — calendar days on which you logged that duration in that
  zone on the scope. Five reps in one day are one visit. **The window never moves with time**,
  only when a new visit pushes the oldest out, so a machine you have not used in months still
  shows what you last held. That is strength's *the number never moves on its own* (§4), kept.
- **Each point carries its mean heart rate and its entry count**, for the readout (§13.8).
- **Each point is rounded to its unit's step, nearest**: speed and watts as they are; a split
  averaged through `1/split³` and back; a level averaged and rounded to a whole level.
- **Inclines never mix.** 15 km/h at 1 % never claims to be 15 km/h flat. Incline is to the zone
  line what reps are to the curve, and never a scope.
- **Points join by straight segments in duration order**, ending at the shortest and longest
  durations you have done. **No extrapolation, and no correction**: physiology says a longer
  entry in a zone needs a lower intensity, but a point out of that order is drawn as it is.
- **A zone you have never landed in has no line.** A machine you are new to shows only the zones
  your first visit happened to reach.
- **No ghost** ([#102](https://github.com/hermanno3005/Chalk/issues/102) found no sound model).
  Unlike the strength curve, the zone line stands alone.

**Scoping is the caller's job**, exactly as for `RepMaxCurve` (§4): every entry for a
**transferable** erg, at every gym; **one machine's** entries for a **gym-bound** one. Hints never
enter it.

**`ZoneLine`** is a Foundation-only struct beside `RepMaxCurve`, built from already-scoped
`[Entry]`, the zones, the unit, the zone and the incline. **No SwiftData dependency, nothing
cached** — ADR-0002 carries over unchanged. An edited heart rate can move an entry onto another
zone's line; that is the derivation working. Boundary membership, exact-duration grouping, the
ten-visit window and the per-unit mean are the parts an implementer gets subtly wrong; they get
tests, with no `ModelContainer`.

### 13.5 The home screen, in two halves

From [#96](https://github.com/hermanno3005/Chalk/issues/96) and
[#104](https://github.com/hermanno3005/Chalk/issues/104). Prototype:
[`docs/prototypes/endurance-home/`](docs/prototypes/endurance-home/README.md) (variant A, round
two).

**A `Strength | Endurance` segmented control stands where the "Chalk" title was.** One tap,
always visible on the home screen, and the plainest way to say there are exactly two halves.

- **Sticky across launches**, stored per device (`@AppStorage`, backed by a `Half` enum that also
  backs `ExerciseGroup.half`). The app reopens on the half you left it in. **Strength on first
  launch**, so the shipped experience is unchanged until you choose endurance.
- **On the home screen only.** Switching always lands on that half's home screen, and nothing
  remembers where you were in the other half.
- **Each half has its own resume card, search field, `+`, grid, groups, Arrange mode and Edit
  groups.** Search never covers both halves. `LibraryModel` takes the half and scopes all of them
  to it.
- **Shared by both halves:** the current gym and the Gym menu (§7.4), and `Settings…` (§13.3).

**The endurance home screen is §7's screen over ergs.** What differs:

- **The search field reads *Search or add an erg*.** *Create it* opens the create-erg sheet
  (§13.6) with the name filled in.
- **One tile per erg.** A treadmill at four gyms is one *Treadmill* tile; its machine is picked
  inside, as a gym-bound exercise's is.
- **Tiles and the resume card show the last entry in the written form** (§13.2), with when it
  was: `6:00 at 15.0 km/h · today` on a tile; the resume card's line carries the heart rates too.
  The last entry of an erg is its most recent valid interval.
- **The resume card** is the last erg you logged anywhere, with **Log again** into the lap-list
  sheet (§13.7) and a tap through to its detail screen. It carries the goal ring under §7.1's
  rules: **only a goal on the last entry's own scope** — the erg when transferable, that entry's
  machine when gym-bound — so a holiday gym's log never shows your home machine's goal.
- **The library starts empty.** No erg is preset: every erg's name, unit, classification and
  group is your own choice. **The empty state** is §7.1's, with *Calibrate the machines you train
  on*, a line on what an interval is, and **Add your first erg**.
- **Groups are §7.2's mechanics, with a set per half.** An erg sits only in an endurance group,
  an exercise only in a strength one. The suggestion is **`Treadmills / Rowing & Ski / Bikes`**,
  with **Ungrouped last** and no *Other* (Ungrouped is the catch-all) and no *Ergs* (every
  endurance machine is an erg). **The seeded groups are hidden while you have no ergs**, so the
  empty state carries no empty headers.
- **Each half seeds its groups once, with its own flag**, and a deleted suggestion stays deleted.

> **Seed hazard.** The endurance seed's *already seeded* guard must count **endurance groups
> only**. Strength's guard treats any group as seeded, so reusing it would leave every existing
> install — which already has strength groups — with no endurance groups. An updating install
> gets the three groups, exactly once.

### 13.6 Creating an erg

From [#93](https://github.com/hermanno3005/Chalk/issues/93) and
[#104](https://github.com/hermanno3005/Chalk/issues/104).

A sheet, reached from `+`, *Create it* and the empty state, with four rows:

- **Name** — plain text, **no suggestions**. Chalk keeps no vocabulary of machines, and no back
  door to presets.
- **Unit** — speed, watts, split or level, **starting on none**. **Save stays disabled until a
  unit is chosen**, so no erg exists without one. Chalk never guesses a unit, because a unit has
  no repair once the erg has entries.
- **Transferable / Gym-bound** — **starting on gym-bound**, each option with a one-line footer
  stating the test: **does the same number mean the same thing on every one of these machines,
  anywhere?** Gym-bound
  is the cheaper mistake: a cold start and a hint, rather than pooling numbers that should never
  meet. Unlike §7.3, picking gym-bound reveals no machine fields: the first log resolves the
  machine (§13.7).
- **Group** — §7.3's picker over the endurance groups, Ungrouped last and selected.

**The unit is changeable only while the erg has no entries**, from *Change unit…* in the erg's
overflow (§13.8), which is absent once there is an entry. Changing it **clears the erg's goal and
says so**: *Your goal of 260 W · 10:00 in Z3 is cleared.* Once there is an entry the unit is
locked, so no logged number is ever reinterpreted. **There is no repair for a wrong unit with
entries; deleting the erg is the accepted cost.**

### 13.7 The log sheet — a lap-list grid

From [#97](https://github.com/hermanno3005/Chalk/issues/97). Prototype:
[`docs/prototypes/endurance-log/`](docs/prototypes/endurance-log/README.md) (variant C, round
two).

You log **after the block**, reading the watch's lap list. **One sheet takes the whole block as a
grid, one row per entry**, and Save writes **one entry per row** with nothing grouping them
afterwards. The rows are a way of typing, not a session. This is why §6.7's *no run of entries to
batch* holds for strength only.

**Columns follow the watch's order**: `Time | km/h | % | Avg | Peak` on a speed erg, `Time |
<unit> | Avg | Peak` on the others, so your eye moves down the wrist and down the grid together.

**Input.**

- **One keypad, always up. No steppers** — with no pattern from one interval to the next, every
  number is a jump, and a jump is keypad distance (§6.2).
- ***Next* walks the cells left to right**, and becomes ***New row*** at the end of the last row.
  **A heart rate's last digit and a speed's tenth move on by themselves.** A heart rate's last
  digit is its third, or its second when the first is 4–9: every heart rate from 40 to 99 is two
  digits, and none from 100 to 230 starts with 4–9.
- **Typing in a cell replaces its seed**; you never delete a seeded number first.
- **Times fill from the right**, as on a microwave: `6`, `60`, `600` → `6:00`; `h:mm:ss` from an
  hour. **Typed to the second and never snapped**: a `6:00` rep is `6:00` because you typed it,
  and a `6:02` you do type stands on its own (§13.4).
- **A split takes a tenth after the decimal key** (`1:47.5`). **The decimal key is dead on watts
  and level.** Speed takes 0.1 km/h, and **off-step values are refused** (`15.05`).
- **Incline** is on every row of a speed erg, in **0.5 % steps, clamped at 0**. **0 % is a value**.
  It is seeded, and never defaulted to 1 %: Chalk never shows a number you did not set.

**Seeding.** **The first row is seeded from the scope's most recent valid interval** — the erg's
when transferable, the machine's when gym-bound, as §6.3 seeds a weight only from the machine in
scope. **Each new row is seeded from the row above.** A first-ever block opens blank.

**The line under the grid** shows **the zone of the focused row's average heart rate**, e.g. `Z4 ·
158–169 bpm`, **and nothing per row**, so the grid stays a plain copy of the watch. Without zones
set it is **blank, not a prompt** — logging never nags. **There is no goal crossing** (§6.5 has
one; no single row can reach a mean over visits).

**Validation and Save.**

- **Save reads `Save 5`** and is enabled only when every row is complete and valid: every
  number above zero (incline aside: 0 % is a value), **both heart rates 40–230**, and **peak ≥
  average**.
- **A row whose peak is below its average outlines those two cells in red**, and the line under
  the grid says why, so a disabled Save points at the row to fix.
- **Each row carries a visible red minus** to delete it, **except the last remaining row** —
  Cancel is how you log nothing.
- **Cancel asks *Discard 5 entries?* once anything is typed**, and swipe-down is disabled while
  the sheet has been touched. **An untouched sheet closes without asking.**
- After Save, the sheet closes; the detail screen behind it re-reads, as §6.7's does.

**The machine caption** (§6.4, gym-bound only) appears **once, above the grid, covering every
row**: a block is logged on one machine. It opens the shared machine menu with `New machine here`
and `New gym…`, and **resolves a machine as strength's does — a gym-bound erg can never log with
no machine** (invariant 4). A transferable erg's sheet carries no caption. §6.4's stickiness holds:
picking another gym's machine while logging moves the current gym at the pick. **Saving on an
archived gym's machine un-archives that gym and makes it current, once per Save**, not once per
row.

**Edit mode** is §6.6 over this sheet: tapping a history row (§13.9) **reopens the grid with one
row, seeded from that entry**.

- **No *New row*, no row delete, and a plain `Save`.** The date is in the title and not editable.
- Duration, intensity, incline, both heart rates and, on a gym-bound erg, the machine are
  editable. **Changing the machine moves the entry silently.**
- The line under the grid shows the edited row's zone, so you see where it will land.
- **Cancel asks *Discard changes?* only if something changed.**
- **Editing never un-archives a gym or moves the current gym** (§6.4).

The grid's keypad formats and clamps are **shared with the endurance goal sheet** (§13.10), not
copied.

### 13.8 Erg detail screen

From [#98](https://github.com/hermanno3005/Chalk/issues/98). Prototype:
[`docs/prototypes/endurance-detail/`](docs/prototypes/endurance-detail/README.md) (variant A,
round two).

**One zone at a time, laid out like §5.** Top to bottom:

1. **Zone buttons, `Z1`–`Z5`**, with an **incline menu at the trailing end on a speed erg**. They
   pick the effort and the grade you are about to train at. **A zone with no line on this scope
   and incline is dimmed but still tappable** — you see where you have never landed, and can
   still ask.
2. **The scrub readout.** One large intensity (`15.0 km/h`), a speed's pace under it (`4:00
   /km`), then **`6:00 in Z4 · 164 bpm · 12 entries ›`** — the point's duration, zone, mean heart
   rate and entry count. **The entry count is the uncertainty: no ± band is drawn**, because a
   band is a number Chalk computed and you never held. **The goal line** sits under it (§13.10).
3. **The zone line, 150 pt**, in the accent colour, a point on every duration you have done,
   joined by straight segments.
4. **Empty space**, as §5.1 leaves it.
5. **Log bar**, opening the lap-list sheet (§13.7).

**Toolbar:** back; the machine qualifier menu on a gym-bound erg (§5.3, unchanged, including which
machine the screen opens on); an overflow.

**The chart.**

- **The duration axis is linear and fixed at 0–20:00** on every erg and every zone, so lines
  compare and **switching zones never rescales the chart under your thumb**.
- **The intensity axis is framed to the data**, as §5.2's is. **A split is plotted upside down**,
  so harder is up on every erg.
- **Scrubbing snaps to durations you have done**: nothing between two points is a number you have
  held. `chartXSelection`, never a hand-rolled gesture, and **the selection is sticky** (§5.2).
- **The screen opens on the zone, duration and incline of the scope's most recent valid
  interval**, so the usual answer needs no taps.
- **No ghost.** Nothing is drawn that you have not held.
- **Entries over 20:00 are stored but not drawn**, as strength stores reps above 12. Each duration
  stands alone, so they change no drawn point. When the selected zone, incline and scope has any,
  a **dimmed `2 entries over 20:00 ›` caption** sits under the line, so a long entry — or a
  mistyped `60:00` — can still be found (§13.9).

**A zone with no line** shows text where the chart would be — `No Z4 on this machine yet.` /
`Nothing you've logged here averaged 158–169 bpm.` — and under it **up to two lines quoting the
nearest zone above and below that has a line**, at the duration closest to the selection:
`Z5 3:00 at 16.5 km/h — too hard`, `Z3 … — too easy`. **Quotes come from on-axis points only.** A
zone whose only entries are over 20:00 shows this state, with the caption under the text. This is
what makes a first visit useful: it often lands only in Z5, and Z5 still says where Z4 must be.

**Nothing logged on the scope** is §5.4's empty state: no chart, no axes, no readout, short text,
and the Log bar.

**The hint** (§5.4, carried over) is for a gym-bound erg whose machine in scope has no entries:

> `No entries here — 6:00 in Z4 at 15.0 km/h · 1 % on Technogym Run · Urban Gym`

- **The sibling prefers the same model at another gym** — a case-insensitive equal label —
  otherwise §5.4's most recently used sibling. It reuses `MachineHint`'s choice.
- **It quotes the sibling's line at the zone, duration and incline of the sibling's most recent
  valid interval** — the entry the lap-list sheet would seed from on that machine.
- **When that point has dropped out of the sibling's line, there is no hint.** It never quotes a
  number the line no longer holds, and it never falls back to another point (§5.4's rule).
- Text, visibly another machine's numbers, **never part of any line**. A transferable erg has no
  hint.

**Zones not set:** a **`Set your heart-rate zones`** row, which opens Settings, stands in place of
the zone buttons, readout and line (final wording is the build's). The Log bar works as normal.

**The overflow** carries the erg's lifetime operations, as §5.5's does:

- **Rename**.
- **`Change unit…`**, only while the erg has no entries (§13.6). Absent, not disabled, otherwise.
- **Change kind** (§13.11).
- **`Set a goal…` / `Change goal…`** (§13.10). **Absent until zones are set**, and absent on a
  gym-bound erg with no machine (§5.5).
- **Delete erg**, confirmed as §5.5's is, with the count.

The **erg detail model** sits beside `ExerciseDetailModel`, reached from the library model as
`detail(for:)` is. It holds the selected zone, duration and incline, the readout, the no-line text
and quotes, the hint, the over-20:00 caption, the zones gate and the goal line, and builds the
log, history and goal sheets' models.

### 13.9 History — the point's sheet

From [#103](https://github.com/hermanno3005/Chalk/issues/103).

**The readout's `12 entries ›` is the only door from the chart**, as §5.6's is. Tapping a point
does nothing; scrubbing only selects.

- **It lists every entry at this duration, zone and incline on this scope, from all time, newest
  first** — everything that could make the point.
- **A divider after the tenth visit**: `Older — not in the line`. **Nothing is flagged** — a mean
  has no one entry setting it. **The readout's count equals the rows above the divider**; the two
  never disagree.
- Rows read **`date · intensity (pace beside a speed) · avg/peak bpm`**. Duration, zone and incline
  are left out: the point fixes them.
- **The over-20:00 caption opens one flat list**, newest first, with no divider. Rows read **`date
  · duration · intensity · avg/peak bpm`**.
- **Tap a row → edit** (§13.7). **Swipe left → Delete**, exactly §5.6: full-swipe disabled, no
  alert, no undo.

§5.6's two non-special-cases hold:

- **An edit that moves an entry** to another duration, zone, incline or scope **makes its row
  vanish from the sheet it was opened from.** The sheet mirrors the point. Removing an entry
  inside the window can pull an older visit above the divider.
- **Deleting a point's last entry leaves the sheet open and empty.** Behind it, the selection
  falls to the nearest remaining duration in the zone; with none, the zone dims; with nothing left
  on the scope, §5.4's empty state.

**Without zones there is no readout, so no door.** Entries logged before zones were set are
reached once they are.

### 13.10 Endurance goals

From [#99](https://github.com/hermanno3005/Chalk/issues/99). Governed by ADR-0007, ADR-0004's
companion.

On each scope you can name one **goal**: **a point on the zone line** — a zone, a duration and an
intensity, plus an incline on a speed erg. Written `Goal 15.5 km/h · 6:00 in Z4 · 1 %`. Everything
in §12 holds unless it is named here.

**What is stored.** The four endurance goal fields plus the shared `goalSetAt` (§13.1), on the
erg while transferable and on the machine while gym-bound, through `GoalScope` only. **A partial
set is no goal, and a speed goal with no incline is no goal.** **A goal holds a zone, not a
bpm**, so it follows your boundaries when a lactate test moves them. Setting one writes all its
fields with `goalSetAt = now`; clearing nils all seven (§13.1).

**The `EnduranceGoal` value** is Foundation-only, beside `Goal` (§12.2), and the only way to build
an endurance goal: a failable init over the fields, the scope's `[Entry]`, the zones and the unit.
Everything below compares in whole steps (§13.1).

| Member | Meaning |
|---|---|
| `current` | the zone line's point at **exactly** the goal's zone, duration and incline — its ten-visit mean (§13.4) — or nil |
| `isReached` | `current >= goal`, or `current <= goal` on a split |
| `gap` | the distance in the unit's own step; nil when there is no point |
| `origin` | the point over entries dated **strictly before** `setAt`, or else the point as of the first visit after it |
| `progress` | `(current − origin) / (goal − origin)` in the unit's own number, reversed on a split, **clamped to 0…1**, and 1 when reached |

- **No backfill** across zones or durations. A lower zone or a longer duration at the goal's
  intensity never counts: the goal is read against its own point only.
- **A reached goal can un-reach with no edit**, when a slower visit pushes a faster one out of the
  window. Nothing is stored, so nothing needs repairing.
- **Unlike §12.2, `current >= origin` does not hold by construction.** A point can fall back
  below its origin, which leaves the ring empty rather than negative.

**The goal line** sits under the readout **whatever zone is selected**, and under the text in the
no-line and nothing-logged states, as §5.4's does.

- **Gap in the unit's step**: `0.4 km/h to go`, `12 W to go`, `2 s to go`, `2 levels to go`.
- **Reached:** `· reached`, the whole line grey.
- **No point:** `not held yet` — never a gap from zero.
- **No pace on the goal line**, so it stays short.
- **Tappable, no `›`, never drawn on the chart** (§12.4). Orange, grey once reached, no
  celebration (§12.5).

**The goal sheet** is a short form, not the two-stage giant number. Opened from the goal line or
the overflow.

- **Four rows: zone (`Z1–Z5` segmented), duration, incline (speed only) and intensity.**
- **Zone, duration and incline are seeded from the point you scrubbed to. Intensity is blank,
  with the keypad up** — a goal is by definition a number you have not held.
- **It uses the lap-list grid's keypad, formats and clamps**, shared rather than copied (§13.7).
- **One live line under the intensity**:

  | Condition | Line |
  |---|---|
  | above the point | `0.4 km/h above your 6:00 in Z4` |
  | at or below the point | `Already reached — your 6:00 in Z4 is 15.6 km/h` (grey) |
  | no point | `Not held yet — 6:00 in Z4 · 1 %` |

- ***Set goal* is enabled once every field is filled.** *Clear goal* sits at the foot, only with a
  goal, with no confirmation (§12.3). **A goal over 20:00 is valid**, and reads `not held yet`
  until you do one.

**Gates and edges.**

- **No goal before zones are set** — no goal may name a zone that does not exist yet. Zones are
  never cleared, so no goal ever loses them.
- **No goal on a gym-bound erg with no machine**, no goal on tiles, and never another machine's
  goal borrowed (§12.6).
- **A unit change clears the goal and says so** (§13.6).
- **No crossing on the lap-list sheet** (§13.7). You find out on the detail screen after Save.
- **The resume card's ring** is §7.1's, at the last entry's own scope (§13.5).

### 13.11 Repairs

From [#101](https://github.com/hermanno3005/Chalk/issues/101).

**Merge, Move and the kind change carry ergs unchanged in mechanism** — same erg, same gym, all or
nothing, one confirmation with counts, hard delete, and §7.5's *reassign and flush before
deleting*. Incline moves with its entries. What changes is the wording, and two additions.

- **Goals: the most recently set wins**, read off the shared `goalSetAt`, in both repairs. The
  lost-goal clause in endurance wording: *Your goal of 15.5 km/h · 6:00 in Z4 · 1 % is kept; 1
  other goal is cleared.* Move carries the machine's goal, as §7.5's does.
- **Change kind** (§8) works in both directions. **To gym-bound** asks *Which machine is this
  on?* when there are entries or a goal, and moves both there. **To transferable** pools every
  machine behind ***Treadmill has entries on 3 machines. They'll be read as one.***, plus the
  lost-goal clause. **The endurance wording never says *curve*.** Unit and incline are untouched:
  only the scope changes.
- **`Rename…`** on a machine row (§7.5), in both halves.
- **A near-name check on erg machines only.** An erg's label is its model, and the hint matches
  models across gyms by label (§13.8), so spellings must converge. It reuses gym creation's loose
  matching (`GymNameMatch`, §7.4) **against that erg's machines at every gym**, **warns but never
  blocks**, and offers the existing spelling: *You have a Technogym Excite at FitX — same model?*
  - **On create** (the caption menu's and the qualifier menu's `New machine here`): a match **at
    the same gym picks the existing machine**, so one gym never holds two machines with one
    label.
  - **On rename:** a same-gym match offers **Merge into** that sibling, with Merge's usual
    confirmation.
  - **On Move:** when the target gym already has a passing machine for this erg, Move asks *FitX
    already has a Technogym Excite. Merge into it?* → **Merge** (then Merge's confirmation) ·
    **Move anyway** · **Cancel**.
  - **Strength machines get no near-name check**, for §7.5's reason.
- **`Manage gyms…`** is reachable from either half's overflow, and is one screen. **A gym's
  machines sit in two sections, Strength and Endurance**, each ordered by most recent use, an
  empty section hidden, **never filtered by the half you came from**. **The gym row's machine
  count covers both halves**, since that count decides whether hard delete is offered.
- **An erg's unit has no repair once it has entries** (§13.6).

The repair map (§7.5) gains:

| Wrong | Fix |
|---|---|
| Transferable / gym-bound | Change kind (§13.11) |
| Unit, before any entry | `Change unit…` (§13.6) |
| Unit, with entries | Delete the erg |

### 13.12 Recency

From [#106](https://github.com/hermanno3005/Chalk/issues/106).

- **A gym's recency is its latest lift or valid interval** on any of its machines. It orders the
  shared current-gym picker, the machine menu's gym sections and `Manage gyms…` (§7.4), so a gym
  you visit only for endurance does not sink.
- **An erg machine's recency is its latest valid interval.** `Machine.lastLogged` and
  `Gym.lastLogged` count a lift or a valid interval; a machine's is its own half's by
  construction.
- **A transferable erg's entries count toward no gym**, as a free-weight lift's do not.
- Archive and stickiness are unchanged: a Save un-archives and makes current (§13.7); an edit does
  neither.

### 13.13 Tests

Rule names in test titles follow the existing style, and each suite's doc comment names the one
or two rules an implementer gets subtly wrong.

- **No `ModelContainer`:** `ZoneLine`, `EnduranceGoal`, and `HeartRateZones` against an injected
  `UserDefaults` suite (prior art: `RepMaxCurveTests`, `GoalTests`).
- **Through `LibraryFixture`**, over a real temporary store and its own `UserDefaults` suite: half
  scoping, the per-half seed, create-erg's unit gate and lock, the grid, the erg detail, history,
  the goal sheet, the repairs and recency. The fixture gains erg, entry and zones helpers.
- **Store:** §13.1's migration and round-trip tests.
- **Not unit-tested:** views, the chart's drawing, zone colours, the ring and the keypad layout.
  Check them on the phone (§12.5). Zone colours are placeholders until then: Z1 grey, Z2 blue, Z3
  green, Z4 purple, Z5 red — **never orange, which goals own.**

### 13.14 Out of scope for endurance

Beyond §11:

- **Outdoor cardio** — GPS runs, rides, terrain, weather. There is no machine to calibrate.
- **Importing from a watch or platform** (Coros, Apple Health, Strava). Heart rate is typed by
  hand.
- **Sessions, workouts, interval programmes and timers.** Nothing groups a block once saved, and a
  visit is never stored.
- **Units beyond the four**: user-defined units, steps/min, /1000 m splits, and **any
  conversion between units**. (mph is the distance unit's, §15.)
- **Machine settings other than incline** — damper, resistance, programme.
- **Zones per modality, a zone count other than five, any zone model or computed boundary**, and
  naming any boundary *threshold*.
- **A ghost or any fitted or extrapolated line**, an HR–intensity fit, a minimum-duration floor,
  and a ± band.
- ***Am I getting fitter?* as a trend.** The window moving is the answer; no history of the line is
  kept or drawn.
- **Preset ergs**, and name suggestions on the create-erg sheet.
- **A repair for an erg's unit once it has entries.**
- **Brand knowledge of any kind** — Concept2 formulas, calibrations.
- **Settings rows beyond zones**, except the ones §15 adds.
- **Zones syncing across devices** — no sync exists.
- **A goal crossing on the lap-list sheet**, and a history of goals reached.

## 14. Still open

One thing, deliberately: **app identity.** The name (Chalk) and the icon. The bundle id
`com.hermannaust.Chalk` and the 18.0 deployment target are provisional facts from the skeleton
and may be revised. Nothing in this spec waits on it, and an icon is made, not decided.

## 15. Store-ready

From the launch-polish grilling of 2026-10-22, which has no ticket yet. The words are in
`CONTEXT.md`: **Weight unit**, **Distance unit**, **Relabel**, **Convert**, **Backup**,
**Restore**, **Bar**, **Plate breakdown**. Read
[ADR-0009](docs/adr/0009-units-are-rewritten-never-converted-for-display.md) and
[ADR-0010](docs/adr/0010-chalk-makes-and-restores-backups.md) before touching units or backups.

**The posture.** Chalk stays sideloaded and single-user, but it is built so that paying for the
developer account is the only step left before the App Store. The weekly re-sign is lived with
until the features below are done. No free workaround (SideStore, AltStore, a scripted rebuild)
is adopted.

### 15.1 Backup and restore

- **A backup** is one readable file holding everything Chalk knows, made from Settings and
  handed to the share sheet. It round-trips exactly.
- **A restore** replaces everything and never merges. Over a library that is not empty, it first
  says what will be lost and how old the backup is: `This replaces 1,240 entries with 980 from
  12 Mar 2026`. Chalk makes no automatic backup of its own, not even before a restore.
- **Make a backup before the team switch** and before a convert. This replaces *pull a
  container first*.

### 15.2 Units

- **Weight unit**: kg or lb. **Distance unit**: km or miles, which writes a speed as km/h with
  min/km or as mph with min/mile. Both are app-wide and independent, and both are chosen at
  onboarding.
- **Changing one once there are entries is a relabel or a convert**, two separate and plainly
  worded acts on Settings. A relabel keeps every number. A convert rewrites every number and
  goal onto the new scale, rounded to 0.5 kg, 1 lb or 0.1 km/h or mph, and is confirmed with a
  count.
- **The stepper grid follows the weight unit**: 2.5 kg, or 5 lb.

### 15.3 Onboarding

**One screen**: the weight unit, the distance unit, and a quieter *Restore from a backup* link.
There is no tour and no setup flow. Gyms, zones and exercises are still asked for at the moment
they matter, and if strangers turn out to be confused, the fix goes into the empty states.

### 15.4 Design

- **The layouts stay.** Chalk gains an identity on top of them: a palette and a treatment for
  the big numbers, taken from the chalk icon. **Two or three palettes are prototyped on the real
  detail screen before one is chosen.**
- **The library tiles stop truncating** their last entry, and the grid stops leaving half its
  width empty.
- **Haptics in three places only:** a tick at each scrub detent (a rep count on the curve, a
  duration on the zone line), a success tap when an entry saves, and a distinct one when a save
  reaches a goal. §6.5's *no haptic* at the stepper crossing stands.

### 15.5 Features

- **Spotlight and App Shortcuts.** Every exercise and erg is findable from the system search and
  opens on its detail screen.
- **Plate breakdown**, the first item cut if this list grows too long, and prototyped before it
  is built. An exercise may have a **bar**, set only by you at create or from the overflow
  (*No bar*, 20, 15 or 10 kg, or a typed weight), and has none until you set one. Under a readout
  with a bar, the plates per side come from the weight unit's standard set, or the nearest
  loadable weight below when the exact one is not loadable. There is no plate inventory per gym,
  and nothing for plate-loaded machines. It can be switched off on Settings.

### 15.6 Baseline

- **Every string in a String Catalog**, plurals and number formats included. English only.
- **VoiceOver** labels throughout, and chart descriptions so the curve and the zone line can be
  heard as audio graphs.
- **Dynamic Type** that the big readouts survive, and dark mode checked on the phone.
- **A privacy manifest**, and the store listing's screenshots and copy, ready for the day.

### 15.7 Decided against, or parked

- **A reps-in-reserve input.** `8 @ RIR 2` is read at 10 by you (§1).
- **A longer rep axis.** Sets above 12 are by feel, or found in the 12-rep history sheet, which
  lists every entry with `reps >= 12`.
- **Opening the curve anywhere but 5 reps.**
- **HealthKit or watch import.** Typing an endurance block after the session is fine (§13.14
  stands).
- **Siri lookups**, and **swiping between exercises**.
- **A log widget**, parked rather than rejected.
- **A second language at launch.**
