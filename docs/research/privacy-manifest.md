# What Chalk's privacy manifest must declare

**Date:** 2026-10-22
**Question:** [#149](https://github.com/hermanno3005/Chalk/issues/149) — what does
`PrivacyInfo.xcprivacy` have to declare for Chalk, so the build ticket
([#150](https://github.com/hermanno3005/Chalk/issues/150)) is mechanical? Part of map
[#127](https://github.com/hermanno3005/Chalk/issues/127), SPEC §15.6.
**Scope:** required-reason APIs (today's source and the §15 features still to come), collected
data and tracking, third-party SDKs, and how the manifest is checked before submission.
**Status:** findings only. Nothing is built.

**Primary sources** are Apple's developer documentation and technotes, cited inline as [1]–[9]
and listed at the end. The source sweep was run against `main` at `e0d56c3`. One claim could not
be settled from primary sources and is marked **UNVERIFIED**.

## Bottom line

Chalk's manifest declares **one required-reason API category and nothing else**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

1. **`NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`** — the zones, the current
   gym, the seed flag, and (§15.2) the two units are read and written only by Chalk itself [3].
   The units add **no new entry**: the declaration is per *category*, not per key [2].
2. **`NSPrivacyTracking` = `false`, no `NSPrivacyTrackingDomains`.** TN3181 names exactly this
   as a valid form for an app that contacts no tracking domain [5].
3. **No `NSPrivacyCollectedDataTypes`.** Chalk sends nothing off the device, so it collects
   nothing in Apple's sense [8]. Omit the key rather than write an empty array (§3).
4. **No file-timestamp entry, provided the backup carries its own date.** §15.1's restore prompt
   (`… from 12 Mar 2026`) must read that date *from inside the backup file*, not from the file's
   metadata. Read from metadata, it would add
   `NSPrivacyAccessedAPICategoryFileTimestamp` with `3B52.1` (§2).
5. **No third-party SDKs**, so no other manifest in the bundle and nothing to aggregate (§4).
6. **App Store Connect's privacy answer is "No, we do not collect data from this app"** [9],
   which matches the manifest's empty collection.

---

## 1. The source sweep: what Chalk calls today

Apple lists five categories of required-reason API [3][6]:

| Category | APIs named by Apple [3] | In Chalk? |
| --- | --- | --- |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `UserDefaults` | **Yes** |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `FileAttributeKey.creationDate`, `.modificationDate`, `UIDocument.fileModificationDate`, `URLResourceKey.contentModificationDateKey`, `.creationDateKey`, `getattrlist`, `getattrlistbulk`, `fgetattrlist`, `getattrlistat`, `stat`, `fstat`, `fstatat`, `lstat` | No |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `ProcessInfo.systemUptime`, `mach_absolute_time()` | No |
| `NSPrivacyAccessedAPICategoryDiskSpace` | `URLResourceKey.volumeAvailableCapacity*Key`, `.volumeTotalCapacityKey`, `FileAttributeKey.systemFreeSize`, `.systemSize`, `statfs`, `statvfs`, `fstatfs`, `fstatvfs`, `getattrlist`, `fgetattrlist`, `getattrlistat` | No |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | `UITextInputMode.activeInputModes` | No |

The sweep grepped every `.swift` file under `Chalk/` for each API above plus `@AppStorage`,
`@SceneStorage`, `resourceValues`, `ProcessInfo`, `sysctl` and `clock_gettime`.

**UserDefaults is used, in the app target, in these places:**

- `Chalk/Chalk/Settings/HeartRateZones.swift` and `SettingsModel.swift` — the heart-rate zones,
  one key of four `Int`s (ADR-0005).
- `Chalk/Chalk/Gyms/GymsModel.swift` — `currentGymID`, read through `UserDefaults` and
  `@AppStorage` (which is backed by `UserDefaults.standard`).
- `Chalk/Chalk/Library/SuggestedGroups.swift`, `LibraryModel.swift` — the strength-seed flag.
- `Chalk/Chalk/Detail/ErgDetailModel.swift`, `History/ErgHistoryModel.swift`,
  `Log/LapListModel.swift` — read the zones through the same seam.
- `#Preview` blocks in `SettingsSheet.swift`, `LibraryView.swift`, `CreateErgSheet.swift`,
  `CreateExerciseSheet.swift` use `UserDefaults(suiteName: "chalk-preview-<uuid>")`. That is a
  suite in Chalk's own container, not an App Group, so it falls under the same reason.

Every one of these reads and writes data that only Chalk can see. That is `CA92.1` word for word:
*"to read and write information that is only accessible to the app itself"* [3]. Chalk has no
App Group (no entitlements file exists), so `1C8F.1` does not apply, and `C56D.1` is for
third-party SDKs only [3]. Chalk never reads a key another app or the system wrote, which is the
one thing `CA92.1` forbids.

**Nothing else matches.** `ChalkStore.swift` calls `FileManager.createDirectory`, which is not
on the list. The store itself is SwiftData, and Apple's rule covers *"the API in your app's
code"* [2]; what Apple's frameworks do internally is not Chalk's declaration. The test target
also uses `UserDefaults`, but it is not shipped.

## 2. What the §15 features will add

**§15.2 units in `UserDefaults` — nothing new.** One dictionary per category, listing the
reasons [2][7]. The units are app-private like the zones, so `CA92.1` already covers them.

**§15.1 backup and restore — nothing, if the date lives in the file.** Writing the backup to a
temporary file and handing it to the share sheet, and reading one back through a document
picker, use no listed API: `Data(contentsOf:)`, `write(to:)`, `ShareLink`, `fileImporter` and
`Transferable` are not in any category [3]. The one risk is the restore confirmation, which says
*how old the backup is* (SPEC §15.1, ADR-0010). There are two ways to get that date:

- **A date field inside the backup** (for example an `exportedAt` value written when it is made).
  No required-reason API. It also survives AirDrop, Files and Mail copies, which can rewrite a
  file's timestamps, so it is the date the person actually means.
- **The file's own timestamp**, via `resourceValues(forKeys: [.creationDateKey])`,
  `.contentModificationDateKey` or `FileManager.attributesOfItem` → `.creationDate` /
  `.modificationDate`. That is `NSPrivacyAccessedAPICategoryFileTimestamp` [3]. For a file the
  person picked, the reason is **`3B52.1`** (*"files or directories that the user specifically
  granted access to, such as using a document picker"*); `DDA9.1` (*"to display file timestamps
  to the person"*) also fits, since the date is shown. `C617.1` covers only files inside the
  app's own container, which a picked backup is not.

The recommendation is the first: put the date in the file. That keeps the manifest at one entry
and makes the date right. If the build ticket for backup reads file metadata anyway, it must add
the file-timestamp dictionary with `3B52.1` in the same PR.

**§15.5 Spotlight and App Shortcuts — nothing, as long as they live in the app target.** Core
Spotlight and App Intents are not in any category [3]. If a later feature moves code into an
extension that shares data with the app (a widget, which §15.7 parks, or an App Intents
extension), that needs an App Group, and the shared `UserDefaults` would then need **`1C8F.1`**
alongside `CA92.1` [3]. The extension's own bundle would need its own manifest, since *"for each
executable … the bundle that includes the executable … needs to include a privacy manifest file
that reports the API"* [2].

**Haptics, the String Catalog, VoiceOver, Dynamic Type** (§15.4, §15.6) use none of the listed
APIs.

## 3. Collected data and tracking: how "none" is declared

**Chalk collects nothing.** Apple's definition: *"'Collect' refers to transmitting data off the
device in a way that allows you and/or your third-party partners to access it for a period longer
than what is necessary to service the transmitted request in real time,"* and *"data that is
processed only on device is not 'collected' and does not need to be disclosed"* [8]. Chalk has no
backend, no accounts, no analytics and no network code. A backup the person shares through the
share sheet goes where they send it, never to the developer, so it is not collection either.
(Apple's page does not address user-initiated export directly; this reading follows from the
definition, which turns on *you and/or your third-party partners* gaining access.)

**Tracking.** *"Tracking" refers to linking data collected from your app … with Third-Party Data
for targeted advertising or advertising measurement purposes, or sharing data … with a data
broker* [8]. Chalk does neither.

**How to write "none" in the manifest:**

- `NSPrivacyTracking` → `false`, and **no** `NSPrivacyTrackingDomains`. TN3181: *"set the value
  of `NSPrivacyTracking` to `false` and remove `NSPrivacyTrackingDomains`"* is valid, and
  `false` with entries in `NSPrivacyTrackingDomains` is invalid [5]. Removing both keys is also
  valid [5]; keeping `false` is chosen because it states the answer rather than leaving it
  implied.
- `NSPrivacyCollectedDataTypes` → **omit it.** Apple says to add a dictionary *"for each type of
  data your app … collects"* [4], so no data means no dictionaries. TN3181 does not list an empty
  collected-data array as invalid, but for every other array key it says an empty array is
  invalid and the fix is to remove the key [5]. Omitting is the form that cannot trip validation.
- Every key in the file must be one Apple expects, because *"App Store Connect rejects app
  submissions that include invalid privacy manifest files"* [6], and since 12 November 2024 every
  submission must contain a valid one [5].

**How this lines up with the App Store label.** In App Store Connect → App Privacy → Get Started,
choose *"No, we do not collect data from this app"* and Save; no further questions follow [9].
The manifest's empty collection and the "No" answer say the same thing. The manifest does not
fill the label in for you: Xcode's privacy report is something to *"refer to … when you provide
your app's privacy details in App Store Connect"* [4], and the answers are typed by hand.

## 4. Third-party SDKs: none

Confirmed against the project, not presumed:

- `Chalk/Chalk.xcodeproj/project.pbxproj` has no `XCRemoteSwiftPackageReference`,
  `XCLocalSwiftPackageReference` or `packageProductDependencies`, and both
  `PBXFrameworksBuildPhase` sections have empty `files`.
- There is no `Package.swift`, `Package.resolved`, `.xcframework`, `Podfile` or `Cartfile`.
- The only imports across all 149 Swift files are `Foundation`, `SwiftUI`, `SwiftData`,
  `Observation`, `Charts`, `CoreTransferable` (app) and `Testing` (tests) — all Apple.

So Apple's list of *"SDKs that require a privacy manifest and signature"* [1] is moot, and the
app's manifest is the only one in the bundle. If a package is ever added, its own manifest
covers its own API use: *"Your third-party SDK can't rely on the privacy manifest files for apps
that link the third-party SDK"* [2].

## 5. Where the file goes

- **`Chalk/Chalk/PrivacyInfo.xcprivacy`**, named exactly that: *"this is the required file name
  for bundled privacy manifests"* [1]. Xcode's File → New File → Resource → **App Privacy** creates
  it with the target ticked [1].
- It must be in the **app target's resources**, ending up at `Chalk.app/PrivacyInfo.xcprivacy`,
  the root of an iOS app bundle [6]. Chalk's project uses a `PBXFileSystemSynchronizedRootGroup`
  for `Chalk/Chalk/`, so a file dropped there joins the target without a `project.pbxproj` edit.
- Not in `ChalkTests`; the test bundle is not shipped.

## 6. Checking it before submission

In order of how early each check can run:

1. **`plutil -lint Chalk/Chalk/PrivacyInfo.xcprivacy`** — confirms a well-formed plist [5]. The
   XML in the bottom line passes it. Cheap enough to add to `scripts/check`.
2. **It is in the built bundle.** After `scripts/check`,
   `build/DerivedData/Build/Products/Debug-iphonesimulator/Chalk.app/PrivacyInfo.xcprivacy`
   must exist. A test or a line in `scripts/check` can assert it, which turns *"you need to add
   the privacy manifest file to your target's resources"* [1] into a CI failure rather than an
   upload email.
3. **Xcode's privacy report.** Product → Archive; in the Organizer, Control-click the archive →
   **Generate Privacy Report**; save it and open the PDF [4]. Apple describes it as aggregating
   *"the privacy manifests from your app and the third-party SDKs it links to"*, organized like
   the Privacy Nutrition Labels [4]. For Chalk it should show no collected data and no tracking.
   Note what it does **not** do: Apple documents it as a summary of collected data and tracking,
   not as a check of the code's required-reason API use against the manifest. A missing
   `UserDefaults` entry would not show up here. **UNVERIFIED:** whether Archive and
   Generate Privacy Report work under the free personal team Chalk is built with today. Apple's
   page states no account requirement; try it once on the next build.
4. **App Store Connect, at upload.** The authoritative check. For an undeclared required-reason
   API, *"Apple sends you an email reminding you to add the reason"*, and since 1 May 2024 such
   apps *"aren't accepted by App Store Connect"* [2]. An invalid manifest gets an `ITMS-91056`
   email naming the file [5]. (Developers report the missing-reason email as `ITMS-91053:
   Missing API declaration`; that code is from forum reports, not from Apple's documentation.)
   This needs the paid membership, so it cannot run before *the day*; checks 1–3 are what make
   it a formality.

The manifest can be reviewed in raw form in Xcode with Editor → **Raw Keys and Values**, which
shows the `NS…` keys above rather than their display names [7].

## 7. Open points, none blocking the build ticket

- **Where the backup's date comes from** (§2). Recommended: inside the file. This is an
  implementation choice for the backup ticket, but it decides whether the manifest gains a
  second entry, so the backup ticket should say which.
- **A privacy policy URL is required for every iOS app** in App Store Connect [9], even one that
  collects nothing. That is part of the store listing (§15.6), not the manifest, and Chalk has no
  website. Where that page lives is not yet decided.

## Sources

1. [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) — Apple Developer Documentation.
2. [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) — Apple Developer Documentation.
3. [NSPrivacyAccessedAPIType](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) — the categories, their APIs, and every reason code.
4. [Describing data use in privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests) — collected data keys, and "Create your app's privacy report".
5. [TN3181: Debugging an invalid privacy manifest](https://developer.apple.com/documentation/technotes/tn3181-debugging-invalid-privacy-manifest).
6. [Adding a privacy manifest to your app or third-party SDK](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk).
7. [TN3183: Adding required reason API entries to your privacy manifest](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).
8. [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/) — definitions of *collect* and *tracking*.
9. [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/) — App Store Connect Help.
