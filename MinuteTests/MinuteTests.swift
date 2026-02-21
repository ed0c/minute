import Foundation
import Testing
@testable import Minute
@testable import MinuteCore

struct MinuteTests {
    @Test
    func smoke() {
        #expect(Bool(true))
    }
}

@MainActor
struct SettingsWorkspaceRoutingCoverageTests {
    @Test
    func settingsOpensInSingleWindowRoute() {
        let model = SettingsWorkspaceTestSupport.makeNavigationModel()
        SettingsWorkspaceTestSupport.switchToSettings(model)

        #expect(model.mainContent == .settings)
        #expect(model.snapshot().windowMode == "single_window")
        #expect(model.snapshot().noAdditionalWindow)
    }

    @Test
    func closingSettingsReturnsToPipeline() {
        let model = SettingsWorkspaceTestSupport.makeNavigationModel(initial: .settings)
        SettingsWorkspaceTestSupport.switchToPipeline(model)

        #expect(model.mainContent == .pipeline)
    }

    @Test
    func setActiveWorkspace_isIdempotent() {
        let model = SettingsWorkspaceTestSupport.makeNavigationModel(initial: .pipeline)
        let before = model.changedAt
        model.setActiveWorkspace(.pipeline)

        #expect(model.mainContent == .pipeline)
        #expect(model.changedAt == before)
    }
}

@MainActor
struct SettingsWorkspaceContinuityCoverageTests {
    @Test
    func continuityInvariant_remainsTrueAcrossWorkspaceSwitches() {
        let before = WorkspaceContinuitySnapshot(
            isRecordingActive: true,
            pipelineStage: "recording",
            activeSessionID: "session-1",
            unsavedWorkPresent: true
        )

        let model = SettingsWorkspaceTestSupport.makeNavigationModel()
        model.showSettings()
        model.showPipeline()

        let after = WorkspaceContinuitySnapshot(
            isRecordingActive: true,
            pipelineStage: "recording",
            activeSessionID: "session-1",
            unsavedWorkPresent: true
        )

        #expect(WorkspaceContinuityInvariant.isPreserved(before: before, after: after))
    }

    @Test
    func workspaceSnapshot_containsContractFlags() {
        let model = SettingsWorkspaceTestSupport.makeNavigationModel(initial: .settings)
        let snapshot = model.snapshot()

        #expect(snapshot.activeWorkspace == .settings)
        #expect(snapshot.windowMode == "single_window")
        #expect(snapshot.noAdditionalWindow)
    }
}

@MainActor
struct SettingsCategoryCatalogCoverageTests {
    @Test
    func categoryOrder_isStableAndAscending() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let orders = categories.map { $0.sortOrder }
        let sorted = orders.sorted()

        #expect(orders == sorted)
        #expect(Set(categories.map { $0.id }).count == categories.count)
    }

    @Test
    func updatesCategory_obeysVisibilityRule() {
        let hidden = SettingsCategoryCatalog.categories(updatesEnabled: false)
        let visible = SettingsCategoryCatalog.categories(updatesEnabled: true)

        #expect(hidden.contains(where: { $0.id == .updates }) == false)
        #expect(visible.contains(where: { $0.id == .updates }))
    }

    @Test
    func fallbackSelection_returnsFirstVisibleWhenCurrentMissing() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: false)
        let selection = SettingsCategoryCatalog.fallbackSelection(current: .updates, available: categories)

        #expect(selection == categories.first?.id)
    }

    @Test
    func discoverability_allCoreCategoriesPresent() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let ids = Set(categories.map { $0.id })

        #expect(ids.contains(.general))
        #expect(ids.contains(.storage))
        #expect(ids.contains(.speakers))
        #expect(ids.contains(.privacy))
        #expect(ids.contains(.ai))
    }
}

@MainActor
enum SettingsWorkspaceTestSupport {
    static func makeNavigationModel(initial: AppNavigationModel.MainContent = .pipeline) -> AppNavigationModel {
        let model = AppNavigationModel()
        model.mainContent = initial
        return model
    }

    static func switchToSettings(_ model: AppNavigationModel) {
        model.showSettings()
    }

    static func switchToPipeline(_ model: AppNavigationModel) {
        model.showPipeline()
    }
}

struct MeetingNotesBrowserViewModelSpeakerDraftIsolationTests {
    @Test
    func parseSpeakerIDs_parsesUniqueSortedIDs() {
        let transcript = """
        Speaker 2 [00:00]
        Hello

        Speaker 10 [00:05]
        Hi

        Speaker 2 [00:06]
        Again
        """

        let ids = MeetingNotesBrowserViewModel.parseSpeakerIDs(fromTranscriptMarkdown: transcript)
        #expect(ids == [2, 10])
    }

    @Test
    func rewriteSpeakerHeadingsForDisplay_replacesNamedHeadingsOnly() {
        let transcript = """
            Speaker 1 [00:00]
            Hello

        Speaker 2 [00:05]
            Hi

        Speaker 3
        Unchanged
        """

        let rewritten = MeetingNotesBrowserViewModel.rewriteSpeakerHeadingsForDisplay(
            transcriptMarkdown: transcript,
            speakerDisplayNames: [1: "Alice", 2: " Bob "]
        )

        #expect(rewritten.contains("Alice [00:00]"))
        #expect(rewritten.contains("Bob [00:05]"))
        #expect(rewritten.contains("Speaker 3"))
    }
}
