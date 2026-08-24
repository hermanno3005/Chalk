# Rep-maxes are derived, never stored

Chalk stores only `Entry` rows — one `reps × weight` performance each — and computes
every rep-max at read time by monotonic backfill (`best[n] = max(weight) where reps >= n`).
No `best`, `personalRecord`, or `oneRepMax` field exists on any entity, and none should
be added. Entries are freely editable and deletable; a rep-max that drops after an edit
is the derivation working, not data being lost.

## Considered options

Materialising rep-maxes on `Exercise` (or on a `Machine`) and updating them on write is
the obvious optimisation and was rejected. It has to be invalidated on every edit and
every delete — and editing is not an edge case here, because entry validation deliberately
accepts anything above `reps >= 1` and `weight > 0`, which makes correcting a typo the
supported path rather than a rare repair. A stored best that fails to recompute after a
deletion is a wrong number displayed with total confidence, in the one place the app
exists to be right about.

## Consequences

- The derivation lives in `RepMaxCurve`, a plain struct built from `[Entry]` with no
  SwiftData dependency, so backfill, the `reps > 12` flooring rule, and the Epley ghost
  are all unit-testable without a `ModelContainer`.
- Scoping is the caller's job, not the struct's: free-weight exercises pass every entry,
  gym-bound exercises pass one machine's entries only.
- It happens to be the CloudKit-correct shape too. Sync merges last-writer-wins with no
  custom hook, so independent append-only rows never clobber each other — where a mutated
  running-total field would.
- Performance is a non-issue at personal scale: one fetch of an exercise's entries and a
  single pass produces all twelve cells. Do not write twelve `reps >= n` predicates.
