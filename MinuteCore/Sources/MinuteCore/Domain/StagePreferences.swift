import Foundation

public struct StagePreferences: Codable, Sendable, Equatable {
    public var meetingTypeID: String
    public var languageProcessing: LanguageProcessingProfile
    public var microphoneEnabled: Bool
    public var systemAudioEnabled: Bool

    public var meetingType: MeetingType {
        get {
            MeetingType(rawValue: meetingTypeID) ?? AppConfiguration.Defaults.defaultStageMeetingType
        }
        set {
            meetingTypeID = newValue.rawValue
        }
    }

    public init(
        meetingTypeID: String,
        languageProcessing: LanguageProcessingProfile,
        microphoneEnabled: Bool,
        systemAudioEnabled: Bool
    ) {
        let normalizedID = meetingTypeID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.meetingTypeID = normalizedID.isEmpty
            ? AppConfiguration.Defaults.defaultStageMeetingTypeID
            : normalizedID
        self.languageProcessing = languageProcessing
        self.microphoneEnabled = microphoneEnabled
        self.systemAudioEnabled = systemAudioEnabled
    }

    public init(
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        microphoneEnabled: Bool,
        systemAudioEnabled: Bool
    ) {
        self.init(
            meetingTypeID: meetingType.rawValue,
            languageProcessing: languageProcessing,
            microphoneEnabled: microphoneEnabled,
            systemAudioEnabled: systemAudioEnabled
        )
    }

    public static var `default`: StagePreferences {
        StagePreferences(
            meetingTypeID: AppConfiguration.Defaults.defaultStageMeetingTypeID,
            languageProcessing: AppConfiguration.Defaults.defaultStageLanguageProcessing,
            microphoneEnabled: AppConfiguration.Defaults.defaultStageMicrophoneEnabled,
            systemAudioEnabled: AppConfiguration.Defaults.defaultStageSystemAudioEnabled
        )
    }
}
