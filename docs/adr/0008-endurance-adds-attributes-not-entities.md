# Endurance adds attributes, not entities

> **Draft — a recommendation from [#100](https://github.com/hermanno3005/Chalk/issues/100),
> not adopted.** Evidence: [`docs/research/endurance-storage.md`](../research/endurance-storage.md).

Endurance is stored in the five entities strength already has. An interval is an **`Entry`**,
with `duration`, `intensity`, `averageHeartRate`, `peakHeartRate` and `incline` added beside
`reps` and `weight`. An erg is an **`Exercise` whose `unit` is set**, so `unit: String?` is nil
on every lift and one of `speed`, `watts`, `split` or `level` on an erg. An erg's machine is a
**`Machine`**, and transferable and gym-bound reuse `kind`. An endurance group is an
**`ExerciseGroup`** with `half` set to endurance. An endurance goal is four more optional fields
on `Exercise` and `Machine` that share `goalSetAt` with the strength goal. The heart-rate zones
are not in the store at all: they are one `UserDefaults` key holding four `Int`s. Schema `3.0.0`
is attributes only, with no new entity, relationship or delete rule, bumped in place with no
stage, as 2.0.0 was.

**This is the part a future reader will want to "fix"**, by splitting out an `Erg` and an
endurance-entry type so each row holds only meaningful fields. The reason not to is the
relationships, not tidiness. Every repair Chalk has works by re-pointing `Entry.machine` and
`Machine.exercise`: merge, move to another gym, the kind change, and the deletes they end in.
ADR-0002's one ordering rule, *reassign and flush before deleting, or the cascade takes the
entries*, guards a single relationship. A second entity doubles it, and a path that remembers
one relationship but not the other silently deletes history. With one entity, every repair path
carries ergs and intervals with no change.

## Considered options

- **An endurance-entry entity of its own.** Rejected. It would remove the half-filled row
  (a lift's interval fields at zero, an interval's `reps` and `weight` at zero), but that row is
  already absorbed: `isALift` is false for every interval, so `RepMaxCurve`, `LastEntry` and
  every lift reader ignore it, and a sibling `isAnInterval` serves the zone line. The cost is a
  second cascading relationship on every owner, and invariants 1 and 2 restated for the second
  type. It also splits one glossary word, *Entry* ([#89](https://github.com/hermanno3005/Chalk/issues/89)),
  across two types.
- **An `Erg` entity beside `Exercise`.** Rejected. `Machine` and `Entry` would each need a
  second optional owner and an *exactly one is set* rule that ADR-0001's all-optional
  relationships cannot express. And scope, kind change, merge, hint, goals and the library are
  all *carried over* to ergs ([#93](https://github.com/hermanno3005/Chalk/issues/93),
  [#96](https://github.com/hermanno3005/Chalk/issues/96),
  [#99](https://github.com/hermanno3005/Chalk/issues/99)). As one entity they carry over because
  they are the same code. As two, each is a copy or a generic rewrite of shipped strength code.
- **A `half` field on `Exercise`.** Rejected in favour of the unit. An erg is defined by
  speaking a unit and a lift never has one (SPEC §11), so a separate field would only be a
  second fact that has to agree with the first. `ExerciseGroup` does get `half`, because a group
  has no unit.
- **The zones as a SwiftData row.** Rejected. A row that must be the only one is exactly what
  ADR-0001's ban on `.unique` cannot say, and under sync two devices would each create one and
  need de-duplicating. The one thing a row buys, zones that follow you to a second device, waits
  on sync, and until you type them there ADR-0005's gate shows nothing wrong.
- **A separate `goalSetAt` per half on `Machine`.** Rejected. A row is a lift's or an erg's,
  never both, so it holds at most one goal. One shared moment keeps *"the most recently set goal
  wins"* reading one field for both halves.

## Consequences

- **The Swift type `Exercise` holds ergs**, while the glossary's *Exercise* means a lift.
  `CONTEXT.md` gets a `_Note_` as *Group* has one: *the Swift type for both is `Exercise`; an
  erg is an `Exercise` with a unit.* A transferable erg stores `kind` as `freeWeight`, which is
  documented rather than renamed.
- **Fetches filter by half; relationships do not need to.** The library and group fetches, and
  the groups' first-launch seed, filter to the half on screen. Lift-only readers of recency
  (`Machine.lastLogged`, `Gym.lastLogged`) widen to *a lift or an interval* wherever an erg is
  asked. Traversals stay one half by construction.
- **SPEC §3 gains three invariants:** an erg's `unit` is set at create, never cleared, and
  changed only while the erg has no entries; an exercise sits only in a group of its own half;
  a row's goal fields are its own half's, kept by `GoalScope.clear()` nilling all seven.
  Invariant 8 widens to both halves' goal fields.
- **Intensity is a `Double` as typed, compared in whole steps.** 0.1 km/h is not exact in
  binary floating point the way 2.5 kg is, so every derived comparison goes through
  `Int((value / step).rounded())`.
- **The zones live beside the store, not in it.** They are in the app container's
  `Library/Preferences`, so Download Container carries them and `plutil` reads them. If only
  the `.store` were recovered, the lookup is gated until you retype four numbers, and no derived
  number is ever wrong. Once sync exists they will not follow you to another device.
- **The migration test reopens a real `Chalk-2.0.0.store`**, captured from the app before the
  schema changes. It asserts every row and both strength goals survive with every new field at
  its default, and that the upgraded store then takes an erg, an interval and an endurance goal.
  The 1.0.0 test stays.
