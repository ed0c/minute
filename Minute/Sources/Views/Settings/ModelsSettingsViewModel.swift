import Combine
import Foundation
import MinuteCore

@MainActor
final class ModelsSettingsViewModel: ObservableObject {
    enum State: Equatable {
        case checking
        case ready
        case needsDownload(message: String?)
        case downloading(progress: ModelDownloadProgress?)
    }

    @Published private(set) var state: State = .checking
    @Published var selectedSummarizationModelID: String {
        didSet {
            guard oldValue != selectedSummarizationModelID else { return }
            summarizationModelStore.setSelectedModelID(selectedSummarizationModelID)
            refresh()
        }
    }
    @Published var selectedTranscriptionBackendID: String {
        didSet {
            guard oldValue != selectedTranscriptionBackendID else { return }
            transcriptionBackendStore.setSelectedBackendID(selectedTranscriptionBackendID)
            refresh()
        }
    }
    @Published var selectedTranscriptionModelID: String {
        didSet {
            guard oldValue != selectedTranscriptionModelID else { return }
            transcriptionModelStore.setSelectedModelID(selectedTranscriptionModelID)
            refresh()
        }
    }
    @Published var selectedFluidAudioModelID: String {
        didSet {
            guard oldValue != selectedFluidAudioModelID else { return }
            fluidAudioModelStore.setSelectedModelID(selectedFluidAudioModelID)
            refresh()
        }
    }
    @Published var vocabularyBoostingEnabled: Bool {
        didSet {
            guard oldValue != vocabularyBoostingEnabled else { return }
            persistVocabularySettings()
        }
    }
    @Published var vocabularyBoostingTermsInput: String {
        didSet {
            guard oldValue != vocabularyBoostingTermsInput else { return }
            persistVocabularySettings()
        }
    }
    @Published var vocabularyBoostingStrength: VocabularyBoostingStrength {
        didSet {
            guard oldValue != vocabularyBoostingStrength else { return }
            persistVocabularySettings()
        }
    }

    private let modelManager: any ModelManaging
    private let vocabularySettingsStore: any VocabularyBoostingSettingsStoring
    private let summarizationModelStore: SummarizationModelSelectionStore
    private let transcriptionModelStore: TranscriptionModelSelectionStore
    private let transcriptionBackendStore: TranscriptionBackendSelectionStore
    private let fluidAudioModelStore: FluidAudioASRModelSelectionStore
    private var modelTask: Task<Void, Never>?
    private var modelsValidationTask: Task<Void, Never>?
    private var isRestoringVocabularySettings = false
    private var lastModelValidation = ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])

    init(
        modelManager: (any ModelManaging)? = nil,
        summarizationModelStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore(),
        transcriptionModelStore: TranscriptionModelSelectionStore = TranscriptionModelSelectionStore(),
        transcriptionBackendStore: TranscriptionBackendSelectionStore = TranscriptionBackendSelectionStore(),
        fluidAudioModelStore: FluidAudioASRModelSelectionStore = FluidAudioASRModelSelectionStore(),
        vocabularySettingsStore: (any VocabularyBoostingSettingsStoring)? = nil
    ) {
        self.summarizationModelStore = summarizationModelStore
        self.transcriptionModelStore = transcriptionModelStore
        self.transcriptionBackendStore = transcriptionBackendStore
        self.fluidAudioModelStore = fluidAudioModelStore
        self.vocabularySettingsStore = vocabularySettingsStore ?? VocabularyBoostingSettingsStore()
        self.modelManager = modelManager ?? DefaultModelManager(
            selectionStore: summarizationModelStore,
            transcriptionSelectionStore: transcriptionModelStore,
            transcriptionBackendStore: transcriptionBackendStore,
            fluidAudioModelStore: fluidAudioModelStore
        )
        let selectedModel = summarizationModelStore.selectedModel()
        self.selectedSummarizationModelID = selectedModel.id
        if summarizationModelStore.selectedModelID() != selectedModel.id {
            summarizationModelStore.setSelectedModelID(selectedModel.id)
        }
        let selectedBackend = transcriptionBackendStore.selectedBackend()
        self.selectedTranscriptionBackendID = selectedBackend.id
        if transcriptionBackendStore.selectedBackendID() != selectedBackend.id {
            transcriptionBackendStore.setSelectedBackendID(selectedBackend.id)
        }
        let selectedTranscription = transcriptionModelStore.selectedModel()
        self.selectedTranscriptionModelID = selectedTranscription.id
        if transcriptionModelStore.selectedModelID() != selectedTranscription.id {
            transcriptionModelStore.setSelectedModelID(selectedTranscription.id)
        }
        let selectedFluidModel = fluidAudioModelStore.selectedModel()
        self.selectedFluidAudioModelID = selectedFluidModel.id
        if fluidAudioModelStore.selectedModelID() != selectedFluidModel.id {
            fluidAudioModelStore.setSelectedModelID(selectedFluidModel.id)
        }
        let vocabularySettings = self.vocabularySettingsStore.load()
        self.vocabularyBoostingEnabled = vocabularySettings.enabled
        self.vocabularyBoostingTermsInput = vocabularySettings.editorInput
        self.vocabularyBoostingStrength = vocabularySettings.strength
        refresh()
    }

    deinit {
        modelTask?.cancel()
        modelsValidationTask?.cancel()
    }

    func refresh() {
        scheduleModelsValidation()
    }

    func startDownload() {
        modelTask?.cancel()
        state = .downloading(progress: ModelDownloadProgress(fractionCompleted: 0, label: "Starting download"))

        modelTask = Task { [weak self] in
            guard let self else { return }

            do {
                let validation = try await modelManager.validateModels()
                if !validation.invalidModelIDs.isEmpty {
                    try await modelManager.removeModels(withIDs: validation.invalidModelIDs)
                }

                try await modelManager.ensureModelsPresent { [weak self] update in
                    Task { @MainActor [weak self] in
                        self?.state = .downloading(progress: update)
                    }
                }

                state = .checking
                await refreshModelsStatus()
            } catch {
                let message = ErrorHandler.userMessage(for: error, fallback: "Failed to download models.")
                state = .needsDownload(message: message)
            }
        }
    }

    private func refreshModelsStatus() async {
        if case .downloading = state {
            return
        }

        guard !Task.isCancelled else { return }

        let wasReady: Bool
        if case .ready = state {
            wasReady = true
        } else {
            wasReady = false
        }

        if !wasReady {
            state = .checking
        }

        do {
            let result = try await modelManager.validateModels()
            guard !Task.isCancelled else { return }
            lastModelValidation = result
            if result.isReady {
                state = .ready
            } else {
                state = .needsDownload(message: modelMessage(from: result))
            }
        } catch {
            guard !Task.isCancelled else { return }
            lastModelValidation = ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
            let message = ErrorHandler.userMessage(for: error, fallback: "Failed to check model status.")
            state = .needsDownload(message: message)
        }
    }

    private func scheduleModelsValidation() {
        modelsValidationTask?.cancel()
        modelsValidationTask = Task { [weak self] in
            guard let self else { return }
            await refreshModelsStatus()
        }
    }

    private func modelMessage(from result: ModelValidationResult) -> String {
        if result.missingModelIDs.isEmpty && result.invalidModelIDs.isEmpty {
            return "Models ready."
        }

        var parts: [String] = []
        if !result.missingModelIDs.isEmpty {
            let names = result.missingModelIDs.map(displayName(for:))
            parts.append("Missing: \(names.joined(separator: ", "))")
        }
        if !result.invalidModelIDs.isEmpty {
            let names = result.invalidModelIDs.map(displayName(for:))
            parts.append("Invalid: \(names.joined(separator: ", "))")
        }
        return parts.joined(separator: " ")
    }

    var summarizationModels: [SummarizationModel] {
        SummarizationModelCatalog.all
    }

    var transcriptionBackends: [TranscriptionBackend] {
        TranscriptionBackend.allCases
    }

    var transcriptionModels: [TranscriptionModel] {
        TranscriptionModelCatalog.all
    }

    var fluidAudioModels: [FluidAudioASRModel] {
        FluidAudioASRModelCatalog.all
    }

    var isFluidAudioSelected: Bool {
        TranscriptionBackend.backend(for: selectedTranscriptionBackendID) == .fluidAudio
    }

    var selectedTranscriptionBackendDisplayName: String {
        TranscriptionBackend.displayName(for: selectedTranscriptionBackendID)
    }

    var vocabularyHintText: String {
        "Use for names, acronyms, product terms."
    }

    var vocabularyBoostingTerms: [String] {
        VocabularyTermEntry.parseFromEditorInput(vocabularyBoostingTermsInput, source: .global)
            .map(\.displayText)
    }

    var vocabularyReadinessStatus: VocabularyReadinessStatus {
        let backend = TranscriptionBackend.backend(for: selectedTranscriptionBackendID)
        guard backend == .fluidAudio else {
            return .unsupported(backend: backend)
        }

        let vocabularyIDs = lastModelValidation.missingModelIDs.filter {
            $0.hasSuffix("-ctc-vocab")
        }
        if !vocabularyIDs.isEmpty {
            let names = vocabularyIDs.map(displayName(for:))
            return .missingModels(
                backend: backend,
                message: "Missing: \(names.joined(separator: ", "))"
            )
        }

        if case .needsDownload(let message) = state {
            return .missingModels(
                backend: backend,
                message: message ?? "Vocabulary models are not ready."
            )
        }

        return .ready(backend: backend)
    }

    var showsVocabularyReadinessRow: Bool {
        isFluidAudioSelected && vocabularyReadinessStatus.state == .missingModels
    }

    var vocabularyReadinessMessage: String? {
        vocabularyReadinessStatus.message
    }

    private func persistVocabularySettings() {
        guard !isRestoringVocabularySettings else { return }
        let settings = GlobalVocabularyBoostingSettings(
            enabled: vocabularyBoostingEnabled,
            strength: vocabularyBoostingStrength,
            terms: vocabularyBoostingTerms
        )
        vocabularySettingsStore.save(settings)
    }

    private func displayName(for id: String) -> String {
        if let summarization = SummarizationModelCatalog.model(for: id) {
            return summarization.displayName
        }
        if let transcription = TranscriptionModelCatalog.model(for: id) {
            return transcription.displayName
        }
        if let fluidAudio = FluidAudioASRModelCatalog.model(for: id) {
            return fluidAudio.displayName
        }
        if id.hasSuffix("-ctc-vocab") {
            return "FluidAudio CTC Vocabulary"
        }
        return id
    }
}
