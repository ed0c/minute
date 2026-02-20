import MinuteCore
import SwiftUI

struct VocabularyBoostingSection: View {
    @ObservedObject var model: ModelsSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable vocabulary boosting", isOn: $model.vocabularyBoostingEnabled)

            VStack(alignment: .leading, spacing: 6) {
                Text("Terms")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $model.vocabularyBoostingTermsInput)
                    .font(.body)
                    .frame(minHeight: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.2))
                    )
                    .accessibilityLabel(Text("Vocabulary terms"))
                    .accessibilityHint(Text("Comma or newline separated terms and phrases."))
            }

            Picker("Strength", selection: $model.vocabularyBoostingStrength) {
                ForEach(VocabularyBoostingStrength.allCases) { strength in
                    Text(strength.displayName).tag(strength)
                }
            }
            .pickerStyle(.segmented)

            Text(model.vocabularyHintText)
                .minuteCaption()

            if model.showsVocabularyReadinessRow, let message = model.vocabularyReadinessMessage {
                HStack(alignment: .center, spacing: 10) {
                    StatusIcon(state: .attention)
                    Text(message)
                        .minuteCaption()
                    Spacer()
                    Button("Download Models") {
                        model.startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
