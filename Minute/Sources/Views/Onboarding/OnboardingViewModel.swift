import AVFoundation
import Combine
import CoreGraphics
import Foundation
import MinuteCore

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case intro
        case permissions
        case models
        case vault
        case complete
    }

    typealias ModelsState = ModelSetupLifecycleController.State

    @Published private(set) var currentStep: Step = .intro
    @Published private(set) var microphonePermissionGranted = false
    @Published private(set) var screenRecordingPermissionGranted = false
    @Published private(set) var vaultConfigured = false
    @Published private(set) var modelsState: ModelsState = .checking
    @Published var selectedSummarizationModelID: String {
        didSet {
            guard oldValue != selectedSummarizationModelID else { return }
            summarizationModelStore.setSelectedModelID(selectedSummarizationModelID)
            modelLifecycleController.refresh()
        }
    }
    @Published var selectedSummarizationContextWindowPreset: SummarizationContextWindowPreset {
        didSet {
            guard oldValue != selectedSummarizationContextWindowPreset else { return }
            summarizationContextWindowStore.setSelectedPreset(selectedSummarizationContextWindowPreset)
        }
    }
    @Published var selectedTranscriptionBackendID: String {
        didSet {
            guard oldValue != selectedTranscriptionBackendID else { return }
            transcriptionBackendStore.setSelectedBackendID(selectedTranscriptionBackendID)
            modelLifecycleController.refresh()
        }
    }
    @Published var selectedTranscriptionModelID: String {
        didSet {
            guard oldValue != selectedTranscriptionModelID else { return }
            transcriptionModelStore.setSelectedModelID(selectedTranscriptionModelID)
            modelLifecycleController.refresh()
        }
    }
    @Published var selectedFluidAudioModelID: String {
        didSet {
            guard oldValue != selectedFluidAudioModelID else { return }
            fluidAudioModelStore.setSelectedModelID(selectedFluidAudioModelID)
            modelLifecycleController.refresh()
        }
    }

    private let defaults: UserDefaults
    private let summarizationModelStore: SummarizationModelSelectionStore
    private let summarizationContextWindowStore: SummarizationContextWindowSelectionStore
    private let transcriptionModelStore: TranscriptionModelSelectionStore
    private let transcriptionBackendStore: TranscriptionBackendSelectionStore
    private let fluidAudioModelStore: FluidAudioASRModelSelectionStore
    private let modelLifecycleController: ModelSetupLifecycleController

    private var defaultsObserver: AnyCancellable?
    private var observedVaultBookmark: Data?
    private var cancellables: Set<AnyCancellable> = []

    private enum DefaultsKey {
        static let didShowIntro = "didShowOnboardingIntro"
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let lastStep = "onboardingLastStep"
        static let didSkipPermissions = "didSkipOnboardingPermissions"
    }

    init(
        modelManager: (any ModelManaging)? = nil,
        defaults: UserDefaults = .standard,
        summarizationModelStore: SummarizationModelSelectionStore? = nil,
        summarizationContextWindowStore: SummarizationContextWindowSelectionStore? = nil,
        transcriptionModelStore: TranscriptionModelSelectionStore? = nil,
        transcriptionBackendStore: TranscriptionBackendSelectionStore? = nil,
        fluidAudioModelStore: FluidAudioASRModelSelectionStore? = nil
    ) {
        let store = summarizationModelStore ?? SummarizationModelSelectionStore(defaults: defaults)
        let contextStore = summarizationContextWindowStore ?? SummarizationContextWindowSelectionStore(defaults: defaults)
        let transcriptionStore = transcriptionModelStore ?? TranscriptionModelSelectionStore(defaults: defaults)
        let backendStore = transcriptionBackendStore ?? TranscriptionBackendSelectionStore(defaults: defaults)
        let fluidStore = fluidAudioModelStore ?? FluidAudioASRModelSelectionStore(defaults: defaults)
        let resolvedModelManager = modelManager ?? DefaultModelManager(
            selectionStore: store,
            transcriptionSelectionStore: transcriptionStore,
            transcriptionBackendStore: backendStore,
            fluidAudioModelStore: fluidStore
        )
        self.defaults = defaults
        self.summarizationModelStore = store
        self.summarizationContextWindowStore = contextStore
        self.transcriptionModelStore = transcriptionStore
        self.transcriptionBackendStore = backendStore
        self.fluidAudioModelStore = fluidStore
        self.modelLifecycleController = ModelSetupLifecycleController(
            modelManager: resolvedModelManager,
            displayName: Self.displayName(for:)
        )
        let selectedModel = store.selectedModel()
        self.selectedSummarizationModelID = selectedModel.id
        if store.selectedModelID() != selectedModel.id {
            store.setSelectedModelID(selectedModel.id)
        }
        self.selectedSummarizationContextWindowPreset = contextStore.selectedPreset()
        let selectedBackend = backendStore.selectedBackend()
        self.selectedTranscriptionBackendID = selectedBackend.id
        if backendStore.selectedBackendID() != selectedBackend.id {
            backendStore.setSelectedBackendID(selectedBackend.id)
        }
        let selectedTranscription = transcriptionStore.selectedModel()
        self.selectedTranscriptionModelID = selectedTranscription.id
        if transcriptionStore.selectedModelID() != selectedTranscription.id {
            transcriptionStore.setSelectedModelID(selectedTranscription.id)
        }
        let selectedFluid = fluidStore.selectedModel()
        self.selectedFluidAudioModelID = selectedFluid.id
        if fluidStore.selectedModelID() != selectedFluid.id {
            fluidStore.setSelectedModelID(selectedFluid.id)
        }
        let bookmarkStore = UserDefaultsVaultBookmarkStore(
            defaults: defaults,
            key: AppConfiguration.Defaults.vaultRootBookmarkKey
        )
        Self.migrateLegacyCompletionIfNeeded(defaults: defaults, bookmarkStore: bookmarkStore)

        refreshAll()
        observedVaultBookmark = currentVaultBookmark()

        defaultsObserver = NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: defaults
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleDefaultsDidChange()
            }

        modelLifecycleController.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.modelsState = state
                self?.updateCurrentStepIfNeeded()
            }
            .store(in: &cancellables)
    }

    var permissionsReady: Bool {
        microphonePermissionGranted && screenRecordingPermissionGranted
    }

    var modelsReady: Bool {
        if case .ready = modelsState {
            return true
        }
        return false
    }

    var requirementsMet: Bool {
        permissionsSatisfied && modelsReady && vaultConfigured
    }

    var isComplete: Bool {
        didCompleteOnboarding
    }

    var summarizationModels: [SummarizationModel] {
        SummarizationModelCatalog.all
    }

    var summarizationContextWindowPresets: [SummarizationContextWindowPreset] {
        SummarizationContextWindowPreset.allCases
    }

    var recommendedSummarizationContextWindowPreset: SummarizationContextWindowPreset {
        summarizationContextWindowStore.recommendedPreset()
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

    var primaryButtonTitle: String {
        switch currentStep {
        case .vault:
            return "Done"
        case .complete:
            return "Done"
        default:
            return "Continue"
        }
    }

    var primaryButtonEnabled: Bool {
        switch currentStep {
        case .intro:
            return true
        case .permissions:
            return permissionsSatisfied
        case .models:
            return modelsReady
        case .vault:
            return vaultConfigured
        case .complete:
            return true
        }
    }

    func refreshAll() {
        refreshPermissions()
        refreshVaultStatus()
        modelLifecycleController.refresh()
        updateCurrentStepIfNeeded()
    }

    func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphonePermissionGranted = granted
            updateCurrentStepIfNeeded()
        }
    }

    func requestScreenRecordingPermission() {
        Task {
            let granted = await ScreenRecordingPermission.request()
            screenRecordingPermissionGranted = granted
            updateCurrentStepIfNeeded()
        }
    }

    func startModelDownload() {
        modelLifecycleController.startDownload()
    }

    func advance() {
        switch currentStep {
        case .intro:
            didShowIntro = true
            setCurrentStep(.permissions)

        case .permissions:
            guard permissionsSatisfied else { return }
            setCurrentStep(.models)

        case .models:
            guard modelsReady else { return }
            setCurrentStep(.vault)

        case .vault:
            guard vaultConfigured else { return }
            didCompleteOnboarding = true
            setCurrentStep(.complete)

        case .complete:
            break
        }
    }

    func skipPermissions() {
        didSkipPermissions = true
        setCurrentStep(.models)
    }

    private func refreshPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionGranted = (status == .authorized)
        Task {
            let granted = await ScreenRecordingPermission.refresh()
            screenRecordingPermissionGranted = granted
            updateCurrentStepIfNeeded()
        }
    }

    private func handleDefaultsDidChange() {
        let bookmark = currentVaultBookmark()
        guard bookmark != observedVaultBookmark else { return }
        observedVaultBookmark = bookmark
        refreshVaultStatus()
    }

    private func currentVaultBookmark() -> Data? {
        defaults.data(forKey: AppConfiguration.Defaults.vaultRootBookmarkKey)
    }

    private func refreshVaultStatus() {
        let isConfigured = currentVaultBookmark() != nil
        guard vaultConfigured != isConfigured else { return }
        vaultConfigured = isConfigured
        updateCurrentStepIfNeeded()
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

    private func updateCurrentStepIfNeeded() {
        guard didShowIntro else {
            setCurrentStep(.intro, persist: false)
            return
        }

        let required = requiredStep()
        let stored = storedStep() ?? required
        var target = stored

        if required.rawValue < stored.rawValue {
            target = required
        }

        if currentStep != target {
            setCurrentStep(target, persist: false)
        }
    }

    private func requiredStep() -> Step {
        if !permissionsSatisfied {
            return .permissions
        }
        if !modelsReady {
            return .models
        }
        if !vaultConfigured {
            return .vault
        }
        return .complete
    }

    private func storedStep() -> Step? {
        guard defaults.object(forKey: DefaultsKey.lastStep) != nil else {
            return nil
        }

        let raw = defaults.integer(forKey: DefaultsKey.lastStep)
        return Step(rawValue: raw)
    }

    private func setCurrentStep(_ step: Step, persist: Bool = true) {
        currentStep = step
        if persist {
            defaults.set(step.rawValue, forKey: DefaultsKey.lastStep)
        }
    }

    private var didShowIntro: Bool {
        get { defaults.bool(forKey: DefaultsKey.didShowIntro) }
        set { defaults.set(newValue, forKey: DefaultsKey.didShowIntro) }
    }

    private var didCompleteOnboarding: Bool {
        get { defaults.bool(forKey: DefaultsKey.didCompleteOnboarding) }
        set { defaults.set(newValue, forKey: DefaultsKey.didCompleteOnboarding) }
    }

    private var didSkipPermissions: Bool {
        get { defaults.bool(forKey: DefaultsKey.didSkipPermissions) }
        set { defaults.set(newValue, forKey: DefaultsKey.didSkipPermissions) }
    }

    private var permissionsSatisfied: Bool {
        permissionsReady || didSkipPermissions
    }

    private static func migrateLegacyCompletionIfNeeded(
        defaults: UserDefaults,
        bookmarkStore: any VaultBookmarkStoring
    ) {
        guard defaults.object(forKey: DefaultsKey.didCompleteOnboarding) == nil else {
            return
        }
        guard bookmarkStore.loadVaultRootBookmark() != nil else {
            return
        }

        defaults.set(true, forKey: DefaultsKey.didShowIntro)
        defaults.set(true, forKey: DefaultsKey.didCompleteOnboarding)
        defaults.set(Step.complete.rawValue, forKey: DefaultsKey.lastStep)
    }
}
