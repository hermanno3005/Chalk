# An erg is read as a zone line, per duration, from your last ten visits

Endurance answers *what do I set on this machine to hit this zone*, and it answers it from
your own entries alone. For one zone on one scope at one incline, Chalk takes every entry
whose **average heart rate** fell in that zone and groups them by **duration, exactly as
typed**. Each duration gets one point: the **mean intensity** of its entries over **the last
ten visits** on which you did that duration in that zone — a visit being a calendar day you
logged on the scope — carried with their mean heart rate and how many entries made it. The
points are joined by straight segments, in duration order, and the line stops at the
shortest and longest durations you have done. This is the **zone line**. Nothing in it is
fitted, and nothing on it is a number you have not held.

## Considered options

- **Fitting heart rate against intensity on each machine and reading off where each zone
  begins** — the research's top-ranked sound derivation
  ([#91](https://github.com/hermanno3005/Chalk/issues/91)), and the first one chosen. It was
  dropped because it does not fit how the machine is actually trained: you return to the
  same speed for the same rep length and adjust it a little each visit, so the fit rarely
  has two intensities to stand on. It also answers for one duration-blind effort, when the
  question at the machine is *what do I set for 5 × 6 minutes*.
- **A floor of four minutes**, below which an entry's lagging average would be kept out of
  every derivation, was chosen and then withdrawn. Comparing a duration only with itself
  makes the lag the same for every entry in a point, so a one-minute entry is as honest as
  a twenty-minute one and nothing needs excluding.
- **All-time, as strength is** (§4), was rejected: the speed a zone costs measurably moves
  within weeks of training, so a year-old point would mislead. A **time window** was
  rejected because it moves on its own — a machine you have not visited in three months
  would go blank. A **count of entries** was rejected because one visit's five reps would be
  half of a ten-entry window, and intervals from one day share that day's heat, hydration
  and fatigue. Ten visits keeps strength's rule that a number never moves on its own — only
  a new visit pushes the oldest out — while letting fitness show.
- **The fastest intensity held in the zone**, a rep-max-like best, was rejected for the mean:
  one cool, rested day would set the number for good, where a mean over ten visits drifts
  as you do.
- **A fitted speed-duration curve across the whole axis** was rejected. Every model of that
  shape found so far describes maximal efforts, which Chalk cannot recognise; whether a
  sound one exists for a fixed heart-rate zone is a research question
  ([#102](https://github.com/hermanno3005/Chalk/issues/102)), and its answer could only ever
  be a ghost drawn behind the line — guidance, as the strength ghost is.
- **Naming a zone boundary *threshold*** was rejected. Zones are typed in and Chalk owns no
  model (ADR-0005), and which boundary is threshold depends on the model — Friel puts it
  where Z5 begins, Coggan in the middle of Z4.

## Consequences

- ADR-0002 carries over unchanged. The zone line is computed at read time by a plain struct
  over already-scoped entries plus the zones, with no SwiftData dependency, and nothing is
  cached. It changes when an entry is added, edited or deleted, or when a zone boundary
  moves — and an edited heart rate can move an entry onto another zone's line, which is the
  derivation working. The zone-membership rule, exact-duration grouping and the ten-visit
  window are the parts an implementer gets subtly wrong; they get tests.
- An entry belongs to the zone its average falls in, with a heart rate exactly on a boundary
  in the upper zone, since zones are stored as their lower bounds. Peak heart rate is not
  read.
- Every unit is averaged on its own line and rounded to its step, nearest: speed and watts
  as they are, a split through `1/split³` and back, a level averaged and rounded to a whole
  level. Level ergs need no case of their own.
- The line is drawn as it comes out. Physiology says a longer entry in the same zone needs a
  slower intensity, but a point out of that order is shown, not corrected.
- A zone you have never landed in on a machine has no line there, and a machine you are new
  to shows only the zones your first visit happened to reach. Lines are gated until zones
  are set; logging is not.
- *Am I getting fitter?* is answered by the window moving, not by a trend: no history of
  the line is kept or drawn.
- **No ghost is drawn.** [#102](https://github.com/hermanno3005/Chalk/issues/102) found no
  sound model for the intensity that holds a zone across durations, and
  [#98](https://github.com/hermanno3005/Chalk/issues/98) declined the one stub Chalk could
  draw past the longest duration. Unlike strength's curve, the zone line stands alone.
