# Units are rewritten, never converted for display

Chalk gains two app-wide scales, a **weight unit** (kg or lb) and a **distance unit**
(km or miles, so a speed erg reads km/h with min/km or mph with min/mile). They are
independent of each other and both are chosen on the one onboarding screen. Every stored
weight and speed is a plain number on the scale currently chosen. No entry records the unit
it was typed in, and nothing converts at read time. Changing a scale once there are entries
is one of two explicit acts on Settings, never a silent switch. **Relabel** keeps every
number and changes only the scale, which repairs a wrong pick at onboarding. **Convert**
rewrites every number onto the new scale, goals included, rounded to a fine grid (0.5 kg,
1 lb, 0.1 km/h or mph), which is what moving to a gym on the other scale asks for. Convert
is one-way, and a backup is how you take it back
([ADR-0010](0010-chalk-makes-and-restores-backups.md)).

**This is the part a future reader will want to "fix"**, by storing kg and converting for
display, or by storing each entry's unit beside it so the switch is lossless. Either one
puts a conversion factor inside every `max()` and every mean that ADR-0002 and ADR-0006
derive, which turns *converts nothing* (SPEC §13.2) into *converts everywhere*.
`225 lb` is `102.058… kg`, so the exact 2.5 kg grid that §3 relies on for equality no longer
holds for any derived number. Rewriting on an explicit act keeps the derivation pure and
puts the rounding in one place, at a moment you chose.

## Considered options

- **A single *switch units* action.** Rejected. A wrong pick and a move between countries
  need opposite operations, and a switch that guessed which one you meant would sooner or
  later corrupt data in one direction or the other.
- **Relabel only.** Rejected. You could not move gyms without starting your numbers again.
- **Convert only.** Rejected. A wrong pick discovered after three weeks of logging would turn
  `185` lb into `408` lb.
- **Coupling weight and distance into one *metric/imperial* choice.** Rejected. Lifting in
  kg and running in miles is ordinary, for example in the UK.
- **A per-machine weight unit**, for lb-labelled stacks in a kg gym. Not taken for now. A
  gym-bound machine's numbers never leave it, so this would need no conversion either, and
  it can be added later without undoing anything here.

## Consequences

- **A convert can move a derived number by a hair.** A `best[n]`, a goal's reached state or
  the entry flagged in a history sheet may shift by one grid step. That follows from the
  derivation and needs no repair, exactly as an edited entry does.
- **The stepper grid follows the weight unit**: 2.5 kg, or 5 lb. The plate set used by a
  plate breakdown follows it too.
- **The erg's Unit is untouched.** It stays the *kind* of number an erg speaks. The distance
  unit only says which scale a speed is on, and watts, splits and levels have no scale to
  change.
