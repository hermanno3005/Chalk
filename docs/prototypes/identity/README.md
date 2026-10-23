# PROTOTYPE — which palette and big-number treatment gives Chalk its identity?

Throwaway. Answers [Which palette and big-number treatment gives Chalk its identity?](https://github.com/hermanno3005/Chalk/issues/140),
a ticket on [Map: Store-ready — paying is the only step left](https://github.com/hermanno3005/Chalk/issues/127).

> **Archived.** This write-up and its screenshots live here; the runnable Swift source
> lives at the `prototype-identity` tag. See
> [`docs/agents/branch-lifecycle.md`](../../agents/branch-lifecycle.md).

> ## Verdict
>
> **E — Trade Republic's design language, its layout included, with Chalk's orange goal.**
> None of round one's three chalk palettes landed. The dev pointed at
> [Trade Republic's app](https://apps.apple.com/de/app/trade-republic-broker-bank/id1410703839)
> for its layout, styling and design language, and chose E, which takes all three.
>
> - **Monochrome.** Pure white in light, pure black in dark. The accent is black in light and
>   white in dark: the curve, the zone line, the selected tab, the Log bar and the toolbar.
>   Text on an accent fill is the inverse. Labels are a cool grey.
> - **The goal stays orange** (`Goal.colorset`, unchanged), the dev's call over Trade
>   Republic's purple: the one warm touch on the screen. **The zones take no colour of their
>   own.**
> - **Type is SF Pro, semibold by default.** Trade Republic's face, Trade Republic Sans
>   Display, is theirs, so SF Pro bold stands in. **The big number is 40 pt bold, tracked
>   −0.8**, with the unit in the same size and weight (`102,5 kg`), as theirs is (`218,40 €`).
> - **The layout is their stock screen's.** The name moves out of the nav bar into grey text
>   above the number, with a small bold aside beside it: `× 5` on a lift, `6:00 in Z4` on an
>   erg. The goal line sits under the number. On an erg, the zones are **text tabs**, grey off
>   and black on, between the readout and the chart, with the incline menu at the trailing end.
>   The chart **bleeds off the leading edge** with **no y axis, no grid and no points** except
>   the selected one. The rest of the readout moves into **label-and-value rows** under the
>   chart: `Entries at 5+ reps 6 ›` and `Logged 8 entries` on a lift; `Pace`, `Heart rate` and
>   `Entries 3 ›` on an erg.
> - **The ghost is dotted**, as their reference line is.
> - **A detail screen never scrolls.** Every button, the Log bar included, is always on
>   screen. The chart is the one thing that gives way: it takes up to 210 pt and shrinks to
>   110 pt before anything is pushed off. The dev's words: *scrolling kills the whole vibe.*

## The tokens

Light / dark. The dark greys are a guess: no Trade Republic screenshot shows its app in dark.
Check them on the phone (§15.6).

| Token | Light | Dark | Where |
|---|---|---|---|
| Ground | `#FFFFFF` | `#000000` | every screen's background |
| Primary text, accent | `#000000` | `#FFFFFF` | the number, values, curve, zone line, selected tab, Log bar, toolbar tint |
| On accent | `#FFFFFF` | `#000000` | the Log bar's label |
| Secondary | `#A2A7AC` | `#8A8F96` | the name, row labels, off tabs, axis labels, the ghost, the subhead's `›` |
| Tertiary | secondary at 45 % | secondary at 45 % | a tab with no line behind it |
| Goal | `#FF9500` | `#FF9F0A` | `Goal.colorset` as on main: the goal line and donut, and nothing else |

| Text | Font |
|---|---|
| The big number and its unit | SF Pro 40 bold, tracking −0.8, monospaced digits |
| The name above it | SF Pro 17 semibold, secondary |
| The aside beside it (`× 5`, `6:00 in Z4`) | SF Pro 18 bold |
| Tabs | SF Pro 16 semibold, about 52 pt apart, no fill |
| Rows | SF Pro 16, semibold secondary label, bold value; at least 45 pt tall, no divider |
| Axis labels | SF Pro 13 semibold, secondary; the selected rep count in primary |
| Everything else | semibold by default |

| Gap | Points |
|---|---|
| Side margin | 16, the system's |
| Name → number | 4 |
| Number → goal line | 12 |
| Goal line → chart (lift) | 40 |
| Goal line → tabs (erg) | 24 |
| Tabs → chart (erg) | 16 |
| Chart → rows | 28 on a lift, 16 on an erg |

| Chart | |
|---|---|
| Line | 3.5 pt, round caps and joins, in the accent |
| Points | the selected one only, at symbol size 90 |
| Ghost | 2 pt, dotted (`dash: [0.1, 6]`, round caps), secondary |
| Rule at the scrub | 1 pt, secondary at 40 %, behind the marks |
| Axes | no grid, no y axis; the x axis's labels only |
| Height | 110–210 pt, the one flexible thing on the screen |
| Bleed | off the leading edge, to the trailing margin |

## What the build touches

- **The colour assets**: `AccentColor` set to black and white, plus a ground and a secondary
  grey. `Goal` is unchanged.
- **Both detail screens**: `ExerciseDetailView`, `ScrubReadout`, `ErgDetailView`, `StrengthCurve`,
  `ZoneLineChart`, `ErgNoLineView`'s accent, and both Log bars' label colour. The tabs and rows
  are new views.
- **The rest of the app takes the palette and the type, not the layout**: the library and its
  tiles, the log sheet and the lap-list grid (its focused cell is accent-tinted), the goal sheets,
  History and Settings. This prototype never drew them.
- **Dynamic Type** (§15.6). The prototype uses fixed sizes. The build scales them, and the chart
  still gives way first so the screen keeps from scrolling.

## Run it

Check out the `prototype-identity` tag, open `Chalk/Chalk.xcodeproj` and run. The app is rooted at
`IdentityPrototypeRoot`: the real exercise and erg detail screens over a sample library in a
scratch store that is wiped on every launch. The black bar below the app has these controls:

- **‹ ›** switches between variants A–E.
- **screen pill**: Bench Press (free-weight, goal 7.5 kg away) → Treadmill (transferable speed
  erg, zones set, lines in Z2–Z5 at 1 %, a Z4 goal).
- **appearance pill**: Light → Dark.

The real views read `Palette.current` where main reads `accentColor` and `Goal`, and branch on its
style for D and E. Screenshots were launched as
`-prototype.variant E -prototype.screen erg -prototype.dark YES`, on an iPhone 18 Pro and, for E,
an iPhone 17e as well. The simulator's region writes `102,5`.

## Round one — three chalk palettes, layouts unchanged

Each came from the icon (`docs/app-icon.svg`: chalk faces `#FBFAF6`, `#E2DFD7`, `#C4C0B6` on
slate `#2C2D33` → `#16171A`). The dev liked none of them.

| | Palette | Zones | Goal | Number |
|---|---|---|---|---|
| **A — Chalk on slate** | warm chalk on slate, no hue; ink accent in light, chalk in dark | no colour | yellow chalk | heavy rounded, chalk grain knocked out |
| **B — Chalk bag** | chalk faces, one ember accent | warm ramp, ember is Z4 | teal | black compressed, small capitalised unit |
| **C — Cue chalk** | billiard-chalk blue on cool slate | one blue, pale to deep | orange | bold serif, italic unit |

**A** exercise light · dark · erg light · dark

![A exercise light](a-exercise-light.png) ![A exercise dark](a-exercise-dark.png) ![A erg light](a-erg-light.png) ![A erg dark](a-erg-dark.png)

**B**

![B exercise light](b-exercise-light.png) ![B exercise dark](b-exercise-dark.png) ![B erg light](b-erg-light.png) ![B erg dark](b-erg-dark.png)

**C**

![C exercise light](c-exercise-light.png) ![C exercise dark](c-exercise-dark.png) ![C erg light](c-erg-light.png) ![C erg dark](c-erg-dark.png)

## Round two — Trade Republic

What their app is made of, from their website and their App Store screenshots:

- **Type.** The website's CSS serves **Trade Republic Sans Display** at weights 500, 580, 680 and
  740, a custom face no foundry sells. Everything is semibold or bold. A grey label sits over a
  black number of modest size, with the unit in the same weight, and a small bold aside beside
  it (`▲ 10,55 %`).
- **Colour.** White, black and one cool grey (`#A2A7AC`, sampled). Colour appears only where it
  means something: green `#00CC4B` for *Aktiv*, purple `#5F28FF` on interest.
- **Charts.** A thick black line, about 3.5 pt, with no axes, no grid and no points, and a dotted
  grey reference line. It runs off the leading edge.
- **Tabs and rows.** `1T 1W 1M 1J Max` as plain text, grey off and black on, about 52 pt apart.
  Facts in label-and-value rows about 45 pt apart, with no dividers and a grey `›` after a label
  that opens something.

**D** kept Chalk's layout and took the styling: text tabs for the zones, the chart's line and
dots, the grey, the type, and a purple goal. **E** took the layout too.

**D** exercise light · dark · erg light · dark

![D exercise light](d-exercise-light.png) ![D exercise dark](d-exercise-dark.png) ![D erg light](d-erg-light.png) ![D erg dark](d-erg-dark.png)

**E, as chosen** (orange goal, the chart giving way), iPhone 18 Pro

![E exercise light](e-pro-exercise-light.png) ![E exercise dark](e-pro-exercise-dark.png) ![E erg light](e-pro-erg-light.png) ![E erg dark](e-pro-erg-dark.png)

**E on iPhone 17e**, the smallest current iPhone, still with the prototype's bar taking its height

![E 17e exercise light](e-17e-exercise-light.png) ![E 17e exercise dark](e-17e-exercise-dark.png) ![E 17e erg light](e-17e-erg-light.png) ![E 17e erg dark](e-17e-erg-dark.png)

## What the screenshots show

The dev chose E. These are the differences the comparison turned up, not the dev's stated
reasons.

- **Round one changed colour on a layout that stayed the same, and that wasn't enough.** Each
  palette was recognisably different, and none made the screen feel new. D, which is mostly
  Trade Republic's subtraction (no grid, no small points, no pills), already read as more of a
  change than any of A–C.
- **E's rows are what make the bottom half feel designed.** In D the space under the chart is
  empty, as §5.1 left it. E puts the readout's subhead there as rows, and the number above
  loses its two lines of small text.
- **Moving the name out of the nav bar** turns the bar into chrome alone (back, qualifier,
  overflow) and lets the name lead the number, as `Apple` leads `218,40 €`.
- **On the first E, the erg pushed its Log bar down.** The readout, goal line, tabs, a 210 pt
  chart and three rows over-filled the screen. That is why the chart now gives way.
- **The orange goal is the only colour left** once everything else is monochrome, so it reads at
  once. The dev, on D and the first E's purple: *I like the orange touch more.*
