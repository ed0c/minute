import SwiftUI

struct SessionVocabularyPopover: View {
    @Binding var termsInput: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Vocabulary")
                .font(.system(size: 14, weight: .semibold))

            Text("Add meeting-specific names, acronyms, and product terms.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextEditor(text: $termsInput)
                .font(.body)
                .frame(width: 280, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.2))
                )
                .accessibilityLabel(Text("Custom vocabulary terms"))

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
