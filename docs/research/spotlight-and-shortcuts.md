# How exercises and ergs are found from Spotlight and Shortcuts

**Date:** 2026-10-22
**Question:** [#142](https://github.com/hermanno3005/Chalk/issues/142). SPEC §15.5 says *every
exercise and erg is findable from the system search and opens on its detail screen*. How is that
built on iOS 18.0 with SwiftData, so that the build ticket
[#143](https://github.com/hermanno3005/Chalk/issues/143) has no open choices? Part of map
[#127](https://github.com/hermanno3005/Chalk/issues/127).
**Scope:** indexing, keeping the index true, routing a result into the right half's
`NavigationStack`, what a result shows, and whether App Shortcuts are needed. Siri lookups are
out (§15.7) and §15's decisions are not reopened.
**Status:** findings only. Availability is read from Apple's documentation data as of the date
above. Where a claim is inferred rather than stated by Apple, it says so.

## Bottom line

**Use App Intents only. Give Chalk two `IndexedEntity` types, `ExerciseEntity` and `ErgEntity`,
and index them with `CSSearchableIndex(name:).indexAppEntities(_:)`. Give each type an
`OpenIntent` whose `perform()` runs on the main actor and replaces the library's navigation path.
Don't create `CSSearchableItem`s or `NSUserActivity`s, and don't add an `AppShortcutsProvider`
to meet §15.5.**

- **One mechanism covers both surfaces.** An indexed entity appears in Spotlight results, and
  tapping one runs the matching `OpenIntent`. Every app intent also appears as an action in the
  Shortcuts app, and the entity query fills that action's picker with every exercise or erg.
- **The index holds the name and nothing else.** Only create, rename, delete and restore change
  it. Archive, merge, kind change, re-filing and every entry write leave it alone, so one diffing
  `sync` after each save keeps it true.
- **Routing needs one change to the app.** The library's navigation path moves out of
  `LibraryView`'s `@State` and into `LibraryModel`, which `ChalkApp.init` creates before any
  intent runs. Because of that, the same code works from a cold launch and from the background.
- **The trade-off:** Chalk adds about four small types and one moved property, and gets both
  surfaces from them. What it gives up is the convenience Apple added after iOS 18:
  `onAppIntentExecution` view routing (iOS 26), `@Property(indexingKey:)` (iOS 18.4),
  `@ComputedProperty` (iOS 26) and `IndexedEntityQuery` reindexing (iOS 27). None of them is
  needed at Chalk's size.

---

## 1. Indexing: App Intents, Core Spotlight, or both?

### What iOS 18.0 offers

| API | Introduced | What it does |
|---|---|---|
| `IndexedEntity` | iOS 18.0 | "An interface that allows you to include an entity in your app's Spotlight index." ([doc](https://developer.apple.com/documentation/appintents/indexedentity)) |
| `CSSearchableIndex.indexAppEntities(_:priority:)` | iOS 18.0 | Indexes entities directly. If an entity's identifier is already in the index, "Spotlight updates the existing entry instead of creating a new one." ([doc](https://developer.apple.com/documentation/corespotlight/cssearchableindex/indexappentities(_:priority:)), [article](https://developer.apple.com/documentation/appintents/making-app-entities-available-in-spotlight)) |
| `deleteAppEntities(identifiedBy:ofType:)`, `deleteAppEntities(ofType:)` | iOS 18.0 | Removes some or all entities of a type. ([doc](https://developer.apple.com/documentation/corespotlight/cssearchableindex/deleteappentities(identifiedby:oftype:)), [doc](https://developer.apple.com/documentation/corespotlight/cssearchableindex/deleteappentities(oftype:))) |
| `IndexedEntity.attributeSet` / `defaultAttributeSet` | iOS 18.0 | The default implementation "provides an attribute set with the title, subtitle, and image values from the entity's display representation." ([doc](https://developer.apple.com/documentation/appintents/indexedentity/attributeset)) |
| `CSSearchableItemAttributeSet.associateAppEntity(_:priority:)` | iOS 18.0 | Attaches an entity to an existing `CSSearchableItem`. ([doc](https://developer.apple.com/documentation/corespotlight/cssearchableitemattributeset/associateappentity(_:priority:))) |
| `IndexedEntity.hideInSpotlight` | **iOS 18.4** | ([doc](https://developer.apple.com/documentation/appintents/indexedentity/hideinspotlight)) |
| `@Property(indexingKey:)` | **iOS 18.4** | ([doc](https://developer.apple.com/documentation/appintents/entityproperty/init(indexingkey:)-16blv)) |
| `@ComputedProperty(indexingKey:)` | **iOS 26.0** | ([doc](https://developer.apple.com/documentation/appintents/computedproperty(indexingkey:))) |
| `IndexedEntityQuery` (system-requested reindex) | **iOS 27.0** | ([doc](https://developer.apple.com/documentation/appintents/indexedentityquery)) |

### What surfaces where

- **Spotlight.** "Adding entities to Spotlight makes them discoverable … and also serves as the
  first step in letting Spotlight launch your app and display items that appear in search
  results" ([IndexedEntity](https://developer.apple.com/documentation/appintents/indexedentity)).
  The article continues: "For each `AppEntity` type that you define and donate to Spotlight,
  create an `OpenIntent` type that opens that entity in your app … When an open intent is
  present, Spotlight can use it to provide that behavior"
  ([Making app entities available in Spotlight](https://developer.apple.com/documentation/appintents/making-app-entities-available-in-spotlight)).
  WWDC24 demonstrates exactly this: index on launch, then "because I have an OpenTrailIntent that
  accepts our TrailEntity as a parameter, I can tap on the result to go straight to it in the
  app" ([What's new in App Intents, WWDC24](https://developer.apple.com/videos/play/wwdc2024/10134/)).
  The open intent's "target parameter must have the same entity type as the results"
  ([Explore new advances in App Intents, WWDC25](https://developer.apple.com/videos/play/wwdc2025/275/)).
- **Shortcuts.** "All intents appear by default as actions in the Shortcuts app." The entity's
  query answers the picker: "what entities are there? So the device can show a list of options
  someone can pick from" ([Bring your app's core features to users with App Intents, WWDC24](https://developer.apple.com/videos/play/wwdc2024/10210/)).

Core Spotlight on its own (`CSSearchableItem`, routed back through `CSSearchableItemActionType`
and `NSUserActivity`, [doc](https://developer.apple.com/documentation/corespotlight/cssearchableitemactiontype))
reaches Spotlight but not Shortcuts. Using it would still mean writing the entities and intents.
Using both is worse than either: "If you index a searchable item and entity for the same content,
Spotlight creates separate entries for each one in your app's index"
([indexAppEntities](https://developer.apple.com/documentation/corespotlight/cssearchableindex/indexappentities(_:priority:))).
`associateAppEntity` exists for apps that already have Core Spotlight code. Chalk has none.

**Recommendation: `indexAppEntities` on a named index only.** Apple's guidance is "use a named
`CSSearchableIndex` type and not the default index"
([article](https://developer.apple.com/documentation/appintents/making-app-entities-available-in-spotlight)).

### The entity shape for Chalk

- **Two entity types, `ExerciseEntity` and `ErgEntity`**, even though the model is one
  `Exercise` type (ADR-0008). Each type's `typeDisplayRepresentation` is shown to people. The
  Shortcuts action titles are built from it too: *Open Exercise* and *Open Erg*. CONTEXT.md lists
  *exercise* under an erg's *Avoid*, so one shared type would have to call an erg an exercise.
  Two types keep each half's word, and each half gets its own picker. Both conform to a small
  shared protocol, and they share one query implementation generic over the half.
- **Identifier: `Exercise.id` (UUID).** It survives rename, kind change and restore (a backup
  round-trips ids, §15.1). An entity's half never changes, because an erg's unit is never
  cleared (invariant 9). That means the entity type for an id is fixed, and
  `deleteAppEntities(identifiedBy:ofType:)` always knows which type to name.
- **Plain `Sendable` structs (`id`, `name`), not the `@Model`.** Apple recommends an entity
  "that merely refers to your implementation" when model instances are created on demand (WWDC24
  10210). Swift 6 needs the entity to be `Sendable`, and a SwiftData model is not.
- **Query: `EnumerableEntityQuery`** (iOS 17) with `allEntities()` and `entities(for:)`. Apple
  describes it as the query for "a short list of entities that are relatively small in size". It
  "enable[s] the Shortcuts app to generate a Find action and do filtering automatically"
  ([doc](https://developer.apple.com/documentation/appintents/enumerableentityquery)), and
  "App Intents can derive the more complicated ones from this, if you build with the iOS 18 SDK"
  (WWDC24 10210). A library holds tens of rows, not thousands. The query builds its own
  `ModelContext` from the `ModelContainer`, which is `Sendable`, because a query can run in the
  background without a scene.
- **No custom `attributeSet`.** The default carries the display representation's title, which is
  the name. `@Property(indexingKey:)` would need 18.4 and adds nothing here.

## 2. What a result shows

**Title: the exercise's or erg's name. No subtitle, no custom image.**

Each candidate was weighed against the ticket's rule, *nothing beyond what the tile shows*:

- **Last entry** (`8 × 52.5 kg · today`) is the tile's subtitle, but it is wrong in the index:
  - Its relative *today* goes stale overnight in a stored index.
  - It changes on every log, edit, entry delete, convert (§15.2) and merge. Each of those
    becomes a reindex trigger, which brings back most of the write paths §3 below avoids.
  - Dropping the *when* would show a different string from the tile.
- **Group** is not on the tile. It is the section header, and it would make group rename,
  group delete and every re-file into index writes.
- **Name only** changes on create, rename, delete and restore, and nowhere else.

Spotlight shows the app's icon beside the result. The entity type (*Exercise* or *Erg*) labels it
in Shortcuts pickers.

`priority` (by recency) was also considered and rejected for the same reason as the last entry:
it would make every log an index write.

## 3. Keeping the index true

### What changes the indexed fields

| Library event (SPEC) | Changes `(id, name, type)`? | Index action |
|---|---|---|
| Create exercise (§7.3) or erg (§13.6) | yes, a new id | index it |
| Rename (§5.5, §13.8) | the name | index it again (an upsert by id) |
| Delete exercise or erg (§5.5) | the id is gone | `deleteAppEntities(identifiedBy: [id], ofType:)` |
| Archive a gym (§7.4) | no: archive is a gym's display state, and exercises have none | none |
| Merge machines (§7.5, §13.11) | no: machine-level, name and half untouched | none |
| Kind change (§8, §13.11) | no: kind is not indexed, and the half cannot change (invariant 9) | none |
| Change unit (§13.6) | no: the half stays endurance | none |
| Re-file, group edits (§7.2) | no: the group is not indexed | none |
| Log, edit or delete an entry, relabel or convert (§15.2) | no | none |
| Restore a backup (§15.1) | every row may change | everything removed, then everything indexed again |

### Is reindexing on save enough?

Mostly, but a rename-only hook would miss the delete. A deleted model's UUID can no longer be
read once it is gone. `ModelContext.didSave` reports only `PersistentIdentifier`s
([doc](https://developer.apple.com/documentation/swiftdata/modelcontext/didsave)), so a save
handler has no way to learn which exercise id to remove.

**Recommendation: one deep module, `LibraryIndex`, with a single entry point, `sync()`:**

1. Fetch every `Exercise` from the store. That is ids, names and `unit != nil`, all rows, both
   halves.
2. Diff the result against the snapshot it last pushed, kept in memory as
   `[UUID: (name, Half)]`. New or renamed rows are indexed with `indexAppEntities`. Ids missing
   from the store are removed with `deleteAppEntities(identifiedBy:ofType:)`, using the half the
   snapshot recorded.
3. Push the result through an injected sink. In the app the sink is the named `CSSearchableIndex`.
   In tests it is a recorder.

**When it runs:**

- **On every `ModelContext.didSave` of the main context.** Every write in Chalk ends in
  `context.save()`, so one observer covers every path that exists now and any added later
  (restore included), with nothing to remember at each call site. A log save produces an empty
  diff, so its cost is one fetch of a few dozen rows and no Spotlight call.
  `LibraryModel.refresh()` is deliberately **not** the hook: it runs on every search keystroke,
  and it only fetches one half.
- **On launch, as a full rebuild.** Call `deleteAppEntities(ofType:)` for both types, then index
  everything, and seed the snapshot from the result. This is how iOS 18 apps answer the system's
  reindex requests. The protocol for answering them, `IndexedEntityQuery`, needs iOS 27. The
  alternative is a Core Spotlight delegate extension ([Regenerating your app's indexes on demand](https://developer.apple.com/documentation/corespotlight/regenerating-your-app-s-indexes-on-demand)),
  which would also need an App Group so it could open the store. A launch rebuild also mends
  anything a crash left half-done, and costs nothing at Chalk's size.

**One thread at a time.** "Modify a `CSSearchableIndex` object from only one thread or task at a
time" ([CSSearchableIndex](https://developer.apple.com/documentation/corespotlight/cssearchableindex)).
An `actor` alone does not guarantee this, because it reenters at each `await`. Chain each sync
onto the previous one's `Task`, so a rename's index call cannot overlap the next delete.

**Tests (#143's first criterion)** call `LibraryIndex.sync()` on a `TemporaryStore` with the
recording sink:

- create → one index
- rename → re-index with the new name
- merge → nothing
- delete → one delete of the right type
- first sync → full rebuild

## 4. Opening on the detail screen, in the right half

### What iOS 18 allows

- **`OpenIntent` foregrounds the app by itself.** "The system automatically brings your app to
  the foreground to run this app intent"
  ([OpenIntent](https://developer.apple.com/documentation/appintents/openintent)). "Open Intent
  implies openAppWhenRun" (WWDC24 10210). `openAppWhenRun` is deprecated from iOS 26 in favour of
  `supportedModes`, and `OpenIntent` "automatically configure[s] the `supportedModes` property to
  run the app intent in the foreground"
  ([Configuring the runtime behavior](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents)).
  Chalk needs neither.
- **On iOS 18, the UI is updated from `perform()`.** "The system runs this method after bringing
  your app to the foreground … Make all interface-related changes from your app's main thread
  using a `MainActor` type" (same article). The scene-routing path
  (`TargetContentProvidingIntent` with `.onAppIntentExecution`) is **iOS 26+**
  ([doc](https://developer.apple.com/documentation/appintents/targetcontentprovidingintent),
  [doc](https://developer.apple.com/documentation/swiftui/view/onappintentexecution(_:perform:))).
  It also requires `UIApplicationSupportsMultipleScenes = YES`
  ([Directing app intents to your app's scenes](https://developer.apple.com/documentation/appintents/directing-app-intents-to-your-apps-scenes)).
- **The intent can't reach a view's `@State`.** "If your App Intents want to perform UI
  navigation, they need to have access to all the app states driving the views. This can only be
  done with globally shared objects like AppDependencies or singletons" (WWDC25 275).
- **`AppDependencyManager` and `@Dependency` are the injection point** (iOS 16). A dependency
  must be `Sendable` ([`add(key:dependency:)`](https://developer.apple.com/documentation/appintents/appdependencymanager)).
  "Register dependencies as early as possible in your app's lifecycle"
  ([Get to know App Intents, WWDC25](https://developer.apple.com/videos/play/wwdc2025/244/)).
- **The URL route was rejected.** `URLRepresentableEntity` (iOS 18) reuses an app's link
  handling, but Chalk has no URL scheme or universal links, and universal links need a paid
  Associated Domains entitlement and a website.

### The design for Chalk

1. **Move the path.** `LibraryView`'s `@State private var opened: [Exercise]` becomes
   `LibraryModel.path`, and `NavigationStack(path:)` binds to it. `LibraryModel` is already made
   once, in `ChalkApp.init`, "rather than per body evaluation" (`ChalkApp.swift`). It therefore
   exists before any intent runs and outlives every scene.
2. **Add `LibraryModel.open(exerciseWithID:) -> Bool`.** It looks the row up by UUID
   (`assign(exerciseWithID:)` already does this lookup) and returns `false` if the row is gone.
   Otherwise it:
   - calls `show(half)` for the row's half. That persists the sticky half, so the app reopens in
     endurance after an erg result, which is consistent with §13.5's *reopens on whichever half
     you left it in*;
   - calls `endSearch()`;
   - sets `path = [exercise]`. The path is replaced, not appended to, so Back lands on that
     half's home screen, as §9 and §13.5 require;
   - bumps a `routeGeneration` counter. `LibraryView` observes it to clear `arranging` and
     `searchFocused`, which are view state. Today's `onChange(of: opened)` only fires on a push
     that grows the path, so it misses a replacement.
3. **Register a dependency in `ChalkApp.init`.** A `@MainActor final class LibraryRouter`
   wrapping the `LibraryModel` is registered with `AppDependencyManager.shared`. A main-actor
   class is `Sendable`, and `LibraryModel` is not. The `ModelContainer` is registered alongside
   it for the queries. On the `.unavailable` branch nothing is registered, and the intent throws
   a plain error, while `StoreUnavailableView` stays up.
4. **Write `OpenExerciseIntent` and `OpenErgIntent`.** Each is an `OpenIntent` with
   `@Parameter var target`, `@Dependency var router`, and a
   `@MainActor func perform() async throws -> some IntentResult` that calls
   `router.open(target.id)`.

**From a cold launch:** the process starts and `ChalkApp.init` opens the store, builds
`LibraryModel` and registers the router. The system then foregrounds the app and calls
`perform()`, which sets `path`. The first frame of the `WindowGroup` renders the stack with the
detail screen already on top of the half's home screen.

**From the background:** `perform()` runs on the live `LibraryModel`. Whatever was pushed is
replaced, and the half switches if it has to.

**Stale results.** If an exercise was deleted but Spotlight still shows it before the next
`sync()`, `entities(for:)` returns nothing for that id, and `open` returns `false` as a second
guard. Either way nothing is pushed.

## 5. App Shortcuts: is an `AppShortcutsProvider` needed?

**No, not for §15.5 or for #143's *Shortcuts lists them*.**

- **The entities alone are enough for Shortcuts.** Every intent is already a Shortcuts action
  (WWDC24 10210). The `OpenIntent`s therefore appear as *Open Exercise* and *Open Erg*, and
  their pickers list every exercise and erg through the query. WWDC23 says the same about an
  intent with an entity query: "I can now use this function from inside the Shortcuts app and as
  part of Automations"
  ([Spotlight your app with App Shortcuts, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10102/)).
- **The entities alone are enough for Spotlight.** Entity results come from the index (§1), not
  from App Shortcuts.

**What a provider would add.** App Shortcuts are zero-setup tiles. They need no shortcut to be
built, and they appear in Spotlight Top Hits under the app and at the top of Chalk's page in the
Shortcuts app (WWDC23 10102, WWDC24 10210). A parameterized phrase (*Open \(target) in Chalk*)
makes one App Shortcut per suggested entity. That requires calling `updateAppShortcutParameters()`
whenever the list changes. Those phrases "won't be available until your app has been launched"
([Implement App Shortcuts with App Intents, WWDC22](https://developer.apple.com/videos/play/wwdc2022/10170/)),
and an app has "at most ten App Shortcuts" and "at most 1,000 trigger phrases", counting each
parameter value (WWDC23 10102).

**Its cost, for Chalk.** "Since App Shortcuts are available from Siri, there's a list of phrases
to speak, each of which must contain the app name" (WWDC24 10210). A provider therefore always
makes *Open Bench Press in Chalk* a Siri voice command. Opening by voice is not a Siri *lookup*,
since nothing is answered in a snippet. Whether it sits inside §15.7 is a product call, and it is
**left open** below. It is not decided here.

## 6. Signing and provisioning

App Intents and Core Spotlight need no capability in the target. Apple's capability table lists
*Siri* (SiriKit) as paid-only and *App groups* as free
([Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)).
This design needs neither. It has no SiriKit intents, and there is no reindex extension that
would need a shared container. *Inference, not stated by Apple:* nothing here should behave
differently on the free-provisioned sideloaded build. Check it on the phone when #143 lands.

## 7. Open questions (product, not decided here)

1. **An `AppShortcutsProvider`, and the Siri phrase it brings.** The provider would add per-item
   tiles in Spotlight Top Hits and on the Shortcuts app's Chalk page. In exchange, Siri would
   answer *Open Bench Press in Chalk*. Is that within §15.7's *Siri lookups*? #143 is written
   without a provider, and one can be added later without changing anything above.
2. **A result opened over a half-typed sheet.** If the log sheet or the lap-list grid is open with
   typed rows and a Spotlight result is tapped, the path replacement pops the detail screen and
   tears the sheet down with it. The lap-list sheet's *Discard N entries?* (§13.7) never gets to
   ask. A sheet presented by the home screen itself (create, Edit groups, Manage gyms, Settings,
   *Log again*) would stay on top of the new detail screen instead. Which should win: the result,
   the sheet, or a confirmation?

## Sources

**Apple documentation** (developer.apple.com/documentation; availability read from each page's
data):

- AppIntents:
  - [Making app entities available in Spotlight](https://developer.apple.com/documentation/appintents/making-app-entities-available-in-spotlight)
  - [IndexedEntity](https://developer.apple.com/documentation/appintents/indexedentity) and its [`attributeSet`](https://developer.apple.com/documentation/appintents/indexedentity/attributeset), [`defaultAttributeSet`](https://developer.apple.com/documentation/appintents/indexedentity/defaultattributeset), [`hideInSpotlight`](https://developer.apple.com/documentation/appintents/indexedentity/hideinspotlight)
  - [IndexedEntityQuery](https://developer.apple.com/documentation/appintents/indexedentityquery)
  - [OpenIntent](https://developer.apple.com/documentation/appintents/openintent)
  - [TargetContentProvidingIntent](https://developer.apple.com/documentation/appintents/targetcontentprovidingintent)
  - [`openAppWhenRun`](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun)
  - [Configuring the runtime behavior of your app intents](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents)
  - [Directing app intents to your app's scenes](https://developer.apple.com/documentation/appintents/directing-app-intents-to-your-apps-scenes)
  - [AppDependencyManager](https://developer.apple.com/documentation/appintents/appdependencymanager)
  - [EnumerableEntityQuery](https://developer.apple.com/documentation/appintents/enumerableentityquery)
  - [App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts)
  - [AppShortcutsProvider](https://developer.apple.com/documentation/appintents/appshortcutsprovider)
  - [URLRepresentableEntity](https://developer.apple.com/documentation/appintents/urlrepresentableentity)
- CoreSpotlight:
  - [CSSearchableIndex](https://developer.apple.com/documentation/corespotlight/cssearchableindex)
  - [`indexAppEntities(_:priority:)`](https://developer.apple.com/documentation/corespotlight/cssearchableindex/indexappentities(_:priority:))
  - [`deleteAppEntities(identifiedBy:ofType:)`](https://developer.apple.com/documentation/corespotlight/cssearchableindex/deleteappentities(identifiedby:oftype:))
  - [`deleteAppEntities(ofType:)`](https://developer.apple.com/documentation/corespotlight/cssearchableindex/deleteappentities(oftype:))
  - [`associateAppEntity(_:priority:)`](https://developer.apple.com/documentation/corespotlight/cssearchableitemattributeset/associateappentity(_:priority:))
  - [CSSearchableItemActionType](https://developer.apple.com/documentation/corespotlight/cssearchableitemactiontype)
  - [Regenerating your app's indexes on demand](https://developer.apple.com/documentation/corespotlight/regenerating-your-app-s-indexes-on-demand)
- SwiftData: [`ModelContext.didSave`](https://developer.apple.com/documentation/swiftdata/modelcontext/didsave)
- SwiftUI: [`onAppIntentExecution(_:perform:)`](https://developer.apple.com/documentation/swiftui/view/onappintentexecution(_:perform:))
- Account: [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)

**WWDC sessions** (quoted from Apple's transcripts):

- WWDC24: [What's new in App Intents (10134)](https://developer.apple.com/videos/play/wwdc2024/10134/), [Bring your app's core features to users with App Intents (10210)](https://developer.apple.com/videos/play/wwdc2024/10210/)
- WWDC23: [Spotlight your app with App Shortcuts (10102)](https://developer.apple.com/videos/play/wwdc2023/10102/)
- WWDC22: [Implement App Shortcuts with App Intents (10170)](https://developer.apple.com/videos/play/wwdc2022/10170/), [Dive into App Intents (10032)](https://developer.apple.com/videos/play/wwdc2022/10032/)
- WWDC25, for what changed after iOS 18: [Get to know App Intents (244)](https://developer.apple.com/videos/play/wwdc2025/244/), [Explore new advances in App Intents (275)](https://developer.apple.com/videos/play/wwdc2025/275/)
