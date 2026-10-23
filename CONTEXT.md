# Chalk

A personal training-record tracker for iOS, in two halves. In strength you log
`reps × weight` entries and Chalk tells you what to load at the rack; in endurance you
log intervals on indoor ergs with the heart rate they cost you, and Chalk tells you what
to set on the machine. It is not a workout logger: there are no sessions and no sets.

## Language

### Strength and endurance

**Strength**:
The half of Chalk for lifting, where an entry is `reps × weight` and the question is what
to load at the rack. Everything Chalk shipped first.
_Avoid_: Lifting, weights, strength section, strength mode

**Endurance**:
The half of Chalk for indoor ergs, where an entry is one interval and the heart rate it
cost you, and the question is what to set on this machine to hit a given effort. Reached
from strength by the segmented control that stands in the home screen's title, and the
app reopens on whichever half you left it in.
_Avoid_: Cardio, ergs, conditioning, endurance section, endurance mode, tab

### The record

**Entry**:
One logged performance, and the only thing Chalk stores about your training. A strength
entry is a rep count and a weight; an endurance entry is a duration, an intensity, an
average heart rate and a peak heart rate, plus an incline on a speed erg — every one of
them required. Either carries the moment it was
logged, and either is mutable and deletable. Four intervals are four entries, exactly as
four lifts are, and nothing wraps them.
_Avoid_: Record, set, log line, bout, piece, rep

An endurance entry may be called an **interval** in prose, as a strength entry is a lift —
the word for the thing you did, never a name for the stored row. A **valid interval** has
its duration, intensity and average heart rate all set: the endurance twin of the lift
check (`isAnInterval` beside `isALift`, ADR-0008).

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

**Rep-max card**:
One scope's strength curve read out as numbers rather than drawn, shown outside Chalk —
by Siri, or from a Spotlight result — without opening it. Twelve rep-maxes, a dash where
nothing is proven, and the machine named when the exercise is gym-bound; the scope is the
one the exercise's detail screen would open on, so tapping the card shows the same
numbers. It answers whichever rep count you asked about by holding all twelve, so it can
never answer the wrong one. Strength only: an erg has no single number to read out.
_Avoid_: Snippet, lookup, Siri card, PR card

**Scope**:
What a number is derived over and what a goal is set on: the exercise or erg itself when
it is free-weight or transferable, one machine when it is gym-bound. The boundary is
transferability, so a number is only ever compared against numbers it is comparable to.
Nothing you set on a machine — a treadmill's incline — draws a scope of its own; it is
part of the entry.
_Avoid_: Owner, context, level

**Ghost curve**:
A see-through Epley projection drawn behind the strength curve, showing headroom you
have not yet demonstrated. Guidance only — never a rep-max, never stored, never
presented as something you have lifted.
_Avoid_: Estimated max, projected 1RM, target

**History sheet**:
Every entry that can determine one derived number, newest first. In strength, one
rep-max — `reps >= n`, with the one currently setting the cell flagged. In endurance, one
point on a zone line — every entry at that duration, zone and incline, from all time, with
a divider where the ten-visit window ends; nothing is flagged, because a mean has no one
entry setting it. It mirrors the derivation rather than restating it. The only entry point
to raw history and the only place an entry is edited or deleted; there is no all-entries
log screen. Endurance entries longer than the chart's axis are reached from a list of
their own instead, and entries logged before zones are set are reached once they are.
_Avoid_: Log screen, entry list, records list

### An endurance entry

**Intensity**:
The number an endurance entry was done at, in its erg's unit — a speed on a treadmill,
watts on a bike, a split on a rower, a level on a Stairmaster. It is what you set or hold
on the machine, and what endurance exists to tell you. Stored exactly as you typed it and
never converted; the only number ever worked out from it is a speed's pace, shown beside
it.
_Avoid_: Pace, speed, output, load, level, setting, workload

**Unit**:
The kind of number an erg's intensity is written in — one of four the spec defines:
**speed** (in your distance unit — km/h or mph — with its pace per km or per mile shown
beside it), **watts**, **split** (time per 500 m) or **level** (the console's own scale).
Chosen when you create the erg and changeable only while it has no entries, because
changing it would reinterpret every number logged. A unit is a kind of number, never a
brand: Chalk converts nothing between units.
_Avoid_: Unit type, measure, metric, scale, readout
_Not_: the weight unit or the distance unit, which are app-wide and say which scale a
number is on, not what kind of number it is.

**Weight unit**:
Kilograms or pounds — the scale every strength weight and strength goal is written on,
app-wide. Chosen when Chalk first opens, and independent of the distance unit. Changing
it once you have entries is a relabel or a convert, never a silent switch.
_Avoid_: Unit (that is an erg's), unit system, metric, imperial

**Distance unit**:
Kilometres or miles — the scale a speed erg's intensity and its pace are written on
(km/h with min/km, or mph with min/mile), app-wide. Chosen when Chalk first opens, and
independent of the weight unit. Changing it once you have entries is a relabel or a
convert, never a silent switch.
_Avoid_: Unit (that is an erg's), speed unit, unit system, metric, imperial

**Relabel**:
Changing the weight or distance unit while every stored number stays as it is — the
repair for having picked the wrong unit, when the numbers were already on the new scale.
_Avoid_: Switch, change unit, fix

**Convert**:
Changing the weight or distance unit and rewriting every stored number onto the new
scale, goals included — what moving to a gym on the other scale asks for. Rounding is
part of it, so a convert can move a derived number by a hair; it is one-way, and never
what happens when you meant to relabel.
_Avoid_: Switch, change unit, migrate, recalculate

**Incline**:
The treadmill's grade, in percent, recorded on every entry of a speed erg beside its
intensity. 0 % is a value, not a blank. The one machine setting Chalk records: it never
draws a scope, but entries at different inclines never answer each other's question —
incline is to the lookup what reps are to the curve.
_Avoid_: Grade, gradient, slope, elevation

**Average heart rate**:
Your mean heart rate across one endurance entry, read off your watch and typed by hand.
The number that says what an entry cost you — the heart rate an entry's effort is read by.
_Avoid_: HR, avg, pulse

**Peak heart rate**:
The highest heart rate your watch showed during one endurance entry. Required, but second
to the average, which is what an entry's effort is read by. A property of the interval,
not of you, which is why it is never called a max. Never below the entry's average.
_Avoid_: Max heart rate, max HR, max, top

**Heart-rate zone**:
One of five bands of heart rate, Z1 to Z5, whose boundaries you worked out yourself —
from your watch's data or a lactate test — and typed in. Chalk holds one set, shared by
every erg; you can move the boundaries, never the count. Chalk owns no zone model and
computes no boundary — never from an age, never from a max. A zone is a way to name a
target heart rate, so it is read when you ask for one and never written onto an entry.
No boundary is ever called a threshold: which one that is depends on a zone model, and
Chalk owns none.
_Avoid_: Training zone, HR zone, band, level, intensity zone, threshold

**Zone line**:
What endurance derives, and its counterpart of the strength curve: for one zone on one
scope at one incline, the intensity you held at each duration you have done — the mean of
every entry at that duration whose average heart rate fell in that zone, over the last ten
visits on which you did it — joined in duration order and ending at the shortest and
longest durations you have done. Derived and never stored, and it states only what you
have held: a zone you have never landed in on a machine has no line there.
_Avoid_: Calibration, fit, threshold speed, pace curve, zone speed
(The endurance empty state's *Calibrate the machines you train on* is copy, not a domain term.)

**Visit**:
A calendar day on which you logged on a scope — what the zone line's window counts,
because entries from one day share that day's heat, hydration and fatigue. Not a session:
nothing groups a visit's entries, and nothing about it is stored.
_Avoid_: Session, workout, training day

**Settings**:
Chalk's one app-wide screen, reached from the home screen in either half. It holds your
heart-rate zones, your weight unit, your distance unit and whether plate breakdowns show,
and is where a backup is made
and restored; each further setting is its own decision.
_Avoid_: Preferences, options, profile, configuration

**Backup**:
One file holding everything Chalk knows — every entry, exercise, erg, group, gym,
machine and goal, your heart-rate zones and both units — readable by eye and restorable
exactly. Made by you, when you choose; Chalk keeps none of its own. What carries your
history across anything Chalk cannot carry it across itself: a new phone, a reinstall, a
convert you regret.
_Avoid_: Export, archive, snapshot, dump, save file

**Restore**:
Loading a backup in place of everything Chalk holds — a replace, never a merge, so what
you get back is exactly what the backup held, both units and your zones included — a
backup made before zones were set clears them, the one way zones are ever unset. Over a
library that is not empty it first says what will be lost, how old the backup is, any
unit it switches and zones it clears, because a stale backup restored by mistake is the
one way it can cost you.
_Avoid_: Import, merge, sync, recover

### What you're heading toward

**Goal**:
A number you have named and not yet held, on one scope — at most one, replaced rather than
added to. In strength it is a weight at a rep count; in endurance it is a point on the zone
line, an intensity at a duration in a zone, and at an incline on a speed erg. The only
number Chalk stores that is not something you performed, and its job is motivation: it
never tells you what to load or set. An endurance goal holds a zone, not a heart rate, so
it follows your boundaries when you move them.
_Avoid_: Target, PR, PB, milestone, aim, projection

**Reached**:
What a goal is once the number it is read against meets it — in strength your best at its
rep count, `best[reps] >= weight`; in endurance the zone line's point at its zone,
duration and incline, and only that point. Asked of the entries each time it is shown and
never stored, so a goal can un-reach on its own: in strength when an entry is corrected
downward, in endurance also when a slower visit pushes a faster one out of the window.
Nothing needs repairing either way.
_Avoid_: Achieved, hit, completed, retired, `reachedAt`

**Gap**:
The distance between what you have and your goal, in the goal's own unit — the weight
between your curve and your goal in strength, `goal weight − best[reps]`, and the
intensity between the point and the goal in endurance, the other way round on a split.
The number the whole feature exists to show; a reached goal has none. With nothing logged,
a strength gap is the entire weight, and an endurance goal has no gap at all — it is not
held yet.
_Avoid_: Headroom, remainder, deficit, progress

**Origin**:
Where a goal's ring fills from: the number it was read against at the moment it was named,
derived from the entries dated before then. In strength it is zero when there were none;
in endurance it is the point as it stood after your first visit on it. An endurance point
can fall back below its origin, which leaves the ring empty rather than negative.
_Avoid_: Start, baseline, starting point, `bestWhenSet`

**Setting a goal**:
The one write a goal has: naming a `(reps, weight)` pair — or a zone, duration,
intensity and incline — on a scope, which replaces whatever goal was there and records the
moment it was named, which is where the ring counts from. Naming your first goal and
replacing a reached one are the same act, which is why *change* is a word on a menu row
rather than an operation.
_Avoid_: Update, edit, amend, adjust, save

**Clearing a goal**:
Removing a goal without naming another — the only other way one leaves a scope. It sits at
the foot of the goal sheet, not in the exercise's or erg's overflow, which carries lifetime
operations only. Changing an erg's unit clears its goal too, and says so.
_Avoid_: Delete, remove, cancel, abandon, retire

**Goal sheet**:
Where a goal is named, borrowing the log sheet's input and nothing else of it. In strength
it is the two-stage giant number — reps, then weight; in endurance a short form of zone,
duration, incline and intensity, the first three taken from the point you scrubbed to. No
machine row, because the scope comes from the caller; no seeded weight or intensity,
because a goal is by definition one you have not held; and it commits with *Set goal*,
never *Save*.
_Avoid_: Goal editor, target sheet, goal modal

### The library

**Exercise**:
A lift you train, held in your strength library. Either free-weight or gym-bound.
_Avoid_: Lift, movement, activity

**Erg**:
A kind of indoor endurance machine you train on, held in your endurance library —
treadmill, rower, SkiErg, bike erg, Stairmaster, air bike, or one you add. A type of
machine, not a particular one: that is a machine. It speaks one unit. Either transferable
or gym-bound, and which is your call: Chalk knows no brands, so a *Concept2 RowErg* is simply an erg you
named that way.
_Avoid_: Cardio machine, equipment, exercise
_Note_: the Swift type for both exercises and ergs is `Exercise`; an erg is an `Exercise` with a unit.

**Free-weight**:
An exercise whose load transfers between gyms. 60 kg is 60 kg wherever you lift it,
so its rep-maxes derive across every entry. A strength word only; an erg whose numbers
transfer is transferable.
_Avoid_: Barbell, non-machine

**Transferable**:
An erg whose numbers transfer between gyms — the endurance counterpart of free-weight.
Its entries derive together wherever you logged them, and it has no machines. Never
Chalk's judgement: an erg is gym-bound until you say its numbers mean the same thing
everywhere.
_Avoid_: Free-weight (of an erg), portable, calibrated, standard

**Gym-bound**:
An exercise or erg whose numbers do not transfer between gyms — machines, cables, and
plate-loaded kit alike; a treadmill whose speed costs a different heart rate from one
model to the next. The test is transferability, not whether it is colloquially a
machine. Its numbers derive from one machine's entries only.
_Avoid_: Machine exercise, fixed-weight

**Bar**:
The weight of the empty bar an exercise is loaded on, if it is loaded on one — said by
you, never assumed, so an exercise has no bar until you give it one. A property of the
exercise, not of a gym or machine, and never part of any derivation.
_Avoid_: Barbell (as a kind of exercise), implement, equipment

**Plate breakdown**:
The plates per side that make up the weight you are reading, for an exercise with a bar,
from the standard plates of your weight unit — the nearest loadable weight below it when
the exact one is not. Arithmetic on a number Chalk already shows, never a prescription,
and something you can turn off.
_Avoid_: Plate calculator, loading guide, plate math

**Group**:
A user-owned, ordered bucket that an exercise or an erg may sit in, and a shelf rather
than a taxonomy — "Compound" next to "Legs" is incoherent as a classification and
entirely fine here. Each half keeps its own groups, so an erg never sits in a strength
group nor an exercise in an endurance one. Anything sits in at most one, chosen when it
is created and changed whenever you like. Its job is structure, not navigation, which is
why it never has to beat search.
_Avoid_: Category, muscle group, tag
_Note_: the Swift type is `ExerciseGroup`, to leave SwiftUI's `Group` view alone.

**Empty library**:
A library holding no exercise, no erg and no gym — nothing you made. Groups do not count,
since Chalk suggests them on a fresh install, and neither do your zones or units, which
are settings rather than library. One line for two questions: whether an install that
has no units yet is new, and whether a restore must say what it replaces.
_Avoid_: Fresh install, new user, no data

**Ungrouped**:
The state of an exercise or erg that sits in no group — a named place, not a missing
value, and the catch-all in both halves, so neither seeds an *Other*. It
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
The last thing you logged anywhere in this half's library, at the top of its home
screen: the exercise or erg, its last entry, and a one-tap way back into the log sheet.
Each half has its own, since you rarely train both on one day. Derived from the
entries like everything else, so it has nothing to maintain and is simply absent when
nothing has been logged. It carries the goal ring, with no words, but only for a goal at
the last entry's own scope — never a sibling machine's — so a log at a holiday gym never
shows your home machine's goal.
_Avoid_: Recent card, quick log, continue

### Where you train

**Gym**:
A place you train, held in its own right with an identity independent of its name — which
is what makes renaming one cost nothing. Gyms churn, so one can also be archived.
_Avoid_: Location, club, venue

**Machine**:
A gym-bound exercise or erg at a particular gym, optionally distinguished by
manufacturer or label. One gym may hold several for the same exercise or erg, and their
numbers are separate. For an erg the label is its model, by convention, so one machine
stands for every one of that model at that gym; the same model at another gym is
another machine. Its identity is independent of its label, so a label can be renamed
without touching its numbers — though an erg's renamed model changes which machine the
hint prefers, which is usually why you rename it.
_Avoid_: Station, equipment, apparatus

**Merge**:
Moving every entry from one machine onto a sibling — same exercise or erg, same gym —
and deleting the emptied machine. The repair for split numbers, when the same physical
machine was recorded twice because you learned its name late. Costs nothing to the
numbers, because no derived number is stored to recompute.
_Avoid_: Combine, de-duplicate, consolidate

**Current gym**:
The gym you are standing in, chosen once per visit and remembered until you change it.
A property of a device in a moment, not of your account, so strength and endurance share
it.
_Avoid_: Home gym, default gym, active location

**Archived**:
The state of a gym you have stopped visiting. It leaves the current gym picker but keeps
every entry it holds, and un-archives itself the moment you log there again. A matter of
display alone — no derived number is ever affected by it.
_Avoid_: Hidden, deleted, inactive, retired

**Hint**:
Your numbers for the same exercise or erg on a different machine, shown when the machine
in front of you has no history — for an erg, one of the same model at another gym when
there is one, since that is the likeliest to feel the same. Visibly marked as such, and
never part of any derivation.
_Avoid_: Estimate, reference, suggestion
