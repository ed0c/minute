import Foundation
import os
import MinuteCore
import MinuteWhisper

@main
struct WhisperXPCMain {
    static func main() {
        let delegate = WhisperXPCServiceDelegate()
        let listener = NSXPCListener.service()
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}

final class WhisperXPCServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let service = WhisperXPCService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: WhisperXPCTranscriptionProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}

final class WhisperXPCService: NSObject, WhisperXPCTranscriptionProtocol {
    private let worker = WhisperXPCWorker()
    private let encoder = JSONEncoder()

    func transcribe(
        wavData: Data,
        modelPath: String,
        detectLanguage: Bool,
        language: String,
        threads: Int,
        reply: @escaping (Data?, String?) -> Void
    ) {
        Task {
            do {
                let result = try await worker.transcribe(
                    wavData: wavData,
                    modelPath: modelPath,
                    detectLanguage: detectLanguage,
                    language: language,
                    threads: threads
                )
                let data = try encoder.encode(result)
                reply(data, nil)
            } catch {
                if let minuteError = error as? MinuteError {
                    reply(nil, minuteError.debugSummary)
                } else {
                    reply(nil, String(describing: error))
                }
            }
        }
    }
}

actor WhisperXPCWorker {
    func transcribe(
        wavData: Data,
        modelPath: String,
        detectLanguage: Bool,
        language: String,
        threads: Int
    ) async throws -> WhisperXPCTranscriptionResult {
        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xpc-input-\(UUID().uuidString).wav")
        try wavData.write(to: inputURL, options: [.atomic])
        defer {
            try? FileManager.default.removeItem(at: inputURL)
        }

        let service = WhisperLibraryTranscriptionService(
            configuration: WhisperLibraryTranscriptionConfiguration(
                modelURL: URL(fileURLWithPath: modelPath),
                detectLanguage: detectLanguage,
                language: language,
                threads: threads
            )
        )

        let result = try await service.transcribe(wavURL: inputURL)
        let segments = result.segments.map { segment in
            WhisperXPCSegment(
                startSeconds: segment.startSeconds,
                endSeconds: segment.endSeconds,
                text: segment.text
            )
        }
        return WhisperXPCTranscriptionResult(text: result.text, segments: segments)
    }
}
