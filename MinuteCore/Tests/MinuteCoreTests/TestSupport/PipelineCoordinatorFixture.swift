import Foundation
@testable import MinuteCore

enum PipelineCoordinatorFixture {
    static func makeCoordinator(vaultRootURL: URL) throws -> MeetingPipelineCoordinator {
        let vaultAccess = try RefactorParityTestSupport.makeVaultAccess(vaultRootURL: vaultRootURL)
        return MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: { MockSummarizationService() },
            modelManager: MockModelManager(),
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter()
        )
    }

    static func makeRecordingArtifacts(
        in directory: URL,
        basename: String = "fixture-recording"
    ) throws -> (audioTempURL: URL, workingDirectoryURL: URL) {
        let workingDirectory = directory.appendingPathComponent("working-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        let audioURL = workingDirectory.appendingPathComponent("\(basename).wav")
        try Data([0x00, 0x01, 0x02]).write(to: audioURL, options: [.atomic])
        return (audioTempURL: audioURL, workingDirectoryURL: workingDirectory)
    }
}
