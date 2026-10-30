# Chalk's store listing

Everything App Store Connect asks for to put Chalk on the App Store, written ahead of time for
the day the paid developer account exists (SPEC §15.6,
[Draft the store listing: screenshots and copy](https://github.com/hermanno3005/Chalk/issues/169)).
Copy each field across as it stands. The lengths are App Store Connect's limits.

## App information

| Field | Value |
|---|---|
| Name | Chalk: Rep Max & Erg Log |
| Subtitle | What to load. What to set. |
| Primary category | Health & Fitness |
| Secondary category | none |
| Content rights | Contains no third-party content |
| Age rating | 4+: every age-rating question answered *None* or *No* |
| Privacy policy URL | https://hermann-aust.com/chalk/privacy |
| Support URL | https://hermann-aust.com/chalk/support |
| Marketing URL | none |
| Copyright | 2026 Hermann Aust |
| Price | Free |

### Name: 24 of 30 characters

```
Chalk: Rep Max & Erg Log
```

*Chalk* alone is likely taken on the App Store, and names are unique across it. The rest of
the name says what is in it to someone who has never heard of Chalk, and it is also where
search weighs words most. If *Chalk* turns out to be free, the plain name is better.

### Subtitle: 26 of 30 characters

```
What to load. What to set.
```

### Promotional text: 149 of 170 characters

Shown above the description, and changeable at any time without a new version.

```
Log a lift as reps × weight, or an interval with the heart rate it cost you. Chalk tells you what to load at the rack and what to set on the machine.
```

### Description: 1,887 of 4,000 characters

```
Chalk is a training record for the plan you already follow. Your plan says 8 reps with 2 in reserve, or six minutes in Zone 4. Chalk tells you the weight to load on the bar, or the speed to set on the treadmill.

STRENGTH
Log what you lifted as plain reps × weight. No sets, no sessions, no routines: one entry is one lift. From every entry Chalk works out your rep-maxes, the heaviest weight you have proven at each rep count from 1 to 12, and draws them as one curve. Five reps at 100 kg proves 100 kg at 1 to 4 reps too, so the curve fills in by itself. Behind it, a faint projection shows the headroom you haven't tested yet.

ENDURANCE
For treadmills, rowers, bikes and any other indoor erg. Log each interval with its duration, what you held, and the average and peak heart rate your watch showed. Type in your own heart-rate zones once, and Chalk draws a line for each zone: what you have held at every duration you have done, averaged over your last ten visits. Six minutes in Zone 4 at 1 % incline? Chalk tells you the speed.

EVERY GYM IS ITS OWN
A barbell is the same everywhere, but a chest press or a treadmill isn't. Mark a machine as gym-bound, and its numbers stay with that machine at that gym. When you meet one you haven't used, Chalk shows your numbers from a sibling, clearly marked as a hint.

GOALS
Name one number per exercise or erg, like 92.5 kg for 5 reps, and Chalk shows how far you have to go. Reach it, and you will feel it when you save.

YOURS, AND ONLY YOURS
No account, no sign-up, no analytics, no ads. Your training stays on your iPhone. Make a backup whenever you like: one readable file you keep wherever you choose, and restore exactly.

ALSO
• Kilograms or pounds, km/h or mph
• Find any exercise or erg from Spotlight, or ask Siri for your rep-maxes
• Dark mode, Dynamic Type and VoiceOver, with the curve and zone lines playable as audio graphs
```

### Keywords: 100 of 100 bytes

Comma-separated with no spaces. Search already covers words in the name and subtitle, and
plurals and the category, so none of those are repeated.

```
1rm,strength,lifting,gym,workout,tracker,weightlifting,treadmill,rower,heart rate,zones,pace,barbell
```

## Screenshots

Taken by `scripts/screenshots`, which restores a believable half-year library into the
simulator and shoots each screen. Both halves are shown, in light mode at 9:41 with a full
battery. Upload them in this order:

1. `1-library`: the strength library, with Bench Press on the resume card.
2. `2-bench-press`: Bench Press's curve, ghost and goal.
3. `3-endurance`: the endurance library.
4. `4-treadmill`: the treadmill's Z4 line against its goal.

| Display size in App Store Connect | Folder | Pixels | Simulator |
|---|---|---|---|
| iPhone, Dynamic Island (medium), required | `screenshots/medium/` | 1206 × 2622 | iPhone 18 Pro |
| iPhone, Dynamic Island (large) | `screenshots/large/` | 1320 × 2868 | iPhone 18 Pro Max |

App Store Connect needs the medium set, and also either the large Dynamic Island set or a large
Face ID set. Both sets here cover that, and every smaller iPhone is scaled from them.
The files are JPEG because the simulator's PNGs carry an alpha channel, which App Store Connect
refuses. Chalk is iPhone only, so no iPad set is needed.

Retake them after any change to a screen they show. The library counts back from the day it is
restored, so a retake still logged Bench Press *today*.

## App Privacy

**Data collection: No, we do not collect data from this app.** No question follows. This matches
the privacy manifest
([Ship a privacy manifest](https://github.com/hermanno3005/Chalk/issues/150)): nothing leaves
the phone except a backup you share yourself, which is not collection.

## App Review

| Field | Value |
|---|---|
| Sign-in required | No |
| Notes | Chalk has no account and no network. On first launch, pick units and Continue. To see a full library quickly, add an exercise from the search field and log a few entries. |
| Contact | Hermann's name, phone and email, filled in on the day |

## Still to do on the day

- Check the name is free, and fall back to the plain *Chalk* if it is.
- `MARKETING_VERSION` is `0.1`. Raise it to the version the store should show, probably `1.0`,
  before the first upload.
- *Export compliance*: Chalk uses no encryption beyond what iOS provides, so add
  `ITSAppUsesNonExemptEncryption = NO` to the target's Info, or answer *None of the algorithms
  mentioned above* when App Store Connect asks.
- From April 2027, an app built with the iOS 27.1 SDK or later also needs *iPhone Duo*
  screenshots. Chalk builds with the iOS 26.5 SDK, so this applies only once Xcode moves on.
