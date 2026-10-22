# Chalk makes and restores backups

This reverses the *no export and no import* line in ADR-0001 and SPEC §2. Chalk is now built
so that the paid developer account is the only thing between it and the App Store, and the
old durability story does not survive that. Xcode's Download Container is unavailable to
anyone who did not build the app, and possibly to you as well on the day you switch to a
paid team. An app installed under a different team ID may not install over the existing one,
which would leave *delete and reinstall* as the way forward, the one act §2 forbids because
it takes the history with it. Sync cannot help there either, because it is switched on under
the new team, after the reinstall. The claim about installing over is **unverified**, and it
cannot be tested without the membership.

So Chalk gains a **backup**: one readable file holding every entry, exercise, erg, group, gym,
machine and goal, the heart-rate zones and both units. It is made from Settings whenever you
choose, and shared through the share sheet. A **restore** loads one in place of everything,
always a replace and never a merge. Over a library that is not empty, it first states what
will be lost and how old the backup is. Onboarding offers *Restore from a backup* beside the
unit pickers, so the team-switch day takes one tap.

## Considered options

- **Merge on restore.** Rejected. It needs identity across files, a rule for two goals on one
  scope, gyms that differ only by name, and backups on different units. Restoring last week's
  backup after a convert you regret would then leave half your numbers in kg and half in lb.
  On a single-device app, nothing is ever really in two places to need merging.
- **An automatic backup before every restore.** Rejected. Chalk keeps no files of its own,
  and one that appears unasked is exactly that. The confirmation, with its counts and the
  backup's date, is what guards against restoring a stale file.
- **CSV export only.** Rejected for now. It cannot restore, so it cannot carry history across
  a reinstall. It can be added later as a second format.
- **Waiting for sync.** Rejected, for the team-switch reason above.

## Consequences

- **ADR-0001's readability rule now has two readers.** No encrypted store and no opaque
  `Transformable` still serve the Download Container, and the backup file is readable by eye
  for the same reason.
- **The backup must round-trip exactly**, every number byte for byte. Its test is the same
  shape as the schema migration tests: a fixed library goes out to a file and comes back
  identical.
- **Before the team switch, make a backup.** This is the standing rule that replaces *pull a
  container before anything irreversible*, and it applies to a convert too.
