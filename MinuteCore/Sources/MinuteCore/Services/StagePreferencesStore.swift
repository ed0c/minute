import Foundation

public final class StagePreferencesStore {
    private let defaults: UserDefaults
    private let meetingTypeKey: String
    private let meetingTypeIDKey: String
    private let languageProcessingKey: String
    private let microphoneEnabledKey: String
    private let systemAudioEnabledKey: String

    public init(
        defaults: UserDefaults = .standard,
        meetingTypeKey: String = AppConfiguration.Defaults.stageMeetingTypeKey,
        meetingTypeIDKey: String = AppConfiguration.Defaults.stageMeetingTypeIDKey,
        languageProcessingKey: String = AppConfiguration.Defaults.stageLanguageProcessingKey,
        microphoneEnabledKey: String = AppConfiguration.Defaults.stageMicrophoneEnabledKey,
        systemAudioEnabledKey: String = AppConfiguration.Defaults.stageSystemAudioEnabledKey
    ) {
        self.defaults = defaults
        self.meetingTypeKey = meetingTypeKey
        self.meetingTypeIDKey = meetingTypeIDKey
        self.languageProcessingKey = languageProcessingKey
        self.microphoneEnabledKey = microphoneEnabledKey
        self.systemAudioEnabledKey = systemAudioEnabledKey
    }

    public func load() -> StagePreferences {
        let meetingTypeID = resolveMeetingTypeIDForLoad()

        let languageRaw = defaults.string(forKey: languageProcessingKey)
        let languageProcessing = LanguageProcessingProfile.resolved(from: languageRaw)

        let microphoneEnabled = defaults.object(forKey: microphoneEnabledKey) as? Bool
            ?? AppConfiguration.Defaults.defaultStageMicrophoneEnabled
        let systemAudioEnabled = defaults.object(forKey: systemAudioEnabledKey) as? Bool
            ?? AppConfiguration.Defaults.defaultStageSystemAudioEnabled

        return StagePreferences(
            meetingTypeID: meetingTypeID,
            languageProcessing: languageProcessing,
            microphoneEnabled: microphoneEnabled,
            systemAudioEnabled: systemAudioEnabled
        )
    }

    public func save(_ preferences: StagePreferences) {
        let normalizedTypeID = normalizedMeetingTypeID(preferences.meetingTypeID)
        defaults.set(normalizedTypeID, forKey: meetingTypeIDKey)
        if let builtIn = MeetingType(rawValue: normalizedTypeID) {
            defaults.set(builtIn.rawValue, forKey: meetingTypeKey)
        } else {
            defaults.removeObject(forKey: meetingTypeKey)
        }
        defaults.set(preferences.languageProcessing.rawValue, forKey: languageProcessingKey)
        defaults.set(preferences.microphoneEnabled, forKey: microphoneEnabledKey)
        defaults.set(preferences.systemAudioEnabled, forKey: systemAudioEnabledKey)
    }

    public func clear() {
        defaults.removeObject(forKey: meetingTypeIDKey)
        defaults.removeObject(forKey: meetingTypeKey)
        defaults.removeObject(forKey: languageProcessingKey)
        defaults.removeObject(forKey: microphoneEnabledKey)
        defaults.removeObject(forKey: systemAudioEnabledKey)
    }

    private func resolveMeetingTypeIDForLoad() -> String {
        let storedID = defaults.string(forKey: meetingTypeIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !storedID.isEmpty {
            return storedID
        }

        let legacyRaw = defaults.string(forKey: meetingTypeKey) ?? ""
        if let legacyMeetingType = MeetingType(rawValue: legacyRaw) {
            let migrated = legacyMeetingType.rawValue
            defaults.set(migrated, forKey: meetingTypeIDKey)
            return migrated
        }

        return AppConfiguration.Defaults.defaultStageMeetingTypeID
    }

    private func normalizedMeetingTypeID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AppConfiguration.Defaults.defaultStageMeetingTypeID
        }
        return trimmed
    }
}
