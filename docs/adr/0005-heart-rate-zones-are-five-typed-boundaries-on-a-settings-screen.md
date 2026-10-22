# Heart-rate zones are five typed boundaries, on Chalk's one Settings screen

Endurance names a target effort by heart-rate zone, so Chalk holds one set of zones, shared
by every erg. It holds them as **four whole-bpm numbers you type** — the lower bounds of Z2
to Z5, strictly rising, each between 40 and 230 — and nothing else. Chalk owns no zone model
and computes no boundary: you work the numbers out yourself, from your watch's data or a
lactate test. They live on a **Settings screen**, Chalk's first, reached from the home
screen's overflow in both halves, and for now it holds the zones and nothing else.

## Considered options

- **A reference number with Chalk's percentages** — HRmax, HRmax plus resting HR, or LTHR —
  was rejected. Every reference is one Chalk cannot derive from submaximal intervals, so you
  would type a number either way, and Chalk would also have to pick a model and own its
  bands. Typing the boundaries keeps Chalk and the source you trust saying the same thing.
  Seeding HRmax from your highest logged peak heart rate was rejected with it: a peak is a
  floor on HRmax, not a measurement of it.
- **COROS's six-zone model, or a count you choose**, was rejected for a fixed five. A count
  that can change means Z4 stops meaning Z4, and every feature that names a zone has to
  survive a renumbering. Five is the conventional model, and COROS's six can be worked down
  to it by hand.
- **One set per erg type** was deferred, not rejected. Heart rate is sport-specific, but the
  lookup is already per machine, so the setting it returns is right whatever the label says;
  only what "Z2" means on a rower shifts. Per-modality sets would be a later effort.
- **Zones as endurance data on a sheet of their own**, keeping v1's "no Settings screen", was
  rejected in favour of an app-wide screen, so zones sit where a setting is looked for.

## Consequences

- v1's "no Settings screen" (SPEC §2, §11, ADR-0001) is withdrawn. What it guarded is not:
  there is still no export, import or share sheet, and Settings carries none of them. Each
  further setting is its own decision, never a row added in passing.
  _Amended 2026-10-22:_ three such decisions have since been made. Settings also holds the
  weight and distance units ([ADR-0009](0009-units-are-rewritten-never-converted-for-display.md)),
  the plate-breakdown switch, and backup and restore
  ([ADR-0010](0010-chalk-makes-and-restores-backups.md)).
- Zones are read live. No entry stores a zone, nothing caches a boundary, and moving one
  recomputes everything on the next read — nothing migrates.
- Zones are held per device, beside the store rather than in it (ADR-0008), so *one set*
  is one set across every erg on this device; once sync exists, a second device starts gated.
- Zones are edited, never cleared, and a save needs all four numbers. Before the first save,
  logging works as normal and only the lookup is gated, by a row that opens Settings.
