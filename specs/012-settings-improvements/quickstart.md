# Quickstart: Settings Information Architecture Refresh

## Prerequisites

- Branch: `012-settings-improvements`
- macOS 14+ development environment
- Xcode configured for `Minute.xcodeproj`

## 1) Convert settings from overlay to single-window workspace

1. Update app-level routing so settings is displayed in the existing main window workspace.
2. Remove panel/overlay presentation for settings.
3. Ensure opening settings does not create any new `Window`/window scene instance.

## 2) Keep runtime continuity while switching workspaces

1. Ensure recording/session runtime state is owned by long-lived app state.
2. Confirm switching `pipeline -> settings -> pipeline` does not pause, cancel, or reset active recording.
3. Confirm in-progress session context remains intact after returning from settings.

## 3) Implement scalable settings sidebar organization

1. Define stable category metadata (id, title, order, visibility rule).
2. Render categories in sidebar and selected category content in main area.
3. Reorganize existing settings into clearer, task-oriented categories while preserving access to all options.

## 4) Accessibility and keyboard behavior

1. Verify keyboard-only navigation across categories and controls.
2. Verify focus order is stable when switching categories.
3. Verify labels and category names remain clear and discoverable.

## 5) Test-first coverage

1. Add/extend app tests in `MinuteTests` for:
   - single-window settings workspace behavior
   - category selection and visibility rules
   - continuity behavior while recording/in-progress work
2. Add/extend non-regression tests in `MinuteCore/Tests/MinuteCoreTests` for continuity-related pipeline invariants used by app routing.
3. Re-run existing output contract tests to ensure no regression in vault output behavior.

## 6) Validation commands

```bash
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test -destination 'platform=macOS'
xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'
```

## 7) Manual acceptance checklist

1. Opening settings replaces current content in the same window (no overlay, no extra window).
2. Sidebar categories remain visible and selecting each category updates main content.
3. All settings available before refactor are still reachable.
4. While recording, opening/closing settings does not interrupt recording.
5. While session work is in progress, returning from settings preserves current state.
6. Repeated settings open/close actions remain idempotent and do not duplicate windows.

## 8) Validation Evidence (2026-02-21)

### Build command

- Command: `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build`
- Result: PASS (`** BUILD SUCCEEDED **`)

### App test command

- Command: `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test -destination 'platform=macOS'`
- Result: PASS (`** TEST SUCCEEDED **`)
- Summary: `42 tests in 15 suites passed`
- xcresult: `/Users/roblibob/Library/Developer/Xcode/DerivedData/Minute-edmgxeanefatcjbkefoyqyndlmyp/Logs/Test/Test-Minute-2026.02.21_12-04-09-+0100.xcresult`

### MinuteCore test command

- Command: `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'`
- Result: PASS (`** TEST SUCCEEDED **`)
- Summary: `193 tests in 72 suites passed`
- xcresult: `/Users/roblibob/Library/Developer/Xcode/DerivedData/Minute-hksyobkiwxaismamsqqhhfmywtws/Logs/Test/Test-MinuteCore-2026.02.21_12-04-36-+0100.xcresult`

### Acceptance evidence for single-window + continuity

- Single-window workspace routing validated by passing tests:
  - `SettingsWorkspaceRoutingCoverageTests.settingsOpensInSingleWindowRoute`
  - `SettingsWorkspaceRoutingCoverageTests.closingSettingsReturnsToPipeline`
  - `SettingsWorkspaceRoutingCoverageTests.setActiveWorkspace_isIdempotent`
- Ongoing work/recording continuity validated by passing tests:
  - `SettingsWorkspaceContinuityCoverageTests.continuityInvariant_remainsTrueAcrossWorkspaceSwitches`
  - `SettingsWorkspaceContinuityCoverageTests.workspaceSnapshot_containsContractFlags`
- Category discoverability and fallback behavior validated by passing tests:
  - `SettingsCategoryCatalogCoverageTests.categoryOrder_isStableAndAscending`
  - `SettingsCategoryCatalogCoverageTests.discoverability_allCoreCategoriesPresent`
  - `SettingsCategoryCatalogCoverageTests.fallbackSelection_returnsFirstVisibleWhenCurrentMissing`

### Output-contract regression evidence

- Output contract and vault-path coverage remained green in `MinuteCore` test run, including:
  - `OutputContractCoverageTests`
  - `MeetingFileContractTests`
  - `VaultWriteCoverageTests`
  - `speakerFrontmatterUpdate_doesNotCreateExtraVaultFilesBeyondContractOutputs`
  - `vocabularyBoostingContext_stillProducesOnlyThreeVaultFiles`
