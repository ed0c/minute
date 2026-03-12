import MinuteCore
import SwiftUI

struct MainSessionView: View {
    @ObservedObject var model: MeetingPipelineViewModel
    @ObservedObject var notesModel: MeetingNotesBrowserViewModel
    var bottomInset: CGFloat
    let screenContextEnabled: Bool
    let isDropTargeted: Bool
    let dropErrorMessage: String?
    let onUploadTap: () -> Void

    var body: some View {
        RecordingSessionCardView(
            model: model,
            bottomInset: bottomInset,
            screenContextEnabled: screenContextEnabled,
            isDropTargeted: isDropTargeted,
            dropErrorMessage: dropErrorMessage,
            onUploadTap: onUploadTap
        )
    }
}

struct RecordingSessionCardView: View {
    @ObservedObject var model: MeetingPipelineViewModel
    let bottomInset: CGFloat
    let screenContextEnabled: Bool
    let isDropTargeted: Bool
    let dropErrorMessage: String?
    let onUploadTap: () -> Void

    @State private var isScreenContextPopoverPresented = false
    @State private var isVocabularyPopoverPresented = false

    private var microphoneBinding: Binding<Bool> {
        Binding(
            get: { model.microphoneCaptureEnabled },
            set: { model.setMicrophoneCaptureEnabled($0) }
        )
    }

    private var systemAudioBinding: Binding<Bool> {
        Binding(
            get: { model.systemAudioCaptureEnabled },
            set: { model.setSystemAudioCaptureEnabled($0) }
        )
    }

    private var customVocabularyInputBinding: Binding<String> {
        Binding(
            get: { model.sessionCustomVocabularyInput },
            set: { model.setSessionCustomVocabularyInput($0) }
        )
    }

    private var vocabularyButtonSymbolName: String {
        model.sessionVocabularyMode == .custom ? "bubble.right.fill" : "bubble.right"
    }

    private var isRecording: Bool {
        if case .recording = model.state { return true }
        return false
    }

    private var isStopping: Bool {
        model.captureState == .stopping
    }

    private var isListening: Bool {
        !isStopping && isRecording && (model.microphoneCaptureEnabled || model.systemAudioCaptureEnabled)
    }

    private var topInset: CGFloat {
        if #available(macOS 26.0, *) {
            12
        } else {
            40
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {

                        if isStopping {
                            Text("Stopping session")
                                .font(.system(size: 20, weight: .semibold))
                                .tracking(-0.4)
                                .foregroundStyle(Color.minuteTextPrimary)
                            Text("Finalizing audio capture...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.minuteTextSecondary)
                        } else if isRecording {
                            Text("Session in progress")
                                .font(.system(size: 20, weight: .semibold))
                                .tracking(-0.4)
                                .foregroundStyle(Color.minuteTextPrimary)
                            Text("You can continue editing your session settings.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.minuteTextSecondary)
                        } else {
                            Text("New Session")
                                .font(.system(size: 20, weight: .semibold))
                                .tracking(-0.4)
                                .foregroundStyle(Color.minuteTextPrimary)
                            Text("Configure your session and start recording.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.minuteTextSecondary)
                        }

                        if let dropErrorMessage {
                            Text(dropErrorMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.9))
                                .accessibilityLabel(Text("Import error"))
                                .accessibilityValue(Text(dropErrorMessage))
                                .transition(.opacity)
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Language Processing")
                            .minuteFootnote()
                            .textCase(.uppercase)

                        HStack(alignment: .center, spacing: 8) {
                            Menu {
                                Button(model.autoToEnglishOptionTitle) {
                                    model.languageProcessing = .autoToEnglish
                                }
                                Button(model.autoToPickedLanguageOptionTitle) {
                                    model.languageProcessing = .autoPreserve
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "globe")
                                        .foregroundStyle(Color.green)
                                    Text(model.selectedLanguageProcessingTitle)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Color.minuteTextPrimary)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.minuteTextSecondary)
                                }
                            }
                            .menuStyle(.borderlessButton)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.minuteSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.minuteOutline, lineWidth: 1)
                            )
                            .fixedSize(horizontal: true, vertical: false)
                            .help(model.selectedLanguageProcessingDetailText)
                            .accessibilityLabel(Text("Language Processing"))
                            .accessibilityValue(Text(model.selectedLanguageProcessingTitle))
                            .accessibilityHint(Text(model.selectedLanguageProcessingDetailText))

                            if model.showsSessionVocabularyPopoverButton {
                                Button {
                                    isVocabularyPopoverPresented = true
                                } label: {
                                    Image(systemName: vocabularyButtonSymbolName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(
                                            model.sessionVocabularyMode == .custom
                                                ? Color.minuteGlow
                                                : Color.minuteTextSecondary
                                        )
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.minuteSurface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.minuteOutline, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Vocabulary list: \(model.sessionVocabularyListLabel)")
                                .accessibilityLabel(Text("Vocabulary terms"))
                                .accessibilityValue(Text(model.sessionVocabularyListLabel))
                                .popover(isPresented: $isVocabularyPopoverPresented, arrowEdge: .bottom) {
                                    SessionVocabularyPopover(
                                        termsInput: customVocabularyInputBinding,
                                        settingsTerms: model.globalVocabularyTerms,
                                        hintText: model.sessionVocabularyHintText,
                                        listLabel: model.sessionVocabularyListLabel
                                    )
                                }
                            }
                        }

                        if let message = model.sessionVocabularyWarningMessage, !message.isEmpty {
                            Text(message)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.orange)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Meeting Type")
                        .minuteFootnote()
                        .textCase(.uppercase)

                    MeetingTypeSelectionWrapLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(model.meetingTypeOptions, id: \.typeId) { definition in
                            MeetingTypeSelectionChip(
                                title: definition.displayName,
                                symbolName: MeetingTypeSelectionStyle.symbolName(for: definition),
                                symbolTint: MeetingTypeSelectionStyle.symbolTint(for: definition),
                                isSelected: model.selectedMeetingTypeID == definition.typeId
                            ) {
                                model.selectedMeetingTypeID = definition.typeId
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("Meeting Type"))
                    .accessibilityValue(Text(model.selectedMeetingTypeDisplayName))

                    Text(model.selectedMeetingTypeStatusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.minuteTextSecondary)

                    if let warning = model.selectedMeetingTypeWarningMessage {
                        Text(warning)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    GridRow {
                        Text("Audio Channels")
                            .minuteFootnote()
                            .textCase(.uppercase)
                            .gridCellColumns(2)

                        Text("Screen Context")
                            .minuteFootnote()
                            .textCase(.uppercase)

                        Text("File Processing")
                            .minuteFootnote()
                            .textCase(.uppercase)
                    }

                    GridRow {
                        CaptureSourceCard(
                            title: "Microphone",
                            systemImage: "mic.fill",
                            tint: Color.accentColor,
                            isOn: microphoneBinding.wrappedValue,
                            isEnabled: true,
                            action: { microphoneBinding.wrappedValue.toggle() }
                        )

                        CaptureSourceCard(
                            title: "System",
                            systemImage: "speaker.wave.2.fill",
                            tint: Color.pink,
                            isOn: systemAudioBinding.wrappedValue,
                            isEnabled: true,
                            action: { systemAudioBinding.wrappedValue.toggle() }
                        )

                        CaptureSourceCard(
                            title: "Screen Record",
                            systemImage: model.hasScreenCaptureSelection ? "display" : "rectangle.slash",
                            tint: Color.minuteGlow,
                            isOn: model.screenCaptureEnabled && model.hasScreenCaptureSelection,
                            isEnabled: screenContextEnabled,
                            action: { isScreenContextPopoverPresented = true }
                        )
                        .popover(isPresented: $isScreenContextPopoverPresented, arrowEdge: .bottom) {
                            ScreenContextWindowPickerPopover(
                                currentSelection: model.currentScreenCaptureSelection,
                                onDismiss: {
                                    isScreenContextPopoverPresented = false
                                },
                                onSelect: { selection in
                                    if let selection {
                                        model.setScreenCaptureSelection(selection)
                                        model.setScreenCaptureEnabled(true)
                                    } else {
                                        model.setScreenCaptureSelection(nil)
                                    }
                                    isScreenContextPopoverPresented = false
                                }
                            )
                        }

                        FileProcessingCard(
                            isHighlighted: isDropTargeted,
                            isEnabled: model.state.canImportMedia,
                            action: onUploadTap
                        )
                    }

                    GridRow {
                        Text("")
                        Text("")

                        Text(model.screenCaptureSelectionDisplayText ?? "None")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.minuteTextSecondary)
                            .lineLimit(1)
                            .accessibilityLabel(Text("Selected window"))
                            .accessibilityValue(Text(model.screenCaptureSelectionDisplayText ?? "None"))

                        Text("")
                    }
                }
                .frame(maxWidth: .infinity)

            }
            .padding(.horizontal, 22)
            .padding(.top, topInset)

            Group {
                if case .recording(let session) = model.state {
                    RecordingSessionView(
                        session: session,
                        levels: model.audioLevelSamples,
                        isListening: isListening
                    )
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.minuteTextSecondary)

                        Text(model.currentStatusLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.minuteTextPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 22 + bottomInset)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

}

struct RecordingSessionView: View {
    let session: RecordingSession
    let levels: [CGFloat]
    let isListening: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            Text(isListening ? "Listening" : "Not listening (mic and system audio are off)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isListening ? Color.minuteTextSecondary : Color.orange)

            Spacer(minLength: 0)

            WaveformRibbonView(levels: levels)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 180)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct CaptureSourceCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.minuteSurfaceStrong)
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isEnabled ? (isOn ? tint : Color.minuteTextMuted) : Color.minuteTextMuted)
                }
                .frame(width: 46, height: 46)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isEnabled ? (isOn ? tint : Color.minuteTextSecondary) : Color.minuteTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isEnabled ? (isOn ? Color.minuteSurfaceStrong : Color.minuteSurface) : Color.minuteSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isEnabled ? (isOn ? tint.opacity(0.55) : Color.minuteOutline) : Color.minuteOutline,
                        lineWidth: isOn ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct FileProcessingCard: View {
    let isHighlighted: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.minuteSurfaceStrong)
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isEnabled ? Color.minuteGlow : Color.minuteTextMuted)
                }
                .frame(width: 46, height: 46)

                Text("Upload File")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.minuteTextSecondary : Color.minuteTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isEnabled ? (isHighlighted ? Color.minuteSurfaceStrong : Color.minuteSurface) : Color.minuteSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isEnabled ? (isHighlighted ? Color.minuteGlow.opacity(0.55) : Color.minuteOutline) : Color.minuteOutline,
                        lineWidth: isHighlighted ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        .accessibilityLabel(Text("Upload recording file"))
        .accessibilityHint(Text("Browse for audio or video to process."))
    }
}

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.red.opacity(0.5), lineWidth: 6)
                    .scaleEffect(isPulsing ? 1.5 : 0.6)
                    .opacity(isPulsing ? 0 : 0.6)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

struct WaveformRibbonView: View {
    let levels: [CGFloat]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let count = max(levels.count, 1)
                let midY = size.height / 2
                let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate)

                var path = Path()
                for index in 0..<count {
                    let x = size.width * CGFloat(index) / CGFloat(max(count - 1, 1))
                    let level = min(max(levels[safe: index] ?? 0, 0), 1)
                    let wave = sin(CGFloat(index) * 0.35 + phase) * level
                    let y = midY + wave * midY * 0.9
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 8))
                    layer.stroke(
                        path,
                        with: .linearGradient(
                            MinuteTheme.waveformGradient,
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: 0)
                        ),
                        lineWidth: 10
                    )
                }

                context.stroke(
                    path,
                    with: .linearGradient(
                        MinuteTheme.waveformGradient,
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    lineWidth: 3
                )
            }
        }
    }
}

private extension Array where Element == CGFloat {
    subscript(safe index: Int) -> CGFloat? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview(traits: .fixedLayout(width: 1024, height: 800)) {
    RecordingSessionCardView(
        model: MeetingPipelineViewModel.live(),
        bottomInset: 104,
        screenContextEnabled: true,
        isDropTargeted: false,
        dropErrorMessage: nil,
        onUploadTap: {}
    )
    .frame(width: 1024, height: 800)
    .background(MinuteTheme.windowBackground)
}
