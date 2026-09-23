# How a goal is stored

**Date:** 2026-09-15
**Question:** [#66](https://github.com/hermanno3005/Chalk/issues/66) — how is a goal stored, in
SwiftData, under [ADR-0001](../adr/0001-local-swiftdata-with-cloudkit-shaped-schema.md)'s
CloudKit-shaped constraints? Part of map [#62](https://github.com/hermanno3005/Chalk/issues/62).
**Scope:** the schema shape (fields vs. entity), where the derived `reached` and gap live,
what the migration is, and where a goal sits in SPEC §3's delete-rule table.
**Status:** findings only. The ADR sketched in §5 was adopted as
[ADR-0004](../adr/0004-a-goal-stores-its-reps-weight-and-when-it-was-set.md), with its merge sentence
corrected by [#68](https://github.com/hermanno3005/Chalk/issues/68); the ADR is the current word.

**Primary sources** are Apple's developer documentation and WWDC sessions. Two of the four
questions could not be fully settled from primary sources; both are marked **UNVERIFIED** and
§3 says what test settles them.

## Bottom line

1. **Two optional attributes on each of `Exercise` and `Machine`** — `goalReps: Int?`,
   `goalWeight: Double?` — not a first-class `Goal` entity. The decisive argument is not
   simplicity: it is that fields express *exactly one goal per scope* **structurally**, where an
   entity cannot express it at all under ADR-0001's no-`.unique` rule and would add an eighth
   row to SPEC §3's list of invariants the schema cannot express, plus an orphan sweep.
2. **The comparison lives *beside* `RepMaxCurve`**, in a Foundation-only `Goal` value struct in
   `Chalk/Chalk/Derivation/`, modelled on `LastEntry`. Not inside `RepMaxCurve` (a goal is not
   derived from entries, and every existing caller would have to pass one), and not in the view
   layer (three screens would restate `>=`). Presentation *state* — the words, the colour —
   belongs in the view model, exactly as `LogSheetModel.Verdict` does today.
3. **Migration is an additive, inferred one.** Apple's primary source for the mechanism is Core
   Data's inferred-mapping list, which names "Addition of an attribute" outright. Whether it
   should be spelled `ChalkSchemaV2` is a judgement call with a Chalk-specific catch (§3), and
   whether SwiftData applies an inferred migration when a plan is supplied with no matching
   stage is **UNVERIFIED** — settle it with a reopen test, not with reading.
4. **A goal adds no row to the delete-rule table** under option A. It is deleted exactly when
   its owner is, by the cascades already there, and it correctly survives `Gym --nullify-->
   Machine`. Under option B it costs two new cascade rows *and* an app-level sweep for the
   orphan that cascade cannot reach.

---

## 1. Fields versus an entity

The two candidates, both written to ADR-0001's rules:

**Option A — two optional attributes on each of two entities.**

```swift
@Model final class Exercise {
    // …existing…
    var goalReps: Int? = nil        // the pair is set together or not at all
    var goalWeight: Double? = nil   // kilograms, as everything else is (SPEC §3)
}

@Model final class Machine {
    // …existing…
    var goalReps: Int? = nil
    var goalWeight: Double? = nil
}
```

**Option B — a first-class entity.**

```swift
@Model final class Goal {
    var id: UUID = UUID()
    var reps: Int = 0
    var weight: Double = 0
    var exercise: Exercise?    // free-weight scope
    var machine: Machine?      // gym-bound scope
}

// with, on each owner:
@Relationship(deleteRule: .cascade, inverse: \Goal.exercise) var goal: Goal?
@Relationship(deleteRule: .cascade, inverse: \Goal.machine)  var goal: Goal?
```

### 1.1 CloudKit-shaped-ness

**Both are compliant in form.** A has optional attributes and no relationships at all, so there is
nothing for the rules to bite on. B has optional relationships with explicit inverses, no
`.unique`, and `.cascade` rather than `.deny` — which is the supported set (`.deny` is the only
rule Apple names as unsupported, per the SwiftData constraint table in
[Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)).

**But compliance is not the whole question — atomicity is.** Apple, verbatim, on `@Relationship`:

> "The iCloud servers don't guarantee atomic processing of relationship changes, so CloudKit
> requires all relationships to be optional. […] explicitly set the inverse before saving because
> CloudKit processes changes in an indeterminate order."
> — [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)

And Core Data's statement of the same thing:

> "Due to operation size limitations, CloudKit may not save relationship changes atomically. All
> relationships must have an inverse, in case the records synchronize out of order."
> — [Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)

Under A, `goalReps` and `goalWeight` ride on the same `CKRecord` as the exercise's `name` and
`kind`. They are last-writer-wins *together with their owner* and can never be half-present
relative to it. Under B, the `Goal` record and the link field on `Exercise` are separate records
that travel independently: a device can legitimately hold a goal whose exercise has not arrived,
or an exercise whose goal link points at nothing yet. Apple's own justification for requiring
optional relationships *is* that state. A has no such state to be in.

This is the same argument ADR-0002 already makes for append-only entries — "independent
append-only rows never clobber each other" — applied to a stored scalar rather than a derived
one. It is the CloudKit-correct shape for the same reason.

### 1.2 The "exactly one per scope" invariant

This is where the two options genuinely diverge, and it runs opposite to the usual instinct that
an entity is the more expressive choice.

**Option A expresses it structurally.** A field holds one value. Two goals on one exercise are
not representable, so there is no invariant to maintain, no guard to write, and nothing an
implementer can invent behaviour around. SPEC §3's list of "invariants the schema cannot express"
stays at seven items.

**Option B cannot express it at all.** ADR-0001 rule 4 bans `@Attribute(.unique)` and `#Unique`,
which is the only schema-level way to say "at most one `Goal` per `Exercise`". A to-one inverse
gets you most of the way locally — SwiftData maintains the back-pointer — but under sync, two
devices each setting a goal produce two `Goal` records, last-writer-wins on the exercise's link
field, and one orphaned `Goal` row left behind pointing at an exercise that no longer points
back. Option B therefore adds:

- **invariant 8** to SPEC §3: *at most one `Goal` may reference any given `Exercise` or
  `Machine`; app code enforces it on write*; and
- **an orphan sweep**, because a `Goal` with both `exercise` and `machine` nil is representable
  and no delete rule can reach it (see §4).

SPEC §3 introduces that invariant list with "they are listed because this is exactly where an
implementer invents behaviour." Adding to it is a real cost, and it is the cost B pays for a
benefit A already delivers for free.

**A's honest cost is the half-set state**: `goalReps` set with `goalWeight` nil is representable
and meaningless. This is *exactly* the shape of the problem the codebase already solved once.
`Entry`'s attributes are all defaulted for the same CloudKit reason, so a zeroed row is
representable, and `Entry.isALift` (`Chalk/Chalk/Model/Entry.swift`) absorbs it at a single seam
with a doc comment that says so out loud. A goal does the same: a failable initialiser on the
`Goal` value struct (§2) is the only door, and a half-set pair reads as *no goal*, not as a
broken one. The failure modes are not equivalent — A's is **absent**, B's is **silently wrong**
(two goals, or a stale orphan). Absent is the one Chalk consistently chooses.

### 1.3 The duplication

The same pair appears on two entities. This is real, and it is small: two `Int?`/`Double?`
declarations. More to the point, it is the *same* duplication the derivation already has and
accepts. `Exercise.entries` and `Machine.entries` are the identical free-weight/gym-bound scoping
split, and `lastLogged` is written out separately on `Gym` and on `Machine`. A goal "scopes
exactly as the derivation scopes" (#62), so it duplicates exactly where the derivation does.

Crucially, **the duplication is at the schema level only, and it is deduplicated at the value
level.** One `Goal` value struct holds the rule; `Exercise` and `Machine` each expose
`var goal: Goal? { Goal(reps: goalReps, weight: goalWeight) }`. That is precisely the `LastEntry`
pattern, whose doc comment states the reason: the screens agree "by construction rather than by
agreement between two copies of the same" rule.

### 1.4 Query ergonomics

A is better, and the margin is wider than it looks.

- **The goal is always read alongside the entity that scopes it.** `ExerciseDetailModel` already
  holds `exercise` and `machine`. Under A the goal is two already-faulted scalars on an object in
  hand: no fetch, no join, no predicate.
- **Under B it is a relationship traversal or a `FetchDescriptor<Goal>`.** A `#Predicate` over an
  optional to-one relationship is a known rough edge in SwiftData, and "which exercises have a
  goal?" — the question a library tile would ask (#62, "not yet specified") — is a nil check on a
  scalar under A and a relationship predicate under B.
- **Deletion timing.** `ExerciseDetailModel` already caches `name` and `entryCount` off the model
  object with the comment "the screen stays on-stack for a frame or two after a delete, and a
  deleted `Exercise` is no longer a thing to ask." Under A the goal caches the same way, as two
  scalars. Under B it is a relationship on a possibly-deleted object — one more thing that can be
  a fault on a tombstone.

### 1.5 Verdict

**Option A.** It is CloudKit-safer (no cross-record atomicity to lose), it is the only one of the
two that expresses "exactly one per scope" *at all*, it adds nothing to SPEC §3's invariant list
or to the delete-rule table, and its one new representable-but-meaningless state has an existing
idiom in the codebase to absorb it.

The single thing B would buy is a place to hang future per-goal data — a set date, a note, a
history of goals. **Every one of those is already ruled out** by #62: "reached is derived, never
stored", "no `reachedAt`, no retirement event", and "a history of goals reached" is explicitly
out of scope. There is no future field for the entity to be holding a place for.

---

## 2. Where `reached` and the gap live

The rule is one comparison: **reached when `best[reps] >= weight`**; the gap is
`weight - best[reps]`.

### 2.1 Not inside `RepMaxCurve`

`RepMaxCurve` is a function of `[Entry]` and nothing else. Putting a goal in it means either a
second initialiser or a goal parameter that the log sheet, the history sheet and the scrub
readout would all have to pass and none of them wants. It also fuses two things that should fail
independently in tests: the twelve-cell backfill, and the target comparison.

The deeper reason is ADR-0002's. `RepMaxCurve` **is** the derivation — everything in it is
computed from lifts you performed. A goal is the first stored number in Chalk that is not a lift
you performed (#62). It is compared *against* the derivation, not part of it. Keeping that line
sharp in the type system is the same discipline that keeps the ghost curve labelled "guidance
only, never a rep-max."

### 2.2 Not in the view layer

The gap is likely to be read in more than one place — the detail screen certainly, and #62 leaves
open a library tile and a sixth verdict-line state (§6.5). Three restatements of `>=` is exactly
the drift `LastEntry` exists to prevent.

### 2.3 Beside it — the recommendation

A Foundation-only value struct at `Chalk/Chalk/Derivation/Goal.swift`:

```swift
/// A (reps, weight) pair you have named as a target and not yet lifted.
/// Reached is derived, never stored — an edited entry un-reaches a goal for free.
struct Goal: Equatable {
    let reps: Int
    let weight: Double

    /// The only door. A half-set pair is no goal at all, the way a zeroed row is not a lift.
    init?(reps: Int?, weight: Double?) { … }

    /// `best[reps] >= weight`, by the same rule the curve uses — read from
    /// `RepMaxCurve.best(atLeast:in:)`, so the two cannot drift.
    func isReached(in entries: [Entry]) -> Bool

    /// What is left to close, or nil once it is reached. The full weight on a
    /// zero-entry exercise, which is the state a goal is allowed to be set in.
    func remaining(in entries: [Entry]) -> Double?
}
```

**It does not drag SwiftData in.** The bar ADR-0002 actually sets is "no `ModelContainer`, no
fetch, no SwiftData beyond the `Entry` type itself" — `RepMaxCurve.swift` imports `Foundation`
only, and so does `LastEntry.swift`, while both take `Entry` values. `Goal` meets exactly that
bar: `import Foundation`, tests construct `Entry(...)` in memory, no container.

**Two details that make this the right shape rather than merely a tidy one:**

- **It takes `[Entry]`, not a `RepMaxCurve`, and reuses `RepMaxCurve.best(atLeast:in:)`.** A goal
  is `(reps, weight)` with no stated cap; the 1–12 range is the *drawn axis*, not a limit on rep
  counts (SPEC §4: entries above 12 are stored and floor the axis). §6.5's verdict line already
  sits at arbitrary rep counts and already reads `RepMaxCurve.best(atLeast:in:)` for exactly that
  reason, with the doc comment "a curve keyed 1...12 has nothing to say about that." A goal at 15
  reps has to work, and going through the existing static gets it for free, along with the
  zero-entry case (`nil` best → not reached, gap is the full weight).
- **The extra O(n) pass is not a concern.** ADR-0002 already settles this: "Performance is a
  non-issue at personal scale." `LogSheetModel` does precisely this today.

### 2.4 The seam

**Rule in `Goal`; presentation state in the view model.** `LogSheetModel.Verdict` is the
established pattern — an enum of five states in the `@Observable` model, computed from
`RepMaxCurve`'s rule, with the words and the colour above it. Whatever a goal's on-screen states
turn out to be (#67, #68), they belong in `ExerciseDetailModel` next to `Readout` and `hint`,
reading `Goal` for the truth. `ExerciseDetailModel` should cache `private(set) var goal: Goal?`
alongside `name` and `entryCount`, refreshed with the curve, for the deleted-object reason its
existing cache comment gives.

---

## 3. Migration

### 3.1 What Apple actually says

SwiftData's API reference is **silent**. Pulling developer.apple.com's own documentation JSON for
[`MigrationStage`](https://developer.apple.com/documentation/swiftdata/migrationstage),
[`MigrationStage.lightweight(fromVersion:toVersion:)`](https://developer.apple.com/documentation/swiftdata/migrationstage/lightweight(fromversion:toversion:))
and [`SchemaMigrationPlan`](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
returns a one-line abstract for the types and **no abstract or discussion at all** for the
`lightweight` and `custom` cases. There is no primary reference page stating what is
lightweight-eligible.

The primary source is the WWDC session, verbatim:

> "when you make a change to your schema, like adding or removing a property, a data migration
> occurs. […] The first is a lightweight migration stage. Lightweight migrations do not require
> any additional code to migrate the existing data for my next app release. Modifications like
> adding `originalName` to my date properties or specifying the delete rules on my relationships
> are lightweight migration eligible. However, making the name of a trip unique is not eligible
> for a lightweight migration."
> — [Model your schema with SwiftData, WWDC23 session 10195](https://developer.apple.com/videos/play/wwdc2023/10195/)

Note it names `originalName` and delete rules as examples, not as the full list. The full list
lives one layer down, in the Core Data mechanism SwiftData sits on
([Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices):
"SwiftData uses the `NSPersistentCloudKitContainer` class from Core Data"). Core Data, verbatim:

> "Generating an inferred mapping model requires changes to fit an obvious migration pattern, for
> example: Addition of an attribute / Removal of an attribute / A nonoptional attribute becoming
> optional / An optional attribute becoming non-optional, and defining a default value / Renaming
> an entity or property"
> — [Migrating your data model automatically](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically)

And, for option B's sake:

> "Lightweight migration can also manage changes to relationships and to the type of relationship.
> You can add a new relationship or delete an existing relationship. […] You can add, remove, and
> rename entities in the hierarchy."
> — [Lightweight Migration](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/vmLightweightMigration.html)
> (Apple, archived documentation — primary but no longer maintained.)

**So both options are additive and inferrable.** Option A is the first bullet, twice, on two
entities. Option B is a new entity plus two new relationships. Migration does **not** discriminate
between A and B, and it is worth saying so plainly, because the instinct that an entity is harder
to add later is wrong here. Note also that both new fields under A are **optional**, so the
"defining a default value" clause never applies — no existing row needs anything written to it.

### 3.2 Is it a `ChalkSchemaV2`? — a Chalk-specific catch

In principle yes. **In Chalk's actual code, not straightforwardly**, and this is the finding worth
the dev's attention.

`Chalk/Chalk/Store/ChalkSchema.swift` reads:

```swift
enum ChalkSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Exercise.self, Entry.self, Gym.self, Machine.self, ExerciseGroup.self]
    }
}
```

Those are the **live** classes, not frozen copies. The WWDC pattern namespaces each version's
models *inside* its `VersionedSchema` (`SampleTripsSchemaV1.Trip`) precisely so that V1 stays a
snapshot of what shipped. In Chalk, adding `goalReps` to `Exercise` silently changes what
`ChalkSchemaV1` describes. Declaring a `ChalkSchemaV2` that also lists the live classes would make
V1 and V2 *identical*, and
`MigrationStage.lightweight(fromVersion: ChalkSchemaV1.self, toVersion: ChalkSchemaV2.self)` would
describe a migration between two identical schemas — a no-op that documents nothing and misstates
what is on the old store's disk.

Two honest paths:

**(a) Freeze V1 properly.** Copy today's five `@Model` classes into `ChalkSchemaV1` as nested
types, move the live ones under `ChalkSchemaV2`, and typealias the app-facing names. This is the
textbook shape and buys a genuinely versioned store. Cost: five duplicated model classes carried
forever, plus a typealias indirection through the whole app — for two `Int?` / `Double?` fields.

**(b) Bump in place.** Keep one `VersionedSchema`, raise `versionIdentifier` to
`Schema.Version(2, 0, 0)`, leave `stages` empty, and let the inferred mapping add the columns.

**Recommendation: (b) for this change, and it is not laziness.** SPEC §3 says the plan "exists
from day one so that adding a stage later is an edit rather than a retrofit" — the retrofit it
avoids is *the plan*, not frozen model snapshots. The first change that genuinely rewrites data —
a rename, a type change, a dedupe — is the one that earns a frozen V1, because that is the first
time a stage has real work to do. Two additive optional fields is not it. **This is a judgement
call and the dev should overrule it if they would rather pay the ceremony now than later.**

### 3.3 UNVERIFIED — and the test that settles it

**Does SwiftData apply the inferred lightweight migration when a `SchemaMigrationPlan` is supplied
but lists no stage for the version pair?** Apple documents neither behaviour. This matters
because `ChalkStore.open` passes `migrationPlan: ChalkMigrationPlan.self` unconditionally. There
is a developer report on Apple's forums ([thread 738812](https://developer.apple.com/forums/thread/738812))
that a change which migrates cleanly with *no* plan fails when a plan is supplied — but that is an
**ordinary developer, not an Apple Frameworks Engineer**, and I found no Apple statement either
way. Treat it as a rumour, not a fact.

It is cheap to settle empirically, and **the test is the real deliverable for this question**:
open a store against today's schema, write one of each entity, close it, reopen it against the
goal-bearing schema, and assert every row survives with `goalReps == nil`. `TemporaryStore`
already does open-write-reopen (`Chalk/ChalkTests/SchemaRoundTripTests.swift`,
`Chalk/ChalkTests/TemporaryStore.swift` — note `reopened()`), so the harness exists. The one thing
it does not yet do is reopen against a *different* schema, which is the whole point.

The stakes are concrete: the dev's own device holds the only copy of the store, and ADR-0001's
durability story is "sync later" with Xcode's Download Container as the escape hatch. **Download
the container before the first launch that carries the new schema.**

### 3.4 CloudKit side

Nothing is at stake yet. Chalk is local-only (`cloudKitDatabase: .none`), so no schema has been
promoted and there is no production CloudKit schema to be additive against — the goal fields will
simply be part of the first schema ever initialised. And even after a future promotion, both
options stay viable:

> "After you promote your schema to production, the record types and their fields are immutable
> and exist for all time. You can add new record types, and additional fields to existing record
> types, but you can't modify or delete existing record types."
> — [Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)

> "CloudKit schemas are additive only, which means you're unable to delete model types or change
> existing model attributes after you promote a schema to production."
> — [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)

The forward-compatibility asymmetry is worth one line: under A, an older build of the app that
does not know about `goalReps` still fetches every record and simply ignores two fields. Under B,
an older build does not know the `Goal` record type at all. Apple names the first as a supported
strategy — "Incrementally add new fields to existing record types. If you adopt this approach,
older versions of your app have access to every record a user creates, but not every field."

---

## 4. Delete rules

SPEC §3's table today:

```
Exercise      --cascade--> Entry
Exercise      --cascade--> Machine --cascade--> Entry
ExerciseGroup --nullify --> Exercise          (falls back to Ungrouped)
Gym           --nullify --> Machine
```

### 4.1 Under option A: the table is unchanged

A goal is not a row, so it has no delete rule. It is two columns on the `Exercise` record and two
on the `Machine` record, and it is deleted exactly when its owner is, by the cascades already
there. Walking the existing table:

| Existing rule | What happens to the goal | Right? |
|---|---|---|
| `Exercise --cascade--> Machine` | the machine's goal goes with the machine | yes — the goal was named at that machine |
| Deleting an `Exercise` | its own goal and every machine's goal go | yes |
| `ExerciseGroup --nullify--> Exercise` | nothing; the exercise and its goal survive re-shelving | yes |
| `Gym --nullify--> Machine` | **the machine keeps its goal** | yes, and this is the interesting one |

That last row is the one to check, and A gets it right without being asked. SPEC §3 invariant 3
says a gym-less machine "still derives normally; it simply renders as `label` with no gym suffix."
A goal is measured against that derivation, so it should survive alongside it. Under A it does,
because the goal is *on* the machine record.

**Machine merge** is the other free win. `CONTEXT.md` defines a merge as moving every entry onto a
sibling and deleting the emptied machine. Under A the emptied machine's goal dies with it, the
survivor keeps its own, and no merge code has to think about goals at all. ADR-0002's ordering
rule — "reassign and flush *before* deleting, or the cascade from `Machine` takes the entries with
it" — is untouched.

> **Superseded.** [#68](https://github.com/hermanno3005/Chalk/issues/68) rejected *survivor keeps
> its own*: on a merge the most recently set goal wins, so merge code does handle goals. See
> ADR-0004 and SPEC §7.5.

### 4.2 Under option B: two new rows, plus something cascade cannot reach

```
Exercise --cascade--> Goal
Machine  --cascade--> Goal
```

(and `Exercise --cascade--> Machine --cascade--> Goal` transitively). Cascade is fine under
CloudKit; only `.deny` is out.

But a `Goal` with **both** `exercise` and `machine` nil is representable, and **no delete rule can
reach it.** Cascade only fires from an owner, and `.deny` — the rule that would have prevented a
detached goal existing — is banned by ADR-0001 rule 5. So B needs an app-level sweep on top of the
two table rows, in a codebase whose §8 is proud that "each is one decision, with **no orphans and
no permanent null case**." Machine merge would have to decide what to do with the emptied
machine's `Goal` row, or leak it.

### 4.3 Verdict

Delete rules are the cleanest single argument for A: **zero new rows, zero new sweeps, and the one
subtle case (`Gym --nullify--> Machine`) comes out right by construction.**

---

## 5. Draft ADR — *for review, not adopted*

The entity-vs-fields call does warrant an ADR, because the instinct to promote a concept to an
entity is strong and the reason not to here is CloudKit-specific and non-obvious — the same
"a future reader will want to fix this" hazard ADR-0001 names about optionality. Sketch:

> **A goal is two optional fields, not an entity**
>
> A goal is stored as `goalReps: Int?` and `goalWeight: Double?` on `Exercise` (free-weight
> scope) and on `Machine` (gym-bound scope). There is no `Goal` model type.
>
> The pair is duplicated across two entities on purpose: a goal scopes exactly as the derivation
> scopes, so it duplicates exactly where `entries` already does. The duplication is deduplicated
> at the value level by the `Goal` value struct, not at the schema level.
>
> **The reason is not simplicity.** ADR-0001 bans `.unique`, which is the only schema-level way
> an entity could say "at most one goal per exercise." As fields, that invariant is structural —
> a field holds one value — and SPEC §3's list of invariants the schema cannot express stays at
> seven. As an entity it would grow to eight, with an orphan sweep attached, because `.deny` is
> banned too and cascade cannot reach a detached `Goal`. Under sync, an entity is also two records
> that travel independently, where CloudKit "doesn't guarantee atomic processing of relationship
> changes"; fields ride the owner's record and cannot be half-present relative to it.
>
> **Consequences.** A half-set pair is representable and means *no goal* — absorbed by
> `Goal.init?(reps:weight:)`, the way `Entry.isALift` absorbs a zeroed row. `reached` stays
> derived (ADR-0002): `Goal` compares against `RepMaxCurve.best(atLeast:in:)` and never stores an
> answer. The delete-rule table is unchanged. There is no place to hang per-goal metadata later —
> deliberately, since a set date, a `reachedAt` and a history of goals are all already out of
> scope.

---

## 6. Hand-offs (not decided here — storage does not settle them)

- **Changing an exercise's kind (SPEC §8) moves which scope a goal lives in.** Free-weight →
  gym-bound: the exercise's goal is on the wrong entity once entries move to a machine. Gym-bound
  → free-weight: §8 deletes the machine rows, so every machine goal is dropped silently. Both
  options behave identically here (B re-points a relationship, A copies two scalars), so this is a
  **behaviour** question for the spec section, not a storage one — but it must be answered, since
  §8's promise is "no orphans and no permanent null case." Relevant to
  [#67](https://github.com/hermanno3005/Chalk/issues/67) /
  [#68](https://github.com/hermanno3005/Chalk/issues/68).
- **Validation bounds for a goal.** §6.7 sets `reps >= 1` and `weight > 0` for entries. A goal
  presumably takes the same guard — and pointedly *not* a "must exceed your current best" guard,
  since a goal is settable with zero entries (#62) and an entry correction can un-reach one.
- **Whether a goal at `reps > 12` is offered.** Nothing in storage forbids it and
  `RepMaxCurve.best(atLeast:in:)` handles it; whether the UI lets you pick one is a screen
  question.

## 7. Sources

Primary (Apple):

- [Syncing model data across a person's devices — SwiftData](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)
- [Migrating your data model automatically — Core Data](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically)
- [Lightweight Migration — Core Data Model Versioning and Data Migration (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/vmLightweightMigration.html)
- [Model your schema with SwiftData — WWDC23 session 10195](https://developer.apple.com/videos/play/wwdc2023/10195/)
- [Deploying an iCloud container's schema — CloudKit](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)
- [`SchemaMigrationPlan`](https://developer.apple.com/documentation/swiftdata/schemamigrationplan),
  [`MigrationStage`](https://developer.apple.com/documentation/swiftdata/migrationstage),
  [`VersionedSchema`](https://developer.apple.com/documentation/swiftdata/versionedschema) — cited
  for what they *do not* say (no discussion for the `lightweight` / `custom` cases).

Secondary, flagged as such in text:

- [Apple Developer Forums thread 738812](https://developer.apple.com/forums/thread/738812) —
  developer report, not an Apple engineer.

In-repo:

- [`docs/research/swiftdata-cloudkit.md`](swiftdata-cloudkit.md) — the evidence behind ADR-0001.
- `SPEC.md` §3, §4, §6.5, §8; `CONTEXT.md`; ADR-0001; ADR-0002.
- `Chalk/Chalk/Model/*.swift`, `Chalk/Chalk/Store/ChalkSchema.swift`,
  `Chalk/Chalk/Derivation/RepMaxCurve.swift`, `Chalk/Chalk/Library/LastEntry.swift`,
  `Chalk/Chalk/Log/LogSheetModel.swift`, `Chalk/ChalkTests/SchemaRoundTripTests.swift`.
