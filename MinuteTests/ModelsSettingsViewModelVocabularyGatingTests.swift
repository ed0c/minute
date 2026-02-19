import Foundation
import Testing
@testable import Minute
@testable import MinuteCore

struct ModelsSettingsViewModelVocabularyGatingTests {
    @Test
    func vocabularyControlsHidden_whenBackendIsWhisper() async throws {
        let suite = "ModelsSettingsViewModelVocabularyGatingWhisper.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.whisper.rawValue)

        let model = await MainActor.run {
            ModelsSettingsViewModel(
                modelManager: StubModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
                summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
                transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
                transcriptionBackendStore: backendStore,
                fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
            )
        }

        let isFluid = await MainActor.run { model.isFluidAudioSelected }
        #expect(isFluid == false)
    }

    @Test
    func vocabularyControlsVisible_whenBackendIsFluidAudio() async throws {
        let suite = "ModelsSettingsViewModelVocabularyGatingFluid.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.fluidAudio.rawValue)

        let model = await MainActor.run {
            ModelsSettingsViewModel(
                modelManager: StubModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
                summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
                transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
                transcriptionBackendStore: backendStore,
                fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
            )
        }

        let isFluid = await MainActor.run { model.isFluidAudioSelected }
        #expect(isFluid == true)
    }
}

private struct StubModelManager: ModelManaging {
    var validation: ModelValidationResult

    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        _ = progress
    }

    func validateModels() async throws -> ModelValidationResult {
        validation
    }

    func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}
