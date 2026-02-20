@preconcurrency import FluidAudio
import Foundation
import os

public struct FluidAudioASRModelManager: ModelManaging, @unchecked Sendable {
    private let selectionStore: FluidAudioASRModelSelectionStore
    private let logger = Logger(subsystem: "roblibob.Minute", category: "fluidaudio.models")
    private static let ctcVocabularyVariant: CtcModelVariant = .ctc110m

    public init(selectionStore: FluidAudioASRModelSelectionStore = FluidAudioASRModelSelectionStore()) {
        self.selectionStore = selectionStore
    }

    public static func vocabularyModelID(for model: FluidAudioASRModel) -> String {
        "\(model.id)-ctc-vocab"
    }

    public func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        let model = selectionStore.selectedModel()
        let version = FluidAudioASRVersionResolver.version(for: model.versionKey)
        let vocabularyModelID = Self.vocabularyModelID(for: model)

        progress?(ModelDownloadProgress(fractionCompleted: 0, label: "Downloading \(model.displayName)"))

        do {
            try await AsrModels.download(version: version)
            progress?(ModelDownloadProgress(fractionCompleted: 0.75, label: "Downloaded \(model.displayName)"))

            progress?(ModelDownloadProgress(fractionCompleted: 0.8, label: "Downloading \(vocabularyModelID)"))
            try await CtcModels.download(variant: Self.ctcVocabularyVariant)
            progress?(ModelDownloadProgress(fractionCompleted: 1, label: "Downloaded \(vocabularyModelID)"))
        } catch {
            logger.error("Failed to download FluidAudio ASR models: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            throw MinuteError.modelDownloadFailed(underlyingDescription: ErrorHandler.debugMessage(for: error))
        }
    }

    public func validateModels() async throws -> ModelValidationResult {
        let model = selectionStore.selectedModel()
        let version = FluidAudioASRVersionResolver.version(for: model.versionKey)
        let asrCacheDir = AsrModels.defaultCacheDirectory(for: version)
        let ctcCacheDir = CtcModels.defaultCacheDirectory(for: Self.ctcVocabularyVariant)

        var missingModelIDs: [String] = []
        if !AsrModels.modelsExist(at: asrCacheDir, version: version) {
            missingModelIDs.append(model.id)
        }
        if !CtcModels.modelsExist(at: ctcCacheDir) {
            missingModelIDs.append(Self.vocabularyModelID(for: model))
        }

        return ModelValidationResult(missingModelIDs: missingModelIDs, invalidModelIDs: [])
    }

    public func removeModels(withIDs ids: [String]) async throws {
        let model = selectionStore.selectedModel()
        let vocabularyModelID = Self.vocabularyModelID(for: model)
        let shouldRemoveASR = ids.contains(model.id)
        let shouldRemoveVocabulary = ids.contains(vocabularyModelID)

        guard shouldRemoveASR || shouldRemoveVocabulary else { return }

        if shouldRemoveASR {
            let version = FluidAudioASRVersionResolver.version(for: model.versionKey)
            let asrCacheDir = AsrModels.defaultCacheDirectory(for: version)
            try removeDirectoryIfPresent(
                asrCacheDir,
                modelID: model.id
            )
        }

        if shouldRemoveVocabulary {
            let ctcCacheDir = CtcModels.defaultCacheDirectory(for: Self.ctcVocabularyVariant)
            try removeDirectoryIfPresent(
                ctcCacheDir,
                modelID: vocabularyModelID
            )
        }
    }

    private func removeDirectoryIfPresent(_ directoryURL: URL, modelID: String) throws {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: directoryURL)
        } catch {
            throw MinuteError.modelDownloadFailed(
                underlyingDescription: "Failed to remove FluidAudio model \(modelID): \(error)"
            )
        }
    }
}
