# SwiftData + CloudKit for Chalk

**Date:** 2026-08-13
**Scope:** SwiftData/CloudKit modelling constraints, project setup, free-vs-paid provisioning, versioned migration, and operational pitfalls, researched against Apple primary sources.
**Status:** a snapshot as of that date, kept as the evidence behind
[ADR-0001](../adr/0001-local-swiftdata-with-cloudkit-shaped-schema.md). It is not binding and it
pre-dates `CONTEXT.md`'s glossary and `SPEC.md`'s schema, so its sketches use placeholder model
names (`ExerciseRecord`, `WorkoutSet`) rather than Chalk's entities, and §6.2 suggests more than
the ADR adopted. **Where this document and ADR-0001 differ, the ADR governs.**

## Bottom line

**CloudKit does not work with a free Apple ID / Xcode "Personal Team". It requires a paid Apple Developer Program membership.** Apple's [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) reference lists `iCloud: CloudKit`, `iCloud: iCloud documents`, `iCloud: iCloud key-value storage` and `Push notifications` as available to **ADP** (paid) and **ADEP** (paid enterprise) only — the free "Apple Developer" column is blank for all four. (`Background modes` *is* available free, but it is useless here without the iCloud and push entitlements.) Apple's own CloudKit setup docs say the same in prose: "Before you proceed, verify that your **Apple Developer Program membership is active** and has admin permissions" ([Enabling CloudKit in Your App](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app)), and the SwiftData sync article repeats it: "The iCloud capability requires an active Apple Developer account with admin permissions" ([Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)). **Practical consequence for Chalk v1:** ship a local-only SwiftData store (`ModelConfiguration(cloudKitDatabase: .none)`, no iCloud/Push capabilities in the target), but **design the schema to CloudKit's rules from day one** — every attribute optional or defaulted, every relationship optional with a declared inverse, no `@Attribute(.unique)` / `#Unique`, no `.deny` delete rules. Flipping to CloudKit later is then a capability + one-line configuration change, not a data model rewrite.

---

## 1. SwiftData modelling features unavailable or constrained under CloudKit

SwiftData does not implement sync itself: "SwiftData uses the [`NSPersistentCloudKitContainer`] class from Core Data to handle CloudKit synchronization" ([Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)). So every Core Data + CloudKit constraint applies transitively, and the Core Data docs are the more complete statement of them.

### 1.1 The two authoritative constraint tables

Apple's SwiftData table ([Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)), verbatim:

| SwiftData macro | CloudKit schema limitation |
|---|---|
| `@Attribute` | "The framework synchronizes changes concurrently and at opportune times, which means CloudKit is unable to enforce the `unique` property option." |
| `@Relationship` | "The iCloud servers don't guarantee atomic processing of relationship changes, so CloudKit requires all relationships to be optional. SwiftData automatically sets the inverse of a relationship if it can reliably infer that inverse from your schema. Otherwise, explicitly set the inverse before saving because CloudKit processes changes in an indeterminate order. The framework doesn't immediately synchronize changes, meaning CloudKit is unable to support the `deny` delete rule." |

Apple's Core Data table ([Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)), verbatim:

| Core Data model element | CloudKit schema limitation |
|---|---|
| Entities | "Unique constraints aren't supported." |
| Attributes | "`Undefined` and [`objectID`] attribute types aren't supported." |
| Relationships | "All relationships must be optional. Due to operation size limitations, CloudKit may not save relationship changes atomically. All relationships must have an inverse, in case the records synchronize out of order. CloudKit doesn't support the Deny deletion rule." |
| Configurations | "Entities in a configuration must not have relationships to entities in another configuration." |

### 1.2 Feature-by-feature

**`@Attribute(.unique)` and `#Unique` — not supported.**
Both tables above are explicit. The stated reason is the asynchronous, non-transactional nature of sync: uniqueness would have to be enforced across devices that are writing independently and merging later, and CloudKit offers no cross-device constraint primitive. In the local-only case, SwiftData implements `.unique` as an *upsert*: "If a trip already exists with that name, then the persistent back end will update to the latest values. This is called an upsert" ([Model your schema with SwiftData, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10195/)). There is no server-side equivalent, so the option is simply unavailable when the store is CloudKit-backed. `#Unique` ([documentation](https://developer.apple.com/documentation/swiftdata/unique(_:))) is the same mechanism expressed as a macro; Apple's `#Unique` page does not itself carry a CloudKit warning, but the constraint it produces is the same entity-level unique constraint the Core Data table declares unsupported. *(Uncertainty flagged: I did not find a page that names `#Unique` and CloudKit in the same sentence. The inference is from the Core Data "Unique constraints aren't supported" row plus `#Unique`'s stated purpose — "the key-paths that SwiftData uses to enforce the uniqueness of model instances".)*

**Non-optional attributes without default values — not supported.**
Apple's published documentation tables do **not** state this, but the framework enforces it at container-initialisation time with the error `CloudKit integration requires that all attributes be optional, or have a default value set`. The valid forms are therefore `var x: T?` or `var x: T = <default>`. **Source is secondary:** an Apple Frameworks Engineer's reply on the [Apple Developer Forums thread 739351](https://developer.apple.com/forums/thread/739351) confirms both fixes (`var timestamp: Date?` or `var timestamp: Date = Date()`) and that the stock Xcode template model fails once CloudKit is enabled. I could not verify this rule against developer.apple.com/documentation; treat the forum post plus the framework's own error string as the evidence. The underlying reason is the same as for relationships: a `CKRecord` field may be absent (never written, or not yet synced), so materialising a record into a model object must always have a value to fall back on.

**Relationships — must be optional, must have an inverse, no `.deny`.**
Directly stated in both tables. The *why* is the record-level, non-atomic mapping. From [Using Core Data with CloudKit (WWDC19, session 202)](https://developer.apple.com/videos/play/wwdc2019/202/): a to-one relationship is stored as a plain UUID field on the related record ("The UUID of the related record in CloudKit will always be stored on the object it's linked to"), and Apple deliberately avoided `CKReference` because "it's limited to 750 total objects". Many-to-many relationships are materialised as a synthetic join record — "a CDMR or Core Data Mirrored Relationship". Because those records travel independently and may arrive out of order or in separate batches, a device can legitimately hold a record whose counterpart has not arrived yet — hence *optional*. `.deny` is unsupportable because the check would have to run against an object graph the local device may not fully have, and the change is not synchronised immediately. Cascade and nullify are not called out as unsupported; the WWDC23 session even names "specifying the delete rules on my relationships" as a lightweight-migration-eligible change. *(Uncertainty flagged: Apple documents `.deny` as unsupported by exclusion; it does not publish an explicit "cascade is supported" statement. Cascade is used in Apple's own CloudKit-mirroring sample material, and only `.deny` is listed as unsupported, so cascade/nullify are the supported set by elimination.)*

**`@Attribute(.allowsCloudEncryption)` — supported, but one-way and new-attributes-only.**
The SwiftData option is documented only as "Stores the property's value in an encrypted form" ([`allowsCloudEncryption`](https://developer.apple.com/documentation/swiftdata/schema/attribute/option/allowscloudencryption)). The substantive rules are on the Core Data property it maps to, [`NSAttributeDescription.allowsCloudEncryption`](https://developer.apple.com/documentation/coredata/nsattributedescription/allowscloudencryption): "Only use this property with new attributes. Core Data doesn't support encrypting attributes that already exist in your CloudKit schema, or attributes that represent relationships between entities." And, marked Important: "Attributes can't change their encryption state after you promote them to your production CloudKit schema. If you choose to encrypt an attribute, it always remains that way." Encrypted fields also can't be queried/indexed server-side in the usual way — *that* I did not verify against a primary page, so treat it as unverified.

**Attribute types.**
Core Data's table rules out `Undefined` and `objectID` attribute types. Transformable attributes are *not* listed as unsupported — and Apple demonstrated "optional Transformable attributes with Cloud Encryption enabled" in [Build apps that share data through CloudKit and Core Data (WWDC21)](https://developer.apple.com/videos/play/wwdc2021/10015/). For SwiftData enums and `Codable` structs stored as attributes, **I found no primary Apple statement about CloudKit compatibility.** Practically they become composite/opaque attributes in the generated schema; they must still be optional or defaulted. Do not treat this paragraph as verified.

**Large values are handled for you.**
Not a constraint, but load-bearing for schema design: Core Data implements "asset externalization" — a variable-length attribute gets a companion `CD_<name>_ckAsset` field, and "if one of them grows to be very large, approximately larger than 750 kilobytes, or if the total size of the record exceeds CloudKit's maximum 1 megabyte limit, you'll begin to see asset fields" ([WWDC19 202](https://developer.apple.com/videos/play/wwdc2019/202/)).

**Configurations.** If Chalk ever splits into local and synced stores, entities in one configuration must not have relationships to entities in another ([Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)).

---

## 2. Container, entitlement and capability setup

Apple's SwiftData article states the requirement plainly: "SwiftData requires two separate capabilities to perform automatic iCloud sync: the iCloud capability, which lets you configure CloudKit, and the Background Modes capability, which lets your app receive remote notifications from CloudKit" ([Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)).

### 2.1 Xcode steps (from [Enabling CloudKit in Your App](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app) and [Setting up Core Data with CloudKit](https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit))

1. Signing & Capabilities → tick **Automatically manage signing**, set the development team, confirm the bundle identifier (it determines the container name).
2. **+ Capability → iCloud.**
3. Tick the **CloudKit** checkbox. Per Apple: "In addition to adding the CloudKit capability to your app, this selection also creates an iCloud container and **adds the Push Notifications capability**." So you do not add Push Notifications by hand.
4. Tick the box next to the container. "The name of the container is your app's bundle identifier prefixed with 'iCloud.'" — i.e. `iCloud.com.example.Chalk`. Note: "Once you've created a container, you can't delete or rename it."
5. **+ Capability → Background Modes**, tick **Remote notifications**. Apple: "For CloudKit to silently notify your app when new content is available, without presenting a user notification such as an alert, sound, or badge, you need to enable the Remote notifications Background Mode."
6. Xcode then "checks that your development team supports the Push Notification and iCloud capabilities, then registers your app's bundle identifier and manages provisioning profiles" — this is exactly the check that fails for a Personal Team (see §3).

### 2.2 What `cloudKitDatabase:` does

From [`ModelConfiguration.CloudKitDatabase`](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct):

- `.automatic` — "Enables managed CloudKit sync using the primary ubiquity container from the app's entitlements." This is the default behaviour: "By default, SwiftData inspects your app's `Entitlements.plist` file to determine which CloudKit container to use, and selects the first identifier it finds in that file."
- `.private("iCloud.x")` — "Enables managed CloudKit sync using the specified ubiquity container." Use when the app has multiple containers. Apple warns: "For apps already using a production CloudKit schema, specify only containers that SwiftData or Core Data have managed previously. All other CloudKit containers are incompatible."
- `.none` — "Disables managed CloudKit sync." Apple: "Specifying `none` overrides any automatically discovered identifiers and disables SwiftData's automatic iCloud sync."

Note the naming: only the **private** database is addressable this way. SwiftData's managed sync mirrors to the CloudKit *private* database — `NSPersistentCloudKitContainer` is documented as "a container that encapsulates the Core Data stack in your app, and **mirrors select persistent stores to a CloudKit private database**" ([docs](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)). Fine for Chalk, which is single-user by design.

### 2.3 Minimal app setup sketch

```swift
import SwiftUI
import SwiftData

@main
struct ChalkApp: App {
    let modelContainer: ModelContainer

    init() {
        // v1 (free provisioning): local only.
        let config = ModelConfiguration(cloudKitDatabase: .none)

        // Later, once a paid membership + iCloud/CloudKit + Background Modes
        // (Remote notifications) capabilities exist, this becomes:
        //   let config = ModelConfiguration(cloudKitDatabase: .automatic)
        // or, to pin the container explicitly:
        //   let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.example.Chalk"))

        do {
            modelContainer = try ModelContainer(
                for: Exercise.self, ExerciseRecord.self,
                configurations: config
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(modelContainer)
    }
}
```

### 2.4 Development-schema initialisation (only relevant once CloudKit is on)

CloudKit's schema is not created from the Swift model automatically for production; you must push a development schema and then promote it. Apple's recommended SwiftData recipe drops to Core Data to do it, verbatim from [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices):

```swift
let config = ModelConfiguration()

do {
#if DEBUG
    // Use an autorelease pool to make sure Swift deallocates the persistent
    // container before setting up the SwiftData stack.
    try autoreleasepool {
        let desc = NSPersistentStoreDescription(url: config.url)
        let opts = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.example.Trips")
        desc.cloudKitContainerOptions = opts
        desc.shouldAddStoreAsynchronously = false
        if let mom = NSManagedObjectModel.makeManagedObjectModel(for: [Trip.self, Accommodation.self]) {
            let container = NSPersistentCloudKitContainer(name: "Trips", managedObjectModel: mom)
            container.persistentStoreDescriptions = [desc]
            container.loadPersistentStores { _, err in
                if let err { fatalError(err.localizedDescription) }
            }
            try container.initializeCloudKitSchema()
            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }
#endif
    modelContainer = try ModelContainer(for: Trip.self, Accommodation.self, configurations: config)
} catch {
    fatalError(error.localizedDescription)
}
```

Apple's notes on this: load the store synchronously so it finishes before schema init; "Unload the persistent store before creating an instance of [`ModelContainer`] to avoid both frameworks attempting to sync data to CloudKit"; and wrap in `#if DEBUG` so it never runs in production.

---

## 3. DECISIVE: free Apple ID / Personal Team vs paid membership

### 3.1 The primary evidence

Apple's [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) page opens with: *"The capabilities available to an iOS provisioning profile depend on your program membership."* Its column legend is:

- **ADP:** "Apple Developer Program membership. Members of this paid program can distribute apps on the App Store."
- **ADEP:** "Apple Developer Enterprise Program membership. Members of this paid program can distribute apps to employees within an organization."
- **Apple Developer:** "Apple Account holders who have agreed to the Apple Developer Agreement to access certain resources on the Apple Developer website. **No cost is associated with this agreement** and developers can't distribute apps."

The relevant rows of that table (read from the page's HTML — the free column cells are empty, i.e. no checkmark):

| Capability | ADP | ADEP | Apple Developer (free) |
|---|---|---|---|
| iCloud: CloudKit | ✔ | ✔ | — |
| iCloud: iCloud documents | ✔ | ✔ | — |
| iCloud: iCloud key-value storage | ✔ | ✔ | — |
| Push notifications | ✔ | ✔ | — |
| Background modes | ✔ | ✔ | ✔ |

For context, the capabilities the free tier *does* get are: App groups, Background modes, Data protection, HealthKit, HomeKit, Inter-App Audio, Keychain sharing, Maps, Wireless Accessory Configuration. Everything else on that page is paid-only.

This **confirms** the historical detail in the brief. All three iCloud capabilities are paid-only — so **iCloud Documents and iCloud key-value store do *not* differ**; they are equally unavailable to a free account. The only free-tier iCloud-adjacent thing is `Background modes`, which on its own does nothing for sync.

Apple's prose docs agree independently:
- [Enabling CloudKit in Your App](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app): "Before you proceed, verify that your **Apple Developer Program membership is active** and has admin permissions."
- [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices): "**Important.** The iCloud capability requires an active Apple Developer account with admin permissions."
- [Adding capabilities to your app](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app): "The platform, and whether you're a member of the Apple Developer Program, may limit the capabilities available to your app," and links to exactly the Supported capabilities table above.

### 3.2 Free provisioning, for the record

[Choosing a Membership](https://developer.apple.com/support/compare-memberships/) confirms a free Apple Account gets Xcode, Xcode betas, **on-device testing**, forums, Feedback Assistant and OS betas; the paid program adds "advanced app capabilities and services" plus distribution. The free on-device testing limits it states: at most 10 App IDs at a time, each expiring after 7 days; at most 3 test devices per platform; provisioning profiles expire after 7 days. That matches the "sideload from Xcode, re-sign weekly" workflow Chalk is planning — that part is fine. It's specifically the *capabilities* that are gated.

### 3.3 What actually happens if you try

Per [Setting up Core Data with CloudKit](https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit), when you tick the CloudKit checkbox, "Xcode checks that your development team supports the Push Notification and iCloud capabilities, then registers your app's bundle identifier and manages provisioning profiles." With a Personal Team that check fails: Xcode cannot register an App ID carrying the `com.apple.developer.icloud-services` / `aps-environment` entitlements, so automatic signing cannot produce a valid profile and the build fails at the signing/provisioning step — before your code runs. **This specific failure mode is an inference** from the capability table plus that sentence; I did not find an Apple page that spells out the exact Xcode error text for a Personal Team + CloudKit. Community reports describe a signing/provisioning error rather than a silent no-op, which is consistent, but I'm labelling it unverified.

Note also that creating an iCloud container is done through the developer account's Certificates, Identifiers & Profiles, which per [Enable app capabilities](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/) requires "Account Holder or Admin" role in a team — a free Apple Account has no Identifiers section to work with.

### 3.4 Consequence and fallback for Chalk

**Verdict: CloudKit is off the table for v1 under the stated free-provisioning constraint.** The fallback — a local-only SwiftData store — is cheap, and the migration path later is genuinely a flip:

- Today: no iCloud capability, no Background Modes, `ModelConfiguration(cloudKitDatabase: .none)`.
- Later (paid membership): add iCloud + CloudKit checkbox (which auto-adds Push Notifications) + Background Modes → Remote notifications, then `.automatic` (or `.private("iCloud.<bundle-id>")`).

The cheapness is conditional on **designing to CloudKit's schema rules now**. Apple's own framing supports this: "A model layer described using macros in SwiftData will, in many cases, generate a schema already compatible with CloudKit. However, the SwiftData framework does include a small number of features that CloudKit doesn't support natively... It's important you consider these limitations as you design your app's model layer (or adapt an existing one) to ensure it remains compatible with CloudKit" ([Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)). If you instead use `.unique`, non-optional attributes, and required relationships now, turning CloudKit on later becomes a versioned migration of every affected model — including a custom migration stage if you need to deduplicate (see §4).

One caveat worth stating honestly: the *existing local store on a device* would, at flip time, need to be uploaded into a freshly initialised CloudKit schema. Apple documents schema initialisation and promotion but I found no primary page describing "existing local SwiftData store, later CloudKit-enabled" as a supported one-step upgrade. Core Data's mirroring is designed to backfill an existing store into CloudKit on first sync, so this should work, but it is **unverified against a primary source** and should be tested before relying on it.

---

## 4. Versioned schema migration under CloudKit

### 4.1 The SwiftData mechanism

Per [Model your schema with SwiftData (WWDC23, session 10195)](https://developer.apple.com/videos/play/wwdc2023/10195/):

> "Whenever you prepare to release a new version of your app with changes to your SwiftData models, define a `VersionedSchema` that encapsulates your previously released schema. Each distinct version of your schema should be defined as a `VersionedSchema` so that SwiftData knows what changes occurred between them. Then, use your total ordering of `VersionedSchema`s to create a `SchemaMigrationPlan`."

API references: [`VersionedSchema`](https://developer.apple.com/documentation/swiftdata/versionedschema) — "An interface for describing a specific version of a schema, including the models it contains"; [`SchemaMigrationPlan`](https://developer.apple.com/documentation/swiftdata/schemamigrationplan) — "An interface for describing the evolution of a schema and how to migrate between specific versions"; [`MigrationStage`](https://developer.apple.com/documentation/swiftdata/migrationstage) — "Describes a migration between two versions of the same schema."

**Lightweight vs custom**, same session:

> "Lightweight migrations do not require any additional code to migrate the existing data for my next app release. Modifications like adding `originalName` to my date properties or specifying the delete rules on my relationships are lightweight migration eligible. However, making the name of a trip unique is not eligible for a lightweight migration. I need to create a custom migration stage for this change, in which I can deduplicate my trips, before their names are made unique."

A custom stage exposes `willMigrate` / `didMigrate` closures: "In the `willMigrate` closure, I can deduplicate my trips before the migration happens. SwiftData will detect when a migration from V1 to V2 will occur and will perform this closure for me." You then pass the plan to the container: "I setup my `ModelContainer` with my current schema and the migration plan, and I'm done."

### 4.2 What CloudKit permits once data exists

Additive only. From [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices): "CloudKit schemas are **additive only**, which means you're unable to delete model types or change existing model attributes after you promote a schema to production."

The Core Data article is more detailed ([Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)):

- Development schema: "a draft schema that you can rewrite as often as necessary during development. **You can't delete a record type or modify any existing attributes after you promote a development schema to production.**"
- Resetting: "As you change the model during development, periodically visit the CloudKit dashboard to reset the development environment and delete the existing development schema, before initializing a new one."
- Promotion is one-way and permanent — marked **Important**: "After you promote your schema to production, the record types and their fields are **immutable and exist for all time**. You can add new record types, and additional fields to existing record types, but you can't modify or delete existing record types."

Apple's three suggested strategies for evolving a production schema, verbatim in substance:

1. "Migrate users to a completely new store, using [`NSPersistentCloudKitContainerOptions`] to associate the new store with a new container."
2. "Incrementally add new fields to existing record types. If you adopt this approach, older versions of your app have access to every record a user creates, but not every field."
3. "Version your entities by including a `version` attribute from the outset, and use a fetch request to select only those records that are compatible with the current version of the app."

**Implication for Chalk:** the local SwiftData migration story (`VersionedSchema` + `SchemaMigrationPlan`) and the CloudKit schema story are *separate*. A lightweight local migration that renames a property is still a *new field* server-side and the old field is stranded forever. And renaming/removing a model attribute after production promotion is not possible at all on the CloudKit side. Also note: encryption state is frozen at promotion ([`allowsCloudEncryption`](https://developer.apple.com/documentation/coredata/nsattributedescription/allowscloudencryption)) — decide encryption per-attribute *before* going to production.

One clean side-effect of not shipping CloudKit in v1: nothing is promoted to a production CloudKit schema yet, so the schema stays freely resettable through the development environment for as long as Chalk is unreleased.

---

## 5. Pitfalls for an app of this shape

### 5.1 Sync latency and gradual appearance

Apple's mental model, verbatim from [Syncing a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit):

> "It can be helpful to think of this process as similar to the water cycle. Water evaporates up and rains down on a natural cadence... **Generally, you can expect data to synchronize a local change within about a minute of the change.** Core Data also occasionally syncs CloudKit data in scenarios such as when the app hasn't synced in a long time."

Uploads and downloads happen as **background tasks** the system schedules; "You don't need to add any code to your project to synchronize records across devices." The consequence for first launch on a second device is that data materialises **incrementally**, not atomically — the store fills in over multiple background import batches. For Chalk's UI that means: no empty-state that reads as "you have no records" during initial import if it can be confused with the real empty state, and views must tolerate a partially populated graph (an `Exercise` whose sets haven't arrived yet). This is the same reason relationships must be optional (§1.2).

Apple also warns about the inverse hazard — objects **disappearing** underneath a view: "The iPad's current view may still show the record if the UI hasn't updated with the changes yet. The user taps on the now-deleted record, which is no longer available in the store." Their Core Data remedy is pinning to a query generation (`setQueryGenerationFrom(.current)`). **SwiftData exposes no equivalent API that I could find**, so for SwiftData the practical mitigation is defensive view code (treat model objects as possibly-deleted, avoid force-unwraps on relationships). Flagged as unverified — I found no Apple guidance on query generations *for SwiftData*.

### 5.2 Conflict resolution: last-writer-wins, no hook

From [Using Core Data with CloudKit (WWDC19, session 202)](https://developer.apple.com/videos/play/wwdc2019/202/), verbatim:

> "Conflict resolution is implemented automatically by `NSPersistentCloudKitContainer` using a **last writer wins merge policy**. And the reason we do this, is that the job of conflict resolution is to keep the object graph and the data in CloudKit consistent with how you've modeled your data."

and:

> "`NSPersistentCloudKitContainer` seeing that something has changed in CloudKit while it was away, will resolve this to preserve one of the two values. Right? Using a last writer wins merge policy."

So: **no custom merge policy hook.** Apple's guidance is to model your way around it — if two devices might contribute independently, model those contributions as separate records (their "collaboration is not conflict resolution" framing) rather than as two writes to one field. For single-user Chalk this is low-risk, but it argues for append-only-ish modelling of set/rep entries (each logged set its own model object) rather than mutating an aggregate. I did **not** find a primary statement on whether the merge is per-field or whole-record; WWDC19 describes it at the value level ("preserve one of the two values") which reads as per-field, but I am not asserting it.

### 5.3 Offline writes

The local SwiftData/Core Data store is the source of truth on-device; writes succeed offline and the mirroring machinery exports them when it next runs. Apple's error guidance is that connectivity failures are expected and self-healing: "Most errors, like those that result from a network failure or a user not being signed in, are **transient and don't require action**" ([Syncing a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)). **I did not find a primary source specifying exactly when a queued export flushes after connectivity returns** — Apple only commits to "within about a minute of the change" for the online case and to occasional catch-up syncs. Assume "eventually, on the system's schedule, not on yours". For gym-with-no-signal usage this is the right shape: logging never blocks on the network.

### 5.4 Not signed into iCloud

Same doc: a user not being signed in is grouped with transient errors that "don't require action" — sync simply doesn't happen and the local store keeps working. If Chalk wants to *tell* the user, CloudKit exposes [`CKContainer.accountStatus(completionHandler:)`](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:)): "Call this method before accessing the private database to determine whether that database is available. While your app is running, use the [account-changed] notification to detect account changes, and call this method again to determine the status of the new account." Values are the [`CKAccountStatus`](https://developer.apple.com/documentation/cloudkit/ckaccountstatus) constants. SwiftData itself surfaces no sync-status API that I could find.

### 5.5 Testing requirements

[Enabling CloudKit in Your App](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app): "You need an iCloud account to save records to a container. In your app or the simulator on which you test your app during development, enter the credentials for this iCloud account." And: "Perform the same sign-in process for **each iOS or iPadOS simulator** you test your app on." Also "To enable iCloud Drive, choose iCloud and then click the iCloud Drive switch."

For diagnosing sync specifically ([Syncing a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)): "confirm that you're testing on **two unlocked devices logged into the same iCloud account**, with good wireless internet connections." And a caution that undermines simulator-only testing: "**Push notifications may get dropped or deferred, so don't rely on them for testing.**" Simulators can be signed into iCloud per the CloudKit doc, but I found **no primary Apple statement confirming that CloudKit *silent push* delivery works in the iOS Simulator** — so plan on at least one real device for end-to-end sync verification.

Your iCloud account and your developer account are distinct but may share an email: "Note that your iCloud account is distinct from your Apple Developer account; however, you can use the same email address for both. Doing so gives you access to your iCloud account's private user data in CloudKit Dashboard, which can be helpful for debugging."

### 5.6 Debugging

From [Syncing a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit):

> "Choose Product > Scheme > Edit Scheme. Select an action such as Run, and select the Arguments tab. Pass the `com.apple.CoreData.CloudKitDebug` user default setting with a debug level value as an argument to the application. Higher argument values produce more information; start at `1` and increase if you need more detail."

i.e. `-com.apple.CoreData.CloudKitDebug 1` in the scheme's launch arguments.

Log streaming, verbatim from the same page:

```
$ log stream --info --debug --predicate 'process = "cloudd" and message
contains[cd] "containerID=com.mycontainer"'
```

```
$ log stream --info --debug --predicate 'process = "myprocess" and
(subsystem = "com.apple.coredata" or subsystem = "com.apple.cloudkit")'
```

Expected success line after schema initialisation ([Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)):

```
<NSCloudKitMirroringDelegate: 0x7f9699d29a90>: Successfully set up CloudKit
    integration for store
```

Also worth knowing when reading raw records in CloudKit Console: Core Data prefixes everything with `CD_` — "we prefix everything; the record type and all of our field names with CD under bar. But, in the CD_entityName field, we keep the real entity name" ([WWDC19 202](https://developer.apple.com/videos/play/wwdc2019/202/)). Record names are UUIDs Core Data owns.

---

## 6. Verdict / recommendations for Chalk

### 6.1 Free vs paid decision

**v1 ships local-only.** The free-provisioning constraint is dispositive: CloudKit, iCloud Documents, iCloud KVS and Push Notifications are all paid-membership-only per [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/). There is no workaround; attempting it fails at signing, not at runtime. Do not add the iCloud or Push Notifications capabilities to the target while on a Personal Team.

If cross-device sync becomes a must-have, the only route is the $99/yr Apple Developer Program. Given Chalk is single-user and gym-logging is inherently one-device-at-a-time, deferring is reasonable; the cost of deferral is bounded to (a) no backup/restore across a device replacement, and (b) the untested-but-expected backfill of an existing local store on first CloudKit sync (§3.4).

### 6.2 Schema rules to follow from day one

Adopt these now, even though nothing syncs yet:

1. **Every attribute is optional or has a default value.** `var weightKg: Double = 0` or `var notes: String?`. Never `var date: Date` with no default. (Framework error text; secondary source — [forums 739351](https://developer.apple.com/forums/thread/739351).)
2. **Every relationship is optional**, on both sides. `var sets: [WorkoutSet]?` and `var exercise: Exercise?`. ([Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices))
3. **Declare the inverse explicitly** with `@Relationship(inverse:)` rather than relying on inference. Apple: "SwiftData automatically sets the inverse of a relationship if it can reliably infer that inverse from your schema. Otherwise, explicitly set the inverse before saving." Being explicit removes the "if it can reliably infer" caveat.
4. **No `@Attribute(.unique)` and no `#Unique`.** Give each model a `var id: UUID = UUID()` and enforce uniqueness in app code (fetch-then-insert, or a deduplication pass). Note this is also the one change WWDC23 calls out as *not* lightweight-migration-eligible — adding uniqueness later costs a custom migration stage with deduplication, which is precisely the cost you avoid by never adding it.
5. **Delete rules: `.cascade` or `.nullify` only. Never `.deny`.** ([Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices))
6. **Prefer append-only modelling for logged data.** Each logged set is its own model object rather than a mutated aggregate — this sidesteps last-writer-wins field clobbering entirely.
7. **Consider a `schemaVersion: Int = 1` attribute on each model now.** This is Apple's own third strategy for surviving a frozen production CloudKit schema ([Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)) and costs nothing to add before v1.
8. **Decide encryption before any production promotion.** `.allowsCloudEncryption` cannot be added to existing CloudKit attributes and cannot be changed after promotion ([`allowsCloudEncryption`](https://developer.apple.com/documentation/coredata/nsattributedescription/allowscloudencryption)). Strength records are unlikely to need it; just don't retrofit it later.
9. **Wrap the container setup behind one function** so `.none` → `.automatic` is a single-line, single-site change (see §2.3).
10. **Start `VersionedSchema` discipline at v1.** Define `ChalkSchemaV1` now even with an empty migration plan, so the ordering exists when it's first needed.

### 6.3 Things to verify before committing to CloudKit later

- That an existing populated local SwiftData store backfills correctly into a freshly initialised CloudKit schema (§3.4 — unverified).
- Whether silent push reaches the iOS Simulator, or whether device testing is mandatory (§5.5 — unverified).
- Per-field vs whole-record granularity of last-writer-wins (§5.2 — unverified).

---

## Sources

Primary — Apple Developer documentation and help:

- [Supported capabilities (iOS) — Developer Account Help](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) *(capability-by-membership table; read from page HTML)*
- [Choosing a Membership — Apple Developer Support](https://developer.apple.com/support/compare-memberships/)
- [Enable app capabilities — Developer Account Help](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)
- [Enabling CloudKit in Your App — CloudKit](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app)
- [Syncing model data across a person's devices — SwiftData](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Creating a Core Data model for CloudKit — Core Data](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)
- [Setting up Core Data with CloudKit — Core Data](https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit)
- [Syncing a Core Data store with CloudKit — Core Data](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)
- [NSPersistentCloudKitContainer — Core Data](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)
- [NSAttributeDescription.allowsCloudEncryption — Core Data](https://developer.apple.com/documentation/coredata/nsattributedescription/allowscloudencryption)
- [ModelConfiguration.CloudKitDatabase — SwiftData](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct)
- [ModelConfiguration init(_:schema:isStoredInMemoryOnly:allowsSave:groupContainer:cloudKitDatabase:) — SwiftData](https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:isstoredinmemoryonly:allowssave:groupcontainer:cloudkitdatabase:))
- [Schema.Attribute.Option.unique — SwiftData](https://developer.apple.com/documentation/swiftdata/schema/attribute/option/unique)
- [Schema.Attribute.Option.allowsCloudEncryption — SwiftData](https://developer.apple.com/documentation/swiftdata/schema/attribute/option/allowscloudencryption)
- [Unique(_:) macro — SwiftData](https://developer.apple.com/documentation/swiftdata/unique(_:))
- [Schema.Relationship.DeleteRule.deny — SwiftData](https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/deny)
- [VersionedSchema — SwiftData](https://developer.apple.com/documentation/swiftdata/versionedschema)
- [SchemaMigrationPlan — SwiftData](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [MigrationStage — SwiftData](https://developer.apple.com/documentation/swiftdata/migrationstage)
- [Adding capabilities to your app — Xcode](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)
- [CKContainer.accountStatus(completionHandler:) — CloudKit](https://developer.apple.com/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:))
- [CKAccountStatus — CloudKit](https://developer.apple.com/documentation/cloudkit/ckaccountstatus)

Primary — WWDC session transcripts:

- [Using Core Data with CloudKit — WWDC19, session 202](https://developer.apple.com/videos/play/wwdc2019/202/)
- [Model your schema with SwiftData — WWDC23, session 10195](https://developer.apple.com/videos/play/wwdc2023/10195/)
- [Build apps that share data through CloudKit and Core Data — WWDC21, session 10015](https://developer.apple.com/videos/play/wwdc2021/10015/)

Secondary — clearly labelled, used only where no primary source exists:

- [Apple Developer Forums thread 739351](https://developer.apple.com/forums/thread/739351) — Apple Frameworks Engineer reply confirming the "all attributes be optional, or have a default value set" requirement and its two fixes. Used for §1.2 and rule 1 in §6.2 only.

### Explicitly unverified

Stated here so nothing above is mistaken for established fact:

- Exact Xcode error/behaviour when a Personal Team build enables CloudKit (§3.3).
- That `#Unique` specifically (as opposed to entity unique constraints generally) is rejected under CloudKit (§1.2).
- CloudKit compatibility of SwiftData enum and `Codable` attributes (§1.2).
- That `.cascade`/`.nullify` are affirmatively supported (established only by exclusion) (§1.2).
- Whether encrypted CloudKit fields lose query/index capability (§1.2).
- A SwiftData equivalent of Core Data query generations (§5.1).
- Per-field vs whole-record granularity of last-writer-wins (§5.2).
- When queued offline exports flush after connectivity returns (§5.3).
- Whether CloudKit silent push is delivered to the iOS Simulator (§5.5).
- Whether an existing populated local SwiftData store backfills cleanly when CloudKit is enabled later (§3.4).
