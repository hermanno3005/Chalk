# What each erg displays, and how its units convert

**Date:** 2026-10-16
**Question:** [#90](https://github.com/hermanno3005/Chalk/issues/90) — what does each indoor erg's
console show as its intensity, and which of those numbers can be converted into each other? Part of
map [#88](https://github.com/hermanno3005/Chalk/issues/88).
**Scope:** treadmill, Concept2 BikeErg, Concept2 RowErg, Concept2 SkiErg, Stairmaster
(StepMill / stair climber), AssaultBike and Rogue Echo Bike. Console readouts, exact conversions,
what a Stairmaster "level" is, treadmill incline, and the evidence on calibration between units.
**Status:** findings only. The decisions belong to [#94](https://github.com/hermanno3005/Chalk/issues/94)
(how an intensity is stored and shown) and [#93](https://github.com/hermanno3005/Chalk/issues/93)
(which ergs' numbers transfer between gyms). §8 notes which facts bear on which decision.

**Primary sources** are manufacturer pages and manuals (Concept2, Assault Fitness, Rogue,
StairMaster / Core Health & Fitness, Life Fitness), NIST for unit definitions, and peer-reviewed
papers for the treadmill. Anything that rests on a forum post, a retailer or my own arithmetic is
labelled as such. Claims I could not settle are collected in §9.

## Bottom line

1. **Concept2's three ergs share one physical scale.** Watts and pace are two views of one number,
   related by Concept2's published `watts = 2.80 / pace³`, with pace in **seconds per metre**. The
   RowErg and SkiErg show pace per 500 m. The BikeErg shows pace per **1000 m**, and Concept2 states
   that a given /1000 m pace on the BikeErg takes the same watts as that pace per 500 m on the rower.
   So for the bike, the formula takes the /1000 m split where the rower takes the /500 m split.
   Calories are a third view of the same number, computed for a fixed 175 lb person.
2. **AssaultBike and Echo Bike watts are not shown to be Concept2 watts.** Both consoles display
   watts, RPM, a bicycle-equivalent speed and calories, but neither manufacturer publishes how watts
   are computed, and no independent validation turned up. Treat them as each brand's own scale.
3. **A Stairmaster "level" is not a physical quantity.** It runs 1–20 on some models and 1–25 on
   others. One StepMill manual says level speeds "may differ depending on user weight". Step height
   differs between models (8 in vs 6 in). Gyms can configure a maximum step rate. The physical
   readout is **steps per minute**, which modern StepMills display beside the level. Even that converts
   to vertical speed only once you know the step height.
4. **Treadmill speed is km/h or mph, and pace is its arithmetic reciprocal.** Incline is **percent
   grade**, typically 0–15 % on commercial units. The "1 % incline equals outdoor running" convention
   comes from one 1996 study of trained runners at 10.5–18 km/h. A 2026 study found it does not fully
   close the gap.
5. **Calibration.** Concept2 RowErg and SkiErg recalculate their drag factor on every stroke. The
   BikeErg needs periodic calibration, which the monitor prompts for. Treadmill belt speed is shown to
   differ from the set speed (about 98–103 % on average across four lab treadmills) and to depend on
   the runner's weight. **No peer-reviewed survey of gym treadmills was found**, so the map's premise
   rests on mechanism and anecdote, not on a measured gym-to-gym spread (§9).

---

## 1. What each console shows

| Erg | Primary intensity readout | Also shows | Unit choice on the console |
|---|---|---|---|
| **Concept2 RowErg** | Pace /500 m | Watts, Cal/hr, total Cal, stroke rate (s/m), time, distance | Units button cycles pace → Calories → watts |
| **Concept2 SkiErg** | Pace /500 m | as RowErg | as RowErg |
| **Concept2 BikeErg** | Pace **/1000 m** | Watts, Cal/hr, total Cal, cadence in **rpm**, time, distance | as RowErg |
| **AssaultBike Classic** | Watts, speed, RPM, shown together | Time, distance, calories, heart rate | mi/km chosen in setup mode |
| **Rogue Echo Bike** | Speed, watts and cadence, shown together | Time, distance, calories, heart rate | — |
| **StairMaster StepMill (8G)** | Level 1–25, and speed in **steps/min** | Floors, steps, kcal, watts/METs alternating, time, HR | English/metric in maintenance mode |
| **StairMaster StepMill 3** | Level 1–20 ("speed level") | Floors, **floors/min**, calories, watts, HR | — |
| **StairMaster SM916 / 7000PT (older)** | Step rate in steps/min (SM916); level 1–20 (7000PT) | Floors, cal/hr, watts, METs, "miles" | — |
| **Treadmill** (Life Fitness Integrity, as an example) | Speed (mph or km/h) and incline (%) | Time, distance, heart rate, calories | Imperial/metric call-out button |

Sources and detail:

- **Concept2 PM5.** "Pace per 500 meters (on a BikeErg this is pace per 1000 meters)". The Units
  button cycles "from pace to Calories or watts". Stroke rate is spm, and "On a BikeErg, this cadence
  will be displayed as rpm" ([PM5 display options](https://www.concept2.com/service/monitors/pm5/how-to-use/using-monitor-display-options);
  [PM5 101](https://www.concept2.com/blog/pm5-101)). The SkiErg uses the same /500 m pace: "How long it
  takes you to row or ski 500 metres" ([Understanding and changing units](https://www.concept2.nl/en/service/monitors/pm5/how-to-use/understanding-and-changing-units)).
- **AssaultBike Classic** (owner's manual #23-AS-100-1, 2022). "Watts, Speed and RPM will be
  displayed during all programs." Speed "simulates that of riding a standard bicycle and is derivative
  of the current RPM or pedal speed", in mph or km/h. A separate panel tracks time, distance and
  calories ([manual PDF](https://resources.sport-tiedje.com/pdf/assault/Assualt%20Bike%20Classic%202023%20Manual.pdf)).
- **Rogue Echo Bike** (user guide, 2019). The display's "Speed / Watts / Cadence" section shows
  intensity, and "Exercise data, such as watts, speed, cadence, time, distance, calories and heart
  rate, will be calculated and displayed as the user pedals" ([user guide PDF](https://fitatmidlife.com/wp-content/uploads/Echo-Bike-User-Guide-FINAL-v2-3-7-19.pdf)).
  Rogue's current M2 monitor firmware 30.1.40 (March 2026) adds "an additional active workout screen
  that simultaneously displays Watts and Cals" ([Rogue Echo Bike page](https://www.roguefitness.com/rogue-echo-bike)).
- **StairMaster 8G StepMill.** "SPEED — Displays the current speed in Steps per Minute"; "LEVEL —
  Displays the current level, from 1-25"; "WATTS/METS — Alternates display of current user Watts and
  METS"; the top window shows floors, steps and HR. A floor is 16 steps ([8G owner's manual](https://fitnessengros.dk/media/c8/82/f7/1670237019/Owners%20Manual%20G8.pdf)).
- **StairMaster StepMill 3.** "The intensity or speed level displays the rate that the staircase
  revolves on a scale from 1-20"; "FLOORS PER MINUTE — Displays the step rate in floors per minute";
  a floor is "22 steps or approximately 11 feet/3.3 meters" ([SM3 owner's manual](https://support.corehandf.com/Brands/Stairmaster/Manuals/SM3_Owners_Manual.pdf)).
- **StairMaster SM916.** The user types a step rate directly ("The StepMill machine has a step rate
  range of 24 to 162"), and the Level keys change the step rate ([SM916 manual](https://coloradocardio.com/wp-content/uploads/2019/07/stairmaster_stepmill_sm916_owners_manual.pdf)).
  **7000PT** (2001): "Level — Shows the current intensity level between 1 (the easiest) and 20 (the
  hardest)"; "Floors — the equivalent number of floors climbed with an 8-inch step. There are 16 steps
  per floor" ([7000PT manual](https://coloradocardio.com/wp-content/uploads/2019/07/stairmaster_stepmill_7000pt_c40_owners_manual.pdf)).
- **Other brands' stair machines speak the same mix.** The Life Fitness PowerMill console shows
  "Speed, Time, Calories, Heart Rate, SPM, Level" ([Integrity C console manual](https://cdn.shopify.com/s/files/1/2781/4920/files/integrity-c-console-owners-manual.pdf?2673)).
- **Treadmill.** Life Fitness Integrity: "0.5 - 14mph (0.8 - 23 km/h) in 0.1 increments", incline
  15 % ([Life Fitness Integrity](https://lifefitness.com/en-gb/catalog/cardio/treadmills/integrity-series-treadmill)).
  The Integrity C console "Displays Speed, Time, Distance, Heart rate, Calories, Incline", and its
  call-out button toggles Imperial/Metric ([Integrity C console manual](https://cdn.shopify.com/s/files/1/2781/4920/files/integrity-c-console-owners-manual.pdf?2673)).
  Whether a given treadmill also shows **pace** (min/km) is per-console. Many do, but I did not
  confirm it in a primary manual (§9).

---

## 2. Exact conversions

### 2.1 Treadmill speed and pace — arithmetic

- **min/km = 60 / (km/h).** 10 km/h = 6:00 /km; 12 km/h = 5:00 /km; 15 km/h = 4:00 /km.
- **1 mile = 1.609 344 km exactly**, so 1 mph = 1.609 344 km/h exactly ([NIST SP 811, App. B.9](https://www.nist.gov/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/nist-guide-si-appendix-b9);
  boldface factors are exact).
- A treadmill stepping in 0.1 mph steps does **not** land on round km/h values, and the reverse is
  also true: 6.2 mph = 9.98 km/h. If someone switches the console's units, the same physical belt
  setting reads as a number that has been rounded (arithmetic).

### 2.2 Concept2 watts and pace — published formula, confirmed

> `watts = 2.80 / pace³` and `pace = ³√(2.80 / watts)`, where pace is "time in seconds over distance
> in meters". Worked example on the page: 2:05 /500 m → 125/500 = 0.25 → 2.80 / 0.25³ = 179.2 W.
> — [Concept2 Watts Calculator](https://www.concept2.com/training/watts-calculator), whose
> description covers "the Concept2 RowErg, BikeErg and SkiErg". The
> [Pace Calculator](https://www.concept2.com/training/pace-calculator) gives the same thing as
> `watts = 2.8/(split/500)³`.

- **RowErg and SkiErg use the same constant and the same /500 m split.** The pace calculator offers a
  single "Indoor Rower/SkiErg" option, and the PM5 defines pace for both as time to "row or ski 500
  metres".
- **BikeErg: the same 2.80, applied to the /1000 m split as if it were a /500 m split.** Concept2:
  "The wattage required to go at a given pace per 500m on the indoor rower is the same wattage
  required to go at that pace per 1000m on the BikeErg. However, the 'meters' traveled has been given a
  value that more closely simulates biking on the road, and has been pegged at 2X for the same power"
  ([Concept2 blog, 30 Apr 2019](https://www.concept2.com/blog/benefits-of-cycling-the-bikeerg-for-rowers);
  repeated in [15 May 2019](https://www.concept2.com/blog/dont-miss-a-beat-of-training-bikeerg)).
  So:
  - BikeErg: `watts = 2.80 / (split₁₀₀₀ / 500)³`, which equals `22.4 / (seconds per BikeErg metre)³`.
  - Example: 2:00 /1000 m on the BikeErg = 2:00 /500 m on the RowErg = **202.5 W**.
  - Put another way, the cube formula **does not** carry over unchanged in seconds per metre. The
    BikeErg's "metre" is half a rower metre at equal power.
- **Worked values** (arithmetic from the formula):

  | /500 m (row, ski) or /1000 m (bike) | Watts |
  |---|---|
  | 1:30 | 480.1 |
  | 1:45 | 302.3 |
  | 2:00 | 202.5 |
  | 2:30 | 103.7 |

  Inverse: 100 W ↔ 2:31.8, 150 W ↔ 2:12.6, 200 W ↔ 2:00.5, 250 W ↔ 1:51.9, 300 W ↔ 1:45.3.
- **The relation is a cube.** Twice the watts gives 2^(1/3), about 1.26×, the speed. A *lower* split
  is *harder*, and equal steps in split are not equal steps in watts.

### 2.3 Concept2 calories

- PM formula: "Calories = (4x average watts/1.1639) + 300 Cal/hour x time rowed (in hours)", based
  on "a 175 pound (80 kg) person" ([PM2/PM2+ how-to-use](https://www.concept2.com/support/monitors/pm2/how-to-use)).
  The PM5 pages repeat that calories use "a formula based on a 175 pound individual" but do not print
  the formula again.
- Concept2's own correction for body weight: "True Calories/hour burned = Calories on the PM - 300 +
  (1.714 * weight)", weight in lb ([Calorie Calculator](https://www.concept2.com/training/calorie-calculator)).
- **Interpretation (mine, not Concept2's):** 1/1.1639 ≈ 0.8592, which is close to 3600/4186.8 ≈
  0.8598, the conversion from W to kcal/h. So `Cal/hr ≈ 4 × (mechanical kcal/h) + 300`, meaning about
  25 % efficiency plus a 300 kcal/h base. Cal/hr is therefore an affine function of watts and carries
  no information beyond watts.
- Whether the BikeErg and SkiErg use the identical calorie formula is not stated on any page I found
  (§9).

### 2.4 AssaultBike / Echo Bike watts — no published formula

- Neither the AssaultBike Classic manual nor the Echo Bike user guide says how watts are derived. The
  Assault manual says only that "Watts are a measurement of energy generation". Speed is stated to be
  "derivative of the current RPM".
- I found **no manufacturer formula and no peer-reviewed validation** of either bike's displayed
  power. Calculator sites give conflicting RPM-to-watts curves with no attribution (§9).
- **The standard that would make watts comparable exists, but neither bike is shown to meet it.**
  EN ISO 20957-5 (stationary bikes) Class SA tolerance is "+/- 5 Watts up to 50 Watts and +/- 10% over
  50 Watts", as Life Fitness quotes for its own bikes ([Integrity C console manual](https://cdn.shopify.com/s/files/1/2781/4920/files/integrity-c-console-owners-manual.pdf?2673)).
  Two bikes that both comply could still read about 20 % apart at the same true power (arithmetic
  from the tolerance band). I did not find either Assault Fitness or Rogue claiming any accuracy class
  (§9).

### 2.5 Stair machines — steps/min to vertical speed (arithmetic, model-dependent)

- **Vertical speed = steps/min × step height.** Step height is a per-model fact:
  - StepMill (SM5 / commercial): "Revolving staircase with eight steps, 8" (20cm) high"; step rate
    "24 to 162 steps/minute" ([StepMill technical manual, rev. 10/5/15](https://support.corehandf.com/Brands/StairMaster/Manuals/637-4243AStairMasterStepMillTechManual.pdf)).
  - StepMill 3 (light commercial): "Revolving staircase with six, 6" inch steps" (same document).
- So 100 steps/min is 20.3 m/min on 8-inch steps and 15.2 m/min on 6-inch steps, a 25 % difference
  at the same displayed number.
- **Floors** happen to be nearly equal across those two models: 16 × 8 in = 3.25 m; 22 × 6 in =
  3.35 m (the SM3 manual says "approximately 11 feet/3.3 meters"). Floors/min is therefore closer to a
  physical vertical speed than steps/min, but only to within about 3 %, and only for the models whose
  manuals define it.
- **Watts and calories on a stair machine depend on the body weight entered.** "Your weight, step
  rate or intensity levels are used to calculate the number of calories burned" (SM916). The 8G
  falls back to a default weight of 176 lb, set by the gym in maintenance mode, if none is entered
  (8G manual). That the displayed watts are `weight × g × vertical speed` is physically plausible but
  not stated (§9).

---

## 3. What a Stairmaster "level" is

**A level is a per-model target setting, not a physical unit.** Facts, all from primary manuals:

- **The scale differs by model.** 1–25 on the 8G; 1–20 on the StepMill 3 and the 7000PT.
  The SM916 has no level scale at all: you enter steps/min.
- **It is a target that the motor controller chases.** On the StepMill, "the console controls the
  alternator's field current attempting to maintain the desired step rate", and a very light user may
  be unable to reach a step rate at all ([technical manual](https://support.corehandf.com/Brands/StairMaster/Manuals/637-4243AStairMasterStepMillTechManual.pdf)).
  On the 8G, level-up "will not allow the user to increase the level past the stop point until the
  actual machine speed has reached the set level", so set level and actual speed can differ for a while.
- **The same level is not the same speed for every user, even on one machine.** StepMill 3: "Workout
  level speeds may differ depending on user weight … Users with different weight may get different
  speed results" ([SM3 manual](https://support.corehandf.com/Brands/Stairmaster/Manuals/SM3_Owners_Manual.pdf)).
- **The gym can cap it.** The 8G maintenance menu has `MAX SPM`, from 110 to 140 with a default of 120
  (8G manual, maintenance parameters). A gym's level 25 may therefore not be another gym's level 25.
- **No level→steps/min table** was found in any StairMaster manual retrieved (8G, SM3, SM916, 7000PT,
  technical manual). A third-party blog table exists but contradicts the manuals' scales (§9).

**Net:** level behaves like a gym-bound weight-stack number, not like watts. **Steps/min** is the
nearest physical readout, and modern StepMills (8G) and the Life Fitness PowerMill display it beside
the level. Even steps/min needs the step height to become vertical speed, and step height varies by
model.

---

## 4. Treadmill incline

- **Unit: percent grade**, rise over run × 100. On Life Fitness, Woodway and Precor consoles it is
  written as `%` ([Life Fitness Integrity](https://lifefitness.com/en-gb/catalog/cardio/treadmills/integrity-series-treadmill):
  "Incline 15%"; [Woodway 4Front spec](https://www.woodway.com/wp-content/uploads/2024/02/4Front-200902-4Front-Spec.pdf):
  0–15 %). Converting to an angle: atan(grade): 1 % = 0.57°, 10 % = 5.71°, 15 % = 8.53° (arithmetic).
- **Typical commercial range: 0–15 %.** Some units decline (Precor TRM 885 is listed by a dealer as
  −3 %), and some incline trainers go far higher. Neither is verified from a manufacturer sheet (§9).
- **Steps:** Life Fitness speed steps are 0.1 mph. Incline step size was not confirmed in a primary
  source; 0.5 % is common (§9).
- **The 1 % convention.** Jones & Doust (1996), *J Sports Sci* 14:321–327,
  [doi:10.1080/02640419608727717](https://doi.org/10.1080/02640419608727717): nine trained male
  runners at 2.92–5.0 m/s (10.5–18 km/h). The absence of air resistance makes treadmill running
  cheaper, and "a 1% treadmill grade" equalised energy cost "over a duration of approximately 5 min and
  at velocities between 2.92 and 5.0 m s⁻¹". At the two slowest speeds, 0 % and 1 % were both
  indistinguishable from the road. The result therefore says nothing about walking or slow jogging.
- **Newer counter-evidence.** Shahidi et al. (2026), *PLoS One*,
  [doi:10.1371/journal.pone.0355988](https://doi.org/10.1371/journal.pone.0355988): twelve male
  runners, 8–15 km/h, found overground energy cost consistently higher than treadmill at 1 %, and
  concluded "the commonly used 1% treadmill grade correction does not fully replicate the energetic
  demands of overground running."
- **Grade in the standard metabolic equations.** The ACSM equations used throughout exercise science
  put grade in as a fraction: walking VO₂ = 0.1·S + 1.8·S·G + 3.5, running VO₂ = 0.2·S + 0.9·S·G + 3.5
  (S in m/min, G as a fraction, VO₂ in ml/kg/min). This comes from **secondary reproductions** of
  *ACSM's Guidelines for Exercise Testing and Prescription*; I did not consult the book (§9). The fact
  that bears on #94: incline and speed do not collapse into a single number without a model like this,
  and the model is population-average.

---

## 5. Calibration: Concept2 vs everything else

### 5.1 Concept2

- **RowErg and SkiErg self-calibrate.** "The Performance Monitor self-calibrates on the RowErg and
  SkiErg by recalculating the drag factor on every pull", so "you get a true measure of your effort
  regardless of the damper setting or changing conditions" ([viewing drag factor](https://www.concept2.nl/en/service/monitors/pm5/how-to-use/viewing-drag-factor)).
- **Between machines, Concept2 points at drag factor:** "Drag factor is a much better comparison
  between machines that have different air flows … due to things such as dust in the flywheel or
  elevation", and "the Concept2 Performance Monitor takes into account your choice of damper and drag
  into calculating your speed" ([What damper setting should I use?](https://www.concept2.com/blog/what-damper-setting-should-i-use)).
  Concept2's world rankings rest on this cross-machine comparability.
- **The BikeErg is the exception:** "the BikeErg needs to be calibrated from time to time" (same
  drag-factor page). The monitor prompts for confirmation periodically, including before a ranked
  distance and after the machine is moved ([BikeErg manual](https://www.concept2.co.uk/files/pdf/us/bikeerg/bikeerg_manual_english-only.pdf),
  as quoted in search results; the PDF link has since 404'd for me). That it needs this because a bike
  has no recovery phase in which to measure flywheel decay comes from forum posts (§9).
- **Absolute accuracy is a separate question from consistency.** Holt et al. (2021), *Front Physiol*,
  [doi:10.3389/fphys.2021.758015](https://doi.org/10.3389/fphys.2021.758015), found that a Concept2
  Model D read **11–15 % below** a reference handle-force system, and smoothed stroke-to-stroke
  variation. Only one Concept2 unit was tested, so between-unit spread was not measured. Chalk would
  compare a person's own numbers, which needs consistency rather than absolute accuracy.

### 5.2 Treadmills

- **Belt speed deviates from set speed, and the deviation depends on the treadmill and the runner.**
  Willwacher et al. (2021), *Sci Rep* 11:2244,
  [doi:10.1038/s41598-021-81951-9](https://doi.org/10.1038/s41598-021-81951-9): four treadmills,
  seven participants, 1.0–4.5 m/s. "Average belt speeds varied between about 98 and 103% of the target
  speed". "TBV regulation differs between treadmill types", and with higher body mass the belt
  slowdown in stance increased. On three of four treadmills it exceeded 5 % of target speed during
  running.
- Tielke, Ahn & Lee (2019), *Sci Rep*,
  [doi:10.1038/s41598-019-49272-0](https://doi.org/10.1038/s41598-019-49272-0): "the error of the
  treadmill speed periodically varies depending on the locomotion phase" and "becomes more evident as
  the locomotion speed or the weight of the walker increases", with the motor's limited power named as
  one cause.
- **Both studies used laboratory treadmills.** I found **no peer-reviewed survey of commercial gym
  treadmills' displayed vs actual speed**, and **no published survey of incline accuracy**. Claims of
  "±5–10 %" gym-to-gym error appear only on blogs (e.g. [80/20 Endurance](https://www.8020endurance.com/dont-trust-your-treadmill/))
  without a named measurement (§9).
- **The standard exists, but its tolerance is behind a paywall.** ISO 20957-6 / EN 957-6 (treadmills)
  defines accuracy classes A/B/C and has a test of "the accuracy of time, speed and distance
  indications" (clause 7.15 in the 2021 edition, per [iTeh's listing](https://standards.iteh.ai/catalog/standards/iso/57a1de11-4b29-44fb-ab50-e52bbe17c2ef/iso-20957-6-2021)).
  I could not retrieve the numeric tolerance (§9).
- **Manufacturers treat speed as something a technician calibrates.** Precor service manuals list a
  calibration mode ([ManualsLib index for Precor 905e](https://www.manualslib.com/products/Precor-905e-2947530.html)),
  which implies a unit can drift out of calibration (inference).

### 5.3 Stair machines and air bikes

- **Stairmaster:** step rate is closed-loop to a target. Actual rate depends on user weight (SM3) and
  can lag the set level (8G), and gyms configure a max SPM. I found no calibration procedure for step
  rate and no study of between-unit variance (§9).
- **AssaultBike / Echo Bike:** no calibration procedure in either manual, and no published
  validation. An air bike's fan load depends on air density and blade condition, as Concept2 says of
  its own flywheels (dust, elevation). But without a drag-factor measurement there is no way for the
  console to correct for it. That second point is **inference** (§9).

---

## 6. Summary: which numbers are interconvertible

| Readout | Converts to | Exact? | Conditions |
|---|---|---|---|
| Treadmill km/h | min/km, mph, min/mile | **Exact** | Arithmetic and the NIST mile |
| Treadmill incline % | degrees | **Exact** | atan(grade) |
| Treadmill speed + incline | one "flat-equivalent" speed or VO₂ | **Model-based** | ACSM equations or the 1 % convention; population averages, speed-limited |
| Concept2 /500 m pace (row, ski) | watts | **Exact** | `2.80 / (split/500)³` |
| Concept2 /1000 m pace (bike) | watts | **Exact** | `2.80 / (split₁₀₀₀/500)³`, same constant |
| Concept2 watts | Cal/hr | **Exact, but for a fixed 175 lb person** | `4·W/1.1639 + 300` |
| AssaultBike / Echo watts | Concept2 watts | **No published basis** | — |
| AssaultBike / Echo watts | the same bike's RPM | Monotonic, formula unpublished | — |
| Stairmaster level | steps/min | **No** | Per model, per gym (MAX SPM), per user weight |
| Stairmaster steps/min | vertical m/min | **Exact given step height** | Step height is per model (8 in vs 6 in) |
| Stairmaster floors/min | vertical m/min | ≈ 3.25–3.35 m per floor | Only for models whose manual defines a floor |

---

## 7. Precision as displayed (bears on #94's keypad question)

- Treadmill speed: 0.1 mph or 0.1 km/h steps (Life Fitness: "in 0.1 increments").
- Concept2 pace: minutes:seconds, with tenths on some screens. Watts and Cal/hr are whole numbers.
  This is from general knowledge of the PM5, not a quoted spec (§9).
- Stairmaster: whole levels, whole steps/min.
- Air bikes: whole watts and whole RPM, as shown in the manuals' display descriptions (no decimals).

---

## 8. Which facts bear on which decision

- **#94 (how an intensity is stored and shown):**
  - The BikeErg's native readout is **pace /1000 m**, not watts. Watts is one press of Units away.
    The ticket's draft line "bike **watts**" holds only if Chalk chooses watts over what the screen
    shows by default.
  - For all three Concept2 ergs, pace and watts are one number (§2.2). Only one needs storing, and the
    BikeErg's conversion uses the /1000 m split with the same constant.
  - **Direction of "better" is inverted** for pace: a lower split is harder, while watts and km/h rise
    with effort. The pace–watts relation is a cube, not linear.
  - Stairmaster: **steps/min is the only physical readout**. Level is not, and not every console
    shows both (SM3 shows level and floors/min; SM916 shows steps/min; 8G shows both).
  - Treadmill: pace ↔ km/h is exact, so either can be canonical. A console switched to mph will show
    rounded values.
  - Incline: the "1 %" default has published support only for trained runners at 10.5–18 km/h, and a
    2026 study disputes it.
- **#93 (which ergs' numbers transfer):**
  - Concept2 RowErg/SkiErg: per-stroke drag-factor calibration, and Concept2 asserts cross-machine
    comparability. The strongest case for free-weight-like transfer.
  - Concept2 BikeErg: same physics, but depends on periodic user-confirmed calibration.
  - AssaultBike / Echo: no published formula, calibration or accuracy class. Assault watts and Echo
    watts have no documented relation to each other or to Concept2 watts.
  - Stairmaster level: per model (scale 1–20 vs 1–25), per gym (MAX SPM), per user weight. Behaves
    like a weight stack. Steps/min still depends on step height, which is per model.
  - Treadmill: belt speed differs from set speed by treadmill type and runner mass in lab studies.
    **No gym-fleet evidence was found.** The founding observation (same speed, different heart rate)
    may also include ambient conditions, which this research did not cover.

---

## 9. Unverified claims

Each of these was looked for and not settled from a primary source.

1. **AssaultBike and Echo Bike watts formula.** Neither manufacturer publishes it. Third-party
   calculators give conflicting RPM-to-watts curves (e.g. `0.0022 × RPM^2.5`) with no attribution.
   Whether either bike's watts equal Concept2 watts at the same true power is **unknown**.
2. **Assault vs Echo equivalence.** A Garage Gym Reviews article says Rogue confirmed the Echo
   "counts calories in a very similar fashion" to the AssaultBike. That is secondary, and it does not
   address watts.
3. **Any accuracy class (EN ISO 20957-5) for AssaultBike or Echo Bike.** Not found.
4. **Air bikes drifting with blade wear or air density.** A coaching blog claims an older AssaultBike
   shows the same watts at the same RPM while feeling easier. Not verified.
5. **Concept2 BikeErg and SkiErg calorie formula** being identical to the RowErg's `4·W/1.1639 + 300`.
   Not stated on any Concept2 page found. The PM5 pages say only "based on a 175 pound individual".
6. **Why the BikeErg needs calibration** (no recovery phase in which to measure flywheel decay).
   From forum posts. The BikeErg manual PDF quoting the prompt behaviour returned 404 on fetch.
7. **Concept2 between-unit spread.** Concept2 asserts comparability through drag factor. No
   independent multi-unit study was found; Holt et al. 2021 tested one unit.
8. **Gym treadmill speed error magnitude.** "±5–10 %" and "7.0 mph could be 6.6–7.3" are blog
   claims. No peer-reviewed survey of commercial gym treadmills found. Lab evidence is 98–103 % on
   average.
9. **Treadmill incline accuracy.** No study found.
10. **ISO 20957-6 speed-indication tolerance** for classes A/B/C. Paywalled, not retrieved.
11. **Treadmill pace (min/km) display.** Common, but not confirmed in a primary console manual.
    Incline step size (0.5 %) is also not confirmed.
12. **Decline and high-incline ranges.** Precor TRM 885 "−3 %" is from a dealer, and another dealer
    says "3 degree". Woodway's sheet lists 0–25 % and "(−3 %)–22 %" options whose model is unclear.
13. **Stairmaster level → steps/min table.** None in the manuals retrieved. A blog table
    ("Level 1 ≈ 24, Level 10 ≈ 96, Level 15 ≈ 162 steps/min") uses a 1–15 scale that contradicts the
    manuals.
14. **Stairmaster displayed watts = weight × g × vertical speed.** Physically plausible, not stated.
    The manuals say only that weight feeds calories.
15. **8G step height.** 16 steps per floor implies 8-inch steps, as on the 7000PT, but the 8G manual
    does not state the height.
16. **ACSM metabolic equations' constants** (0.1/1.8 walking, 0.2/0.9 running). Taken from secondary
    reproductions, not from the ACSM book.
17. **Concept2 pace display precision** (tenths of a second). From general knowledge, not quoted.

---

## 10. Sources

Primary (manufacturers):

- Concept2 — [Watts Calculator](https://www.concept2.com/training/watts-calculator),
  [Pace Calculator](https://www.concept2.com/training/pace-calculator),
  [Calorie Calculator](https://www.concept2.com/training/calorie-calculator),
  [PM2/PM2+ how to use](https://www.concept2.com/support/monitors/pm2/how-to-use),
  [PM5 display options](https://www.concept2.com/service/monitors/pm5/how-to-use/using-monitor-display-options),
  [PM5 understanding and changing units](https://www.concept2.nl/en/service/monitors/pm5/how-to-use/understanding-and-changing-units),
  [PM5 viewing drag factor](https://www.concept2.nl/en/service/monitors/pm5/how-to-use/viewing-drag-factor),
  [PM5 101](https://www.concept2.com/blog/pm5-101),
  [What damper setting should I use?](https://www.concept2.com/blog/what-damper-setting-should-i-use),
  [Benefits of cycling: the BikeErg for rowers](https://www.concept2.com/blog/benefits-of-cycling-the-bikeerg-for-rowers),
  [Don't miss a beat of training: BikeErg](https://www.concept2.com/blog/dont-miss-a-beat-of-training-bikeerg).
- Assault Fitness — [AssaultBike Classic owner's manual #23-AS-100-1](https://resources.sport-tiedje.com/pdf/assault/Assualt%20Bike%20Classic%202023%20Manual.pdf)
  (hosted by a retailer).
- Rogue — [Echo Bike user guide](https://fitatmidlife.com/wp-content/uploads/Echo-Bike-User-Guide-FINAL-v2-3-7-19.pdf)
  (hosted by a third party), [Echo Bike product page](https://www.roguefitness.com/rogue-echo-bike).
- StairMaster / Core Health & Fitness —
  [StepMill technical manual](https://support.corehandf.com/Brands/StairMaster/Manuals/637-4243AStairMasterStepMillTechManual.pdf),
  [StepMill 3 owner's manual](https://support.corehandf.com/Brands/Stairmaster/Manuals/SM3_Owners_Manual.pdf),
  [8G owner's manual](https://fitnessengros.dk/media/c8/82/f7/1670237019/Owners%20Manual%20G8.pdf),
  [SM916 owner's manual](https://coloradocardio.com/wp-content/uploads/2019/07/stairmaster_stepmill_sm916_owners_manual.pdf),
  [StepMill 7000PT owner's manual](https://coloradocardio.com/wp-content/uploads/2019/07/stairmaster_stepmill_7000pt_c40_owners_manual.pdf)
  (the last three hosted by retailers).
- Life Fitness — [Integrity treadmill](https://lifefitness.com/en-gb/catalog/cardio/treadmills/integrity-series-treadmill),
  [Integrity C console owner's manual](https://cdn.shopify.com/s/files/1/2781/4920/files/integrity-c-console-owners-manual.pdf?2673).
- Woodway — [4Front spec sheet](https://www.woodway.com/wp-content/uploads/2024/02/4Front-200902-4Front-Spec.pdf).

Primary (standards and literature):

- NIST — [SP 811 Appendix B.9](https://www.nist.gov/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/nist-guide-si-appendix-b9).
- Jones & Doust 1996, [doi:10.1080/02640419608727717](https://doi.org/10.1080/02640419608727717).
- Shahidi et al. 2026, [doi:10.1371/journal.pone.0355988](https://doi.org/10.1371/journal.pone.0355988).
- Willwacher et al. 2021, [doi:10.1038/s41598-021-81951-9](https://doi.org/10.1038/s41598-021-81951-9).
- Tielke, Ahn & Lee 2019, [doi:10.1038/s41598-019-49272-0](https://doi.org/10.1038/s41598-019-49272-0).
- Holt et al. 2021, [doi:10.3389/fphys.2021.758015](https://doi.org/10.3389/fphys.2021.758015).
- ISO 20957-6:2021 — [iTeh catalogue listing](https://standards.iteh.ai/catalog/standards/iso/57a1de11-4b29-44fb-ab50-e52bbe17c2ef/iso-20957-6-2021)
  (abstract and change list only).

Secondary, flagged in text:

- [Concept2 Forum: BikeErg and CTC?](https://www.c2forum.com/viewtopic.php?t=186131) — where the
  Concept2 blog quote was first found.
- [80/20 Endurance: Don't trust your treadmill](https://www.8020endurance.com/dont-trust-your-treadmill/).
- [Garage Gym Reviews: Echo vs Assault](https://www.garagegymreviews.com/rogue-echo-bike-vs-assault-airbike-review).
- Dealer listings for Precor TRM 885 ([Keystone Fitness](https://keystonefitness.ca/product/precor-trm-885-v2-w-p82-console/)).
