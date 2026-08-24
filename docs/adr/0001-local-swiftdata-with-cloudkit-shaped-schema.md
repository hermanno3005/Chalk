# Local-only SwiftData, with a CloudKit-shaped schema

Chalk is sideloaded from Xcode under free provisioning, and CloudKit requires a paid
Apple Developer Program membership — as do iCloud Documents and key-value storage, so
there is no free fallback. v1 therefore ships local-only
(`ModelConfiguration(cloudKitDatabase: .none)`, no iCloud or Push capabilities), but the
schema follows every CloudKit mirroring rule from day one so that enabling sync later is
a capability change plus one line rather than a data-model rewrite.

## Consequences

The rules the model obeys, none of which anything currently enforces:

1. Every attribute is optional or has a default.
2. Every relationship is optional, on both sides.
3. Every relationship declares its inverse explicitly via `@Relationship(inverse:)`.
4. No `@Attribute(.unique)` or `#Unique`. Identity is `var id: UUID = UUID()`, and any
   uniqueness the app wants is enforced in app code.
5. Delete rules are `.cascade` or `.nullify` only. `.deny` is unsupported, so anything
   stricter has to be an app-level guard.

**This is the part a future reader will want to "fix".** The optionality is not
sloppiness and the missing uniqueness constraints are not oversights — tightening them
would work perfectly today and break sync on the day it is switched on. Non-optional
attributes without defaults are rejected by the framework at load time; unique
constraints cannot be added later without a custom deduplicating migration stage.

One claim this rests on is **unverified**: that an already-populated local store
backfills cleanly into a freshly initialised CloudKit schema when sync is turned on.
Core Data's mirroring is designed for it, but no Apple documentation states it, and it
cannot be tested without the paid membership. If it turns out not to hold, durability
needs another answer before much history accumulates.

Full research, including primary sources and an explicit list of unverified claims:
`docs/research/swiftdata-cloudkit.md` on branch `research/swiftdata-cloudkit`.
