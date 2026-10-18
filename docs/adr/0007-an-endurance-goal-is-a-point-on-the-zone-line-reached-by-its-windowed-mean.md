# An endurance goal is a point on the zone line, reached by its windowed mean

An endurance goal names **a zone, a duration and an intensity**, plus an **incline** on a
speed erg — `Goal 15.5 km/h · 6:00 in Z4 · 1 %` — one per scope, as strength's goal is. It
is **reached** when the zone line's point at exactly that zone, duration and incline meets
it: the mean intensity over the last ten visits (ADR-0006), `≥` the goal, or `≤` on a
split. It is stored as ADR-0004's goal is — fields on the scope, a partial set no goal,
with `setAt` the only other thing kept — and everything else is derived. This is
ADR-0004's companion: the same storage and the same one write, read against a different
number.

## Considered options

- **A heart rate at an intensity** (*15 km/h at under 165 bpm*), the fitness direction,
  was rejected. Nothing Chalk derives answers it: the zone line gives the intensity in a
  zone, not the heart rate at an intensity, and fitting one against the other is what
  ADR-0006 dropped.
- **A zone and an intensity with no duration** was rejected: a zone has no single number,
  so the goal would have to pick which duration counts.
- **A best** — reached the first time any one entry at the point meets the goal, kept for
  good — was rejected for the mean. It is a number the screen never shows, so the readout
  would say 15.1 while the goal line says *reached* at 15.5, and it is the one cool,
  rested day ADR-0006 refused to let set the line. A goal says *this is what Z4 for six
  minutes costs me now*, and that is only true once the window agrees.
- **Backfill** — counting a lower zone, or a longer duration, at the goal's intensity, as
  strength counts a `95 × 6` toward a 5-rep goal of 95 — was rejected. Either way the goal
  would read against another point's number, and the duration form would assume a longer
  entry is harder, which ADR-0006 declines to impose on the line.
- **One goal per zone on each scope** was rejected as the ladder §12.6 already rules out.
- **A heart rate held instead of a zone** was rejected: a goal follows your boundaries when
  a lactate test moves them, as the zone line does.

## Consequences

- **A reached goal can un-reach with no edit**, when a slower visit pushes a faster one
  out of the window. Strength's only un-reach is a corrected entry. Nothing is stored, so
  nothing needs repairing, and the window only moves on a new visit, never with time.
- **Only the exact point counts.** When fitness makes 15.5 km/h average Z3, those entries
  join the Z3 line and the Z4 goal stays where it was until you set more and land back in
  Z4. Reading the machine by zone does that anyway.
- **The ring's origin is the point as it stood at `setAt`**, over entries strictly before
  it, or the point as of your first visit on it after `setAt` when there was none. Unlike
  strength, `current >= origin` does not hold by construction, so progress is clamped to
  0…1 and a visit below the origin shows an empty ring.
- **The gap is in the unit's own step**, never in a converted one, and a goal with no
  point reads `not held yet` instead of a gap from zero.
- **A goal needs zones and fixes its unit.** No goal can be named before zones are set;
  since zones are never cleared, none ever loses them. Changing an erg's unit — possible
  only while it has no entries — clears its goal, and says so.
- **No crossing on the endurance log sheet.** No single row reaches a mean; you find out
  on the detail screen after Save.
