import Foundation
import Testing

/// The privacy manifest Chalk ships in its bundle (SPEC §15.6). **It declares only
/// `UserDefaults`, for the app's own use (`CA92.1`)**, and tracks and collects nothing.
@Suite("Privacy manifest")
struct PrivacyManifestTests {

    @Test("The app bundles a manifest declaring only UserDefaults, for the app's own use")
    func theManifestDeclaresOnlyUserDefaults() throws {
        // The tests run inside Chalk.app, so the main bundle is the app's, not the test bundle.
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let manifest = try #require(
            PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any]
        )

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect(manifest["NSPrivacyTrackingDomains"] == nil)
        #expect(manifest["NSPrivacyCollectedDataTypes"] == nil)

        let accessed = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(accessed.count == 1)
        let entry = try #require(accessed.first)
        #expect(entry["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(entry["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }
}
