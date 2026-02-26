# Quickstart: Custom Meeting Prompt Authoring

## Goal

Implement custom meeting types and editable built-in prompts so users can author prompt parts in Settings, then ensure classifier + summarization inference consume the same resolved prompt library end to end.

## Prerequisites

- macOS 14+ development environment.
- Existing local model setup for transcription and summarization.
- Working understanding of current prompt flow in:
  - `MinuteCore/Sources/MinuteCore/Summarization/Prompts/PromptFactory.swift`
  - `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`
  - `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`
  - `MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift`

## Recommended Implementation Sequence (TDD-first)

1. Add prompt-library domain models and persistence store in `MinuteCore`.
2. Add migration support for existing stage meeting type preference values.
3. Add resolver that turns selection + runtime language settings into one `ResolvedPromptBundle`.
4. Refactor classifier label-source logic to use built-ins + autodetect-enabled custom profiles.
5. Refactor summarization service to consume resolved prompt bundles instead of hardcoded strategy-only flow.
6. Add settings authoring UI for:
   - custom type create/edit/delete,
   - built-in prompt override edit/restore,
   - prompt component editing and preview,
   - classifier profile editing for custom types.
7. Wire stage meeting type picker to library-backed selection IDs.
8. Validate end-to-end flows and regression-check output contract.

## Prompt Composition Flow (Target)

1. User selects manual type or autodetect in stage UI.
2. On processing start, pipeline resolves meeting type:
   - manual: selected type ID,
   - autodetect: classifier resolves to eligible type ID or falls back to `general`.
3. Prompt resolver composes final system/user prompt content in deterministic order:
   - type prompt components,
   - schema guardrails,
   - language-processing instruction,
   - output-language instruction,
   - meeting date + timeline payload.
4. Summarization inference runs with resolved prompt bundle.
5. Extraction is validated and rendered through existing deterministic output pipeline.

## Settings UX Flow (Target)

1. Open **Settings → Meeting Types**.
2. Select a built-in type and edit prompt parts, then save.
3. Restore built-in defaults when needed.
4. Create a custom type with name + prompt parts.
5. Optionally enable classifier participation and provide classifier cues.
6. Verify type appears in stage picker and is usable for processing.

## Validation Scenarios

1. **Custom Manual Selection**
   - Create a custom type, select it manually, process meeting, verify resolved type and prompt source are custom.
2. **Built-In Override**
   - Edit a built-in prompt, process meeting, verify override is used; then restore default and verify reversion.
3. **Autodetect With Custom Type**
   - Enable classifier profile for a custom type, process with autodetect, verify classifier can resolve to custom type when cues are strong.
4. **Fallback Behavior**
   - Use ambiguous transcript with autodetect; verify fallback resolves to `general`.
5. **Deleted Selection Guardrail**
   - Delete a previously selected custom type and attempt processing; verify user must select a valid replacement.
6. **Output Contract Regression**
   - Verify processed meeting still writes exactly three files (note/audio/transcript) when save options are enabled.

## Suggested Commands

```bash
cd /Users/roblibob/Projects/FLX/Minute/Minute
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test
xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'
```

## Completion Criteria

- Users can create, edit, rename, and delete custom meeting types.
- Users can edit and restore built-in prompt defaults.
- Autodetect can resolve to eligible custom types and still conservatively fall back to `general`.
- Manual and autodetect paths share one prompt resolution flow before inference.
- Existing output contract and local-only constraints are preserved.

## Validation Evidence

Validation run date: `2026-02-23 16:55:02 CET`

1. `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build CODE_SIGNING_ALLOWED=NO`
   - Result: `BUILD SUCCEEDED`
2. `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test CODE_SIGNING_ALLOWED=NO`
   - Result: `TEST SUCCEEDED`
   - Suite summary: `55 tests in 22 suites passed`
3. `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'`
   - Result: `TEST SUCCEEDED`
   - Suite summary: `236 tests in 82 suites passed`
