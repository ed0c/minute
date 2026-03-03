import Foundation

/// Language options for Whisper transcription.
///
/// The language codes match Whisper's supported language identifiers.
/// "auto" enables Whisper's built-in language auto-detection.
public enum TranscriptionLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case auto
    case english = "en"
    case norwegian = "no"
    case swedish = "sv"
    case danish = "da"
    case finnish = "fi"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"
    case russian = "ru"
    case ukrainian = "uk"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"
    case arabic = "ar"
    case hindi = "hi"
    case turkish = "tr"
    case greek = "el"
    case hebrew = "he"
    case czech = "cs"
    case hungarian = "hu"
    case romanian = "ro"
    case thai = "th"
    case vietnamese = "vi"
    case indonesian = "id"
    case malay = "ms"

    public static let defaultSelection: TranscriptionLanguage = .auto

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto:
            return "Auto-detect"
        case .english:
            return "English"
        case .norwegian:
            return "Norwegian"
        case .swedish:
            return "Swedish"
        case .danish:
            return "Danish"
        case .finnish:
            return "Finnish"
        case .german:
            return "German"
        case .french:
            return "French"
        case .spanish:
            return "Spanish"
        case .italian:
            return "Italian"
        case .portuguese:
            return "Portuguese"
        case .dutch:
            return "Dutch"
        case .polish:
            return "Polish"
        case .russian:
            return "Russian"
        case .ukrainian:
            return "Ukrainian"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        case .chinese:
            return "Chinese"
        case .arabic:
            return "Arabic"
        case .hindi:
            return "Hindi"
        case .turkish:
            return "Turkish"
        case .greek:
            return "Greek"
        case .hebrew:
            return "Hebrew"
        case .czech:
            return "Czech"
        case .hungarian:
            return "Hungarian"
        case .romanian:
            return "Romanian"
        case .thai:
            return "Thai"
        case .vietnamese:
            return "Vietnamese"
        case .indonesian:
            return "Indonesian"
        case .malay:
            return "Malay"
        }
    }

    public var detailText: String {
        switch self {
        case .auto:
            return "Let Whisper auto-detect the spoken language"
        default:
            return "\(displayName) (\(rawValue))"
        }
    }

    /// Whether Whisper should auto-detect language or use the specified language.
    public var detectLanguage: Bool {
        self == .auto
    }

    /// The language code to pass to Whisper when `detectLanguage` is false.
    public var whisperLanguageCode: String? {
        detectLanguage ? nil : rawValue
    }

    public static func resolved(from rawValue: String?) -> TranscriptionLanguage {
        guard let rawValue, let value = TranscriptionLanguage(rawValue: rawValue) else {
            return .defaultSelection
        }
        return value
    }
}
