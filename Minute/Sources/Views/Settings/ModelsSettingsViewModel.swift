import Combine
import Foundation
import MinuteCore

@MainActor
final class ModelsSettingsViewModel: ObservableObject {
    typealias State = ModelSetupLifecycleController.State

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
    @Published var selectedTranscriptionLanguage: TranscriptionLanguage {
        didSet {
            guard oldValue != selectedTranscriptionLanguage else { return }
            transcriptionLanguageStore.setSelectedLanguage(selectedTranscriptionLanguage)
        }
    }

    private let vocabularySettingsStore: any VocabularyBoostingSettingsStoring
    private let summarizationModelStore: SummarizationModelSelectionStore
    private let transcriptionModelStore: TranscriptionModelSelectionStore
    private let transcriptionBackendStore: TranscriptionBackendSelectionStore
    private let fluidAudioModelStore: FluidAudioASRModelSelectionStore
    private let transcriptionLanguageStore: TranscriptionLanguageSelectionStore
    private let modelLifecycleController: ModelSetupLifecycleController
    private var cancellables: Set<AnyCancellable> = []
    private var isRestoringVocabularySettings = false
    private var lastModelValidation = ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])

    init(
        modelManager: (any ModelManaging)? = nil,
        summarizationModelStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore(),
        transcriptionModelStore: TranscriptionModelSelectionStore = TranscriptionModelSelectionStore(),
        transcriptionBackendStore: TranscriptionBackendSelectionStore = TranscriptionBackendSelectionStore(),
        fluidAudioModelStore: FluidAudioASRModelSelectionStore = FluidAudioASRModelSelectionStore(),
        transcriptionLanguageStore: TranscriptionLanguageSelectionStore = TranscriptionLanguageSelectionStore(),
        vocabularySettingsStore: (any VocabularyBoostingSettingsStoring)? = nil
    ) {
        self.summarizationModelStore = summarizationModelStore
        self.transcriptionModelStore = transcriptionModelStore
        self.transcriptionBackendStore = transcriptionBackendStore
        self.fluidAudioModelStore = fluidAudioModelStore
        self.transcriptionLanguageStore = transcriptionLanguageStore
        self.vocabularySettingsStore = vocabularySettingsStore ?? VocabularyBoostingSettingsStore()
        let resolvedModelManager = modelManager ?? DefaultModelManager(
            selectionStore: summarizationModelStore,
            transcriptionSelectionStore: transcriptionModelStore,
            transcriptionBackendStore: transcriptionBackendStore,
            fluidAudioModelStore: fluidAudioModelStore
        )
        self.modelLifecycleController = ModelSetupLifecycleController(
            modelManager: resolvedModelManager,
            displayName: Self.displayName(for:)
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
        self.selectedTranscriptionLanguage = transcriptionLanguageStore.selectedLanguage()
        let vocabularySettings = self.vocabularySettingsStore.load()
        self.vocabularyBoostingEnabled = vocabularySettings.enabled
        self.vocabularyBoostingTermsInput = vocabularySettings.editorInput
        self.vocabularyBoostingStrength = vocabularySettings.strength
        modelLifecycleController.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &cancellables)
        modelLifecycleController.$lastValidation
            .receive(on: RunLoop.main)
            .sink { [weak self] validation in
                self?.lastModelValidation = validation
            }
            .store(in: &cancellables)
        refresh()
    }

    func refresh() {
        modelLifecycleController.refresh()
    }

    func startDownload() {
        modelLifecycleController.startDownload()
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

    var isWhisperSelected: Bool {
        !isFluidAudioSelected
    }

    var transcriptionLanguages: [TranscriptionLanguage] {
        TranscriptionLanguage.allCases
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
            let names = vocabularyIDs.map(Self.displayName(for:))
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

    private static func displayName(for id: String) -> String {
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
