# Is there a sound model for the speed that holds a zone over a given duration?

**Date:** 2026-10-17
**Question:** [#102](https://github.com/hermanno3005/Chalk/issues/102) — for a fixed **average**
heart-rate band (a zone), how does the intensity that produces it change with interval duration,
and is there a published, validated model that could draw a **ghost** behind the zone line across
roughly 0:30–20:00 from the two or three durations actually done? Part of map
[#88](https://github.com/hermanno3005/Chalk/issues/88).
**Scope:** Riegel's power law; critical speed/power and its variants; first-order HR kinetics
combined with a linear HR–intensity relation; heart-rate-clamp studies; HR dynamics models; what
each needs, whether 2–3 `(duration, mean intensity)` points in one zone can fit it, and how wrong
it is for one person.
**Status:** findings only. Whether a ghost is drawn is decided in
[#98](https://github.com/hermanno3005/Chalk/issues/98). The zone line itself is
[ADR-0006](https://github.com/hermanno3005/Chalk/blob/spec/endurance-glossary/docs/adr/0006-an-erg-is-read-as-a-zone-line-per-duration-from-your-last-ten-visits.md).
Builds on [`research/endurance-derivation`](https://github.com/hermanno3005/Chalk/blob/research/endurance-derivation/docs/research/endurance-derivation.md)
(cited below as **the derivation research**) and does not repeat it.

**Primary sources** are peer-reviewed exercise physiology (abstracts read via Europe PMC unless
noted; open-access full texts read where marked). Arithmetic that is Chalk's own — combining
published constants into a model nobody published — is labelled **[arithmetic]** so it is never
mistaken for a finding. Claims that could not be traced to a primary source are listed in
**Unverified claims** at the end and marked **UNVERIFIED** where they appear.

## Bottom line

1. **No published, validated model gives the intensity that holds a fixed *average* HR as a
   function of interval duration.** The literature models the two neighbouring questions: how
   fast you can go for a duration when the effort is *maximal* (Riegel, critical speed/power and
   their variants), and how HR moves second by second at a given intensity (HR kinetics). Nothing
   found joins them into a curve for a zone, and nothing has been validated against intervals.
2. **The maximal-effort models do not transfer.** They describe a *ceiling*: the most you can hold
   for a duration, fitted to efforts taken to exhaustion. A zone is not a ceiling. The
   critical-power hyperbola has no finite duration at all for intensities below critical power,
   which is where most zones sit. Riegel's exponent is a fatigue rate taken from world records.
   Fitted through two zone-line points it can be made to pass through them, but that is curve
   drawing, not Riegel.
3. **The physiology gives the curve's direction, not the curve.** For a fixed average, a short
   rep needs a much higher intensity because HR lags (τ ≈ 46–60 s plus a ~13 s delay). A long rep
   needs a slightly lower one because HR keeps climbing (slow component, drift). Heart-rate-clamp
   studies confirm the long end: holding HR constant needs falling power. **[arithmetic]** Put
   together, this gives `I(d) ≈ a + b/d − c·d`: a hyperbola, the critical-power shape, with a
   downward lean at the long end. Its coefficients are not properties of the athlete. `b` depends
   on the HR the rep **started** from, and Chalk does not record that.
4. **The short end of the axis cannot be read from heart rate at all.** **[arithmetic]** A 30-second
   rep's average HR moves only ~1.5 bpm per km/h, a quarter of what a 10-minute rep's does. That
   is below the 3–5 bpm day-to-day noise. The speed it would ask for, 5 to 50 km/h above steady
   depending on τ and starting HR, implies a steady-state HR above HRmax. At 0:30 the zone is set
   by the rest before the rep, not by the speed.
5. **2–3 points cannot fit it.** **[arithmetic]** Even the two-parameter hyperbola is exactly
   determined by two points, so it has no residual to check itself against. Read out from 4- and
   10-minute points, its noise is multiplied about 3× at 0:30 and 1.4× at 1:00, giving
   **±3–5 km/h at 0:30 even from ten-visit means**. Against the model it is also biased by up to
   ±3 km/h there, and it misses drift at 20:00. On a **level** erg no such curve is defined:
   levels are ordered, not measured.

**Verdict: none does.** Any ghost across 0:30–20:00 would be Chalk-side modelling, with
coefficients that are not the athlete's (see §8 for what it would cost in honesty).

---

## 1. What exactly is being asked

The zone line (ADR-0006) is: for one zone on one scope at one incline, the mean intensity of the
entries whose **average HR** fell in that zone, per **duration as typed**, over the last ten
visits. The ghost would read that line out across the whole duration axis.

The quantity is therefore *the intensity `I` such that an interval of length `d` averages an HR
inside band `[h₁, h₂)`*. Three things set an interval's average HR, and the derivation research
§3 covers each:

- **Lag (on-kinetics):** HR approaches its new level with τ ≈ 56–60 s (Hunt et al. 2015).
- **Slow component:** from about minute 5, HR keeps rising at a rate that grows with intensity
  (Teso et al. 2025).
- **Drift:** after ~10 min, HR keeps rising, more so in heat and with dehydration (Coyle &
  González-Alonso 2001; Lafrenz et al. 2008).

A fourth matters here and was not covered there:

- **Starting HR.** Lag pulls the average towards wherever HR was when the rep began: rest, the
  previous rep's recovery, or a warm-up. HIT responses depend on up to nine variables, including
  "relief interval intensity and duration" and the number of repetitions (Buchheit & Laursen
  2013). An interval's average HR is therefore a property of the rep *and of what came before
  it*. Chalk records the rep only.

## 2. Maximal-effort models: Riegel, critical speed/power and their variants

All of these describe the **speed–duration (or power–duration) relationship for maximal
efforts**: the highest intensity that can be held until exhaustion, or for a race distance.

**Riegel / Kennelly power law.**

- *Form.* `t = a·Dᵇ`. Speed then falls as a power of time: `S ∝ t^(1/b − 1)`. It goes back to
  Kennelly (1906) and Riegel (1981), and is algebraically the same power law (Vandewalle 2018,
  full text).
- *Exponents.* Riegel's world-record exponents were **1.08 for elite and 1.06 for senior
  runners**, as quoted by Blythe & Király (2016, full text). The Riegel *formula* "predicts
  performance by fitting c to each runner and fixing α = 1.06" (ibid.). Riegel's own paper was
  not read. Its stated range of validity is **UNVERIFIED**.
- *Individual error.* An individual's exponent differs and correlates with performance above
  800 m (Blythe & Király 2016). In 2,303 recreational runners, Riegel was "well-calibrated for
  races up to a half-marathon, but dramatically underestimated marathon time, giving times at
  least 10 min too fast for half of runners" (Vickers & Vertosick 2016).
- *Fit against hyperbolic models.* Power-law and logarithmic models extrapolated to 30–60 min
  better than the hyperbolic ones (Vandewalle 2018, six elite runners). Drake et al. (2024)
  argue that the power law fits the whole power–duration relationship better, and that the
  hyperbola only approximates it between 2 and 15 min.
- *Transfer to a zone.* None found. The exponent is a rate of *fatigue at maximal effort*.
  Nothing in the literature links it to a fixed-HR band, and its inputs are race or exhaustion
  times, which Chalk cannot recognise (the derivation research §1).

**Critical speed / critical power (2-parameter hyperbola) and variants.**

- *Forms.* `t = W′/(P − CP)`, or its linear form `D = ADC + CS·t` (Vandewalle 2018). Variants:
  - Morton's 3-parameter model, which adds a maximal instantaneous power;
  - the Péronnet–Thibault logarithmic model, anchored at maximal aerobic speed taken as 7 min;
  - Hopkins' exponential model, for 10 s – 3 min.
- *Range.* All are fitted to time-to-exhaustion or race data, conventionally over **3–15 min**
  (Vandewalle 2018) or 2–15 min (Muniz-Pumares et al. 2019). The hyperbola "unrealistically
  represents efforts that are short (< 2 min) or long (> 15 min)" (Drake et al. 2024).
- *Most accurate variant.* Among elite runners Morton's model fitted best, and the 2-parameter
  hyperbolas worst (Vandewalle 2018).
- *Below CP.* For any intensity `P ≤ CP` the model gives no finite duration. CP sits at the
  heavy–severe boundary (Poole et al. 2016). Every zone below threshold — the whole of a
  Friel Z1–Z4, or Coggan L1–L3 — is therefore outside the model's domain.
- *"Submaximal" CS.* Vandewalle (2019) showed theoretically that CS and CP can still be computed
  when efforts fall short of maximal. "Submaximal" there means performances **80–100 %** of
  maximal (95–100 % in two of the three protocols): exhausting efforts done imperfectly, not a
  zone.
- *Use in interval prescription.* The speed–duration hyperbola is used to set HIIT speed by
  *tolerable duration*. Ferguson et al. (2013) ran 4-min bouts at speeds predicted to exhaust at
  4, 6 and 8 min. That is a ceiling again: a speed you can just hold, not a speed that lands an
  HR band.

**Verdict on maximal models.** Ruled out for a zone ghost.

- They model a different quantity: the maximum, not a fixed-HR intensity.
- Their inputs are maximal efforts Chalk cannot recognise.
- The hyperbola is undefined below CP.
- Any of them *can* be forced through two zone-line points, since each has two free parameters.
  The fitted constants then mean nothing physiological (§6).

## 3. What the heart-rate-clamp literature says about the long end

The closest empirical work to "intensity at a fixed HR over time" is **HR-clamp exercise**:
power is adjusted continuously to hold HR at a target, and the power trace is recorded.

- At 77, 86 and 95 % HRpeak, held to exhaustion or 60 min, power output "decreased
  quadratically … relative to the initial value from 10 % to 100 % of Tlim". VO₂ fell with it
  (Gustave et al. 2024, 12 women). The same protocol in 15 men showed "significant decreases in
  power output … across time for each trial" (Mitchinson et al. 2025). Both conclude that a fixed
  HR "cannot consistently be used to prescribe a desired metabolic stimulus".
- In 12 trained males clamped at the HR of LT1 and LT2 for 15 min, power was sampled every 3 min
  (Li et al. 2025). The abstract reports hypoxia's effect, not the normoxic decline.
- **How much power falls per minute at constant HR is UNVERIFIED.** The abstracts give the shape
  (quadratic), not the size, and the full texts are paywalled.
- The mirror image, HR rising at fixed power, is the **HR slow component**:
  - It is present in **all** intensity domains, about twice the size of the VO₂ slow component
    (Teso et al. 2022, postmenopausal women).
  - The predictive equation (Teso et al. 2025, 66 adults, slope fitted from minute 5) is
    `scHR (bpm·min⁻¹) = −0.0514 + 0.0240·%RCP − 0.0172·age − 0.347·sex`, with males = 0 and
    females = 1. Here %RCP is intensity relative to the VO₂ at the respiratory compensation
    point (full text). This settles the derivation research's Unverified #4: the term is a
    percentage.
  - Its error is r² = 0.54 and **SEE = 0.61 bpm·min⁻¹**. In an independent sample, HR was
    predicted to "±4.09 b·min⁻¹".
  - **[arithmetic]** For a 30-year-old man that is ≈ 0.6 bpm/min at 50 % RCP, 1.1 at 70 %,
    1.6 at 90 % and 1.8 at 100 %. The SEE is a third to a whole of those values.
- Even the intensity *designed* to give no HR drift does drift. The physical working capacity at
  the HR threshold (PWC_HRT) is found from the HR-versus-time slopes of four 8-min bouts. Held
  for an hour, HR still rose at 80, 100 and 120 % of it, so the test "overestimated the maximal
  power output associated with steady-state HR" (Perry et al. 2001).

**What this gives the ghost.** The direction at the long end is sound: past ~5–10 min, a fixed
average needs a falling intensity. A rate usable for one person is not available.

- The equation needs %RCP, a lab threshold.
- Its individual error is as large as the effect.
- The clamp studies hold *instantaneous* HR, not an interval's average from a lower start.

## 4. Heart-rate dynamics models

A model that predicts HR second by second from intensity could, in principle, be integrated over
an interval and inverted to find the intensity that lands a target average. The literature has
several:

| Model | Form | Calibration it needs |
|---|---|---|
| First-order (Hunt et al. 2015) | `HR = HR₀ + k·ΔI·(1 − e^(−t/τ))`; τ 56–60 s, individual SD 30–45 s; gain 24 bpm per m/s | Per-person step tests with continuous HR |
| First-order **with dead time** (Hunt & Wang 2024, full text) | τ **47.7 s + 13.1 s delay** (treadmill), 45.9 s + 13.8 s (cycle); gain 25.0 bpm per m/s, 0.40 bpm/W | Same. Best structure found, but fit only ~50–57 % (normalised RMS) |
| Second-order (Wang & Hunt 2023) | Two time constants | Same; better for HR control, tracking error ~2 bpm |
| Nonlinear ODE (Stirling; Zakynthinaki 2015; Mazzoleni 2016; Cheng) | Coupled HR and intensity equations, sigmoid in HR distance to max | "Has to be calibrated to an individual subject by a graded incremental test" (Ludwig et al. 2018, full text) |
| HR-drift correction (Papini et al. 2024) | Five-block model including fitness and age | Proof of concept, 15 subjects; needs instantaneous HR |
| ARX models, kayak (Jasper et al. 2025) | 1st-order, time-varying parameters | Continuous HR, speed or power; RMSE 3.2–15.6 bpm |

Common to all of them:

- They are identified from **continuous HR traces**, not `(duration, mean)` pairs.
- They need **per-person calibration**. Ludwig et al. (2018) state that "HR kinetics are highly
  variable" and that models are "optimized and tested on specific samples".
- Not one predicts an interval's *average* or was validated for it. Using one that way is
  Chalk-side arithmetic.

## 5. The shape this physiology implies — [arithmetic]

This whole section is Chalk-side arithmetic, not a finding. It combines a first-order rise
(τ from Hunt), a linear HR–speed gain `G` ≈ 6.7 bpm per km/h (Hunt 2015) and a linear slow
component `s` bpm/min from minute 5 (Teso 2025):

```
HR(t)   = HR₀ + (HR_ss − HR₀)·(1 − e^(−t/τ)) + s·max(0, t − 5 min)
mean(d) = HR₀ + (HR_ss − HR₀)·f(d) + s·max(0, d − 5)² / (2d)
f(d)    = 1 − (τ/d)·(1 − e^(−d/τ))           — the share of the step an average reaches
```

`HR_ss` is the steady HR the intensity costs, and `HR₀` the HR the rep starts from.

**5.1 How much the average reaches, and how much it cares about speed.** `G·f(d)` is how far
one km/h moves the interval's *average*:

| `d` | 0:30 | 1:00 | 2:00 | 4:00 | 6:00 | 10:00 | 20:00 |
|---|---|---|---|---|---|---|---|
| `f(d)`, τ = 30 s | 0.37 | 0.57 | 0.75 | 0.88 | 0.92 | 0.95 | 0.97 |
| `f(d)`, τ = 58 s | 0.22 | 0.38 | 0.58 | 0.76 | 0.84 | 0.90 | 0.95 |
| `f(d)`, τ = 90 s | 0.15 | 0.27 | 0.45 | 0.65 | 0.75 | 0.85 | 0.93 |
| bpm of average per km/h, τ = 58 s | **1.5** | 2.5 | 3.9 | 5.1 | 5.6 | 6.1 | 6.4 |
| speed one entry pins (1 SD, σ 3–5 bpm) | **±2.0–3.4** | ±1.2–2.0 | ±0.8–1.3 | ±0.6–1.0 | ±0.5–0.9 | ±0.5–0.8 | ±0.5–0.8 |

Below about 2 minutes, an entry's average HR is mostly its starting HR. Day-to-day noise
(3–5 bpm, the derivation research §4) swamps the speed signal.

**5.2 The speed a fixed average needs.** The table gives the km/h above the steady speed for
`HR_ss = 160` needed to make the *average* 160. An asterisk (\*) means the required `HR_ss`
exceeds 190, so it is past HRmax and the linear relation no longer exists.

| Start HR, τ, slow comp. | 0:30 | 1:00 | 2:00 | 4:00 | 6:00 | 10:00 | 20:00 |
|---|---|---|---|---|---|---|---|
| 100, 30 s, 0 | +15\* | +6.8\* | +2.9 | +1.3 | +0.8 | +0.5 | +0.2 |
| 100, 58 s, 0 | +32\* | +15\* | +6.5\* | +2.8 | +1.7 | +1.0 | +0.5 |
| 100, 90 s, 0 | +51\* | +24\* | +11\* | +4.8\* | +2.9 | +1.6 | +0.7 |
| 140, 58 s, 0 | +11\* | +4.9\* | +2.2 | +0.9 | +0.6 | +0.3 | +0.2 |
| 140, 58 s, 1 bpm/min | +11\* | +4.9\* | +2.2 | +0.9 | +0.6 | +0.1 | **−0.7** |
| 140, 58 s, 2 bpm/min | +11\* | +4.9\* | +2.2 | +0.9 | +0.5 | −0.1 | **−1.6** |

- **Shape.** For `d ≫ τ`, `1/f(d) − 1 ≈ τ/d`. For `d ≪ τ` it is ≈ `2τ/d − 1`. With the slow
  component, the curve is approximately **`I(d) ≈ a + b/d − c·d`**:
  - `a` is the steady speed for the zone;
  - `b ≈ (h − HR₀)·τ/G`, roughly doubling below ~1 min;
  - `c ≈ s/(2G)` past 5 min.

  That is the critical-power hyperbola's shape with a lean added. It is a coincidence of the
  arithmetic, not CP: `b` is not W′.
- **`b` is not a constant of the athlete.** It scales with how far below the zone the rep started.
  A first rep from rest and a fourth rep after 60 s of jogging have different `b`. Chalk records
  neither. The zone line already averages over both, invisibly.
- **The left end is undetermined.** At 0:30 the answer spans +5 to +51 km/h across plausible
  starting HRs and τ. Almost every case needs an `HR_ss` past HRmax: the intensity is in the
  severe or sprint domain, where the linear HR–intensity relation (the derivation research §2)
  no longer holds.
- **The right end depends on `s`, which depends on intensity, age and sex.** At 20:00 the sign
  flips between "slightly faster" and "1.6 km/h slower" over Teso's range.

## 6. Can it be fitted from two or three zone-line points? — [arithmetic]

**Identifiability.** The full model has four unknowns (`a`, `b` or `HR₀`, τ, `c`), and `b`
varies by entry. The zone line offers 2–3 points.

- Fixing τ and `G` at group means and ignoring drift leaves `a` and `b`. Two points fit them
  exactly, with zero residual, so the fit can never show it is wrong. A third point gives one
  degree of freedom against noise of ±0.5–1 km/h per point.
- An individual's τ differs from the group's by an SD of 30–45 s (Hunt et al. 2015), about
  50–75 %. Fixing it imports that error.

**Noise amplification of the simplest candidate, `I = a + b/d`.** The table gives the 1 SD at
the read-out duration per bpm of per-point HR noise, each point weighted by its own sensitivity
(§5.1):

| Points done | 0:30 | 1:00 | 2:00 | 4:00 | 6:00 | 10:00 | 20:00 |
|---|---|---|---|---|---|---|---|
| 4 and 10 min | 3.1 | 1.4 | 0.59 | 0.20 | 0.13 | 0.17 | 0.23 |
| 2 and 6 min | 1.6 | 0.70 | 0.26 | 0.15 | 0.18 | 0.22 | 0.26 |
| 1 and 4 min | 0.96 | 0.40 | 0.19 | 0.20 | 0.22 | 0.25 | 0.27 |
| 2, 4 and 6 min | 1.6 | 0.70 | 0.25 | 0.12 | 0.15 | 0.19 | 0.23 |

Multiplied by the noise:

- **One visit per point** (σ 3–5 bpm): from 4- and 10-minute points, the ghost at 0:30 is
  ±9–16 km/h and at 1:00 ±4–7 km/h.
- **Ten-visit means** (σ/√10 ≈ 1–1.6 bpm), which is what the zone line holds: **±3–5 km/h at
  0:30**, ±1.4–2.3 km/h at 1:00, ±0.6–0.9 at 2:00, and ±0.2–0.4 km/h at 20:00.
- **Visit means are not independent.** They also carry each visit's starting-HR mix (§5.2),
  which does not average to anything fixed.

**Bias against the model**, even with noise-free points: hyperbola through 4 and 10 min, starting
HR 140.

- τ 30–90 s, no slow component: the ghost is **1.6–2.8 km/h too slow at 0:30**, because the
  coefficient doubles below τ.
- Slow component 2 bpm/min: it is **2.3 km/h too fast at 0:30** and 1.2 km/h too fast at 20:00.
  The hyperbola has nowhere to put drift.
- A Riegel-style power law `k·dᵉ` through the same points fits exponents of −0.05 to −0.09. That
  is close to Riegel's speed exponent of −0.057 (1/1.06 − 1), which is a coincidence. It reads
  **7–8 km/h too slow at 0:30**, because a power law rises far more gently than `1/d`.

**Brand-free units.**

- Every form above needs an axis on which arithmetic is meaningful. Speed at fixed incline,
  watts and `1/split³` qualify: HR is roughly linear in each, and on them averaging and
  hyperbolas are defined (the derivation research §2).
- An **ordered level** has no such scale. ADR-0006 can average levels and round because a mean
  of whole levels is still a level. A curve through levels would put numbers *between* levels
  that the erg does not speak and whose spacing no source defines.
- No model, sound or not, gives a ghost on a level erg.

## 7. Candidates, ruled in or out

| Candidate | Inputs it needs | Fittable from 2–3 zone points? | Constants Chalk does not hold | Individual error | Verdict |
|---|---|---|---|---|---|
| **Riegel / power law** | Maximal (race) times at ≥ 2 distances | Mechanically yes, as a curve; the exponent then means nothing | Maximal efforts; the individual exponent | Marathon ≥ 10 min too fast for half of recreational runners (Vickers & Vertosick 2016); no zone data at all | **Out:** different quantity |
| **CS/CP hyperbola** (2-par.) | ≥ 2–3 exhaustive efforts, 2–15 min | Mechanically yes; `a` and `b` are not CS or W′ | Maximal efforts; undefined below CP | Protocol-dependent (Muniz-Pumares et al. 2019); unrealistic < 2 and > 15 min (Drake et al. 2024) | **Out:** undefined for sub-threshold zones |
| **Morton 3-par., Péronnet–Thibault, Hopkins** | Maximal efforts; MAS | No: 3 parameters | As above | Best of the asymptotic models for elites (Vandewalle 2018) | **Out** |
| **"Submaximal" CS** (Vandewalle 2019) | Efforts 80–100 % of maximal | Same as CS | Near-maximal efforts | Theoretical study | **Out:** "submaximal" ≠ a zone |
| **HR-clamp findings** (Gustave 2024; Mitchinson 2025) | Continuous HR clamp | No model published | No equation exists | Power decline size **UNVERIFIED** | **Direction only** at the long end |
| **Teso scHR equation** | %RCP, age, sex | n/a, predicts HR not intensity | %RCP (lab) | SEE 0.61 bpm/min; ±4.1 bpm | **Out** for the ghost; confirms the long-end lean |
| **First-order kinetics + linear gain** **[arithmetic]** | τ, gain, start HR, steady speed, slow-component rate | No: 4 unknowns, start HR varies per entry | τ, gain, start HR, `s` | τ SD 30–45 s; fit ~50 % (Hunt & Wang 2024); §6 tables | **Out** as a validated model; it is Chalk's own |
| **HR dynamics ODE / ARX models** | Continuous HR plus a graded calibration test | No | Every parameter | RMSE 3–16 bpm (kayak ARX) | **Out** |
| **PWC_HRT** | Four 8-min bouts with HR slopes | No | HR time series | Overestimates the drift-free power (Perry 2001) | **Out** |

## 8. Verdict

**None does.** No published, validated model gives the intensity that holds a heart-rate zone,
as an interval average, across durations. None can be fitted to two or three
`(duration, mean intensity)` points in one zone without constants Chalk does not hold.

- The maximal-effort models answer a different question.
- The HR models need continuous traces and per-person calibration.
- The arithmetic that joins them depends on the HR each rep started from.

**What a Chalk-side approximation would cost in honesty.** The cheapest candidate is the
two-parameter hyperbola `I = a + b/d` through the zone line's points, read across 0:30–20:00
**[arithmetic]**.

- **Between the shortest and longest durations done**, it is a different way of joining the
  dots. It is no more supported than ADR-0006's straight segments, so it adds a second line
  that says the same thing.
- **Beyond the longest duration**, out to about twice it and below ~10–15 min, its noise stays
  small (±0.2–0.4 km/h from ten-visit means). It misses the slow component, though, and so
  overstates the speed for a long rep by up to ~1–1.5 km/h near threshold at 20:00. This is the
  only stretch where a ghost would be roughly honest, and even there it assumes the
  athlete's drift is small.
- **Below the shortest duration, and especially under 2 min**, it is not guidance. It amplifies
  noise to ±3–5 km/h at 0:30, it is biased by ±2–3 km/h against its own physiology, and it
  points at speeds whose "steady HR" would exceed HRmax. What it draws there is a guess
  presented as a curve.
- **Unlike the strength ghost**, it would not be a published formula applied to the user. It
  would be a model nobody published, with coefficients that are not the user's, drawn as if it
  were theirs.
- **On level ergs** it cannot be drawn at all.

## 9. Hand-offs (not decided here)

- **[#98](https://github.com/hermanno3005/Chalk/issues/98) — presentation:**
  - Whether any ghost is drawn.
  - If one is: whether it is confined to the span done plus a short reach beyond the longest
    duration, and never to the left of the shortest.
  - Whether it is suppressed on level ergs.
- **ADR-0006 — what it already gets right:**
  - Its "a longer entry needs a slower intensity" is supported at the long end by HR-clamp and
    slow-component work (§3).
  - At the short end, the reason is lag, not fatigue.
  - Exact-duration grouping keeps lag equal within a point, as the ADR says. It does **not**
    keep the starting HR equal: a 30-s point mixes first reps and later reps.
- **[#97](https://github.com/hermanno3005/Chalk/issues/97) — logging:**
  - Nothing here argues for recording the starting HR or the recovery.
  - Without it, short-rep points in a zone mostly measure the recovery before them (§5.1).

## Unverified claims

1. **Riegel's own stated range and exponents.** The 1981 paper was not read. 1.06/1.08 are as
   quoted by Blythe & Király (2016), and the equation form as given by Vandewalle (2018).
2. **Size of the power decline under an HR clamp** (watts or % per minute). The abstracts give
   only "significant" and "quadratic" (Gustave et al. 2024; Mitchinson et al. 2025); the full
   texts are paywalled.
3. **Buchheit & Laursen 2013** was read as an abstract only. It is cited only for the list of
   variables that shape HIT responses.
4. **Every [arithmetic] figure** applies group-mean constants (Hunt's τ and gain, Teso's slope)
   to a first-order model with a linear slow component. That model was assembled here and has no
   validation for interval averages.
5. **HR₀ values of 100 and 140 bpm** in §5.2 are illustrative, not measured starting HRs.
6. **The required `HR_ss` > HRmax** flag uses 190 bpm as an illustrative HRmax.
7. **A zone's band width** adds noise within a point, since entries anywhere in the band count.
   It was not quantified here. The zone line carries each point's mean HR, which could in
   principle correct it, but only with a gain `G` Chalk does not hold.

## Sources

Peer-reviewed (abstract read unless noted):

- Blythe DA, Király FJ. Prediction and quantification of individual athletic performance of runners. *PLoS One* 2016;11(6):e0157257 (full text). [doi:10.1371/journal.pone.0157257](https://doi.org/10.1371/journal.pone.0157257)
- Buchheit M, Laursen PB. High-intensity interval training, solutions to the programming puzzle. Part I: cardiopulmonary emphasis. *Sports Med* 2013;43(5):313–38. [doi:10.1007/s40279-013-0029-x](https://doi.org/10.1007/s40279-013-0029-x)
- Coyle EF, González-Alonso J. Cardiovascular drift during prolonged exercise: new perspectives. *Exerc Sport Sci Rev* 2001;29(2):88–92. [PubMed 11337829](https://pubmed.ncbi.nlm.nih.gov/11337829/)
- Drake JP, Finke A, Ferguson RA. Modelling human endurance: power laws vs critical power. *Eur J Appl Physiol* 2024;124(2):507–26. [doi:10.1007/s00421-023-05274-5](https://doi.org/10.1007/s00421-023-05274-5)
- Ferguson C, Wilson J, Birch KM, Kemi OJ. Application of the speed-duration relationship to normalize the intensity of high-intensity interval training. *PLoS One* 2013;8(11):e76420. [doi:10.1371/journal.pone.0076420](https://doi.org/10.1371/journal.pone.0076420)
- Gustave D et al. Metabolic and perceptual responses to constant heart rate exercise at vigorous intensities in women. *Med Sci Sports Exerc* 2024;56(5):917–26. [doi:10.1249/MSS.0000000000003381](https://doi.org/10.1249/MSS.0000000000003381)
- Hunt KJ, Fankhauser SE, Saengsuwan J. Identification of heart rate dynamics during moderate-to-vigorous treadmill exercise. *BioMed Eng OnLine* 2015;14:117. [doi:10.1186/s12938-015-0112-7](https://doi.org/10.1186/s12938-015-0112-7)
- Hunt KJ, Wang H. Identification of heart rate dynamics during treadmill and cycle ergometer exercise: the role of model zeros and dead time. *F1000Research* 2024;13:894 (full text). [doi:10.12688/f1000research.153397.2](https://doi.org/10.12688/f1000research.153397.2)
- Jasper G et al. Modelling heart rate dynamics in relation to speed and power output in sprint kayaking. *Eur J Sport Sci* 2025;25(1):e12185. [doi:10.1002/ejsc.12185](https://doi.org/10.1002/ejsc.12185)
- Lafrenz AJ, Wingo JE, Ganio MS, Cureton KJ. Effect of ambient temperature on cardiovascular drift and maximal oxygen uptake. *Med Sci Sports Exerc* 2008;40(6):1065–71. [doi:10.1249/MSS.0b013e3181666ed7](https://doi.org/10.1249/MSS.0b013e3181666ed7)
- Li SN et al. Systemic hypoxia has a larger effect on reducing the external load at lower exercise intensity during heart rate clamped cycling. *Eur J Sport Sci* 2025;25(1):e12204. [doi:10.1002/ejsc.12204](https://doi.org/10.1002/ejsc.12204)
- Ludwig M, Hoffmann K, Endler S, Asteroth A, Wiemeyer J. Measurement, prediction, and control of individual heart rate responses to exercise — basics and options for wearable devices. *Front Physiol* 2018;9:778 (full text). [doi:10.3389/fphys.2018.00778](https://doi.org/10.3389/fphys.2018.00778)
- Mitchinson CJ et al. Vigorous intensity heart rate-clamp exercise does not elicit recommended oxygen consumption rates. *Eur J Appl Physiol* 2025;125(4):1205–18. [doi:10.1007/s00421-024-05665-2](https://doi.org/10.1007/s00421-024-05665-2)
- Muniz-Pumares D, Karsten B, Triska C, Glaister M. Methodological approaches and related challenges associated with the determination of critical power and curvature constant. *J Strength Cond Res* 2019;33(2):584–96. [PubMed 30531413](https://pubmed.ncbi.nlm.nih.gov/30531413/)
- Papini GB, Bonomi AG, Sartor F. Proof-of-concept model for instantaneous heart rate-drift correction during low and high exercise exertion. *Front Physiol* 2024;15:1358785. [doi:10.3389/fphys.2024.1358785](https://doi.org/10.3389/fphys.2024.1358785)
- Perry SR, Housh TJ, Johnson GO, Ebersole KT, Bull AJ. Heart rate and ratings of perceived exertion at the physical working capacity at the heart rate threshold. *J Strength Cond Res* 2001;15(2):225–9. [PubMed 11710408](https://pubmed.ncbi.nlm.nih.gov/11710408/)
- Poole DC, Burnley M, Vanhatalo A, Rossiter HB, Jones AM. Critical power: an important fatigue threshold in exercise physiology. *Med Sci Sports Exerc* 2016;48(11):2320–34. [doi:10.1249/MSS.0000000000000939](https://doi.org/10.1249/MSS.0000000000000939)
- Teso M, Colosio AL, Pogliaghi S. An intensity-dependent slow component of HR interferes with accurate exercise implementation in postmenopausal women. *Med Sci Sports Exerc* 2022;54(4):655–64. [doi:10.1249/MSS.0000000000002835](https://doi.org/10.1249/MSS.0000000000002835)
- Teso M, Colosio AL, Loi M, Boone J, Pogliaghi S. Predicting heart rate slow component dynamics: a model across exercise intensities, age, and sex. *Sports* 2025;13(2):45 (full text). [doi:10.3390/sports13020045](https://doi.org/10.3390/sports13020045)
- Vandewalle H. Modelling of running performances: comparisons of power-law, hyperbolic, logarithmic, and exponential models in elite endurance runners. *BioMed Res Int* 2018:8203062 (full text). [doi:10.1155/2018/8203062](https://doi.org/10.1155/2018/8203062)
- Vandewalle H. Effects of submaximal performances on critical speed and power: uses of an arbitrary-unit method with different protocols. *Sports* 2019;7(6):136 (full text). [doi:10.3390/sports7060136](https://doi.org/10.3390/sports7060136)
- Vickers AJ, Vertosick EA. An empirical study of race times in recreational endurance runners. *BMC Sports Sci Med Rehabil* 2016;8:26. [doi:10.1186/s13102-016-0052-y](https://doi.org/10.1186/s13102-016-0052-y)
- Wang H, Hunt KJ. Feedback control of heart rate during treadmill exercise based on a two-phase response model. *PLoS One* 2023;18(10):e0292310. [doi:10.1371/journal.pone.0292310](https://doi.org/10.1371/journal.pone.0292310)
- Zakynthinaki MS. Modelling heart rate kinetics. *PLoS One* 2015;10(4):e0118263. [doi:10.1371/journal.pone.0118263](https://doi.org/10.1371/journal.pone.0118263)

Cited, not read: Riegel PS. Athletic records and human endurance. *Am Sci* 1981;69(3):285–90 (via
Blythe & Király 2016 and Vandewalle 2018).

In-repo: [`research/endurance-derivation`](https://github.com/hermanno3005/Chalk/blob/research/endurance-derivation/docs/research/endurance-derivation.md);
[ADR-0006](https://github.com/hermanno3005/Chalk/blob/spec/endurance-glossary/docs/adr/0006-an-erg-is-read-as-a-zone-line-per-duration-from-your-last-ten-visits.md);
map [#88](https://github.com/hermanno3005/Chalk/issues/88).
