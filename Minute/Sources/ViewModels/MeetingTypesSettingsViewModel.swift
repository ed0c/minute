import Combine
import Foundation
import MinuteCore

@MainActor
final class MeetingTypesSettingsViewModel: ObservableObject {
    private struct DraftSnapshot: Equatable {
        var displayName: String
        var objective: String
        var summaryFocus: String
        var decisionRulesEnabled: Bool
        var decisionRules: String
        var actionItemRulesEnabled: Bool
        var actionItemRules: String
        var openQuestionRulesEnabled: Bool
        var openQuestionRules: String
        var keyPointRulesEnabled: Bool
        var keyPointRules: String
        var noiseFilterRules: String
        var additionalGuidance: String
        var autodetectEligible: Bool
        var classifierLabel: String
        var classifierSignalsInput: String
        var classifierCounterSignalsInput: String
        var classifierPositiveExamplesInput: String
        var classifierNegativeExamplesInput: String
    }

    @Published private(set) var library: MeetingTypeLibrary = .default
    @Published var selectedTypeID: String?
    @Published var draftDisplayName: String = ""
    @Published var draftObjective: String = ""
    @Published var draftSummaryFocus: String = ""
    @Published var draftDecisionRulesEnabled: Bool = true
    @Published var draftDecisionRules: String = ""
    @Published var draftActionItemRulesEnabled: Bool = true
    @Published var draftActionItemRules: String = ""
    @Published var draftOpenQuestionRulesEnabled: Bool = true
    @Published var draftOpenQuestionRules: String = ""
    @Published var draftKeyPointRulesEnabled: Bool = true
    @Published var draftKeyPointRules: String = ""
    @Published var draftNoiseFilterRules: String = ""
    @Published var draftAdditionalGuidance: String = ""
    @Published var draftAutodetectEligible: Bool = false
    @Published var draftClassifierLabel: String = ""
    @Published var draftClassifierSignalsInput: String = ""
    @Published var draftClassifierCounterSignalsInput: String = ""
    @Published var draftClassifierPositiveExamplesInput: String = ""
    @Published var draftClassifierNegativeExamplesInput: String = ""
    @Published var errorMessage: String?
    @Published var isCreatingCustomType: Bool = false
    @Published var pendingDeleteTypeID: String?

    private let store: MeetingTypeLibraryStore
    private var baselineSnapshot = DraftSnapshot(
        displayName: "",
        objective: "",
        summaryFocus: "",
        decisionRulesEnabled: true,
        decisionRules: "",
        actionItemRulesEnabled: true,
        actionItemRules: "",
        openQuestionRulesEnabled: true,
        openQuestionRules: "",
        keyPointRulesEnabled: true,
        keyPointRules: "",
        noiseFilterRules: "",
        additionalGuidance: "",
        autodetectEligible: false,
        classifierLabel: "",
        classifierSignalsInput: "",
        classifierCounterSignalsInput: "",
        classifierPositiveExamplesInput: "",
        classifierNegativeExamplesInput: ""
    )

    init(store: MeetingTypeLibraryStore = MeetingTypeLibraryStore()) {
        self.store = store
        refresh()
    }

    var meetingTypes: [MeetingTypeDefinition] {
        library.activeDefinitions.filter { $0.typeId != MeetingType.autodetect.rawValue }
    }

    var selectedDefinition: MeetingTypeDefinition? {
        guard let selectedTypeID else { return nil }
        return library.definition(for: selectedTypeID)
    }

    var isEditingBuiltIn: Bool {
        guard let selected = selectedDefinition, !isCreatingCustomType else { return false }
        return selected.source == .builtIn
    }

    var isEditingCustomType: Bool {
        guard let selected = selectedDefinition, !isCreatingCustomType else { return false }
        return selected.source == .custom
    }

    var isSelectedBuiltInOverridden: Bool {
        guard let selected = selectedDefinition, selected.source == .builtIn else { return false }
        return library.isBuiltInOverridden(typeID: selected.typeId)
    }

    var canRestoreSelectedBuiltInDefault: Bool {
        guard let selected = selectedDefinition else { return false }
        return selected.source == .builtIn && isSelectedBuiltInOverridden
    }

    var canDeleteSelectedCustomType: Bool {
        guard let selected = selectedDefinition else { return false }
        return selected.source == .custom
    }

    var isDeleteConfirmationPresented: Bool {
        pendingDeleteTypeID != nil
    }

    var hasUnsavedChanges: Bool {
        currentSnapshot() != baselineSnapshot
    }

    var parsedClassifierSignalCount: Int {
        parseListInput(draftClassifierSignalsInput).count
    }

    var canSaveDraft: Bool {
        let hasDisplayName: Bool
        if isCreatingCustomType || selectedDefinition?.source == .custom {
            hasDisplayName = !draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            hasDisplayName = true
        }

        let hasObjective = !draftObjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasSummaryFocus = !draftSummaryFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasClassifierInfo: Bool
        if draftAutodetectEligible {
            let hasLabel = !draftClassifierLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            hasClassifierInfo = hasLabel && parsedClassifierSignalCount > 0
        } else {
            hasClassifierInfo = true
        }

        guard hasDisplayName && hasObjective && hasSummaryFocus && hasClassifierInfo else {
            return false
        }

        if isCreatingCustomType {
            return hasUnsavedChanges
        }

        return selectedDefinition != nil && hasUnsavedChanges
    }

    func refresh() {
        let loaded = store.load()
        library = loaded

        if selectedTypeID == nil || selectedTypeID == MeetingType.autodetect.rawValue {
            selectedTypeID = meetingTypes.first?.typeId
        } else if meetingTypes.contains(where: { $0.typeId == selectedTypeID }) == false {
            selectedTypeID = meetingTypes.first?.typeId
        }

        syncDraftWithSelection()
    }

    func selectType(typeID: String) {
        guard typeID != MeetingType.autodetect.rawValue else {
            selectedTypeID = meetingTypes.first?.typeId
            syncDraftWithSelection()
            return
        }
        selectedTypeID = typeID
        isCreatingCustomType = false
        pendingDeleteTypeID = nil
        errorMessage = nil
        syncDraftWithSelection()
    }

    func startCreateCustomType() {
        isCreatingCustomType = true
        selectedTypeID = nil
        pendingDeleteTypeID = nil
        errorMessage = nil
        draftDisplayName = ""
        draftObjective = ""
        draftSummaryFocus = ""
        draftDecisionRulesEnabled = true
        draftDecisionRules = ""
        draftActionItemRulesEnabled = true
        draftActionItemRules = ""
        draftOpenQuestionRulesEnabled = true
        draftOpenQuestionRules = ""
        draftKeyPointRulesEnabled = true
        draftKeyPointRules = ""
        draftNoiseFilterRules = ""
        draftAdditionalGuidance = ""
        draftAutodetectEligible = false
        draftClassifierLabel = ""
        draftClassifierSignalsInput = ""
        draftClassifierCounterSignalsInput = ""
        draftClassifierPositiveExamplesInput = ""
        draftClassifierNegativeExamplesInput = ""
        baselineSnapshot = currentSnapshot()
    }

    func cancelCreateCustomType() {
        isCreatingCustomType = false
        pendingDeleteTypeID = nil
        errorMessage = nil
        if selectedTypeID == nil || selectedTypeID == MeetingType.autodetect.rawValue {
            selectedTypeID = meetingTypes.first?.typeId
        } else if meetingTypes.contains(where: { $0.typeId == selectedTypeID }) == false {
            selectedTypeID = meetingTypes.first?.typeId
        }
        syncDraftWithSelection()
    }

    func saveDraft() {
        errorMessage = nil
        do {
            if isCreatingCustomType {
                let created = try store.createCustomType(
                    displayName: draftDisplayName,
                    promptComponents: buildPromptComponents(),
                    autodetectEligible: draftAutodetectEligible,
                    classifierProfile: buildClassifierProfileIfNeeded()
                )
                isCreatingCustomType = false
                refresh()
                selectedTypeID = created.typeId
                syncDraftWithSelection()
                return
            }

            guard let selected = selectedDefinition else {
                errorMessage = "Select a meeting type first."
                return
            }

            if selected.source == .builtIn {
                _ = try store.saveBuiltInOverride(
                    typeID: selected.typeId,
                    promptComponents: buildPromptComponents()
                )
                refresh()
                selectedTypeID = selected.typeId
                syncDraftWithSelection()
                return
            }

            let updated = try store.updateCustomType(
                typeID: selected.typeId,
                displayName: draftDisplayName,
                promptComponents: buildPromptComponents(),
                autodetectEligible: draftAutodetectEligible,
                classifierProfile: buildClassifierProfileIfNeeded()
            )
            refresh()
            selectedTypeID = updated.typeId
            syncDraftWithSelection()
        } catch let error as MeetingTypeLibraryStoreError {
            switch error {
            case .duplicateDisplayName:
                errorMessage = "Meeting type name must be unique."
            case .unknownTypeID:
                errorMessage = "Selected meeting type could not be found."
            case .typeIsNotCustom:
                errorMessage = "Only custom meeting types can be renamed or deleted."
            case .typeIsNotBuiltIn:
                errorMessage = "Selected type is not built-in."
            case .typeIsNotEditable:
                errorMessage = "This type cannot be edited."
            case .typeAlreadyDeleted:
                errorMessage = "This meeting type was already removed. Refresh and choose another."
            }
        } catch let error as MeetingTypeLibraryValidationError {
            switch error {
            case .missingPromptObjective:
                errorMessage = "Objective is required."
            case .missingPromptSummaryFocus:
                errorMessage = "Summary focus is required."
            case .emptyDisplayName:
                errorMessage = "Meeting type name is required."
            case .autodetectClassifierMissing:
                errorMessage = "Classifier label is required when autodetect is enabled."
            case .autodetectClassifierSignalsMissing:
                errorMessage = "Add at least one classifier signal when autodetect is enabled."
            default:
                errorMessage = "Please correct the highlighted fields and try again."
            }
        } catch {
            errorMessage = "Failed to save meeting type."
        }
    }

    func restoreBuiltInDefault() {
        errorMessage = nil
        guard let selected = selectedDefinition else { return }
        guard selected.source == .builtIn else {
            errorMessage = "Only built-in meeting types can be restored."
            return
        }

        do {
            _ = try store.restoreBuiltInDefault(typeID: selected.typeId)
            refresh()
            selectedTypeID = selected.typeId
            syncDraftWithSelection()
        } catch {
            errorMessage = "Failed to restore built-in default."
        }
    }

    func requestDeleteSelectedCustomType() {
        errorMessage = nil
        guard let selected = selectedDefinition else { return }
        guard selected.source == .custom else {
            errorMessage = "Built-in meeting types cannot be deleted."
            return
        }
        pendingDeleteTypeID = selected.typeId
    }

    func cancelDeleteConfirmation() {
        pendingDeleteTypeID = nil
    }

    func confirmDeleteSelectedCustomType() {
        errorMessage = nil
        guard let pendingDeleteTypeID else { return }
        do {
            _ = try store.deleteCustomType(typeID: pendingDeleteTypeID)
            self.pendingDeleteTypeID = nil
            refresh()

            if selectedTypeID == pendingDeleteTypeID {
                selectedTypeID = library.activeDefinitions.first?.typeId
            }
            syncDraftWithSelection()
        } catch {
            errorMessage = "Failed to delete meeting type."
            self.pendingDeleteTypeID = nil
        }
    }

    private func buildClassifierProfileIfNeeded() -> ClassifierProfile? {
        guard draftAutodetectEligible else { return nil }

        return ClassifierProfile(
            label: draftClassifierLabel,
            strongSignals: parseListInput(draftClassifierSignalsInput),
            counterSignals: parseListInput(draftClassifierCounterSignalsInput),
            positiveExamples: parseListInput(draftClassifierPositiveExamplesInput),
            negativeExamples: parseListInput(draftClassifierNegativeExamplesInput)
        )
    }

    private func syncDraftWithSelection() {
        guard !isCreatingCustomType else { return }
        guard let selected = selectedDefinition else {
            draftDisplayName = ""
            draftObjective = ""
            draftSummaryFocus = ""
            draftDecisionRulesEnabled = true
            draftDecisionRules = ""
            draftActionItemRulesEnabled = true
            draftActionItemRules = ""
            draftOpenQuestionRulesEnabled = true
            draftOpenQuestionRules = ""
            draftKeyPointRulesEnabled = true
            draftKeyPointRules = ""
            draftNoiseFilterRules = ""
            draftAdditionalGuidance = ""
            draftAutodetectEligible = false
            draftClassifierLabel = ""
            draftClassifierSignalsInput = ""
            draftClassifierCounterSignalsInput = ""
            draftClassifierPositiveExamplesInput = ""
            draftClassifierNegativeExamplesInput = ""
            baselineSnapshot = currentSnapshot()
            return
        }

        draftDisplayName = selected.displayName
        draftObjective = selected.promptComponents.objective
        draftSummaryFocus = selected.promptComponents.summaryFocus
        draftDecisionRulesEnabled = selected.promptComponents.decisionRulesEnabled
        draftDecisionRules = selected.promptComponents.decisionRules
        draftActionItemRulesEnabled = selected.promptComponents.actionItemRulesEnabled
        draftActionItemRules = selected.promptComponents.actionItemRules
        draftOpenQuestionRulesEnabled = selected.promptComponents.openQuestionRulesEnabled
        draftOpenQuestionRules = selected.promptComponents.openQuestionRules
        draftKeyPointRulesEnabled = selected.promptComponents.keyPointRulesEnabled
        draftKeyPointRules = selected.promptComponents.keyPointRules
        draftNoiseFilterRules = selected.promptComponents.noiseFilterRules
        draftAdditionalGuidance = selected.promptComponents.additionalGuidance
        draftAutodetectEligible = selected.autodetectEligible
        draftClassifierLabel = selected.classifierProfile?.label ?? ""
        draftClassifierSignalsInput = selected.classifierProfile?.strongSignals.joined(separator: ", ") ?? ""
        draftClassifierCounterSignalsInput = selected.classifierProfile?.counterSignals.joined(separator: ", ") ?? ""
        draftClassifierPositiveExamplesInput = selected.classifierProfile?.positiveExamples.joined(separator: ", ") ?? ""
        draftClassifierNegativeExamplesInput = selected.classifierProfile?.negativeExamples.joined(separator: ", ") ?? ""
        baselineSnapshot = currentSnapshot()
    }

    private func buildPromptComponents() -> PromptComponentSet {
        PromptComponentSet(
            objective: draftObjective,
            summaryFocus: draftSummaryFocus,
            decisionRulesEnabled: draftDecisionRulesEnabled,
            decisionRules: draftDecisionRules,
            actionItemRulesEnabled: draftActionItemRulesEnabled,
            actionItemRules: draftActionItemRules,
            openQuestionRulesEnabled: draftOpenQuestionRulesEnabled,
            openQuestionRules: draftOpenQuestionRules,
            keyPointRulesEnabled: draftKeyPointRulesEnabled,
            keyPointRules: draftKeyPointRules,
            noiseFilterRules: draftNoiseFilterRules,
            additionalGuidance: draftAdditionalGuidance
        )
    }

    private func parseListInput(_ value: String) -> [String] {
        value
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizeListInput(_ value: String) -> String {
        parseListInput(value).joined(separator: ", ")
    }

    private func currentSnapshot() -> DraftSnapshot {
        DraftSnapshot(
            displayName: draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            objective: draftObjective.trimmingCharacters(in: .whitespacesAndNewlines),
            summaryFocus: draftSummaryFocus.trimmingCharacters(in: .whitespacesAndNewlines),
            decisionRulesEnabled: draftDecisionRulesEnabled,
            decisionRules: draftDecisionRules.trimmingCharacters(in: .whitespacesAndNewlines),
            actionItemRulesEnabled: draftActionItemRulesEnabled,
            actionItemRules: draftActionItemRules.trimmingCharacters(in: .whitespacesAndNewlines),
            openQuestionRulesEnabled: draftOpenQuestionRulesEnabled,
            openQuestionRules: draftOpenQuestionRules.trimmingCharacters(in: .whitespacesAndNewlines),
            keyPointRulesEnabled: draftKeyPointRulesEnabled,
            keyPointRules: draftKeyPointRules.trimmingCharacters(in: .whitespacesAndNewlines),
            noiseFilterRules: draftNoiseFilterRules.trimmingCharacters(in: .whitespacesAndNewlines),
            additionalGuidance: draftAdditionalGuidance.trimmingCharacters(in: .whitespacesAndNewlines),
            autodetectEligible: draftAutodetectEligible,
            classifierLabel: draftClassifierLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            classifierSignalsInput: normalizeListInput(draftClassifierSignalsInput),
            classifierCounterSignalsInput: normalizeListInput(draftClassifierCounterSignalsInput),
            classifierPositiveExamplesInput: normalizeListInput(draftClassifierPositiveExamplesInput),
            classifierNegativeExamplesInput: normalizeListInput(draftClassifierNegativeExamplesInput)
        )
    }
}
