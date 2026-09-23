# Chalk

A personal strength-record tracker for iOS. You keep a library of the exercises you
actually do, log what you lifted as plain `reps × weight` entries, and the app tells
you what to load at the rack. It is not a workout logger: there are no sessions and
no sets.

## Language

### The record

**Entry**:
One logged performance of an exercise: a rep count, a weight, and the moment it was
logged. The only thing Chalk stores about your lifting. Mutable and deletable.
_Avoid_: Record, set, log line

**Rep-max**:
The heaviest weight you have proven at a given rep count, derived from your entries
and never stored. Written `best[n]`.
_Avoid_: PR, personal record, 1RM (as a stored value), max

**Monotonic backfill**:
The rule that derives every rep-max: `best[n] = max(weight) where reps >= n`. A lift
at 5 reps proves the same weight at 1 through 4, so it floors them too.
_Avoid_: Interpolation, estimation

**Strength curve**:
The twelve rep-maxes for one exercise, `best[1]` through `best[12]`, drawn on a fixed
axis so shapes are comparable between exercises.
_Avoid_: Graph, chart, progression

**Scope**:
What a strength curve is derived over and what a goal is set on: the exercise for a
free-weight exercise, one machine for a gym-bound one. The boundary is transferability,
so a number is only ever compared against numbers it is comparable to.
_Avoid_: Owner, context, level

**Ghost curve**:
A see-through Epley projection drawn behind the strength curve, showing headroom you
have not yet demonstrated. Guidance only — never a rep-max, never stored, never
presented as something you have lifted.
_Avoid_: Estimated max, projected 1RM, target

**History sheet**:
Every entry that can determine one rep-max — `reps >= n`, newest first, with the one
currently setting the cell flagged. It mirrors the derivation rather than restating it,
which is what makes it sufficient. The only entry point to raw history and the only place
an entry is edited or deleted; there is no all-entries log screen.
_Avoid_: Log screen, entry list, records list

### What you're heading toward

**Goal**:
A weight you have named at a rep count and have not lifted yet, held on one scope — at
most one, replaced rather than added to. The only number Chalk stores that is not a lift
you performed, and its job is motivation: it never tells you what to load.
_Avoid_: Target, PR, PB, milestone, aim, projection

**Reached**:
What a goal is once your best at its rep count meets it — `best[reps] >= weight`. Asked
of the entries each time it is shown and never stored, so correcting an entry downward un-reaches a goal
on its own, with nothing to repair.
_Avoid_: Achieved, hit, completed, retired, `reachedAt`

**Gap**:
The weight between your curve and your goal, `goal weight − best[reps]` — the number the
whole feature exists to show. With nothing logged it is the entire weight; a reached goal
has none.
_Avoid_: Headroom, remainder, deficit, progress

**Setting a goal**:
The one write a goal has: naming a `(reps, weight)` pair on a scope, which replaces
whatever goal was there and records the moment it was named, which is where the ring
counts from. Naming your first goal and replacing a reached one are the same act, which is
why *change* is a word on a menu row rather than an operation.
_Avoid_: Update, edit, amend, adjust, save

**Clearing a goal**:
Removing a goal without naming another — the only other way one leaves a scope. It sits at
the foot of the goal sheet, not in the exercise's overflow, which carries lifetime
operations only.
_Avoid_: Delete, remove, cancel, abandon, retire

**Goal sheet**:
Where a goal is named: the log sheet's two-stage giant number borrowed whole — reps, then
weight — and nothing else of it. No machine row, because the scope comes from the caller;
no seeded weight, because a goal is by definition one you have not lifted; and it commits
with *Set goal*, never *Save*.
_Avoid_: Goal editor, target sheet, goal modal

### The library

**Exercise**:
A movement you train, held in your library. Either free-weight or gym-bound.
_Avoid_: Lift, movement, activity

**Free-weight**:
An exercise whose load transfers between gyms. 60 kg is 60 kg wherever you lift it,
so its rep-maxes derive across every entry.
_Avoid_: Barbell, non-machine

**Gym-bound**:
An exercise whose load does not transfer between gyms — machines, cables, and
plate-loaded kit alike. The test is transferability, not whether it is colloquially a
machine. Its rep-maxes derive from one machine's entries only.
_Avoid_: Machine exercise, fixed-weight

**Group**:
A user-owned, ordered bucket that an exercise may sit in, and a shelf rather than a
taxonomy — "Compound" next to "Legs" is incoherent as a classification and entirely
fine here. An exercise sits in at most one, chosen when it is created and changed
whenever you like. Its job is structure, not navigation, which is why it never has to
beat search.
_Avoid_: Category, muscle group, tag
_Note_: the Swift type is `ExerciseGroup`, to leave SwiftUI's `Group` view alone.

**Ungrouped**:
The state of an exercise that sits in no group — a named place, not a missing value. It
is the last section on the library screen and the default answer in the create sheet's
group picker, because meeting a machine before you know which shelf it belongs on is
ordinary rather than an omission to be nagged about.
_Avoid_: None, unfiled, uncategorised

**Arrange mode**:
The state the library screen is in while you are filing exercises rather than using them:
every tile carries a group picker and a tap no longer opens anything. Entered from the
overflow and left by a visible Done that replaces it. It is the periodic re-shelving pass
— where you look over the whole library at once, months apart — rather than how an
exercise first reaches a group, which happens when it is created. It exists because
dragging a tile
the length of a long scroll is the path that cannot be relied on, and this one always
works.
_Avoid_: Edit mode, organise mode, jiggle mode

**Searching**:
The state the library screen is in while the field holds a query and the grid is
replaced by its matches. Not a mode: it carries no visible Done, because it ends by
itself — when the field is cleared, or when you open something, which is every route
off the screen. A query is therefore never something you come back to: the next one
starts from nothing.
_Avoid_: Search mode, filtering, find mode

**Last entry**:
What you last did for an exercise, written `8 × 52.5 kg · today` — the most recent entry
that is a lift, read for display and never stored. The tile subtitles and the resume card
say it in the same words.
_Avoid_: Latest, most recent set, history line

**Resume card**:
The last thing you logged anywhere in the library, at the top of the home screen: the
exercise, its last entry, and a one-tap way back into the log sheet. Derived from the
entries like everything else, so it has nothing to maintain and is simply absent when
nothing has been logged. It carries the goal ring, with no words, but only for a goal at
the last entry's own scope — never a sibling machine's — so a log at a holiday gym never
shows your home machine's goal.
_Avoid_: Recent card, quick log, continue

### Where you lift

**Gym**:
A place you train, held in its own right with an identity independent of its name — which
is what makes renaming one cost nothing. Gyms churn, so one can also be archived.
_Avoid_: Location, club, venue

**Machine**:
A gym-bound exercise at a particular gym, optionally distinguished by manufacturer or
label. One gym may hold several for the same exercise, and their numbers are separate.
_Avoid_: Station, equipment, apparatus

**Merge**:
Moving every entry from one machine onto a sibling — same exercise, same gym — and
deleting the emptied machine. The repair for a split curve, when the same physical
machine was recorded twice because you learned its name late. Costs nothing to the
numbers, because no rep-max is stored to recompute.
_Avoid_: Combine, de-duplicate, consolidate

**Current gym**:
The gym you are standing in, chosen once per visit and remembered until you change it.
A property of a device in a moment, not of your account.
_Avoid_: Home gym, default gym, active location

**Archived**:
The state of a gym you have stopped visiting. It leaves the current gym picker but keeps
every entry it holds, and un-archives itself the moment you log there again. A matter of
display alone — no rep-max is ever affected by it.
_Avoid_: Hidden, deleted, inactive, retired

**Hint**:
Your numbers for the same exercise on a different machine, shown when the machine in
front of you has no history. Visibly marked as such, and never part of any derivation.
_Avoid_: Estimate, reference, suggestion
