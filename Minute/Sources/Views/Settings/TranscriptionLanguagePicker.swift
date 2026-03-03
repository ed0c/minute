import MinuteCore
import SwiftUI

struct TranscriptionLanguagePicker: View {
    let languages: [TranscriptionLanguage]
    @Binding var selection: TranscriptionLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription language")
                .minuteRowTitle()

            Menu {
                ForEach(languages) { language in
                    Button {
                        selection = language
                    } label: {
                        if language == selection {
                            Label(language.displayName, systemImage: "checkmark")
                        } else {
                            Text(language.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection.displayName)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .minuteDropdownStyle()
            }
            .menuStyle(.borderlessButton)

            Text(captionText)
                .minuteCaption()
        }
    }

    private var captionText: String {
        if selection == .auto {
            return "Whisper will auto-detect the spoken language."
        }
        return "Force Whisper to transcribe in \(selection.displayName)."
    }
}
