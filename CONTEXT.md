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

**Ghost curve**:
A see-through Epley projection drawn behind the strength curve, showing headroom you
have not yet demonstrated. Guidance only — never a rep-max, never stored, never
presented as something you have lifted.
_Avoid_: Estimated max, projected 1RM, target

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
fine here. An exercise sits in at most one; those in none are Ungrouped. Its job is
structure, not navigation, which is why it never has to beat search.
_Avoid_: Category, muscle group, tag
_Note_: the Swift type is `ExerciseGroup`, to leave SwiftUI's `Group` view alone.

**Last entry**:
What you last did for an exercise, written `8 × 52.5 kg · today` — the most recent entry
that is a lift, read for display and never stored. The tile subtitles and the resume card
say it in the same words.
_Avoid_: Latest, most recent set, history line

**Resume card**:
The last thing you logged anywhere in the library, at the top of the home screen: the
exercise, its last entry, and a one-tap way back into the log sheet. Derived from the
entries like everything else, so it has nothing to maintain and is simply absent when
nothing has been logged.
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
