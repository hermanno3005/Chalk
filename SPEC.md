# Chalk v1 — build specification

This is the build-ready spec. It is the output of [the wayfinding map](https://github.com/hermanno3005/Chalk/issues/1)
and every decision ticket under it; each section names the ticket it came from so the reasoning
is one click away. **The reasoning is not repeated here — the decisions are.**

Read `CONTEXT.md` first: it is the glossary, and this document uses its words exactly
(**Entry**, **rep-max**, **monotonic backfill**, **strength curve**, **ghost curve**,
**free-weight**, **gym-bound**, **Group**, **Gym**, **Machine**, **Merge**, **current gym**,
**Archived**, **Hint**). Read `docs/adr/0001` and `docs/adr/0002` before touching persistence
or the derivation — they record the two decisions most likely to be "helpfully" undone.

Build it in the order of §10. Where this document says **must**, it is closing a hole an
implementer would otherwise fill by invention.

---

## 1. What Chalk is

A personal strength-record tracker for iOS. You keep a library of the exercises you actually
do, log what you lifted as plain `reps × weight` **entries**, and the app tells you what to
load at the rack.

It is **not** a workout logger. There are no sessions, no sets, no routines, no rest timers.
The unit of record is one entry. Every "best" number is derived at read time and never stored.

Single user. One device. No backend, no accounts, no sharing. Sideloaded from Xcode.

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

v1 ships **no export and no import** — no Settings screen, no share sheet, no file writer
([#17](https://github.com/hermanno3005/Chalk/issues/17)). Sync-later is the whole durability
story; entries are re-derivable by lifting again, and what the app is worth is the derivation.

The escape hatch is **Xcode's Download Container** (Devices & Simulators → Installed Apps),
used **on demand** — deliberately not pinned to the weekly ritual. This makes the store's
readability load-bearing: **no encrypted store, and no opaque `Transformable` attributes.**
Pull a container before doing anything irreversible (see the merge in §7.5).

---

## 3. Domain model and schema

From [#9](https://github.com/hermanno3005/Chalk/issues/9), amended by
[#14](https://github.com/hermanno3005/Chalk/issues/14). Governed by ADR-0001.

Five entities. Every attribute optional or defaulted; every relationship optional with an
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
  from entries; group order is `sortIndex`. Nothing else has a reader.
- **`ExerciseGroup.sortIndex` is a real field, not array position** — relationship arrays are not
  order-preserving when mirrored. `Gym` deliberately has **no** `sortIndex`: gyms order by
  usage recency, which they already know (§7.4).

### Persistence setup and versioning

```swift
enum ChalkSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
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
2. **The strength curve**, **150 pt tall**. Full-bleed was tried and rejected as making the screen
   read as a chart rather than as an exercise.
3. **Empty space.** It ships empty and that is deliberate
   ([#16](https://github.com/hermanno3005/Chalk/issues/16)): it keeps the Log bar high and
   thumb-reachable. Do not fill it with a recent-entries list or a rep-max strip.
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
reading `label · gym`. Switching it re-scopes the screen and **re-derives the whole curve**.

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

### 5.5 The overflow menu

- **Rename** — an inline field or one-field alert. Cosmetic; identity is the UUID.
- **Change kind** — the free-weight ↔ gym-bound flip (§8).
- **Delete exercise** — cascades to its entries and machines (§3). Confirm destructively, phrased
  as the outcome with the count: *"Delete Bench Press and its 84 entries?"* No undo.

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

Under the number, one line with five states:

| Condition | Line |
|---|---|
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

**Stage one stays silent.** The line is meaningless until both numbers exist, and showing the
target on the reps stage would turn the log sheet into a lookup surface — the detail screen's job.

### 6.6 Edit mode

Tapping a row in the history sheet (§5.6) **reopens this same sheet**, seeded from **that entry**
rather than from your most recent one, presented as an edit. **No new sheet is designed.**

- **Reps, weight and machine are editable. The date is not.**
- Save **writes back in place**.
- **Changing the machine moves the entry silently** — it leaves the history list you are looking
  at and both curves change. No confirmation, no toast: mistakes here are cheap (move it back),
  and *move* and *delete* are already distinct gestures on that row.
- Editing never moves the current gym (§6.4).

### 6.7 Validation and commit

- **Save is enabled only for `reps >= 1` and `weight > 0`.** No upper bound, no outlier
  confirmation, no hard ceiling — every threshold eventually blocks a real lift, and a heavy leg
  press clears any plausible cap. **A typo is corrected, not prevented**, which is what makes
  §5.6 load-bearing rather than optional.
- 0 kg is displayable but **not savable**.
- **After saving, the sheet closes**, the detail screen flashes a brief confirmation, and the
  curve updates behind it. The sheet never stays open to log again — sessions are not modelled,
  so there is no run of entries to batch.

---

## 7. Exercise library — the home screen

From [#8](https://github.com/hermanno3005/Chalk/issues/8) (variant C1), with gym administration
from [#14](https://github.com/hermanno3005/Chalk/issues/14) and
[#18](https://github.com/hermanno3005/Chalk/issues/18). Prototype:
[`docs/prototypes/exercise-library/`](docs/prototypes/exercise-library/README.md).

The root of the `NavigationStack`. **A sectioned tile grid under a resume card, with search
pinned in thumb reach.**

### 7.1 Layout

1. **Resume card**, top. The last thing you logged: exercise name, `8 × 52.5 kg · today`, a
   one-tap **Log again** (opens the log sheet, machine taken from that entry — §6.4) and a tap
   through to its detail screen. It is the single likeliest thing you want, so it gets the
   biggest target on the screen.
2. **Search field, pinned in thumb reach.** Filters instantly. **A name matching nothing offers
   *Create it* as the last result** — find and create are the same gesture.
3. **Tiles, grouped into sections** — one section per group in **your** order (`sortIndex`),
   **Ungrouped last**. Each tile shows the exercise name and what you last did
   (`8 × 52.5 kg · today`). **Tiles within a group order by recency** of last entry.
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

- **Nothing is asked at create time.** New exercises land in **Ungrouped**.
- **Assignment happens after the fact, two ways:** drag a tile into a section (the fast path for
  a nearby group), or **Arrange mode** — overflow → *Arrange*, exited by a visible **Done** that
  replaces the overflow button — which puts a `•••` group picker on every tile. **The menu is the
  path that always works**; dragging the length of a 42-tile scroll to reach Ungrouped never will
  be pleasant.
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

A sheet: **a name field and a two-way segmented control, Free weight / Gym machine.** Progressive
disclosure — **the gym and make fields do not exist until you pick *Gym machine***. Each option
carries a one-line footer stating the test: **does the load transfer between gyms?**

No group is asked for. No increment is asked for. Nothing else.

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
- **tap through a gym** to its machines, where each machine row offers §7.5's two verbs

**Log-time menus stay pure pickers — they resolve, they never administer.** Nothing destructive
belongs one slip away from the two-tap log path. This is why the destructive verbs are not
long-presses in the picker.

### 7.5 Machine repair: `Move to another gym…` and `Merge into…`

Both live on a machine row inside `Manage gyms…` → gym → machine, and **nowhere else**.

**`Move to another gym…`** repoints `machine.gym`. It fixes the commoner mistake — filing a
machine under the wrong gym — and is half the duplicate-gym repair.

**`Merge into…`** re-points **every** entry from this machine onto a sibling and then
**hard-deletes** the loser. It exists because the real failure is **late relabelling**: ten
entries on the unlabelled default machine, then a month later you notice the stack says *Hammer
Strength* and create a machine for it. Same physical machine, two curves, and the number you
trust has silently halved. **No creation-time warning can catch that** — which is why, unlike
gyms, **machine creation gets no near-name warning.**

- **Targets are same-gym, same-exercise siblings only** — exactly the sibling set the hints draw
  from. Merging across gyms is incoherent by construction.
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

**Merge is all-or-nothing.** Every loser entry moves. Re-pointing only some of them — both
machines genuinely used — is served by §6.6's per-entry machine edit. **Do not build a
checkbox-select merge.**

Merge is affordable at all only because ADR-0002 stores no rep-max: it is a relationship edit and
nothing more, and the curve is simply correct on the next read.

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
machine.

**Gym-bound → free-weight.** **Pool everything, behind one confirmation that names the
consequence out loud:** *"Bench Press has entries on 3 machines. They'll merge into one curve."*
Entries keep their exercise and **nullify their machine link**; the now-meaningless `Machine`
rows are deleted.

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
└── Library (§7)                       root
    ├── search field (pinned)          filters in place; "Create it" as last result
    ├── resume card
    │   ├── Log again        → Log sheet (§6)             sheet
    │   └── card body        → Exercise detail            push
    ├── tile                 → Exercise detail            push
    ├── + / "Create it"      → Create exercise (§7.3)     sheet
    └── overflow
        ├── Arrange                                       in-place mode, exit via Done
        ├── Edit groups (§7.2)                            sheet
        └── Gym ▸
            ├── current-gym picker (§7.4)                 menu
            └── Manage gyms… (§7.4)                       sheet
                └── gym → machines
                    ├── Move to another gym… (§7.5)
                    └── Merge into…          (§7.5)       confirmation alert

Exercise detail (§5)
├── machine qualifier (gym-bound only)  → machine menu (§5.3)     menu
├── overflow → Rename / Change kind (§8) / Delete exercise
├── readout `best for N reps ›`         → History sheet (§5.6)    sheet
│   ├── row tap                         → Log sheet, edit mode    sheet
│   └── swipe                           → Delete (full-swipe off)
└── Log bar                             → Log sheet (§6)          sheet

Log sheet (§6)                          stage 1 reps ⇄ stage 2 weight
└── caption line (gym-bound only)       → machine menu + New machine here / New gym…
```

**Every screen state to build**, so none is invented at the keyboard:

| Screen | States |
|---|---|
| Library | empty (first launch) · normal · searching, with results · searching, no match (*Create it*) · Arrange mode |
| Exercise detail | zero entries, free-weight (bare text) · zero entries, gym-bound with usable sibling (text + hint) · zero entries, gym-bound with no usable sibling (bare text) · one entry (flat curve, ghost far above) · normal |
| Log sheet | stage 1 steppers · stage 1 keypad · stage 2 steppers · stage 2 keypad · stage 2 blank + keypad (unproven machine) · edit mode · Save disabled |
| Verdict line | five states (§6.5) |
| History sheet | populated (always — it is only reachable from a cell that exists) |
| Manage gyms | no gyms · gyms · archived section · gym with no machines (delete available) · machine with no sibling (no *Merge into…*) |

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

---

## 11. Non-goals

Carried from the map's Out of scope. These are **decided**, not deferred by accident.

- **App Store distribution.** Sideloading from Xcode with free provisioning is the v1 delivery.
  Don't paint into a corner that blocks a future release; don't design for one either.
- **iCloud sync.** Gated behind a paid Apple Developer Program membership. The schema is built to
  CloudKit's rules so sync becomes a capability change plus one line — shipping it is not part of
  v1. See ADR-0001, including the one unverified claim it rests on.
- **Export and import.** No Settings screen, no share sheet, no file writer (§2).
- **Apple Watch app.**
- **Workout and program planning** — routines, planned sessions, rest timers. Sessions are not
  part of this domain model at all.
- **Body metrics and cardio** — bodyweight, measurements, runs.
- **Sharing, social, multi-user.** No backend of any kind.
- **Pounds, and any unit setting** (§3, §6.2).
- **A trend over time** — no "5RM this year" chart anywhere ([#16](https://github.com/hermanno3005/Chalk/issues/16)).
  Backfill makes such a chart a guaranteed-rising staircase, and the dated history sheet already
  answers "when".
- **Undo, tombstones, retraction entities, audit trails** ([#11](https://github.com/hermanno3005/Chalk/issues/11)).
- **An all-entries log screen.** The curve is how you reach history.
- **Materialised rep-maxes.** See ADR-0002 — the obvious optimisation, explicitly rejected.

## 12. Still open

One thing, deliberately: **app identity.** The name (Chalk) and the icon. The bundle id
`com.hermannaust.Chalk` and the 18.0 deployment target are provisional facts from the skeleton
and may be revised. Nothing in this spec waits on it, and an icon is made, not decided.
