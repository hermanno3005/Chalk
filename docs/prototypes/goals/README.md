# PROTOTYPE — how is a goal presented?

Throwaway. Answers [How is a goal presented?](https://github.com/hermanno3005/Chalk/issues/64),
a ticket on [Map: Goals — a number to head toward](https://github.com/hermanno3005/Chalk/issues/62).

> **Verdict: open.** The screenshots below are the thing to react to; the dev picks.

Four structurally different answers, mounted on the real exercise detail screen — real
scrub readout, real 150 pt curve, real ghost, real Log bar — so each is judged against
what it is actually competing with for space.

## Run it

Check out the `prototype-goals` branch, open `Chalk/Chalk.xcodeproj` and run. The app is
rooted at `GoalsPrototypeRoot`, not `LibraryView`. The black pill at the bottom carries:

- **‹ ›** — cycle the variant.
- **dataset pill** — `6 entries` → `0 entries` → `1 entry`.
- **goal pill** — `far` (140 × 5) → `close` (102.5 × 5) → `reached` (95 × 5) → `no goal`.
- **reached pill** — `grey out` / `vanish`, the two answers the ticket names.
- **ghost pill** — the ghost on or off, so the fog on the map can be looked at directly.

Sample data is in memory only; nothing is stored. The same combinations can be launched
directly — `-variant A -dataset "0 entries" -goal far -ghost NO` — which is how these
screenshots were taken.

## The four

| | Where the goal lives | Chart | Readout | Empty space |
|---|---|---|---|---|
| **A — Curve marker** | a dashed rule at the goal weight, plus a hollow point at its rep count | marked | untouched | empty |
| **B — Gap under readout** | one line under `best for N reps` | untouched | gains a line | empty |
| **C — Card in the empty space** | a labelled progress bar below the curve | untouched | untouched | **filled** |
| **D — The gap is the headline** | the big number *becomes* the gap | untouched | **replaced** | empty |

## A — Curve marker

6 entries · 1 entry · 0 entries · reached · ghost off

![A far](a-far.png) ![A sparse](a-sparse.png) ![A zero](a-zero.png) ![A reached](a-reached.png) ![A no ghost](a-noghost.png)

Three things the screenshots settle, all of them costs:

- **It cannot render alone.** With no entries there is no chart, so the goal falls back to
  a line of text — which *is* variant B. A is therefore never one presentation; it is two,
  and B is the second one.
- **A goal is drawn data, so the y axis has to frame it.** Compare `a-far` with `b-far`:
  the axis runs to 140 instead of 120 and the staircase loses a third of its height. At one
  entry (`a-sparse`) it is worse — curve and ghost are both crushed into the bottom third
  and the ghost reads as a downward slope near the floor.
- **A reached goal drawn grey collides with the ghost.** `a-reached` has two grey dashed
  lines on one chart meaning entirely different things — a projection and a crossed target.

## B — Gap under the readout

far · close · reached · 0 entries · no goal

![B far](b-far.png) ![B close](b-close.png) ![B reached](b-reached.png) ![B zero](b-zero.png) ![B none](b-nogoal.png)

The cheapest of the four and the only one that changes nothing structural. It renders
identically with and without a curve, so the zero-entry case needs no second design. Its
open question is whether one subhead line is *enough* motivation — and whether the gap
should track the scrubbed rep count or stay fixed at the goal's own.

## C — A card in the empty space

far · reached · 0 entries

![C far](c-far.png) ![C reached](c-reached.png) ![C zero](c-zero.png)

The most motivating and the most expensive: it spends the space §5.1 keeps deliberately
empty, and it is the app's one non-curve visual.

**The bar does not mean anything yet.** It runs from 0 kg to the goal, so 100 → 140 reads
as 71% done — but you were never at zero, and a beginner at 40 kg and a lifter at 100 kg
would both see a bar that is mostly full. Any bar needs an honest origin, and there isn't
an obvious one. Zero entries is the only case where 0 is the true origin.

## D — The gap is the headline

far · close · reached · 0 entries

![D far](d-far.png) ![D close](d-close.png) ![D reached](d-reached.png) ![D zero](d-zero.png)

The only variant that changes what the screen is *about*, and the only one where the
motivation is the first thing you read.

Two costs, both visible above:

- **It spends the scrub readout.** The big number stops being `best[N]`, so scrubbing the
  curve has nothing to update and the screen's answer to *what do I load for 5?* is gone
  from the place it lived. `d-reached` shows the readout handed back once the goal is
  crossed — which means the screen has two headlines depending on a derived state.
- **`d-zero` reads as absurd**: `140 kg to go` with nothing logged, and §5.4's
  `Nothing logged yet.` displaced entirely.

## What the ghost toggle showed

`a-noghost` is the one shot with the ghost switched off. On A it buys back real legibility,
because the goal rule and the ghost are competing for the same band above the curve. On
B, C and D nothing competes with it — the goal never enters the chart — so the ghost has
no reason to leave. **Whether the ghost stays is therefore not an independent question: it
is a cost that only variant A incurs.**

## Assumptions, not decisions

- Orange is a placeholder for "not the curve, not the ghost". No colour decision is implied.
- The wording (`Goal 140 × 5 · 40 kg to go`) is scaffolding; it is
  [How is a goal set, changed and cleared?](https://github.com/hermanno3005/Chalk/issues/65)
  and the glossary that own the words.
- Every shot is free-weight. Nothing here varies by kind — the goal scopes as the curve
  scopes, and the qualifier is unchanged.
- The goal is fixed at 5 reps, the default selection, so the gap and the scrub agree. What
  a goal at 3 reps looks like while you are scrubbing 8 is not shown and is open.
