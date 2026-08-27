# Groups are assigned at create time

The create sheet asks for a group. It offers a `Group` menu row beside the name field,
listing the existing groups in `sortIndex` order with **Ungrouped** last and selected by
default, and creating an exercise files it in one step instead of two.

This reverses an earlier stance, which is the reason this ADR exists: SPEC §7.2 and §7.3
previously stated *"Nothing is asked at create time"* and *"No group is asked for"*, and
the rationale was recorded in `CreateExerciseSheet.swift` and `LibraryModel.create`. That
stance assumed filing after the fact was cheap because grouping's job is structure rather
than navigation. It is cheap; it is still two steps for something that has one natural
moment, and the create sheet is where you already know the answer.

The stance also mis-described **Arrange mode**. It was written as *"the path that always
works"* — the primary way an exercise reaches a group. In practice it is the periodic
re-shelving pass: you open it every few months to look over the whole library and
rearrange it. Create time is the primary assignment moment; Arrange is maintenance. Both
stay, and their priority swaps.

## Considered options

**Requiring a group, or defaulting to the last one used.** Both rejected. Ungrouped has to
remain a free, non-nagging answer — you often meet a new machine before you know which
shelf it belongs on, and the quarterly pass only works if "undecided" is a legal state a
sheet will not talk you out of. Sticky defaults are worse than either: a wrong group is
harder to catch than no group, because Ungrouped is visible on the library screen and a
confidently-wrong *Legs* is not.

**A `New group…` row, mirroring the sheet's `New gym…`.** Rejected — the symmetry is
false. `New gym…` answers a forcing condition: a gym is a place you are physically
standing in, and if it is missing there is no correct alternative. A missing group has
one, and it is Ungrouped. `SuggestedGroups` also seeds five groups on first launch, so
the empty-menu case that would justify the door does not arise. Note where each would
sit: `New gym…` lives inside the *conditional* machine section, visible only once you
declare yourself gym-bound; `New group…` would sit unconditionally on the sheet's first
section, permanent weight for something done a handful of times a year.

**A `Change group` item in the exercise detail overflow.** Rejected for now, and it leaves
a deliberate asymmetry worth naming: group becomes the only create-time field with no
detail-screen counterpart, where name has *Rename* and kind has *Change kind*. Those two
change what the exercise **is** — and kind reshapes how the numbers derive, which is why
it carries a whole confirmation flow. Group changes nothing about the record; it moves a
tile between two headings on one screen, so it belongs on that screen, where Arrange mode
already puts a picker on every tile. If correcting a fresh mistake turns out to be worth
the round trip through Arrange, this is the item to revisit first.

## Consequences

- **The row reads `Ungrouped`, not `None`, and sorts last** — matching the library
  screen's own section order, so the picker reads as a small map of where the exercise is
  about to land. It deliberately differs from the `Gym` picker directly above it, which
  says `None` and means it: a machine with no gym is not somewhere called None, it does
  not exist yet. Ungrouped is a real, named, visible destination.
- **The group row goes in the first section, with the name**, so progressive disclosure
  stays **append-only**: picking *Gym machine* still adds the machine section at the
  bottom and moves nothing above it. It also splits the sheet along a real seam — name and
  group are library concerns, kind and machine are derivation concerns.
- No change to the schema, to `Exercise.group`, or to any derivation. `LibraryModel.assign`
  keeps its existing callers; create gains a group argument.
