# Quickstart: Vocabulary Boosting Controls

## Prerequisites

- Branch: `011-vocabulary-boosting`
- macOS 14+ development environment
- Xcode with Swift package resolution available

## 1) Upgrade dependency (Step 0)

1. Update `MinuteCore/Package.swift` FluidAudio dependency to the latest stable release.
2. Resolve packages and update `MinuteCore/Package.resolved`.
3. Confirm `MinuteCore` builds successfully after dependency upgrade.

## 2) Implement global settings behavior

1. Add Vocabulary Boosting block to `Minute/Sources/Views/Settings/ModelsSettingsSection.swift`.
2. Show block only when backend is FluidAudio.
3. Implement fields:
   - Enable toggle
   - Multi-term editor (comma/newline)
   - Strength selector (`Gentle`, `Balanced`, `Aggressive`)
4. Surface inline readiness status when required vocab models are missing.

## 3) Implement per-session override behavior

1. Add compact vocabulary row to `Minute/Sources/Views/Pipeline/Stage/SessionViews.swift`:
   - `Off`, `Default`, `Custom`
2. Add custom-term popover for session-specific terms.
3. Hide/disable vocabulary row for Whisper backend.
4. Show hint text near control: `Use for names, acronyms, product terms.`

## 4) Apply policy rules

1. Normalize terms (trim, remove blanks, dedupe case-insensitive, preserve first-entered casing/order).
2. Resolve effective session mode:
   - `Off` => no boosting
   - `Default` => global settings
   - `Custom` => global + custom terms; empty custom => effective default
3. If required vocab models are missing at session start:
   - Allow session start
   - Disable boosting for that session
   - Show warning/status
4. Persist custom terms only for active session lifetime.

## 5) Tests (TDD)

1. Add/extend `MinuteCore` tests for:
   - normalization behavior
   - mode resolution (`Off/Default/Custom`)
   - empty custom fallback
   - missing-model fallback on session start
2. Add/extend app tests for:
   - backend-aware visibility/gating
   - settings/session control rendering and hint text

## 6) Validation commands

```bash
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test
```

## 7) Manual acceptance checklist

1. FluidAudio selected: global vocabulary controls visible and editable.
2. Whisper selected: vocabulary controls hidden/disabled in settings and session card.
3. Custom mode adds terms on top of global list for that session.
4. Custom mode with no terms behaves as Default.
5. Missing vocab model case allows recording start and shows warning with boosting disabled.

## 8) Execution notes

- 2026-02-18: Upgraded FluidAudio dependency in `MinuteCore/Package.swift` from `0.10.0` to `0.12.1`.
- 2026-02-18: Ran `swift package update FluidAudio` in `MinuteCore/`, producing `MinuteCore/Package.resolved` with FluidAudio `0.12.1`.
- 2026-02-18: Ran `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug -destination 'platform=macOS' test` -> **TEST SUCCEEDED** (Minute app tests passed).
- 2026-02-18: Ran `swift test` in `MinuteCore/` -> **189 tests passed**, including vocabulary policy and output-contract suites.

## 9) Scenario validation results

- Global settings persistence: **PASS** (covered by `ModelsSettingsViewModelVocabularyBoostingTests` and `VocabularyBoostingSettingsStoreTests`).
- Backend-aware gating (FluidAudio vs Whisper): **PASS** (covered by `ModelsSettingsViewModelVocabularyGatingTests`).
- Session override modes and custom additive terms: **PASS** (covered by `SessionVocabularyResolverTests`, `SessionVocabularyEffectiveTermsTests`, `MeetingPipelineViewModelVocabularyOverrideTests`).
- Empty custom fallback to default: **PASS** (covered by `SessionVocabularyResolverTests`, `SessionVocabularyEffectiveTermsTests`).
- Missing vocabulary model fallback warning (session continues without boosting): **PASS** (covered by `MeetingPipelineViewModelVocabularyOverrideTests` and resolver tests).
- Output contract unchanged (exactly three vault files): **PASS** (covered by `OutputContractCoverageTests`).
