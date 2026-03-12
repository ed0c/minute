import MinuteCore
import SwiftUI

struct SummarizationContextWindowPicker: View {
    let presets: [SummarizationContextWindowPreset]
    let recommendedPreset: SummarizationContextWindowPreset
    @Binding var selection: SummarizationContextWindowPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summarization context window")
                .minuteRowTitle()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selection.displayName)
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Text(tokenCountLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                SettingsSteppedControl(
                    stepLabels: presets.map(\.shortDisplayName),
                    selectedIndex: selectedIndexBinding
                )
            }

            Text(selection.detailText)
                .minuteCaption()

            Text(recommendationText)
                .minuteCaption()
        }
        .gridCellColumns(2)
    }

    private var selectedIndexBinding: Binding<Int> {
        Binding(
            get: { selectedIndex },
            set: { index in
                guard presets.indices.contains(index) else { return }
                selection = presets[index]
            }
        )
    }

    private var recommendationText: String {
        "Default on this Mac: \(recommendedPreset.displayName)."
    }

    private var selectedIndex: Int {
        presets.firstIndex(of: selection) ?? 0
    }

    private var tokenCountLabel: String {
        "\(selection.requestedContextTokens ?? recommendedPreset.requestedContextTokens ?? 8_192) tokens"
    }
}
