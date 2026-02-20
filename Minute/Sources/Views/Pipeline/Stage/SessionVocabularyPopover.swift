import SwiftUI

struct SessionVocabularyPopover: View {
    @Binding var termsInput: String
    let settingsTerms: [String]
    let hintText: String
    let listLabel: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vocabulary Boosting")
                .font(.system(size: 14, weight: .semibold))

            Text(hintText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("List")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(listLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.minuteSurfaceStrong)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("From Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                if settingsTerms.isEmpty {
                    Text("No global terms configured.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(settingsTerms, id: \.self) { term in
                                Text("• \(term)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.minuteTextPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 76)
                }
            }

            Text("Add meeting-specific terms (comma or new line).")
                .font(.system(size: 12, weight: .semibold))
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
        .frame(width: 340)
    }
}
