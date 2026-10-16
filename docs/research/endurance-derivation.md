# What a handful of intervals' heart rates can soundly tell you

**Date:** 2026-10-16
**Question:** [#91](https://github.com/hermanno3005/Chalk/issues/91) — what can be soundly derived
from a few intervals per machine per visit, each holding **duration, intensity in the erg's unit,
average HR, and optional max HR**, typed by hand? Part of map
[#88](https://github.com/hermanno3005/Chalk/issues/88).
**Scope:** threshold definitions and which are field-estimable; how linear HR is in intensity;
duration, lag and drift; day-to-day noise and how many points a fit needs; HR-zone models and the
reference number each needs; candidate derivations ranked by soundness.
**Status:** findings only. What Chalk derives is decided in
[#95](https://github.com/hermanno3005/Chalk/issues/95); how zones are set in
[#92](https://github.com/hermanno3005/Chalk/issues/92). Nothing here is a decision.

**Primary sources** are peer-reviewed exercise physiology (abstracts read via Europe PMC/PubMed
unless noted) and the coaching authors' own published pages (Friel, Coggan). Arithmetic that is
Chalk's own — applying a published constant to Chalk's numbers — is labelled **[arithmetic]** so it
is never mistaken for a finding. Claims that could not be traced to a primary source are listed
in **Unverified claims** at the end and marked **UNVERIFIED** where they appear.

## Bottom line

1. **No physiological threshold can be estimated from a handful of submaximal intervals' HR.**
   Every threshold is defined by something Chalk does not hold: blood lactate (LT1, LT2, MLSS),
   gas exchange (VT1, VT2), or *maximal* efforts (critical speed/power, FTP, Friel's LTHR test).
   The HR-only shortcut, the Conconi deflection point, fails validation. "Threshold speed" can only
   ever be *a speed looked up at a threshold HR the athlete brings*: Chalk can translate a threshold
   into a machine setting, but it cannot find the threshold.
2. **Translating HR into a setting on one machine is sound, within limits.** Steady-state HR rises
   close to linearly with running speed or erg power across the submaximal range, so interpolating
   `(intensity, HR)` points on one machine to answer "what speed gives 170 here" is defensible —
   **inside the range of intensities already done, on an axis that is linear in metabolic cost
   (speed or watts, not pace per 500 m or a "level"), and never extrapolated toward HRmax.**
3. **An interval's average HR is a biased number; its max HR is the better one.** HR takes about a
   minute (time constant ≈ 56–60 s on a treadmill) to settle after a change. A 6-minute interval
   from an easy start averages roughly 6–11 bpm **below** where it ended **[arithmetic]**. If HR
   rises without spikes, an interval's max HR is roughly its end HR, which is the number the
   literature uses. A floor of **~4 minutes** is where steady state is generally reached in
   moderate work. Near threshold, HR never settles at all: it keeps climbing about 1–2 bpm per
   minute, so intervals of different lengths at the same speed disagree by design.
4. **HR moves 3–5 bpm day to day under controlled conditions, and ~10 bpm more with dehydration
   or heat.** At the measured treadmill slope (~6.7 bpm per km/h **[arithmetic]**), one
   interval pins the speed for a target HR only to about **±0.5–0.75 km/h**. A slope fitted on one
   machine from 2–3 points is 30–50 % uncertain **[arithmetic]**. Points from the same visit share
   that visit's day effect, so the unit that counts is **visits, not intervals**.
5. **Every zone model needs a reference number Chalk cannot derive from submaximal data:**
   HRmax (%HRmax), HRmax + resting HR (%HRR/Karvonen), LTHR (Friel, Coggan), or lab-measured VT1/VT2
   (Seiler's 3-zone). The athlete has to supply it. **LTHR and HR are sport-specific**: Friel
   publishes separate run and bike tables, and cycling HR differs from running HR at max and
   submax. That matters for [#92](https://github.com/hermanno3005/Chalk/issues/92).

---

## 1. Threshold definitions — which are estimable without a lab

The literature divides constant-intensity exercise into three **domains**. The boundaries are the
thresholds:

| Boundary | Names in use | What defines it | Needs |
|---|---|---|---|
| moderate → heavy | LT1, aerobic threshold, VT1, gas-exchange threshold (GET) | First sustained rise of blood lactate above baseline; first ventilatory turnpoint | Lactate sampling or gas analysis during an incremental test |
| heavy → severe | LT2, "anaerobic threshold", OBLA (4 mmol·L⁻¹), MLSS, RCP/VT2, **critical power / critical speed** | Highest intensity at which lactate, VO₂ and the rest can still stabilise | MLSS: several 30-min constant bouts with lactate. CP/CS: 2+ **exhaustive** efforts |

- **Domains.** Below CP, physiological responses "can" be stabilised; above it they "cannot", so CP
  is a "fatigue threshold" (Poole et al. 2016). Steady state comes quickly in the moderate domain,
  late (10–20 min) in the heavy domain, and never in the severe domain, where VO₂ climbs to its
  maximum (Jones et al. 2010; secondary summaries of the same framework).
- **Critical speed/power (CS/CP).** This is the asymptote of the hyperbolic speed-duration
  relationship, `t = W′ / (P − CP)`, fitted to **time-to-exhaustion** efforts (Jones et al. 2010).
  It needs **no HR at all**: only the durations and intensities of maximal efforts. Protocols are
  not standardised. The number, duration and spacing of the trials all change the estimate. The
  conventional range is roughly 2–15 min per effort (Muniz-Pumares et al. 2019). It can be
  computed from best efforts in training logs: Smyth & Muniz-Pumares (2020) did so for >25,000
  runners, using at least three target distances. Those were *best* efforts, not routine ones.
- **MLSS** (maximal lactate steady state) needs repeated 30-minute constant bouts with blood lactate.
  The lactate level at MLSS also differs by exercise mode (rowing ≠ cycling), so "the threshold" is
  task-specific (Beneke 2003).
- **FTP** (functional threshold power, Coggan): "the highest power output a cyclist can maintain in
  a quasi-steady state for approximately 60 min". It is usually estimated as 95 % of a 20-minute
  all-out test. On an individual basis FTP20 and FTP60 "should not be used interchangeably", with
  limits of agreement of about ±40–60 W against the individual anaerobic threshold (Borszcz et al.
  2018). FTP matched LT in trained cyclists but *underestimated* it in recreational ones
  (Valenzuela et al. 2018). Functional threshold *pace* is the running analogue; no primary
  validation was found (**UNVERIFIED**).
- **LTHR** (Friel): "do a 30-minute time trial all by yourself … as if it was a race"; the
  "average heart rate … for the last 20 minutes … is an approximation of your LTHR" (Friel,
  TrainingPeaks). In 27 runners and triathletes the 30-minute time trial's HR did not differ
  significantly from HR at a 4 mmol·L⁻¹ lactate threshold, but the standard error of the
  estimate was **8.0 bpm** (McGehee et al. 2005).
- **HR deflection point (Conconi).** The idea is that HR departs from its linear rise at the
  threshold. Definitions and protocols vary widely, and validity is "uncertain" (Bodner & Rhodes
  2000). In cyclists the updated Conconi test "is not a valid method for assessing LT"
  (Bourgois et al. 2004). It is also an incremental-ramp method, not something intervals produce.

**What this means for Chalk's data.** None of these can come out of a handful of submaximal
`(duration, intensity, avg HR, max HR)` rows:

- the lab thresholds need lactate or gas;
- CS/CP/FTP/LTHR need efforts Chalk cannot recognise as maximal, because a row does not say
  "this was all-out";
- the one HR-only method fails validation.

The two field thresholds closest to reach are:

- **LTHR, from a deliberate 30-min solo time trial.** Logged as one 30-minute interval, its
  average would include the first 10 minutes Friel discards. The athlete would have to log the
  last 20 minutes separately.
- **CS, from 2–3 deliberate all-out efforts of different lengths on the same machine.**

Both are tests the athlete chooses to run. Neither falls out of ordinary training.

## 2. The HR–intensity relationship

- **Linear in the submaximal range.** Within one person, %HRR regresses on %VO₂ reserve with
  slope 1.00 and intercept −0.1 across an incremental cycle test (Swain & Leutholtz 1997, 63
  adults). HR is linear in VO₂, and VO₂ is linear in cycle power. The HR–VO₂ line is the basis of
  submaximal VO₂max prediction, though extrapolating it to max "can deviate up to 20 %" (Achten &
  Jeukendrup 2003).
- **Measured on a treadmill.** In 24 healthy men, HR after speed steps behaved as a first-order
  system with steady-state gain **24.3 bpm per m/s** at moderate intensity and **24.1** at
  vigorous intensity, not significantly different (Hunt et al. 2015). That is **≈ 6.7 bpm per
  km/h** **[arithmetic]**. The same gain at two intensities is what linearity looks like.
  Steps *up* had a higher gain than steps *down* (30.2 vs 23.6 bpm per m/s), so HR at a speed
  depends a little on whether you came from faster or slower.
- **It bends at the top.** HRmax is a ceiling. Coggan's own table notes that in his VO₂max level
  the average HR may not reach its band "due to slowness of heart rate response and/or ceiling
  imposed by maximum heart rate" (Coggan, TrainingPeaks). Linearity holds in the submaximal range
  and should not be extrapolated toward HRmax.
- **Linear in what?** HR is linear in *metabolic cost*, so the intensity axis has to be linear in
  metabolic cost too:
  - **Treadmill speed** — running cost is linear in speed. Treadmill VO₂ against velocity was
    "highly linear (r > 0.99)" at every grade from 2.9 to 5.0 m/s (Jones & Doust 1996). The
    ACSM equation, `VO₂ = 0.2·v + 0.9·v·grade + 3.5`, is a secondary source and overestimates in
    athletes. It makes **incline a second axis**: grade multiplies speed, so points at different
    inclines do not sit on one line. Jones & Doust's separate line per grade shows the same thing.
  - **Erg watts** — fine as they are.
  - **Rower and SkiErg pace per 500 m** — not linear. Concept2's formula is
    `watts = 2.80 / pace³`, with pace in seconds per metre, so HR is close to linear in watts and
    strongly curved in split. A fit against split is wrong by construction; convert to watts
    first.
  - **Stairmaster "level" or AssaultBike RPM** — the same caution applies. A level is whatever
    the manufacturer defined, and air-resistance power rises steeply with RPM (**UNVERIFIED** for
    the specific machines; [#90](https://github.com/hermanno3005/Chalk/issues/90)).
- **Why per machine.** Displayed treadmill speed can differ from real belt speed by about 5 %
  across 2–15 km/h, often running fast. That figure comes from Leuchte et al. (2001), cited in a
  university report rather than read in the original (**UNVERIFIED**). A treadmill also needs
  about 1 % grade to match the energy cost of level outdoor running at 2.9–5.0 m/s (Jones & Doust
  1996), so treadmill and outdoor speeds are not the same scale. Heat raises HR at a given
  workload (§4), and gyms differ in temperature. A per-machine relationship therefore absorbs the
  machine's calibration, the gym's climate and the grade convention in one go. That suits Chalk's
  question, which is *what do I set here*, but it is not a pure property of the machine.

**Verdict on "a per-machine linear fit through a few `(intensity, HR)` points".** It is
**defensible for interpolation**, on a metabolically linear axis, from steady (or
duration-matched) intervals, at constant incline. It is **not defensible for extrapolation**,
especially upward, where HR flattens and the heavy and severe domains stop HR from settling.
How many points it needs is §4.

## 3. Duration, lag and drift

Three separate effects push an interval's HR away from "the HR this speed costs":

**3.1 Lag (on-kinetics).** After a speed change, HR approaches its new level with a time constant
of **≈ 56–60 s**: 55.7 s moderate, 59.5 s vigorous, individual SDs of 30–45 s (Hunt et al. 2015).
Steady state in submaximal exercise generally takes "at least 3–4 min", and the analysis
convention is the average HR "over the last 30–60 s" (Buchheit 2014, citing Cerretelli & Di
Prampero 1971). An interval's **average** therefore understates its steady state. The table
assumes a first-order rise **[arithmetic]**; "rise" is how far HR must climb from where the
interval started.

| Duration | τ = 30 s, rise 70 | τ = 58 s, rise 35 | τ = 58 s, rise 70 | τ = 90 s, rise 70 |
|---|---|---|---|---|
| 3 min | −12 bpm | −11 bpm | −22 bpm | −30 bpm |
| 4 min | −9 | −8 | −17 | −24 |
| 6 min | −6 | −6 | −11 | −17 |
| 10 min | −4 | −3 | −7 | −11 |
| 20 min | −2 | −2 | −3 | −5 |

The bias is large, it varies with the athlete's own τ, and it depends on how warmed up you were.
That makes it **not a constant you can subtract**. It is also the mechanism behind Seiler's
observation that HR time-in-zone *underestimates* high-intensity interval work compared with
session RPE (Seiler & Tønnessen 2009).

**3.2 Slow component (heavy domain and above).** In constant-load bouts HR keeps rising after
minute 5 by an amount that "increases with intensity". Teso et al. (2025) measured 66 people over
6 × 9-min bouts and give a predictive equation: about **0.0240 bpm/min per % of RCP intensity**,
minus age and sex terms. At 100 % of RCP for a 30-year-old man that is ≈ **1.8 bpm per minute**
**[arithmetic]**. The unit of the intensity term is **UNVERIFIED**; percent of RCP is assumed. So
two intervals at the same threshold-ish speed, one 6 min and one 12 min, will log different HRs
for physiological reasons, not noise.

**3.3 Cardiovascular drift (prolonged work).** HR rises progressively while stroke volume falls,
beginning "after approximately 10 min" of moderate exercise (Wingo et al. 2012; Coyle &
González-Alonso 2001). In 10 trained men at ~59 % VO₂max, HR rose **11 %** between minutes 15 and
45 at 35 °C against **2 %** at 22 °C (Lafrenz et al. 2008). Drift is graded with dehydration (§4).
Drift is mostly a >10-minute effect. For typical erg intervals of 3–10 minutes, lag and the slow
component dominate.

**Minimum useful duration.** The primary sources support:

- **≥ 3–4 min** before any interval's HR reflects a steady state, in moderate work.
- **≈ 4–6 min** if the *average* is used, and even then the table shows a residual bias of 5–10 bpm.
- **No duration** gives a true steady state at or above threshold. Only the heavy domain settles,
  and that takes 10–20 min.

Rather than a single floor, a derivation could only compare intervals of **similar duration**
near threshold.

**Does max HR help?** Yes, under conditions:

- If HR rises monotonically through an interval, its max is its end HR. That is the quantity the
  literature measures, and it is nearly free of lag after ~4 min (residual < 1 bpm at τ = 58 s
  **[arithmetic]**).
- It still carries the slow component, so it grows with duration near threshold.
- It is a single sample, so one sensor spike or a sprint finish corrupts it. Optical wrist sensors
  may spike more on rowing and SkiErg grips (**UNVERIFIED**).
- The **highest max HR ever logged** is a sound **lower bound on HRmax**, in the same way a
  rep-max is a proven floor. It equals HRmax only if some interval was genuinely maximal.

## 4. Day-to-day noise, and how many points a fit needs

**Measured noise at a fixed submaximal workload:**

| Source | Conditions | Variation |
|---|---|---|
| Lamberts et al. 2004 | 44 runners, same time of day, 5 consecutive days, ~90 % HRmax stage | 5 ± 2 bpm; CV **1.1–1.4 %** |
| Lamberts & Lambert 2009 | 38 subjects, 4 days, 61–98 % HRmax | Falls as intensity rises; lowest **3 ± 1 bpm** at 85–90 % HRmax |
| Buchheit 2014, Table 1 | Review figure for exercise HR | Typical error **~3 %**; smallest worthwhile change ~1 % |

Achten & Jeukendrup (2003) summarise it as "a small day-to-day variability in HR", adding that
"dehydration and ambient temperature can have a profound effect".

**Systematic shifts larger than the noise:**

- **Hydration.** At 65 % VO₂peak in 21 °C, HR was **+10 bpm** at 0.9 % body-mass hypohydration
  and **+18 bpm** at 2.8 % (Heaps et al. 1994). Over 2 h in heat, HR rise was linear with
  dehydration, r = 0.99 (Montain & Coyle 1992).
- **Heat.** Drift over 30 minutes: +11 % at 35 °C vs +2 % at 22 °C (Lafrenz et al. 2008).
- **Training.** Exercise HR changes measurably "within a week" of starting endurance training
  (Buchheit 2014). Old points go stale.
- **Caffeine.** Only a meta-analysis of caffeine *plus* nitrates was found. It showed no HR effect
  over caffeine alone, which says nothing about caffeine against nothing. The effect of caffeine
  alone on submaximal exercise HR is **UNVERIFIED**.

**What that means for a fit [arithmetic]**, at ~6.7 bpm per km/h (Hunt et al. 2015) and
per-point noise σ = 3–5 bpm:

- **One interval** at a speed pins "the speed that gives HR h" to about σ / slope =
  **±0.45–0.75 km/h** (1 SD). That is 3–5 % at 15 km/h, the same size as a treadmill's
  calibration error. Small differences between machines are at the edge of what single points can
  see. The "very different" gym-to-gym effect the user reports is presumably larger.
- **Averaging n independent points** at similar speeds shrinks that by √n. Four points halve it.
- **A slope fitted on one machine is weak:**

  | Points on one machine | Spread | Slope uncertainty (1 SD) |
  |---|---|---|
  | 2–3 | 2 km/h | 30–50 % |
  | 4 | 3 km/h | 20–33 % |
  | 8 | 4 km/h | 12–20 % |

  Predicting near the middle of the points needs little slope precision. Predicting toward the
  edges needs a lot.
- **Independence is the catch.** Intervals from the same visit share that day's hydration, heat
  and fatigue, so the day-to-day component does **not** average down within a visit. It averages
  down across **visits**. Conversely, a slope taken *within* one visit is protected from that
  day's offset, because every point in it carries the same offset.
- Hunt's gain is a group mean from untrained men; an individual's slope differs.

## 5. HR-zone models and the reference each needs

| Model | Reference number(s) | Bands | Notes |
|---|---|---|---|
| **%HRmax** | HRmax | Seiler & Tønnessen's simplified Norwegian Olympic scale: Z1 55–75, Z2 75–85, Z3 85–90, Z4 90–95, Z5 95–100 % | The scale "does not account for individual variation" between HR and lactate, nor for activity (Seiler & Tønnessen 2009) |
| **%HRR (Karvonen)** | HRmax **and** resting HR | Target = HRrest + p·(HRmax − HRrest) (Karvonen et al. 1957; formula from standard usage, original not read) | %HRR tracks %VO₂ *reserve* with slope 1.00, not %VO₂max (Swain & Leutholtz 1997). ACSM's moderate/vigorous %HRR bands are **UNVERIFIED** (paywalled) |
| **%LTHR — Friel, run** | LTHR (30-min TT) | Z1 < 85, Z2 85–89, Z3 90–94, Z4 95–99, Z5a 100–102, Z5b 103–106, Z5c > 106 % | Friel: thresholds and zones differ for bike and run |
| **%LTHR — Friel, bike** | LTHR (bike) | Z1 < 81, Z2 81–89, Z3 90–93, Z4 94–99, Z5a 100–102, Z5b 103–106, Z5c > 106 % | |
| **Coggan levels** (HR column) | Threshold HR, alongside FTP | L1 < 68, L2 69–83, L3 84–94, L4 95–105, L5 > 106 %; L6–7 have no HR band | Coggan: translating power zones to HR is "somewhat difficult" given HR variability and individual differences |
| **Seiler 3-zone** | VT1 and VT2 (or LT1/LT2) | Z1 < VT1; Z2 VT1–VT2; Z3 > VT2 | Physiologically anchored, but **lab-only**. Seiler's 5-zone Z3 maps onto 3-zone Z2 |

**Where the reference numbers come from:**

- **HRmax, predicted.** `208 − 0.7 × age` (Tanaka et al. 2001, a meta-analysis of 18,712
  subjects). It describes groups well. Its individual error, an SEE of ~10 bpm, comes from a
  secondary citation (**UNVERIFIED** at source). Friel: do not use 220 − age, "as this is as
  likely to be wrong as right".
- **HRmax, measured.** An all-out effort. Chalk's highest logged max HR is a floor on it (§3).
- **Resting HR.** From the watch. Chalk does not hold it.
- **LTHR.** From Friel's 30-min solo time trial, with an SEE of ~8 bpm against lab LT (McGehee
  et al. 2005).
- **VT1 and VT2.** From a lab gas-exchange test.

**Two cross-cutting facts for [#92](https://github.com/hermanno3005/Chalk/issues/92):**

- **Fixed-percentage anchors give uneven strain between people.** At a fixed 60 % and 75 %
  VO₂max, blood lactate varied with a CV of 52 % and 41 % (Scharhag-Rosenberger et al. 2010).
  Anchoring to a threshold is expected to reduce that (Mann et al. 2013; abstract only).
  %HRmax and %HRR are both fixed-percentage anchors.
- **HR is sport-specific.** "Heart rate is different between the two activities [cycling and
  running] both for maximal and submaximal intensities" (Millet et al. 2009). Friel publishes
  separate LTHRs and tables for bike and run, and the MLSS lactate level differs by mode
  (Beneke 2003).
  - One LTHR or HRmax applied across treadmill, bike erg, rower and SkiErg is a simplification
    the literature does not support.
  - The direction and size of the gap between modes, for example rowing against running, was not
    established here (**UNVERIFIED**).

## 6. Candidate derivations, ranked by soundness

The test for every candidate: can it be computed from **duration, intensity, avg HR and optional
max HR**, per machine, from a few points per visit, without lying? Ranked best first. None is a
recommendation.

1. **Nearest-record lookup, no model.** For a target HR on this machine, show the logged
   interval or intervals whose HR is closest, with their intensity, duration and date.
   - This is the endurance counterpart of a rep-max: it states only what you have done.
   - It needs one point, and every point in it is a real one.
   - Weaknesses: it cannot answer a target HR no interval came near; it inherits each point's lag
     bias (§3), so it is best on max HR or duration-matched rows; and noisy days show through.
2. **Per-machine interpolation of HR on intensity.** Fit a line through this machine's points and
   invert it at the target HR, **only inside the observed range**.
   - Requirements: points ≥ 3–4 min long, on a metabolically linear axis (§2), at one incline,
     and recent ones weighted more.
   - Sound when there are ≥ 2 distinct intensities over ≥ 2 visits. Uncertainty is ±0.5–0.75
     km/h per point, shrinking with visits (§4).
   - Prefer max HR (≈ end HR) to average HR wherever max HR is present.
   - Weaknesses: the per-machine slope stays noisy for a long time, and near threshold the
     duration dependence (§3.2) means mixing 4-minute and 12-minute intervals adds bias, not noise.
3. **A personal slope shared across machines, with a per-machine offset.** Estimate the HR-per-unit
   slope from all machines of one erg type, and let each machine contribute only its level.
   - The slope is mostly a property of the athlete's physiology (Hunt et al.).
   - A gym's heat and a treadmill's calibration act mostly as a shift: a ~5 % speed-scale error
     changes the slope by only ~5 % **[arithmetic]**.
   - So one point on a new machine yields an answer, which fits the "a few per visit" reality.
   - Weakness: this is Chalk-side modelling. No source validates it as a method, and it does
     **not** transfer across erg types (§5).
4. **"Threshold speed" = candidate 2 or 3 evaluated at an athlete-supplied threshold HR.** Use the
   LTHR from a setting, or from a zone model's boundary.
   - It is exactly as sound as the fit plus the reference. Friel's test carries an ~8 bpm SEE,
     about ±1.2 km/h on its own **[arithmetic]**.
   - The question is asked precisely where HR does not settle (§3.2), so the answer is only
     meaningful for a stated interval length.
   - This is the only way the word *threshold* can be honest in Chalk: the threshold comes from
     the athlete, and Chalk translates it to the machine.
5. **"Best intensity held for ≥ d minutes" envelope.** A monotonic, rep-max-like floor per
   machine, using no HR at all.
   - Sound as a *proven floor*.
   - It would only approximate a speed-duration curve, and so critical speed, if the logged
     efforts were maximal. Chalk cannot know they were. Fitting CS to sub-maximal rows
     underestimates it without any warning.
6. **Inferring LTHR from logged intervals.** Treat a long hard interval as Friel's test.
   - It needs the athlete to have done the test properly: solo, all-out, 30 min, last 20 min
     only, which Chalk cannot see.
   - A whole 30-minute row's average includes the 10 minutes Friel discards.
   - Weak unless the athlete logs it deliberately and says so.
7. **Unsound for an individual:** HRmax from an age formula (§5); threshold from an HR deflection
   (§1); VO₂max or fitness from the HR–VO₂ line (deviations up to 20 %, Achten & Jeukendrup 2003);
   and any extrapolation of the HR–intensity line toward HRmax.

**Side-finding for the map's fog line, "Am I getting fitter?".** The same speed at a lower HR is
exactly the exercise-HR marker the monitoring literature uses (Buchheit 2014). Its noise (~3 %)
is about three times its smallest worthwhile change (~1 %). It is real but only readable across
many visits, which is a trend, not a lookup.

## 7. Hand-offs (not decided here)

- **[#95](https://github.com/hermanno3005/Chalk/issues/95) — derivation:**
  - Which rank to adopt.
  - Whether max HR becomes the preferred field.
  - Whether a minimum duration or a duration match is enforced.
  - Whether old points decay.
  - Whether the answer is shown with its uncertainty.
- **[#92](https://github.com/hermanno3005/Chalk/issues/92) — zones:**
  - Whether the setting is HRmax, HRmax + resting HR, or LTHR.
  - Whether it is **per erg type** rather than one number.
  - Whether Chalk may seed HRmax from the highest logged max HR, knowing that is a floor.
- **[#90](https://github.com/hermanno3005/Chalk/issues/90) / [#94](https://github.com/hermanno3005/Chalk/issues/94)
  — units and intensity:**
  - Any fit needs an axis linear in metabolic cost: speed for a treadmill, watts for the ergs,
    not split per 500 m.
  - Treadmill incline enters cost multiplied by speed, so differing inclines cannot share one
    line.
- **[#93](https://github.com/hermanno3005/Chalk/issues/93) — transfer between gyms:**
  - Treadmill speed carries calibration error of about 5 % (**UNVERIFIED**).
  - Every machine also carries the gym's temperature.
  - Whether ergs that compute watts from a flywheel transfer better was not established
    (**UNVERIFIED**).
- **[#97](https://github.com/hermanno3005/Chalk/issues/97) — logging:**
  - Max HR is the more informative of the two HR fields, not the less.
  - A 2–3-minute interval's HR says little about a steady state.
- **[#100](https://github.com/hermanno3005/Chalk/issues/100) — storage:** every candidate above is
  computable at read time from raw rows, consistent with
  [ADR-0002](../adr/0002-rep-maxes-are-derived-never-stored.md)'s pattern; none needs a stored
  derived value.

## Unverified claims

1. **Treadmill calibration error ≈ 5 %**, displayed against actual belt speed (Leuchte, Faber &
   Speer 2001). Seen only as cited in a Hottenrott report hosted by a treadmill manufacturer; the
   original was not read.
2. **Tanaka HRmax SEE ≈ 10 bpm.** From a secondary review; the Tanaka abstract gives the equation
   and r = −0.90, not the SEE.
3. **ACSM %HRR / %HRmax intensity bands** (e.g. moderate 40–59 % HRR). Garber et al. 2011 is
   paywalled and the table was not read. Deliberately omitted from §5.
4. **Unit of the intensity term in Teso et al. 2025's slow-component equation.** Assumed to be
   percent of RCP, which yields ≈ 1.8 bpm/min at RCP.
5. **Functional threshold pace** as a validated running analogue of FTP. No primary validation
   found.
6. **Caffeine's effect on submaximal exercise HR** alone. Only a caffeine-plus-nitrate
   meta-analysis was found.
7. **Size and direction of HR differences between erg types** (rower, SkiErg and AssaultBike
   against treadmill). Only cycling against running is sourced (Millet et al. 2009), and only for
   "is different".
8. **Optical wrist HR spiking more on grip-heavy ergs**, which would make max HR unreliable there.
   Plausible, not researched.
9. **Air-braked erg power scaling** (AssaultBike RPM, Stairmaster levels) and whether flywheel
   watts transfer between gyms better than treadmill speed. Not researched; belongs to #90 and #93.
10. **Mann et al. 2013's conclusions** beyond the abstract, which is truncated at the claim that
    threshold anchoring "would be expected" to reduce variation.
11. **Buchheit 2014's Table 1 figures** (HRex typical error ~3 %, smallest worthwhile change ~1 %).
    Read from the Frontiers full text through a summarising fetch, not verbatim.
12. **Every [arithmetic] figure** applies a single group-mean constant (Hunt's gain, τ ≈ 58 s) to
    a first-order model. The athlete's own constants will differ.

## Sources

Peer-reviewed (abstract read unless noted):

- Achten J, Jeukendrup AE. Heart rate monitoring: applications and limitations. *Sports Med* 2003;33(7):517–38. [doi:10.2165/00007256-200333070-00004](https://doi.org/10.2165/00007256-200333070-00004)
- Beneke R. Maximal lactate steady state concentration (MLSS): experimental and modelling approaches. *Eur J Appl Physiol* 2003;88:361–9. [doi:10.1007/s00421-002-0713-2](https://doi.org/10.1007/s00421-002-0713-2)
- Bodner ME, Rhodes EC. A review of the concept of the heart rate deflection point. *Sports Med* 2000;30(1):31–46. [PubMed 10907756](https://pubmed.ncbi.nlm.nih.gov/10907756/)
- Borszcz FK et al. Functional threshold power in cyclists: validity of the concept and physiological responses. *Int J Sports Med* 2018;39(10):737–42. [doi:10.1055/s-0044-101546](https://doi.org/10.1055/s-0044-101546)
- Bourgois J et al. Validity of the heart rate deflection point as a predictor of lactate threshold concepts during cycling. *J Strength Cond Res* 2004;18(3):498–503. [PubMed 15320666](https://pubmed.ncbi.nlm.nih.gov/15320666/)
- Buchheit M. Monitoring training status with HR measures: do all roads lead to Rome? *Front Physiol* 2014;5:73 (full text, partly). [doi:10.3389/fphys.2014.00073](https://doi.org/10.3389/fphys.2014.00073)
- Coyle EF, González-Alonso J. Cardiovascular drift during prolonged exercise: new perspectives. *Exerc Sport Sci Rev* 2001;29(2):88–92. [PubMed 11337829](https://pubmed.ncbi.nlm.nih.gov/11337829/)
- Heaps CL, González-Alonso J, Coyle EF. Hypohydration causes cardiovascular drift without reducing blood volume. *Int J Sports Med* 1994;15(2):74–9. [doi:10.1055/s-2007-1021023](https://doi.org/10.1055/s-2007-1021023)
- Hunt KJ, Fankhauser SE, Saengsuwan J. Identification of heart rate dynamics during moderate-to-vigorous treadmill exercise. *BioMed Eng OnLine* 2015;14:117. [doi:10.1186/s12938-015-0112-7](https://doi.org/10.1186/s12938-015-0112-7)
- Jones AM, Doust JH. A 1% treadmill grade most accurately reflects the energetic cost of outdoor running. *J Sports Sci* 1996;14(4):321–7. [doi:10.1080/02640419608727717](https://doi.org/10.1080/02640419608727717)
- Jones AM, Vanhatalo A, Burnley M, Morton RH, Poole DC. Critical power: implications for determination of VO₂max and exercise tolerance. *Med Sci Sports Exerc* 2010;42(10):1876–90. [doi:10.1249/MSS.0b013e3181d9cf7f](https://doi.org/10.1249/MSS.0b013e3181d9cf7f)
- Karvonen MJ, Kentala E, Mustala O. The effects of training on heart rate; a longitudinal study. *Ann Med Exp Biol Fenn* 1957;35(3):307–15. [PubMed 13470504](https://pubmed.ncbi.nlm.nih.gov/13470504/) (no abstract; cited for the method's origin only)
- Lafrenz AJ, Wingo JE, Ganio MS, Cureton KJ. Effect of ambient temperature on cardiovascular drift and maximal oxygen uptake. *Med Sci Sports Exerc* 2008;40(6):1065–71. [doi:10.1249/MSS.0b013e3181666ed7](https://doi.org/10.1249/MSS.0b013e3181666ed7)
- Lamberts RP, Lemmink KA, Durandt JJ, Lambert MI. Variation in heart rate during submaximal exercise: implications for monitoring training. *J Strength Cond Res* 2004;18(3):641–5. [PubMed 15320683](https://pubmed.ncbi.nlm.nih.gov/15320683/)
- Lamberts RP, Lambert MI. Day-to-day variation in heart rate at different levels of submaximal exertion: implications for monitoring training. *J Strength Cond Res* 2009;23(3):1005–10. [doi:10.1519/JSC.0b013e3181a2dcdc](https://doi.org/10.1519/JSC.0b013e3181a2dcdc)
- Mann T, Lamberts RP, Lambert MI. Methods of prescribing relative exercise intensity: physiological and practical considerations. *Sports Med* 2013;43(7):613–25. [PubMed 23620244](https://pubmed.ncbi.nlm.nih.gov/23620244/)
- McGehee JC, Tanner CJ, Houmard JA. A comparison of methods for estimating the lactate threshold. *J Strength Cond Res* 2005;19(3):553–8. [PubMed 16095403](https://pubmed.ncbi.nlm.nih.gov/16095403/)
- Millet GP, Vleck VE, Bentley DJ. Physiological differences between cycling and running: lessons from triathletes. *Sports Med* 2009;39(3):179–206. [doi:10.2165/00007256-200939030-00002](https://doi.org/10.2165/00007256-200939030-00002)
- Montain SJ, Coyle EF. Influence of graded dehydration on hyperthermia and cardiovascular drift during exercise. *J Appl Physiol* 1992;73(4):1340–50. [doi:10.1152/jappl.1992.73.4.1340](https://doi.org/10.1152/jappl.1992.73.4.1340)
- Muniz-Pumares D, Karsten B, Triska C, Glaister M. Methodological approaches and related challenges associated with the determination of critical power and curvature constant. *J Strength Cond Res* 2019;33(2):584–96. [PubMed 30531413](https://pubmed.ncbi.nlm.nih.gov/30531413/)
- Poole DC, Burnley M, Vanhatalo A, Rossiter HB, Jones AM. Critical power: an important fatigue threshold in exercise physiology. *Med Sci Sports Exerc* 2016;48(11):2320–34. [doi:10.1249/MSS.0000000000000939](https://doi.org/10.1249/MSS.0000000000000939)
- Scharhag-Rosenberger F et al. Exercise at given percentages of VO₂max: heterogeneous metabolic responses between individuals. *J Sci Med Sport* 2010;13(1):74–9. [doi:10.1016/j.jsams.2008.12.626](https://doi.org/10.1016/j.jsams.2008.12.626)
- Seiler S, Tønnessen E. Intervals, thresholds, and long slow distance: the role of intensity and duration in endurance training. *Sportscience* 2009;13:32–53 (full text). [sportsci.org/2009/ss.htm](https://sportsci.org/2009/ss.htm)
- Smyth B, Muniz-Pumares D. Calculation of critical speed from raw training data in recreational marathon runners. *Med Sci Sports Exerc* 2020;52(12):2637–45. [PMC7664951](https://pmc.ncbi.nlm.nih.gov/articles/PMC7664951/)
- Swain DP, Leutholtz BC. Heart rate reserve is equivalent to %VO₂ reserve, not to %VO₂max. *Med Sci Sports Exerc* 1997;29(3):410–4. [doi:10.1097/00005768-199703000-00018](https://doi.org/10.1097/00005768-199703000-00018)
- Tanaka H, Monahan KD, Seals DR. Age-predicted maximal heart rate revisited. *J Am Coll Cardiol* 2001;37(1):153–6. [doi:10.1016/S0735-1097(00)01054-8](https://doi.org/10.1016/S0735-1097(00)01054-8)
- Teso M, Colosio AL, Loi M, Boone J, Pogliaghi S. Predicting heart rate slow component dynamics: a model across exercise intensities, age, and sex. *Sports* 2025;13(2):45. [doi:10.3390/sports13020045](https://doi.org/10.3390/sports13020045)
- Valenzuela PL et al. Is the functional threshold power a valid surrogate of the lactate threshold? *Int J Sports Physiol Perform* 2018;13(10):1293–8. [doi:10.1123/ijspp.2018-0008](https://doi.org/10.1123/ijspp.2018-0008)
- Wingo JE, Ganio MS, Cureton KJ. Cardiovascular drift during heat stress: implications for exercise prescription. *Exerc Sport Sci Rev* 2012;40(2):88–94. [doi:10.1097/JES.0b013e31824c43af](https://doi.org/10.1097/JES.0b013e31824c43af)

Coaching references (the authors' own published pages):

- Friel J. *Joe Friel's Quick Guide to Setting Zones.* TrainingPeaks. [link](https://www.trainingpeaks.com/learn/articles/joe-friel-s-quick-guide-to-setting-zones/)
- Coggan A. *Power Training Levels.* TrainingPeaks. [link](https://www.trainingpeaks.com/learn/articles/power-training-levels/)

Manufacturer:

- Concept2. *Watts calculator* (`watts = 2.80 / pace³`). [link](https://www.concept2.com/training/watts-calculator)

Secondary, flagged in text:

- Hottenrott K. Treadmill-speed investigation report, hosted by h/p/cosmos. [PDF](https://www.hpcosmos.com/sites/default/files/uploads/documents/hottenrott_report_investigation_treadmill_speed_0509.pdf), cited only for Leuchte et al. 2001.
- ACSM running equation, via course handouts and Hippokratia 2013 ([PubMed 24376318](https://pubmed.ncbi.nlm.nih.gov/24376318/)).

In-repo: `CONTEXT.md`; [ADR-0002](../adr/0002-rep-maxes-are-derived-never-stored.md); map
[#88](https://github.com/hermanno3005/Chalk/issues/88).
