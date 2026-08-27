# Branch Lifecycle

What a branch means in this repo, and when it stops existing.

A branch is **work in flight**. It is not an archive. Once its work reaches `main`, the branch name carries nothing the PR list doesn't carry better, so it goes away.

## Merged branches are deleted

`delete_branch_on_merge` is enabled on the repository, so GitHub deletes the head branch the moment its PR merges. Nothing is lost: the commits are in `main`'s history, the PR page records what the branch was for, and GitHub's *Restore branch* button stays available indefinitely.

Never keep a merged branch around "in case". If you find one, delete it.

## Unmerged branches must resolve

A branch whose work will never reach `main` — a spike, a probe, an abandoned approach — is not allowed to sit on the remote indefinitely. Resolve it one of three ways:

- **Land it**, if the work is still good.
- **Delete it**, if the finding it produced is durable somewhere else (an issue thread, a doc) and the code itself is dead.
- **Archive it as a tag**, if the code still has value to run but doesn't belong on `main`.

## Prototypes land as docs plus a tag

Prototype branches are the standing case for the third option, and they split in two:

- **The reasoning lands on `main`** under `docs/prototypes/<name>/` — the README with the verdict, and the variant screenshots. This is what `SPEC.md` cites.
- **The runnable Swift source stays at a tag**, `prototype-<name>`, pointing at the branch tip as it stood when the prototype concluded.

The source does not land on `main`. Prototype code roots the app at a `…PrototypeRoot` view instead of the real `LibraryView`, and its variant files sit inside the app target, so merging it would both hijack the app's entry point and force throwaway code to compile against shipping code forever.

Current archive tags: `prototype-log-entry-modal`, `prototype-exercise-detail`, `prototype-exercise-library`.

## Citations must be reachable from `main`

This is the rule the split above exists to satisfy, and it generalises.

**A document on `main` may not cite something a checkout of `main` cannot reach.** Not a branch name, not a working directory, not "see the other branch". Cite a repo-relative path, an issue URL, or a tag.

Branch names are the trap, because they look durable and aren't — the citation silently rots the moment the branch is deleted. [Issue #35](https://github.com/hermanno3005/Chalk/issues/35) was exactly this: ADR-0001 cited research that only existed on `research/swiftdata-cloudkit`. The fix was to move the research to `docs/research/` and cite the path.

When you delete a branch, grep the repo for its name first.
