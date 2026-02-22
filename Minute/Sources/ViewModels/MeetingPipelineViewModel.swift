import AppKit
import CoreGraphics
import QuartzCore
@preconcurrency import AVFoundation
import Combine
import Foundation
import MinuteCore
import MinuteLlama
import MinuteWhisper
import os
import UniformTypeIdentifiers

@MainActor
final class MeetingPipelineViewModel: ObservableObject {
    struct RecordingPermissions: Sendable {
        var requestMicrophonePermission: @Sendable () async throws -> Bool
        var requestScreenRecordingPermission: @Sendable () async throws -> Bool

        nonisolated static func live() -> RecordingPermissions {
            RecordingPermissions(
                requestMicrophonePermission: {
                    // Gate on microphone permission.
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    switch status {
                    case .authorized:
                        return true

                    case .notDetermined:
                        let granted = await AVCaptureDevice.requestAccess(for: .audio)
                        if !granted { throw MinuteError.permissionDenied }
                        return granted

                    case .denied, .restricted:
                        throw MinuteError.permissionDenied

                    @unknown default:
                        throw MinuteError.permissionDenied
                    }
                },
                requestScreenRecordingPermission: {
                    let granted = await ScreenRecordingPermission.refresh()
                    if !granted {
                        throw MinuteError.screenRecordingPermissionDenied
                    }
                    return granted
                }
            )
        }

        nonisolated static func alwaysGranted() -> RecordingPermissions {
            RecordingPermissions(
                requestMicrophonePermission: { true },
                requestScreenRecordingPermission: { true }
            )
        }
    }

    struct VaultStatus: Equatable {
        var displayText: String
        var isConfigured: Bool
    }

    struct ScreenInferenceStatus: Equatable {
        var processedCount: Int
        var skippedCount: Int
        var isInferenceRunning: Bool
        var isFirstInferenceDeferred: Bool
    }

    private struct ObservedDefaultsSnapshot: Equatable {
        var vaultRootBookmark: Data?
        var vaultRootPathDisplay: String?
        var outputLanguageRawValue: String?
        var transcriptionBackendID: String?
        var vocabularySettings: GlobalVocabularyBoostingSettings
    }

    enum CaptureState: Equatable {
        case ready
        case recording
        case stopping
    }

    @Published private(set) var state: MeetingPipelineState = .idle
    @Published private(set) var captureState: CaptureState = .ready
    @Published private(set) var progress: Double? = nil
    @Published private(set) var backgroundProcessingSnapshot: BackgroundProcessingSnapshot = BackgroundProcessingSnapshot()
    @Published private(set) var lastBackgroundProcessedNoteURL: URL? = nil
    @Published private(set) var vaultStatus: VaultStatus = VaultStatus(displayText: "Not selected", isConfigured: false)
    @Published private(set) var microphonePermissionGranted: Bool = false
    @Published private(set) var screenRecordingPermissionGranted: Bool = false
    @Published private(set) var microphoneCaptureEnabled: Bool = true
    @Published private(set) var systemAudioCaptureEnabled: Bool = true
    @Published private(set) var screenCaptureEnabled: Bool = false
    @Published private(set) var audioLevelSamples: [CGFloat] = Array(repeating: 0, count: 24)
    @Published private(set) var screenInferenceStatus: ScreenInferenceStatus? = nil
    @Published private(set) var latestScreenCaptureImage: NSImage? = nil
    @Published private(set) var recoverableRecordings: [RecoverableRecording] = []
    @Published private(set) var silenceStatus: SilenceStatusSnapshot = SilenceStatusSnapshot()
    @Published private(set) var activeSilenceAlert: RecordingAlert? = nil
    @Published private(set) var activeScreenContextAlert: RecordingAlert? = nil
    @Published private(set) var recordingSessionEvents: [RecordingSessionEvent] = []
    @Published private(set) var transcriptionBackend: TranscriptionBackend = .whisper
    @Published private(set) var sessionVocabularyMode: VocabularyBoostingSessionMode = .default
    @Published private(set) var sessionCustomVocabularyInput: String = ""
    @Published private(set) var sessionVocabularyWarningMessage: String? = nil
    @Published private(set) var vocabularyBoostingEnabledInSettings: Bool = false
    @Published private(set) var globalVocabularyTerms: [String] = []
    @Published var meetingType: MeetingType = .autodetect
    @Published var languageProcessing: LanguageProcessingProfile = .autoToEnglish
    @Published var outputLanguage: OutputLanguage = .defaultSelection

    var autoToEnglishOptionTitle: String {
        "Auto -> English"
    }

    var autoToPickedLanguageOptionTitle: String {
        "Auto -> \(outputLanguage.displayName)"
    }

    var selectedLanguageProcessingTitle: String {
        switch languageProcessing {
        case .autoToEnglish:
            return autoToEnglishOptionTitle
        case .autoPreserve:
            return autoToPickedLanguageOptionTitle
        }
    }

    var selectedLanguageProcessingDetailText: String {
        switch languageProcessing {
        case .autoToEnglish:
            return "Detect transcript language and write outputs in English."
        case .autoPreserve:
            return "Detect transcript language and write outputs in \(outputLanguage.displayName)."
        }
    }

    var activeSilenceWarningMessage: String? {
        activeSilenceAlert?.message
    }

    var activeSilenceWarningSecondsRemaining: Int? {
        activeSilenceAlert?.expiresAt.map { max(Int(ceil($0.timeIntervalSinceNow)), 0) }
    }

    var activeScreenContextAlertMessage: String? {
        activeScreenContextAlert?.message
    }

    var activeScreenContextWarningSecondsRemaining: Int? {
        activeScreenContextAlert?.expiresAt.map { max(Int(ceil($0.timeIntervalSinceNow)), 0) }
    }

    var isFluidAudioBackendSelected: Bool {
        transcriptionBackend == .fluidAudio
    }

    var sessionVocabularyHintText: String {
        "Use for names, acronyms, product terms. Settings terms are included automatically."
    }

    var showsSessionVocabularyPopoverButton: Bool {
        isFluidAudioBackendSelected && vocabularyBoostingEnabledInSettings
    }

    var sessionVocabularyListLabel: String {
        sessionVocabularyMode == .custom ? "Custom" : "Default"
    }

    private let audioService: any AudioServicing
    private let mediaImportService: any MediaImporting
    private let recoveryService: any RecordingRecoveryServicing
    private let pipelineCoordinator: MeetingPipelineCoordinator
    private let processingBusyGate: ProcessingBusyGate
    private let processingOrchestrator: MeetingProcessingOrchestrator
    private let screenContextCaptureService: ScreenContextCaptureService
    private let screenContextVideoExtractor: ScreenContextVideoFrameExtractor
    private let screenContextSettingsStore: ScreenContextSettingsStore
    private let recordingPermissions: RecordingPermissions
    private let stagePreferencesStore: StagePreferencesStore
    private let silenceDetectionPolicy: SilenceDetectionPolicy
    private let recordingAlertNotifier: any RecordingAlertNotifying
    private let transcriptionBackendStore: TranscriptionBackendSelectionStore
    private let vocabularySettingsStore: any VocabularyBoostingSettingsStoring
    private let sessionVocabularyResolver: any SessionVocabularyResolving
    private let modelValidationProvider: @Sendable () async throws -> ModelValidationResult

    private let vaultAccess: VaultAccess

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")
    private let defaults: UserDefaults

    private var defaultsObserver: AnyCancellable?
    private var observedDefaultsSnapshot: ObservedDefaultsSnapshot?
    private var cancellables: Set<AnyCancellable> = []
    private var processingTask: Task<Void, Never>?
    private var backgroundProcessingObserverTask: Task<Void, Never>?
    private var isPreparingPipelineContext = false
    private var lastAudioLevelUpdate: CFTimeInterval = 0
    private var screenContextEvents: [ScreenContextEvent] = []
    private var screenCaptureSelection: ScreenContextWindowSelection?
    private var screenCaptureBaseProcessedCount = 0
    private var screenCaptureBaseSkippedCount = 0

    private let audioLevelBucketCount = 24
    private let audioLevelUpdateInterval: CFTimeInterval = 1.0 / 24.0
    private var screenContextFrameIntervalSeconds: TimeInterval {
        screenContextSettingsStore.captureIntervalSeconds
    }
    private var silenceController: (any SilenceAutoStopControlling)?
    private var screenContextAutoStopTask: Task<Void, Never>?
    private var sessionVocabularyReadiness = VocabularyReadinessStatus.unsupported(backend: .whisper)
	
    init(
        audioService: some AudioServicing,
        mediaImportService: some MediaImporting,
        recoveryService: some RecordingRecoveryServicing,
        pipelineCoordinator: MeetingPipelineCoordinator,
        screenContextCaptureService: ScreenContextCaptureService,
        screenContextVideoExtractor: ScreenContextVideoFrameExtractor,
        screenContextSettingsStore: ScreenContextSettingsStore,
        vaultAccess: VaultAccess,
        recordingPermissions: RecordingPermissions = .live(),
        stagePreferencesStore: StagePreferencesStore = StagePreferencesStore(),
        silenceDetectionPolicy: SilenceDetectionPolicy = .default,
        recordingAlertNotifier: (any RecordingAlertNotifying)? = nil,
        transcriptionBackendStore: TranscriptionBackendSelectionStore = TranscriptionBackendSelectionStore(),
        vocabularySettingsStore: (any VocabularyBoostingSettingsStoring) = VocabularyBoostingSettingsStore(),
        sessionVocabularyResolver: (any SessionVocabularyResolving) = SessionVocabularyResolver(),
        modelValidationProvider: (@Sendable () async throws -> ModelValidationResult)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.audioService = audioService
        self.mediaImportService = mediaImportService
        self.recoveryService = recoveryService
        self.pipelineCoordinator = pipelineCoordinator
        let busyGate = ProcessingBusyGate()
        self.processingBusyGate = busyGate
        self.processingOrchestrator = MeetingProcessingOrchestrator(busyGate: busyGate, coordinator: pipelineCoordinator)
        self.screenContextCaptureService = screenContextCaptureService
        self.screenContextVideoExtractor = screenContextVideoExtractor
        self.screenContextSettingsStore = screenContextSettingsStore
        self.recordingPermissions = recordingPermissions
        self.stagePreferencesStore = stagePreferencesStore
        self.silenceDetectionPolicy = silenceDetectionPolicy
        self.recordingAlertNotifier = recordingAlertNotifier ?? RecordingAlertNotificationCoordinator()
        self.transcriptionBackendStore = transcriptionBackendStore
        self.vocabularySettingsStore = vocabularySettingsStore
        self.sessionVocabularyResolver = sessionVocabularyResolver
        self.modelValidationProvider = modelValidationProvider ?? { ModelValidationResult(missingModelIDs: [], invalidModelIDs: []) }
        self.vaultAccess = vaultAccess
        self.defaults = defaults
        self.screenCaptureEnabled = screenContextSettingsStore.isEnabled

        loadStagePreferences()

        refreshVaultStatus()
        refreshOutputLanguageSetting()
        refreshTranscriptionBackendSetting()
        refreshVocabularySettings()
        refreshMicrophonePermission()
        refreshScreenRecordingPermission()
        observedDefaultsSnapshot = makeObservedDefaultsSnapshot()

        defaultsObserver = NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: defaults
        )
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleDefaultsDidChange()
            }

        startStagePreferencesObservation()
        startRecordingAlertActionObservation()

        refreshRecoverableRecordings()

        startBackgroundProcessingObservation()
    }

    private func loadStagePreferences() {
        let preferences = stagePreferencesStore.load()
        meetingType = preferences.meetingType
        languageProcessing = preferences.languageProcessing
        microphoneCaptureEnabled = preferences.microphoneEnabled
        systemAudioCaptureEnabled = preferences.systemAudioEnabled

        Task { [weak self] in
            await self?.applyAudioCaptureToggles()
        }
    }

    private func saveStagePreferences() {
        stagePreferencesStore.save(
            StagePreferences(
                meetingType: meetingType,
                languageProcessing: languageProcessing,
                microphoneEnabled: microphoneCaptureEnabled,
                systemAudioEnabled: systemAudioCaptureEnabled
            )
        )
    }

    private func startStagePreferencesObservation() {
        $meetingType
            .map(\.rawValue)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveStagePreferences()
            }
            .store(in: &cancellables)

        $languageProcessing
            .map(\.rawValue)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveStagePreferences()
            }
            .store(in: &cancellables)

        $microphoneCaptureEnabled
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveStagePreferences()
            }
            .store(in: &cancellables)

        $systemAudioCaptureEnabled
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveStagePreferences()
            }
            .store(in: &cancellables)
    }

    private func startRecordingAlertActionObservation() {
        NotificationCenter.default.publisher(for: .minuteRecordingAlertKeepRecording)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.keepRecordingFromWarning()
            }
            .store(in: &cancellables)
    }

    deinit {
        processingTask?.cancel()
        backgroundProcessingObserverTask?.cancel()
        screenContextAutoStopTask?.cancel()
        let captureService = screenContextCaptureService
        let silenceController = silenceController
        Task { [captureService] in
            await captureService.cancelCapture()
        }
        Task { [silenceController] in
            await silenceController?.stop()
        }
    }

    static func mock() -> MeetingPipelineViewModel {
        let bookmarkStore = UserDefaultsVaultBookmarkStore(key: AppConfiguration.Defaults.vaultRootBookmarkKey)
        let vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: { MockSummarizationService() },
            modelManager: MockModelManager(),
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        return MeetingPipelineViewModel(
            audioService: MockAudioService(),
            mediaImportService: MockMediaImportService(),
            recoveryService: MockRecordingRecoveryService(),
            pipelineCoordinator: coordinator,
            screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
            screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
            screenContextSettingsStore: ScreenContextSettingsStore(),
            vaultAccess: vaultAccess
        )
    }

    static func live() -> MeetingPipelineViewModel {
        let selectionStore = SummarizationModelSelectionStore()
        let transcriptionSelectionStore = TranscriptionModelSelectionStore()
        let transcriptionBackendStore = TranscriptionBackendSelectionStore()
        let fluidAudioModelStore = FluidAudioASRModelSelectionStore()
        let summarizationServiceProvider: @Sendable () -> any SummarizationServicing = {
            LlamaLibrarySummarizationService.liveDefault(selectionStore: selectionStore)
        }
        let transcriptionService: any TranscriptionServicing
        switch transcriptionBackendStore.selectedBackend() {
        case .whisper:
            transcriptionService = ResilientWhisperTranscriptionService.liveDefault()
        case .fluidAudio:
            transcriptionService = FluidAudioTranscriptionService.liveDefault(selectionStore: fluidAudioModelStore)
        }
        let screenInferencer: any ScreenContextInferencing = LlamaMTMDScreenInferenceService
            .liveDefault(selectionStore: selectionStore)
            ?? MissingScreenContextInferenceService()

        let bookmarkStore = UserDefaultsVaultBookmarkStore(key: AppConfiguration.Defaults.vaultRootBookmarkKey)
        let vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)
        let modelManager = DefaultModelManager(
            selectionStore: selectionStore,
            transcriptionSelectionStore: transcriptionSelectionStore,
            transcriptionBackendStore: transcriptionBackendStore,
            fluidAudioModelStore: fluidAudioModelStore
        )
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: transcriptionService,
            diarizationService: FluidAudioOfflineDiarizationService.meetingDefault(),
            summarizationServiceProvider: summarizationServiceProvider,
            audioLoudnessNormalizer: AudioLoudnessNormalizer(),
            modelManager: modelManager,
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        return MeetingPipelineViewModel(
            audioService: DefaultAudioService(),
            mediaImportService: DefaultMediaImportService(),
            recoveryService: DefaultRecordingRecoveryService(),
            pipelineCoordinator: coordinator,
            screenContextCaptureService: ScreenContextCaptureService(inferencer: screenInferencer),
            screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: screenInferencer),
            screenContextSettingsStore: ScreenContextSettingsStore(),
            vaultAccess: vaultAccess,
            transcriptionBackendStore: transcriptionBackendStore,
            vocabularySettingsStore: VocabularyBoostingSettingsStore(),
            sessionVocabularyResolver: SessionVocabularyResolver(),
            modelValidationProvider: {
                try await modelManager.validateModels()
            }
        )
    }

    func refreshVaultStatus() {
        let hasBookmark = defaults.data(forKey: AppConfiguration.Defaults.vaultRootBookmarkKey) != nil
        let storedPath = defaults.string(forKey: AppConfiguration.Defaults.vaultRootPathDisplayKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText: String
        if hasBookmark {
            if let storedPath, !storedPath.isEmpty {
                displayText = storedPath
            } else {
                displayText = "Vault selected"
            }
        } else {
            displayText = "Not selected"
        }
        let updatedStatus = VaultStatus(displayText: displayText, isConfigured: hasBookmark)
        guard vaultStatus != updatedStatus else { return }
        vaultStatus = updatedStatus
    }

    func refreshOutputLanguageSetting() {
        let rawValue = defaults.string(forKey: AppConfiguration.Defaults.outputLanguageKey)
        outputLanguage = OutputLanguage.resolved(from: rawValue)
    }

    func refreshTranscriptionBackendSetting() {
        transcriptionBackend = transcriptionBackendStore.selectedBackend()
        if transcriptionBackend != .fluidAudio {
            sessionVocabularyWarningMessage = nil
            sessionVocabularyReadiness = .unsupported(backend: transcriptionBackend)
        }
        syncSessionVocabularyModeWithCurrentInput()
    }

    func refreshVocabularySettings() {
        let settings = vocabularySettingsStore.load()
        vocabularyBoostingEnabledInSettings = settings.enabled
        globalVocabularyTerms = settings.terms
        syncSessionVocabularyModeWithCurrentInput(using: settings)
    }

    private func handleDefaultsDidChange() {
        let snapshot = makeObservedDefaultsSnapshot()
        guard snapshot != observedDefaultsSnapshot else { return }

        let previous = observedDefaultsSnapshot
        observedDefaultsSnapshot = snapshot

        guard let previous else {
            refreshVaultStatus()
            refreshOutputLanguageSetting()
            refreshTranscriptionBackendSetting()
            refreshVocabularySettings()
            return
        }

        let vaultStatusChanged =
            previous.vaultRootBookmark != snapshot.vaultRootBookmark
            || previous.vaultRootPathDisplay != snapshot.vaultRootPathDisplay
        if vaultStatusChanged {
            refreshVaultStatus()
        }
        if previous.outputLanguageRawValue != snapshot.outputLanguageRawValue {
            refreshOutputLanguageSetting()
        }
        if previous.transcriptionBackendID != snapshot.transcriptionBackendID {
            refreshTranscriptionBackendSetting()
        }
        if previous.vocabularySettings != snapshot.vocabularySettings {
            refreshVocabularySettings()
        }
    }

    private func makeObservedDefaultsSnapshot() -> ObservedDefaultsSnapshot {
        return ObservedDefaultsSnapshot(
            vaultRootBookmark: defaults.data(forKey: AppConfiguration.Defaults.vaultRootBookmarkKey),
            vaultRootPathDisplay: defaults.string(forKey: AppConfiguration.Defaults.vaultRootPathDisplayKey),
            outputLanguageRawValue: defaults.string(forKey: AppConfiguration.Defaults.outputLanguageKey),
            transcriptionBackendID: transcriptionBackendStore.selectedBackendID(),
            vocabularySettings: vocabularySettingsStore.load()
        )
    }

    func setSessionVocabularyMode(_ mode: VocabularyBoostingSessionMode) {
        if mode == .custom {
            sessionVocabularyMode = .custom
            return
        }

        sessionCustomVocabularyInput = ""
        syncSessionVocabularyModeWithCurrentInput()
        if mode == .off {
            sessionVocabularyWarningMessage = nil
        }
    }

    func setSessionCustomVocabularyInput(_ input: String) {
        sessionCustomVocabularyInput = input
        syncSessionVocabularyModeWithCurrentInput()
    }

    func refreshRecoverableRecordings() {
        Task { [weak self] in
            guard let self else { return }
            let recordings = await recoveryService.findRecoverableRecordings()
            self.recoverableRecordings = recordings
        }
    }

    func send(_ action: MeetingPipelineAction) {
        switch action {
        case .startRecording:
            startRecordingIfAllowed(selection: nil)
        case .startRecordingWithWindow(let selection):
            startRecordingIfAllowed(selection: selection)
        case .stopRecording:
            stopRecordingIfAllowed()
        case .cancelRecording:
            cancelSessionIfAllowed()
        case .process:
            processIfAllowed()
        case .importFile(let url):
            importFileIfAllowed(url)
        case .cancelProcessing:
            cancelProcessingIfAllowed()
        case .reset:
            resetIfAllowed()
        }
    }

    func cancelBackgroundProcessing(clearPending: Bool) {
        Task { [processingOrchestrator] in
            await processingOrchestrator.cancelActiveProcessing(clearPending: clearPending)
        }
    }

    func retryBackgroundProcessing() {
        Task { [processingOrchestrator] in
            _ = await processingOrchestrator.retryLastFailedOrCanceled()
        }
    }

    func recoverRecording(_ recording: RecoverableRecording) {
        guard state.canImportMedia else { return }

        processingTask?.cancel()
        progress = nil
        screenContextEvents = []
        screenInferenceStatus = nil
        screenCaptureBaseProcessedCount = 0
        screenCaptureBaseSkippedCount = 0
        state = .importing(sourceURL: recording.sessionURL)

        processingTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let result = try await recoveryService.recover(recording: recording)
                let startedAt = result.startedAt
                let stoppedAt = result.stoppedAt
                state = .recorded(
                    audioTempURL: result.wavURL,
                    durationSeconds: result.duration,
                    startedAt: startedAt,
                    stoppedAt: stoppedAt
                )
                await MainActor.run {
                    self.refreshRecoverableRecordings()
                }
            } catch is CancellationError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .idle
            } catch let minuteError as MinuteError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
            }
        }
    }

    func discardRecoverableRecording(_ recording: RecoverableRecording) {
        Task { [weak self] in
            guard let self else { return }
            await recoveryService.discard(recording: recording)
            await MainActor.run {
                self.refreshRecoverableRecordings()
            }
        }
    }

    var hasScreenCaptureSelection: Bool {
        screenCaptureSelection != nil
    }

    var currentScreenCaptureSelection: ScreenContextWindowSelection? {
        screenCaptureSelection
    }

    var screenCaptureSelectionDisplayText: String? {
        guard let selection = screenCaptureSelection else { return nil }
        let title = selection.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return selection.applicationName
        }
        return "\(selection.applicationName) — \(title)"
    }

    func setMicrophoneCaptureEnabled(_ enabled: Bool) {
        guard microphoneCaptureEnabled != enabled else { return }
        microphoneCaptureEnabled = enabled
        Task { [weak self] in
            await self?.applyAudioCaptureToggles()
        }
    }

    func setSystemAudioCaptureEnabled(_ enabled: Bool) {
        guard systemAudioCaptureEnabled != enabled else { return }
        systemAudioCaptureEnabled = enabled
        Task { [weak self] in
            await self?.applyAudioCaptureToggles()
        }
    }

    func setAudioCaptureConfiguration(microphoneEnabled: Bool, systemAudioEnabled: Bool) {
        guard microphoneCaptureEnabled != microphoneEnabled || systemAudioCaptureEnabled != systemAudioEnabled else { return }
        microphoneCaptureEnabled = microphoneEnabled
        systemAudioCaptureEnabled = systemAudioEnabled
        Task { [weak self] in
            await self?.applyAudioCaptureToggles()
        }
    }

    func setScreenCaptureEnabled(_ enabled: Bool) {
        guard screenCaptureEnabled != enabled else { return }
        screenCaptureEnabled = enabled

        if !enabled {
            latestScreenCaptureImage = nil
            Task { [weak self] in
                await self?.stopScreenContextCaptureAndAppend()
            }
            return
        }

        guard let selection = screenCaptureSelection else { return }
        guard case .recording(let session) = state else { return }
        let offsetSeconds = Date().timeIntervalSince(session.startedAt)
        Task { [weak self] in
            await self?.startScreenContextCapture(selection: selection, offsetSeconds: offsetSeconds)
        }
    }

    func setScreenCaptureSelection(_ selection: ScreenContextWindowSelection) {
        screenCaptureSelection = selection
        guard screenCaptureEnabled else { return }
        guard case .recording(let session) = state else { return }
        let offsetSeconds = Date().timeIntervalSince(session.startedAt)
        Task { [weak self] in
            await self?.startScreenContextCapture(selection: selection, offsetSeconds: offsetSeconds)
        }
    }

    func setScreenCaptureSelection(_ selection: ScreenContextWindowSelection?) {
        guard let selection else {
            clearScreenCaptureSelection()
            return
        }
        setScreenCaptureSelection(selection)
    }

    func clearScreenCaptureSelection() {
        screenCaptureSelection = nil
        latestScreenCaptureImage = nil

        guard screenCaptureEnabled else { return }
        screenCaptureEnabled = false
        Task { [weak self] in
            await self?.stopScreenContextCaptureAndAppend()
        }
    }

    // MARK: - Actions

    private func startRecordingIfAllowed(selection: ScreenContextWindowSelection?) {
        guard captureState == .ready else { return }
        guard state.canStartRecording else { return }
        guard !state.canCancelProcessing else { return }

        let resolvedSelection: ScreenContextWindowSelection? = {
            if let selection { return selection }
            guard screenCaptureEnabled else { return nil }
            return screenCaptureSelection
        }()
        let shouldCaptureScreen = (resolvedSelection != nil)

        if screenCaptureEnabled, resolvedSelection == nil {
            screenCaptureEnabled = false
        }

        Task {
            do {
                sessionVocabularyReadiness = await resolveSessionVocabularyReadiness()
                let globalSettings = vocabularySettingsStore.load()
                let vocabularyResolution = sessionVocabularyResolver.resolve(
                    globalSettings: globalSettings,
                    sessionMode: sessionVocabularyMode,
                    sessionCustomInput: sessionCustomVocabularyInput,
                    readiness: sessionVocabularyReadiness
                )
                sessionVocabularyWarningMessage = vocabularyResolution.warningMessage

                microphonePermissionGranted = try await recordingPermissions.requestMicrophonePermission()
                if shouldCaptureScreen {
                    screenRecordingPermissionGranted = try await recordingPermissions.requestScreenRecordingPermission()
                }

                if let resolvedSelection {
                    screenCaptureSelection = resolvedSelection
                    screenCaptureEnabled = true
                }

                latestScreenCaptureImage = nil
                screenContextEvents = []
                screenInferenceStatus = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                recordingSessionEvents = []
                screenContextAutoStopTask?.cancel()
                screenContextAutoStopTask = nil
                activeSilenceAlert = nil
                activeScreenContextAlert = nil
                silenceStatus = SilenceStatusSnapshot()
                await recordingAlertNotifier.clearSilenceStopWarning()
                await recordingAlertNotifier.clearSharedWindowClosedWarning()

                let session = RecordingSession()
                await applyAudioCaptureToggles()
                try await audioService.startRecording()
                await startScreenContextCaptureIfNeeded(selection: resolvedSelection, offsetSeconds: 0)
                await startAudioLevelMonitoring()
                resetAudioLevelSamples()
                state = .recording(session: session)
                captureState = .recording
                await startSilenceMonitoring(for: session)
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                await stopSilenceMonitoring()
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
                captureState = .ready
            } catch {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                await stopSilenceMonitoring()
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
                captureState = .ready
            }
        }
    }

    private func cancelSessionIfAllowed() {
        guard case .recording(let session) = state else { return }
        guard captureState == .recording else { return }

        Task {
            await stopAudioLevelMonitoring()
            await stopSilenceMonitoring()
            resetAudioLevelSamples()
            await screenContextCaptureService.cancelCapture()
            screenInferenceStatus = nil
            screenContextEvents = []
            screenCaptureSelection = nil
            latestScreenCaptureImage = nil
            screenCaptureBaseProcessedCount = 0
            screenCaptureBaseSkippedCount = 0
            appendRecordingSessionEvent(.recordingCanceled, sessionID: session.id)
            await clearActiveRecordingWarnings()
            silenceStatus = SilenceStatusSnapshot()

            await audioService.cancelRecording()

            progress = nil
            state = .idle
            captureState = .ready
            resetSessionVocabularyOverride()
        }
    }

    private enum StopRecordingTrigger {
        case manual
        case silenceAutoStop
        case screenContextAutoStop
    }

    private func stopRecordingIfAllowed(trigger: StopRecordingTrigger = .manual) {
        guard case .recording(let session) = state else { return }
        guard captureState == .recording else { return }

        let stoppedAt = Date()
        captureState = .stopping

        Task {
            do {
                if trigger == .manual {
                    appendRecordingSessionEvent(.manualStop, sessionID: session.id)
                }
                let result = try await audioService.stopRecording()
                await stopSilenceMonitoring()
                _ = await stopScreenContextCaptureAndAppend()
                await stopAudioLevelMonitoring()
                resetAudioLevelSamples()
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()

                guard let context = await makePipelineContext(
                    audioTempURL: result.wavURL,
                    audioDurationSeconds: result.duration,
                    startedAt: session.startedAt,
                    stoppedAt: stoppedAt,
                    screenContextEvents: screenContextEvents
                ) else {
                    throw MinuteError.vaultUnavailable
                }

                let accepted = await processingOrchestrator.enqueue(meetingID: session.id, context: context)

                screenCaptureSelection = nil
                screenContextEvents = []

                if accepted {
                    state = .idle
                    resetSessionVocabularyOverride()
                } else {
                    state = .recorded(
                        audioTempURL: result.wavURL,
                        durationSeconds: result.duration,
                        startedAt: session.startedAt,
                        stoppedAt: stoppedAt
                    )
                }
                captureState = .ready
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                await stopSilenceMonitoring()
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
                captureState = .ready
            } catch {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                await stopSilenceMonitoring()
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
                captureState = .ready
            }
        }
    }

    private func importFileIfAllowed(_ url: URL) {
        guard state.canImportMedia else { return }

        processingTask?.cancel()
        progress = nil
        screenContextEvents = []
        screenInferenceStatus = nil
        screenCaptureBaseProcessedCount = 0
        screenCaptureBaseSkippedCount = 0
        state = .importing(sourceURL: url)

        processingTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let result = try await mediaImportService.importMedia(from: url)
                if screenContextSettingsStore.isVideoImportEnabled, isVideoImportURL(url) {
                    screenInferenceStatus = ScreenInferenceStatus(
                        processedCount: 0,
                        skippedCount: 0,
                        isInferenceRunning: true,
                        isFirstInferenceDeferred: false
                    )
                    if let inferenceResult = await extractScreenContextForImport(sourceURL: url) {
                        screenContextEvents = inferenceResult.events
                        screenInferenceStatus = ScreenInferenceStatus(
                            processedCount: inferenceResult.processedCount,
                            skippedCount: 0,
                            isInferenceRunning: false,
                            isFirstInferenceDeferred: false
                        )
                    } else {
                        logger.info("Screen context extraction returned nil for imported video \(url.lastPathComponent, privacy: .private(mask: .hash))")
                        screenInferenceStatus = nil
                    }
                }
                try Task.checkCancellation()
                let startedAt = result.suggestedStartDate
                let stoppedAt = startedAt.addingTimeInterval(result.duration)
                state = .recorded(
                    audioTempURL: result.wavURL,
                    durationSeconds: result.duration,
                    startedAt: startedAt,
                    stoppedAt: stoppedAt
                )
            } catch is CancellationError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .idle
            } catch let minuteError as MinuteError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
            }
        }
    }

    private func processIfAllowed() {
        guard !isPreparingPipelineContext else { return }
        guard case .recorded(let audioTempURL, let durationSeconds, let startedAt, let stoppedAt) = state else { return }

        isPreparingPipelineContext = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isPreparingPipelineContext = false }

            // Snapshot vault configuration.
            guard let context = await makePipelineContext(
                audioTempURL: audioTempURL,
                audioDurationSeconds: durationSeconds,
                startedAt: startedAt,
                stoppedAt: stoppedAt,
                screenContextEvents: screenContextEvents
            ) else {
                state = .failed(error: .vaultUnavailable, debugOutput: nil)
                return
            }

            // One active task at a time.
            processingTask?.cancel()
            progress = 0
            state = .processing(stage: .downloadingModels, context: context)

            processingTask = Task(priority: .utility) { [weak self] in
                guard let self else { return }
                await self.runPipeline(context: context)
            }
        }
    }

    private func cancelProcessingIfAllowed() {
        if state.canCancelProcessing {
            processingTask?.cancel()
            return
        }

        if backgroundProcessingSnapshot.activeMeetingID != nil {
            cancelBackgroundProcessing(clearPending: true)
        }
    }

    private func resetIfAllowed() {
        guard state.canReset else { return }
        progress = nil
        state = .idle
        captureState = .ready
        resetAudioLevelSamples()
        screenInferenceStatus = nil
        screenContextEvents = []
        latestScreenCaptureImage = nil
        screenCaptureSelection = nil
        screenCaptureBaseProcessedCount = 0
        screenCaptureBaseSkippedCount = 0
        screenContextAutoStopTask?.cancel()
        screenContextAutoStopTask = nil
        activeSilenceAlert = nil
        activeScreenContextAlert = nil
        silenceStatus = SilenceStatusSnapshot()
        meetingType = .autodetect
        resetSessionVocabularyOverride()
        Task { @MainActor [recordingAlertNotifier] in
            await recordingAlertNotifier.clearSilenceStopWarning()
            await recordingAlertNotifier.clearSharedWindowClosedWarning()
        }
    }

    private func applyAudioCaptureToggles() async {
        guard let controller = audioService as? (any AudioCaptureControlling) else { return }
        await controller.setMicrophoneEnabled(microphoneCaptureEnabled)
        await controller.setSystemAudioEnabled(systemAudioCaptureEnabled)
    }

    private func updateScreenInferenceStatus(_ status: ScreenContextCaptureStatus) {
        let processed = screenCaptureBaseProcessedCount + status.processedCount
        let skipped = screenCaptureBaseSkippedCount + status.skippedCount
        screenInferenceStatus = ScreenInferenceStatus(
            processedCount: processed,
            skippedCount: skipped,
            isInferenceRunning: status.isInferenceRunning,
            isFirstInferenceDeferred: status.isFirstInferenceDeferred
        )
    }

    private func updateLatestScreenCaptureImage(_ frame: ScreenContextCapturedFrame) {
        guard let image = NSImage(data: frame.imageData) else { return }
        latestScreenCaptureImage = image
    }

    private func startSilenceMonitoring(for session: RecordingSession) async {
        let controller = SilenceAutoStopController(
            policy: silenceDetectionPolicy,
            onEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    await self?.handleSilenceEvent(event)
                }
            }
        )
        silenceController = controller
        await controller.start(sessionID: session.id, startedAt: session.startedAt)
    }

    private func stopSilenceMonitoring() async {
        guard let silenceController else { return }
        await silenceController.stop()
        self.silenceController = nil
    }

    private func clearScreenContextAutoStopWarning(logKeepSelection: Bool = false) async {
        screenContextAutoStopTask?.cancel()
        screenContextAutoStopTask = nil

        if logKeepSelection, let alert = activeScreenContextAlert {
            appendRecordingSessionEvent(
                .keepRecordingSelected,
                metadata: ["source": "screen_window_closed"],
                sessionID: alert.sessionID
            )
        }

        activeScreenContextAlert = nil
        await recordingAlertNotifier.clearSharedWindowClosedWarning()
    }

    private func clearActiveRecordingWarnings() async {
        activeSilenceAlert = nil
        await recordingAlertNotifier.clearSilenceStopWarning()
        await clearScreenContextAutoStopWarning()
    }

    private func beginScreenContextAutoStopWarning(session: RecordingSession, windowTitle: String) {
        guard activeScreenContextAlert == nil else { return }

        let warningSeconds = Int(silenceDetectionPolicy.warningCountdownSeconds)
        let now = Date()
        let expiresAt = now.addingTimeInterval(silenceDetectionPolicy.warningCountdownSeconds)
        let alert = RecordingAlert(
            type: .screenWindowClosedStopWarning,
            sessionID: session.id,
            message: "Shared window closed: \(windowTitle). Recording will stop in \(warningSeconds) seconds unless you keep recording.",
            issuedAt: now,
            expiresAt: expiresAt,
            actions: [.keepRecording]
        )

        activeScreenContextAlert = alert
        appendRecordingSessionEvent(
            .screenWindowClosedNotified,
            metadata: [
                "window_title": windowTitle,
                "countdown_seconds": "\(warningSeconds)",
                "stop_pending": "true"
            ],
            sessionID: session.id
        )

        screenContextAutoStopTask?.cancel()
        let countdownNanoseconds = UInt64(max(silenceDetectionPolicy.warningCountdownSeconds, 0) * 1_000_000_000)
        screenContextAutoStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: countdownNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.triggerScreenContextAutoStopIfNeeded(alertID: alert.id, sessionID: session.id)
        }

        Task { @MainActor [recordingAlertNotifier] in
            _ = await recordingAlertNotifier.notifySharedWindowClosed(alert: alert)
        }
    }

    private func triggerScreenContextAutoStopIfNeeded(alertID: UUID, sessionID: UUID) async {
        guard case .recording(let currentSession) = state, currentSession.id == sessionID else { return }
        guard activeScreenContextAlert?.id == alertID else { return }

        appendRecordingSessionEvent(
            .autoStopExecuted,
            metadata: ["source": "screen_window_closed"],
            sessionID: sessionID
        )

        await clearScreenContextAutoStopWarning()
        stopRecordingIfAllowed(trigger: .screenContextAutoStop)
    }

    private func handleSilenceEvent(_ event: SilenceAutoStopEvent) async {
        switch event {
        case .statusChanged(let snapshot):
            silenceStatus = snapshot
        case .warningStarted(let alert):
            activeSilenceAlert = alert
            appendRecordingSessionEvent(
                .silenceWarningIssued,
                metadata: ["countdown_seconds": "\(Int(silenceDetectionPolicy.warningCountdownSeconds))"],
                sessionID: alert.sessionID
            )
            _ = await recordingAlertNotifier.notifySilenceStopWarning(alert: alert)
        case .warningCanceledBySpeech:
            if let sessionID = silenceStatus.sessionID {
                appendRecordingSessionEvent(.warningCanceledBySpeech, sessionID: sessionID)
            }
            activeSilenceAlert = nil
            await recordingAlertNotifier.clearSilenceStopWarning()
        case .warningCanceledByUser:
            if let sessionID = silenceStatus.sessionID {
                appendRecordingSessionEvent(
                    .keepRecordingSelected,
                    metadata: ["source": "silence"],
                    sessionID: sessionID
                )
            }
            activeSilenceAlert = nil
            await recordingAlertNotifier.clearSilenceStopWarning()
        case .autoStopTriggered:
            if let sessionID = silenceStatus.sessionID {
                appendRecordingSessionEvent(
                    .autoStopExecuted,
                    metadata: ["source": "silence"],
                    sessionID: sessionID
                )
            }
            activeSilenceAlert = nil
            await recordingAlertNotifier.clearSilenceStopWarning()
            stopRecordingIfAllowed(trigger: .silenceAutoStop)
        }
    }

    private func appendRecordingSessionEvent(
        _ eventType: RecordingSessionEventType,
        metadata: [String: String] = [:],
        sessionID: UUID? = nil
    ) {
        let resolvedSessionID = sessionID ?? currentRecordingSessionID ?? silenceStatus.sessionID
        guard let resolvedSessionID else { return }

        recordingSessionEvents.append(
            RecordingSessionEvent(
                sessionID: resolvedSessionID,
                eventType: eventType,
                metadata: metadata
            )
        )
    }

    private var currentRecordingSessionID: UUID? {
        if case .recording(let session) = state {
            return session.id
        }
        return silenceStatus.sessionID
    }

    func keepRecordingFromWarning() {
        Task { [silenceController] in
            await silenceController?.keepRecording()
        }
        Task { @MainActor [weak self] in
            await self?.clearScreenContextAutoStopWarning(logKeepSelection: true)
        }
    }

    func acknowledgeActiveScreenContextAlert() {
        guard let alertID = activeScreenContextAlert?.id else { return }
        _ = acknowledgeAlert(alertID: alertID)
    }

    @discardableResult
    func acknowledgeAlert(alertID: UUID) -> Bool {
        if activeScreenContextAlert?.id == alertID {
            activeScreenContextAlert?.status = .resolved
            screenContextAutoStopTask?.cancel()
            screenContextAutoStopTask = nil
            activeScreenContextAlert = nil
            Task { @MainActor [recordingAlertNotifier] in
                await recordingAlertNotifier.clearSharedWindowClosedWarning()
            }
            return true
        }
        return false
    }

    func currentSilenceStatusSnapshot() -> SilenceStatusSnapshot {
        silenceStatus
    }

    func sessionEvents(for sessionID: UUID) -> [RecordingSessionEvent] {
        recordingSessionEvents.filter { $0.sessionID == sessionID }
    }

    private func handleScreenContextLifecycleEvent(_ event: ScreenContextLifecycleEvent) {
        guard case .recording(let session) = state else { return }
        guard event.type == .sharedWindowClosed else { return }
        beginScreenContextAutoStopWarning(session: session, windowTitle: event.windowTitle)
    }

    func _testHandleScreenContextLifecycleEvent(_ event: ScreenContextLifecycleEvent) {
        handleScreenContextLifecycleEvent(event)
    }

    // MARK: - Pipeline

    private func startScreenContextCaptureIfNeeded(
        selection: ScreenContextWindowSelection?,
        offsetSeconds: TimeInterval
    ) async {
        guard screenCaptureEnabled else { return }
        guard let selection else { return }
        let selections = [selection]

        screenInferenceStatus = ScreenInferenceStatus(
            processedCount: screenCaptureBaseProcessedCount,
            skippedCount: screenCaptureBaseSkippedCount,
            isInferenceRunning: true,
            isFirstInferenceDeferred: false
        )

        do {
            try await screenContextCaptureService.startCapture(
                selections: selections,
                minimumFrameInterval: screenContextFrameIntervalSeconds,
                timestampOffsetSeconds: offsetSeconds,
                processingBusyGate: processingBusyGate,
                statusHandler: { [weak self] status in
                    Task { @MainActor [weak self] in
                        self?.updateScreenInferenceStatus(status)
                    }
                },
                frameHandler: { [weak self] frame in
                    Task { @MainActor [weak self] in
                        self?.updateLatestScreenCaptureImage(frame)
                    }
                },
                lifecycleEventHandler: { [weak self] lifecycleEvent in
                    Task { @MainActor [weak self] in
                        self?.handleScreenContextLifecycleEvent(lifecycleEvent)
                    }
                }
            )
        } catch {
            logger.error("Screen context capture failed: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
        }
    }

    private func startScreenContextCapture(
        selection: ScreenContextWindowSelection,
        offsetSeconds: TimeInterval
    ) async {
        _ = await stopScreenContextCaptureAndAppend()
        await clearScreenContextAutoStopWarning()
        await startScreenContextCaptureIfNeeded(selection: selection, offsetSeconds: offsetSeconds)
    }

    private func stopScreenContextCaptureAndAppend() async -> ScreenContextCaptureResult? {
        guard let captureResult = await screenContextCaptureService.stopCapture() else { return nil }
        screenCaptureBaseProcessedCount += captureResult.processedCount
        screenCaptureBaseSkippedCount += captureResult.skippedCount
        screenContextEvents.append(contentsOf: captureResult.events)
        screenContextEvents.sort { $0.timestampSeconds < $1.timestampSeconds }
        screenInferenceStatus = ScreenInferenceStatus(
            processedCount: screenCaptureBaseProcessedCount,
            skippedCount: screenCaptureBaseSkippedCount,
            isInferenceRunning: false,
            isFirstInferenceDeferred: false
        )
        return captureResult
    }

    private func startBackgroundProcessingObservation() {
        backgroundProcessingObserverTask?.cancel()

        let orchestrator = processingOrchestrator
        backgroundProcessingObserverTask = Task { [weak self] in
            guard let self else { return }

            var lastCompletedNoteURL: URL?
            let snapshots = await orchestrator.snapshots()

            for await snapshot in snapshots {
                if Task.isCancelled {
                    break
                }

                if case let .completed(noteURL, _) = snapshot.lastOutcome {
                    lastCompletedNoteURL = noteURL
                }

                await MainActor.run {
                    if self.backgroundProcessingSnapshot != snapshot {
                        self.backgroundProcessingSnapshot = snapshot
                    }
                    if self.lastBackgroundProcessedNoteURL != lastCompletedNoteURL {
                        self.lastBackgroundProcessedNoteURL = lastCompletedNoteURL
                    }
                }
            }
        }
    }

    private func extractScreenContextForImport(sourceURL: URL) async -> ScreenContextVideoInferenceResult? {
        guard screenContextSettingsStore.isVideoImportEnabled else { return nil }

        let access = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if access {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try await screenContextVideoExtractor.inferEvents(from: sourceURL)
        } catch {
            logger.error("Video screen context failed: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
            return nil
        }
    }

    private func isVideoImportURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .movie)
    }

    private func runPipeline(context: PipelineContext) async {
        do {
            let outputs = try await pipelineCoordinator.execute(
                context: context,
                progress: { [weak self] update in
                    Task { @MainActor [weak self] in
                        self?.applyPipelineProgress(update, context: context)
                    }
                }
            )
            progress = nil
            state = .done(noteURL: outputs.noteURL, audioURL: outputs.audioURL)
        } catch is CancellationError {
            progress = nil

            if let recorded = state.recordedContextIfAvailable {
                state = .recorded(
                    audioTempURL: recorded.audioTempURL,
                    durationSeconds: recorded.durationSeconds,
                    startedAt: recorded.startedAt,
                    stoppedAt: recorded.stoppedAt
                )
            } else {
                state = .idle
            }
        } catch let minuteError as MinuteError {
            progress = nil
            state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
        } catch {
            progress = nil
            state = .failed(error: .vaultWriteFailed, debugOutput: ErrorHandler.debugMessage(for: error))
        }
    }

    private func applyPipelineProgress(_ update: PipelineProgress, context: PipelineContext) {
        progress = min(max(update.fractionCompleted, 0), 1)

        switch update.stage {
        case .downloadingModels:
            state = .processing(stage: .downloadingModels, context: context)
        case .transcribing:
            state = .processing(stage: .transcribing, context: context)
        case .summarizing:
            state = .processing(stage: .summarizing, context: context)
        case .writing:
            guard let extraction = update.extraction else { return }
            state = .writing(context: context, extraction: extraction)
        }
    }

    private func makePipelineContext(
        audioTempURL: URL,
        audioDurationSeconds: TimeInterval,
        startedAt: Date,
        stoppedAt: Date,
        screenContextEvents: [ScreenContextEvent]
    ) async -> PipelineContext? {
        let configuration = AppConfiguration()

        // Validate vault selection.
        do {
            _ = try await vaultAccess.resolveVaultRootURL(timeout: .seconds(2))
        } catch {
            return nil
        }

        let workingDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-work-\(UUID().uuidString)", isDirectory: true)

        let effectiveOutputLanguage: OutputLanguage
        switch languageProcessing {
        case .autoToEnglish:
            effectiveOutputLanguage = .englishUS
        case .autoPreserve:
            effectiveOutputLanguage = outputLanguage
        }

        let globalVocabularySettings = vocabularySettingsStore.load()
        syncSessionVocabularyModeWithCurrentInput(using: globalVocabularySettings)
        let vocabularyResolution = sessionVocabularyResolver.resolve(
            globalSettings: globalVocabularySettings,
            sessionMode: sessionVocabularyMode,
            sessionCustomInput: sessionCustomVocabularyInput,
            readiness: sessionVocabularyReadiness
        )
        sessionVocabularyMode = vocabularyResolution.effectiveMode
        if vocabularyResolution.warningMessage != nil {
            sessionVocabularyWarningMessage = vocabularyResolution.warningMessage
        }

        return PipelineContext(
            vaultFolders: MeetingFileContract.VaultFolders(
                meetingsRoot: configuration.meetingsRelativePath,
                audioRoot: configuration.audioRelativePath,
                transcriptsRoot: configuration.transcriptsRelativePath
            ),
            audioTempURL: audioTempURL,
            audioDurationSeconds: audioDurationSeconds,
            startedAt: startedAt,
            stoppedAt: stoppedAt,
            workingDirectoryURL: workingDirectoryURL,
            saveAudio: configuration.saveAudio,
            saveTranscript: configuration.saveTranscript,
            normalizeAnalysisAudio: configuration.normalizeAnalysisAudio,
            screenContextEvents: screenContextEvents,
            transcriptionOverride: nil,
            transcriptionVocabulary: vocabularyResolution.transcriptionVocabulary,
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: effectiveOutputLanguage,
            knownSpeakerSuggestionsEnabled: configuration.knownSpeakerSuggestionsEnabled
        )
    }

    private func resolveSessionVocabularyReadiness() async -> VocabularyReadinessStatus {
        let backend = transcriptionBackendStore.selectedBackend()
        guard backend == .fluidAudio else {
            return .unsupported(backend: backend)
        }

        do {
            let validation = try await modelValidationProvider()
            let vocabularyModelIDs = (validation.missingModelIDs + validation.invalidModelIDs).filter {
                $0.hasSuffix("-ctc-vocab")
            }
            if !vocabularyModelIDs.isEmpty {
                return .missingModels(
                    backend: backend,
                    message: "Vocabulary models missing. Recording will continue without boosting."
                )
            }
            return .ready(backend: backend)
        } catch {
            return .missingModels(
                backend: backend,
                message: "Vocabulary model status unavailable. Recording will continue without boosting."
            )
        }
    }

    private func resetSessionVocabularyOverride() {
        sessionCustomVocabularyInput = ""
        sessionVocabularyWarningMessage = nil
        sessionVocabularyReadiness = .unsupported(backend: transcriptionBackend)
        syncSessionVocabularyModeWithCurrentInput()
    }

    private func syncSessionVocabularyModeWithCurrentInput(
        using settings: GlobalVocabularyBoostingSettings? = nil
    ) {
        let resolvedSettings = settings ?? vocabularySettingsStore.load()
        let hasCustomTerms = !VocabularyTermEntry.parseFromEditorInput(
            sessionCustomVocabularyInput,
            source: .sessionCustom
        ).isEmpty

        guard transcriptionBackend == .fluidAudio, resolvedSettings.enabled else {
            sessionVocabularyMode = .off
            return
        }

        sessionVocabularyMode = hasCustomTerms ? .custom : .default
    }


    // MARK: - Audio levels

    private func startAudioLevelMonitoring() async {
        guard let meter = audioService as? (any AudioLevelMetering) else { return }
        await meter.setLevelHandler { [weak self] level in
            Task { @MainActor [weak self] in
                self?.pushAudioLevel(level)
            }
        }
    }

    private func stopAudioLevelMonitoring() async {
        guard let meter = audioService as? (any AudioLevelMetering) else { return }
        await meter.setLevelHandler(nil)
    }

    private func resetAudioLevelSamples() {
        audioLevelSamples = Array(repeating: 0, count: audioLevelBucketCount)
        lastAudioLevelUpdate = 0
    }

    private func pushAudioLevel(_ level: Float) {
        let now = CACurrentMediaTime()
        guard now - lastAudioLevelUpdate >= audioLevelUpdateInterval else { return }
        lastAudioLevelUpdate = now

        if audioLevelSamples.count != audioLevelBucketCount {
            audioLevelSamples = Array(repeating: 0, count: audioLevelBucketCount)
        }

        let clamped = min(max(level, 0), 1)
        // Keep quiet microphone signal visible without affecting silence auto-stop logic.
        let visualTarget = min(max(powf(clamped, 0.55), 0), 1)
        let previous = Float(audioLevelSamples.last ?? 0)
        let smoothing: Float = visualTarget > previous ? 0.55 : 0.22
        let smoothed = previous + (visualTarget - previous) * smoothing
        audioLevelSamples.removeFirst()
        audioLevelSamples.append(CGFloat(smoothed))

        if case .recording = state {
            let silenceController = silenceController
            Task {
                await silenceController?.ingest(level: clamped, at: Date())
            }
        }
    }

    // MARK: - Permissions

    func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphonePermissionGranted = granted
        }
    }

    func requestScreenRecordingPermission() {
        Task { @MainActor [weak self] in
            let granted = await ScreenRecordingPermission.request()
            self?.screenRecordingPermissionGranted = granted
        }
    }

    private func refreshMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionGranted = (status == .authorized)
    }

    private func refreshScreenRecordingPermission() {
        Task { @MainActor [weak self] in
            let granted = await ScreenRecordingPermission.refresh()
            self?.screenRecordingPermissionGranted = granted
        }
    }



    // MARK: - Workspace continuity

    func workspaceContinuitySnapshot() -> WorkspaceContinuitySnapshot {
        WorkspaceContinuitySnapshot(
            isRecordingActive: captureState == .recording,
            pipelineStage: state.statusLabel,
            activeSessionID: currentSessionID,
            unsavedWorkPresent: hasActiveSessionContext
        )
    }

    func workspaceDidBecomeVisible() {
        refreshVaultStatus()
    }

    private var currentSessionID: String? {
        switch state {
        case .recording(let session):
            return session.id.uuidString
        default:
            return nil
        }
    }

    private var hasActiveSessionContext: Bool {
        switch state {
        case .recording, .recorded, .processing, .writing:
            return true
        case .done, .failed, .idle, .importing:
            return false
        }
    }
    // MARK: - UI helpers

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyDebugInfoToClipboard() {
        let content: String
        switch state {
        case .failed(let error, let debugOutput):
            var lines: [String] = []
            lines.append(ErrorHandler.userMessage(for: error, fallback: "Error"))
            lines.append(error.debugSummary)
            if let debugOutput, !debugOutput.isEmpty {
                lines.append(debugOutput)
            }
            content = lines.joined(separator: "\n\n")
        default:
            content = ""
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
    }
}

private struct FailingTranscriptionService: TranscriptionServicing {
    let error: MinuteError

    init(error: Error) {
        self.error = ErrorHandler.minuteError(
            for: error,
            fallback: .whisperFailed(exitCode: -1, output: ErrorHandler.debugMessage(for: error))
        )
    }

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        throw error
    }
}

final class ResilientWhisperTranscriptionService: TranscriptionServicing, @unchecked Sendable {
    private static let xpcOptInEnvironmentKey = "MINUTE_ENABLE_WHISPER_XPC"

    private let primary: any TranscriptionServicing
    private let fallback: any TranscriptionServicing
    private let stateLock = NSLock()
    private var primaryDisabled: Bool
    private let logger = Logger(subsystem: "roblibob.Minute", category: "whisper-resilience")

    init(
        primary: any TranscriptionServicing,
        fallback: any TranscriptionServicing,
        primaryEnabled: Bool = true
    ) {
        self.primary = primary
        self.fallback = fallback
        self.primaryDisabled = !primaryEnabled
    }

    static func liveDefault() -> ResilientWhisperTranscriptionService {
        let inProcess = WhisperLibraryTranscriptionService.liveDefault()
#if DEBUG
        let xpcOptInEnabled = ProcessInfo.processInfo.environment[Self.xpcOptInEnvironmentKey] == "1"
        if xpcOptInEnabled {
            return ResilientWhisperTranscriptionService(
                primary: WhisperXPCTranscriptionService.liveDefault(),
                fallback: inProcess,
                primaryEnabled: true
            )
        }
#endif
        return ResilientWhisperTranscriptionService(primary: inProcess, fallback: inProcess, primaryEnabled: false)
    }

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        if isPrimaryDisabled() {
            return try await fallback.transcribe(wavURL: wavURL)
        }

        do {
            return try await primary.transcribe(wavURL: wavURL)
        } catch {
            guard shouldFallbackToInProcessWhisper(for: error) else {
                throw error
            }

            disablePrimary()
            logger.error("Whisper XPC failed; retrying in-process whisper. reason=\(ErrorHandler.debugMessage(for: error), privacy: .public)")
            return try await fallback.transcribe(wavURL: wavURL)
        }
    }

    private func isPrimaryDisabled() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return primaryDisabled
    }

    private func disablePrimary() {
        stateLock.lock()
        if primaryDisabled {
            stateLock.unlock()
            return
        }
        primaryDisabled = true
        stateLock.unlock()
    }

    private func shouldFallbackToInProcessWhisper(for error: Error) -> Bool {
        if let minuteError = error as? MinuteError {
            switch minuteError {
            case .whisperMissing:
                return true
            case .whisperFailed(let exitCode, let output):
                guard exitCode == -1 else { return false }
                let normalized = output.lowercased()
                if normalized.isEmpty {
                    return true
                }
                if normalized.contains("code=257")
                    || normalized.contains("code=260")
                    || normalized.contains("operation not permitted")
                    || normalized.contains("no such file or directory")
                    || normalized.contains("don’t have permission")
                    || normalized.contains("don't have permission")
                    || normalized.contains("permission to view it")
                    || normalized.contains("nscocoaerrordomain")
                    || normalized.contains("nsposixerrordomain")
                    || normalized.contains("xpc")
                    || normalized.contains("inherited sandbox")
                    || normalized.contains("unable to obtain a task name port right") {
                    return true
                }
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain && nsError.code == 1 {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain && nsError.code == 2 {
            return true
        }

        if nsError.domain == "NSXPCConnectionErrorDomain" {
            return true
        }

        return false
    }
}
