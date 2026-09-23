# A goal stores its reps, weight and when it was set; everything else is derived

A goal is the first stored number in Chalk that is not a lift you performed. It is stored as
three optional fields on its scope — `goalReps: Int?`, `goalWeight: Double?` and
`goalSetAt: Date?` on `Exercise` (free-weight) and on `Machine` (gym-bound) — and nothing else.
*Reached* (`best[goalReps] >= goalWeight`), the *gap*, and the donut's *origin* are all computed
at read time. The origin is `best[goalReps]` over the scope's entries dated **strictly before**
`goalSetAt`, or zero when there are none. This is ADR-0002's companion, not an exception to it.

## Considered options

- **Storing the origin as a number** (`bestWhenSet`) was rejected. It is a snapshot of a
  derived value — exactly what ADR-0002 exists to prevent. Correcting an old entry downward
  leaves it at a best you never had, and the ring then needs a clamp to hide the
  inconsistency. Storing the *moment* instead works because `Entry.date` is immutable after
  creation (§6.6): the before/after partition is fixed, and every other change — an edited
  weight, a deletion, a merge, an entry moved between machines — just recomputes. Because the
  current best is taken over a superset of the origin's entries, `best >= origin` holds by
  construction, so the ring can never read negative.
- **A `Goal` entity** was rejected. ADR-0001 bans `.unique` and `.deny`, so an entity could not
  say *at most one goal per scope* and could be orphaned with both relationships nil — an
  another schema-inexpressible invariant plus an app-level sweep. As fields, one goal per scope
  is structural, the §3 delete rules are unchanged (a goal dies with its scope), and a
  gym-less machine keeps its goal. The fields also ride their scope's CloudKit record, so they
  sync atomically with it.

## Consequences

- A partly set triple is no goal. The only way to build one is a Foundation-only `Goal` value
  struct beside `RepMaxCurve`, which reads `RepMaxCurve.best(atLeast:in:)` so rep counts
  above the drawn 1–12 axis work.
- There is one write: setting a goal replaces all three fields and stamps `goalSetAt = now`,
  which is what re-snapshots the ring. Clearing nils all three.
- The schema change is additive. `versionIdentifier` is bumped to `2.0.0` in place with
  `stages` still empty, instead of freezing V1 as copies. Whether SwiftData infers that
  migration with no stage listed is unverified, so a test that reopens a V1 store against the
  new schema and asserts every row survives with nil goal fields is a required part of the
  build.
- Merge code does handle goals. When two machines are merged, the goal with the later
  `goalSetAt` ends up on the survivor and keeps its own `goalSetAt`, the same rule as a kind
  change ([#68](https://github.com/hermanno3005/Chalk/issues/68)). It is copied in the same
  save as the entry reassignment, before the loser is deleted, because the cascade takes the
  loser's fields with it. Keeping the survivor's own goal was rejected: in late relabelling the
  only goal usually sits on the machine being deleted.
