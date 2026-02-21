import Foundation
import Testing
@testable import MinuteCore

struct WhisperXPCTranscriptionServiceTests {
    @Test
    func loadWavDataForXPC_readsInputData() throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-whisper-xpc-stage-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }

        let sourceURL = sourceDirectory.appendingPathComponent("contract.wav")
        let sourceData = Data([0x01, 0x02, 0x03, 0x04])
        try sourceData.write(to: sourceURL, options: [.atomic])

        let loaded = try WhisperXPCTranscriptionService.loadWavDataForXPC(sourceURL: sourceURL)
        #expect(loaded == sourceData)
    }

    @Test
    func loadWavDataForXPC_whenInputMissing_throws() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-whisper-xpc-stage-missing-\(UUID().uuidString).wav")

        #expect(throws: Error.self) {
            _ = try WhisperXPCTranscriptionService.loadWavDataForXPC(sourceURL: missingURL)
        }
    }
}
