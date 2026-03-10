# Quickstart — Token Budget and Multi-Pass Summarization

## Goal

Validate token-budget preflight, hardware-aware context selection, multi-pass execution, deterministic delta merging, and resume-from-checkpoint behavior.

## Prerequisites

- macOS 14+ Apple Silicon machine.
- Minute project checked out on branch `015-token-budget-multipass-summary`.
- Local summarization model downloaded and selected.
- A long transcript fixture that exceeds single-pass capacity.

## 1. Build and test baseline

```bash
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build
xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'
```

Expected:
- Build succeeds.
- Existing tests pass before feature-specific tests are added.

## 2. Validate preflight budget and pass estimate

1. In onboarding or AI settings, verify the stepped context-window slider is visible next to summarization model selection.
2. Confirm the initially selected slider value matches the expected default for the current Mac class.
3. Start a processing run with a long transcript.
4. Confirm the app shows token budget and estimated pass count before execution starts.
5. Confirm estimate values change when the selected slider step changes and pass count is at least 2 for oversized transcript input.
6. If the selected summarizer supports runtime refinement, confirm the final pass count may adjust once the summarization model finishes loading without ignoring the selected context setting.

Expected:
- Preflight appears before summarization begins.
- The selected context slider is available in onboarding and AI settings and defaults appropriately for the current hardware.
- Reported values match transcript size changes.
- Reported values also match context-setting changes.
- Any runtime refinement reuses the already loaded model rather than causing a second visible model startup pause.

## 3. Validate progressive multi-pass updates

1. Run summarization for the long transcript.
2. Observe pass progress increments from pass 1 to final pass.
3. After each pass, verify the summary document is updated and remains valid.
4. Confirm later passes update existing sections with net-new information instead of duplicating earlier summary paragraphs.

Expected:
- Same summary document path is updated after each successful pass.
- No invalid/partial JSON checkpoint is persisted.
- Repeated facts from later chunks do not double the rendered summary length.

## 4. Validate failure containment and restart-safe resume

1. Inject or simulate failure on a middle pass.
2. Confirm the run pauses/fails without deleting last valid summary checkpoint.
3. Quit and relaunch the app or recreate the processing context for the same meeting.
4. Retry/resume the run.
5. Confirm malformed pass output does not replace the last valid note with fallback freeform text such as `Failed to structure output`.

Expected:
- Retry resumes from next uncompleted pass.
- Previously completed pass progress is preserved.
- The same summary note path is reused; no duplicate ` (2)` note is created.
- Invalid pass JSON is either repaired into schema-valid delta output or rejected without poisoning the accepted note.

## 5. Validate cancellation behavior

1. Start a multi-pass run.
2. Cancel during an active pass.
3. Retry the same meeting run.

Expected:
- Run transitions to cancelled state.
- Last valid summary checkpoint remains intact.
- UI remains responsive.
- Retry continues from the last completed pass when a checkpoint exists.

## 6. Validate output contract invariants

1. Complete a run and inspect vault outputs.
2. Verify exactly three files are written per meeting.
3. Verify note/transcript/audio paths remain unchanged by this feature.

Expected:
- Existing file contract is preserved.
- Markdown rendering remains deterministic.

## Suggested Feature Test Additions

- Unit tests for:
  - Budget calculation and safety reserve handling.
  - Pass planning/chunk boundaries and deterministic ordering.
  - Delta-schema decoding, deterministic merge deduplication, and checkpoint update rules.
  - Resume state selection from last valid checkpoint.
- Integration tests for:
  - Mid-pass failure and resume behavior.
  - Progress status transitions across full run lifecycle.
