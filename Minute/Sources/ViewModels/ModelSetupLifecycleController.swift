import Combine
import Foundation
import MinuteCore

@MainActor
final class ModelSetupLifecycleController: ObservableObject {
    enum State: Equatable {
        case checking
        case ready
        case needsDownload(message: String?)
        case downloading(progress: ModelDownloadProgress?)
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var lastValidation = ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])

    private let modelManager: any ModelManaging
    private let displayName: (String) -> String
    private var downloadTask: Task<Void, Never>?
    private var validationTask: Task<Void, Never>?

    init(
        modelManager: any ModelManaging,
        displayName: @escaping (String) -> String
    ) {
        self.modelManager = modelManager
        self.displayName = displayName
    }

    deinit {
        downloadTask?.cancel()
        validationTask?.cancel()
    }

    func refresh() {
        scheduleValidation()
    }

    func startDownload() {
        downloadTask?.cancel()
        state = .downloading(progress: ModelDownloadProgress(fractionCompleted: 0, label: "Starting download"))

        downloadTask = Task { [weak self] in
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
                await refreshStatus()
            } catch {
                let message = ErrorHandler.userMessage(for: error, fallback: "Failed to download models.")
                state = .needsDownload(message: message)
            }
        }
    }

    private func scheduleValidation() {
        validationTask?.cancel()
        validationTask = Task { [weak self] in
            guard let self else { return }
            await refreshStatus()
        }
    }

    private func refreshStatus() async {
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
            lastValidation = result
            if result.isReady {
                state = .ready
            } else {
                state = .needsDownload(message: modelMessage(from: result))
            }
        } catch {
            guard !Task.isCancelled else { return }
            lastValidation = ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
            let message = ErrorHandler.userMessage(for: error, fallback: "Failed to check model status.")
            state = .needsDownload(message: message)
        }
    }

    private func modelMessage(from result: ModelValidationResult) -> String {
        if result.missingModelIDs.isEmpty && result.invalidModelIDs.isEmpty {
            return "Models ready."
        }

        var parts: [String] = []
        if !result.missingModelIDs.isEmpty {
            let names = result.missingModelIDs.map(displayName)
            parts.append("Missing: \(names.joined(separator: ", "))")
        }
        if !result.invalidModelIDs.isEmpty {
            let names = result.invalidModelIDs.map(displayName)
            parts.append("Invalid: \(names.joined(separator: ", "))")
        }
        return parts.joined(separator: " ")
    }
}
