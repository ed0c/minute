import Foundation
import Testing
@testable import MinuteCore

struct StagePreferencesStoreMigrationTests {
    @Test
    func load_whenLegacyMeetingTypeKeyExists_migratesToMeetingTypeID() {
        let suite = "StagePreferencesStoreMigrationTests.legacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(MeetingType.designReview.rawValue, forKey: "legacyMeetingType")

        let store = StagePreferencesStore(
            defaults: defaults,
            meetingTypeKey: "legacyMeetingType",
            meetingTypeIDKey: "meetingTypeID",
            languageProcessingKey: "language",
            microphoneEnabledKey: "mic",
            systemAudioEnabledKey: "system"
        )

        let loaded = store.load()

        expectEqual(loaded.meetingTypeID, MeetingType.designReview.rawValue)
        expectEqual(defaults.string(forKey: "meetingTypeID"), MeetingType.designReview.rawValue)
    }

    @Test
    func save_persistsStableMeetingTypeID() {
        let suite = "StagePreferencesStoreMigrationTests.save.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = StagePreferencesStore(
            defaults: defaults,
            meetingTypeKey: "legacyMeetingType",
            meetingTypeIDKey: "meetingTypeID",
            languageProcessingKey: "language",
            microphoneEnabledKey: "mic",
            systemAudioEnabledKey: "system"
        )

        store.save(
            StagePreferences(
                meetingTypeID: "custom-discovery",
                languageProcessing: .autoPreserve,
                microphoneEnabled: false,
                systemAudioEnabled: true
            )
        )

        expectEqual(defaults.string(forKey: "meetingTypeID"), "custom-discovery")
    }

    @Test
    func load_whenMeetingTypeIDMissingOrInvalid_defaultsToAutodetectID() {
        let suite = "StagePreferencesStoreMigrationTests.invalid.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = StagePreferencesStore(
            defaults: defaults,
            meetingTypeKey: "legacyMeetingType",
            meetingTypeIDKey: "meetingTypeID",
            languageProcessingKey: "language",
            microphoneEnabledKey: "mic",
            systemAudioEnabledKey: "system"
        )

        defaults.set("  ", forKey: "meetingTypeID")
        defaults.set("invalid", forKey: "legacyMeetingType")

        let loaded = store.load()

        expectEqual(loaded.meetingTypeID, MeetingType.autodetect.rawValue)
        expectEqual(loaded.meetingType, .autodetect)
    }

    @Test
    func load_whenNoKeysExist_returnsDefaults() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = StagePreferencesStore(defaults: defaults)

        let loaded = store.load()

        expectEqual(loaded, .default)
    }
}
