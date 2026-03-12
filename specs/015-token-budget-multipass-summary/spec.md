# Feature Specification: Token Budget and Multi-Pass Summarization

**Feature Branch**: `015-token-budget-multipass-summary`  
**Created**: 2026-03-06  
**Status**: Draft  
**Input**: User description: "specify token budget and multi-pass summarization"

## Clarifications

### Session 2026-03-06

- Q: Should retry resume from checkpoint only in-session or also after app restart? → A: Resume from last valid checkpoint even after app restart for the same meeting run.
- Q: What should happen when a transcript would require an unusually high number of passes? → A: No hard pass limit; process until transcript is fully consumed.
- Q: Where should resume/checkpoint state be persisted for cross-restart recovery? → A: Use the existing app-owned recovery path.
- Q: How should concurrent multi-pass runs for the same meeting session be handled? → A: Disallow concurrent runs for the same meeting and reject secondary starts clearly.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reliable Long Meeting Processing (Priority: P1)

As a Minute user processing long meetings, I want summarization to continue safely across multiple passes so that long transcripts do not crash processing and still produce a complete structured summary.

**Why this priority**: Preventing summarization failures is required to deliver core product value for long recordings.

**Independent Test**: Can be fully tested by processing a transcript intentionally larger than the per-pass budget and verifying completion with a valid final summary document.

**Acceptance Scenarios**:

1. **Given** a transcript larger than the available single-pass token budget, **When** summarization starts, **Then** the system processes the transcript in multiple passes and completes successfully.
2. **Given** multi-pass processing is in progress, **When** each pass finishes, **Then** the same meeting summary document is updated with the latest valid merged summary.
3. **Given** multi-pass processing completes, **When** the final pass ends, **Then** the final summary document remains valid and includes content from the full transcript scope.
4. **Given** pass N+1 covers transcript content already represented in the accepted summary, **When** the pass completes, **Then** the final summary keeps a single canonical section entry rather than appending a duplicated restatement.

---

### User Story 2 - Predictable Capacity Before Run (Priority: P2)

As a Minute user, I want to see the estimated token budget and pass count before processing so that I understand how the app will handle my meeting length.

**Why this priority**: Early visibility improves trust and reduces confusion about long-running processing behavior.

**Independent Test**: Can be tested by providing transcripts of different sizes and verifying that the app reports a per-pass token budget and estimated number of passes before execution.

**Acceptance Scenarios**:

1. **Given** a selected summarization model and transcript, **When** preflight runs, **Then** the app reports an estimated per-pass token budget and expected pass count.
2. **Given** transcript size changes, **When** preflight recalculates, **Then** budget usage and pass estimates update accordingly.
3. **Given** the user changes the summarization context setting in onboarding or AI settings, **When** preflight runs, **Then** the estimate reflects the same effective context window that runtime summarization will use on that Mac.

---

### User Story 3 - Resilient Recovery During Multi-Pass Runs (Priority: P3)

As a Minute user, I want partial progress to be preserved if a pass fails so that I can retry without losing the last valid summary state.

**Why this priority**: Recovery reduces wasted time and keeps failures from forcing full restarts.

**Independent Test**: Can be tested by injecting a failure on a middle pass and verifying that the most recent valid summary remains available and can be resumed.

**Acceptance Scenarios**:

1. **Given** pass N has completed and pass N+1 fails, **When** processing stops, **Then** the document remains at the last valid completed pass output.
2. **Given** a previous run stopped after partial completion, **When** the user retries, **Then** processing resumes from the last valid summary state and remaining transcript scope.

---

### Edge Cases

- Transcript content exceeds the model's practical capacity by a large margin, requiring many passes.
- A single transcript segment is larger than the remaining pass budget and must be split safely.
- A pass output is invalid or incomplete and cannot be merged directly.
- User cancels during mid-run after some passes have already updated the summary document.
- Available runtime capacity changes between preflight and execution, causing pass estimates to drift.
- Duplicate or overlapping transcript slices could introduce repeated summary facts during merge.
- App is restarted after a pass failure and resume must continue from the last valid checkpoint.
- A second run is requested while another run for the same meeting is already active.
- Later passes restate earlier summary sections with minor wording changes.
- A middle pass returns malformed JSON after repair and must not poison the accepted note.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST perform a summarization preflight that computes an estimated per-pass token budget before summarization starts.
- **FR-002**: System MUST compute and expose an estimated number of passes required for the current transcript and selected summarization model.
- **FR-003**: System MUST split transcript input into ordered pass-sized chunks that do not exceed the computed per-pass budget.
- **FR-004**: System MUST generate a valid structured summary after each pass using both prior accepted summary state and the current transcript chunk.
- **FR-004a**: System MUST require multi-pass runtime outputs to be chunk-local structured deltas that contain only net-new or higher-fidelity information from the current transcript chunk.
- **FR-005**: System MUST update the same meeting summary document after each successful pass so users can observe progressive completion.
- **FR-006**: System MUST preserve the last valid summary state if any later pass fails.
- **FR-007**: System MUST allow retry from the last valid summary state rather than requiring a full restart.
- **FR-012**: System MUST persist resume state for a meeting run so retry can continue from the last valid checkpoint after app restart.
- **FR-014**: System MUST store resume/checkpoint state in existing app-owned local recovery storage (outside the Obsidian vault).
- **FR-008**: System MUST prevent duplicate final content caused by overlapping chunk boundaries.
- **FR-009**: System MUST surface clear run status showing current pass number and total estimated passes.
- **FR-010**: System MUST mark completion only after all transcript chunks are processed and merged into a valid final summary.
- **FR-011**: System MUST handle both generic and custom meeting types when processing multiple passes.
- **FR-013**: System MUST continue pass execution without a fixed maximum pass cap, until the full transcript chunk set is processed or the run is cancelled/failed.
- **FR-015**: System MUST allow at most one active multi-pass summarization run per meeting session and reject additional start attempts with a clear user-facing message.
- **FR-016**: System MUST refine pass planning with the runtime tokenizer after the summarization model is loaded when the selected runtime supports that capability.
- **FR-017**: System MUST reuse the loaded summarization runtime across refined pass planning and pass execution so accurate chunking does not require an extra model startup.
- **FR-018**: System MUST expose a user-selectable summarization context window setting in AI settings and onboarding alongside summarization model selection.
- **FR-019**: System MUST default the summarization context window setting based on the local hardware profile, using lower defaults on constrained Macs and higher defaults on larger-memory Macs.
- **FR-020**: System MUST apply the same effective context window selection to both preflight estimates and runtime summarization configuration for a given run.
- **FR-021**: System MUST not expose a 4K summarization context option in release builds; a 4K option MAY remain available only in debug builds for constrained-memory testing.
- **FR-022**: System MUST merge successful pass deltas deterministically in application code rather than relying on the model to rewrite the full accumulated summary each pass.
- **FR-023**: System MUST reject malformed multi-pass outputs that remain invalid after repair and keep the last valid checkpoint unchanged instead of merging fallback freeform text into the summary state.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output formatting for intermediate and final summary document updates.
- **NFR-003**: Long-running multi-pass summarization MUST support cancellation without corrupting the current summary document.
- **NFR-004**: User-visible status and errors MUST be concise and actionable, without exposing internal diagnostic details by default.
- **NFR-005**: Preflight budgeting and pass planning MUST complete quickly enough to present feedback before summarization starts.
- **NFR-006**: Runtime tokenizer refinement MUST add only minimal overhead relative to summarization itself by avoiding redundant model loads.

### Key Entities *(include if feature involves data)*

- **Token Budget Estimate**: Preflight result describing available tokens per pass, reserved tokens, and estimated pass count for the current run.
- **Summarization Pass Plan**: Ordered set of transcript chunks and pass sequencing metadata used to process a meeting incrementally.
- **Summary State Snapshot**: Last valid structured summary content accepted after a pass, used for progress display and recovery.
- **Pass Delta**: Chunk-local structured output containing only net-new or improved facts extracted from a single pass.
- **Deterministic Merge State**: Canonical in-app accumulation of unique summary points, decisions, actions, questions, and key points derived from accepted pass deltas.
- **Pass Execution Record**: Per-pass status data including pass index, outcome, and timestamps for user-visible progress and troubleshooting.
- **Recovery Checkpoint Store**: Existing app-owned local storage for resumable run state and last valid checkpoint snapshots.

## Assumptions

- The selected summarization model and transcript are available locally before preflight begins.
- A conservative safety margin is applied to each pass budget to reduce runtime failures from capacity variability.
- Heuristic preflight remains cheap and user-visible, but runtime-supported summarizers may replace it with a more accurate tokenizer-based plan once the model is already loaded.
- The default context-window selection is derived from the current Mac's hardware profile and may still be capped by the selected model's actual supported context window at runtime.
- If pass estimation differs from actual runtime behavior, the system may adjust pass count during execution while preserving completed progress.
- Progressive document updates are user-visible artifacts and should always represent the latest valid state, not partial invalid output.
- Resume/checkpoint persistence reuses existing app-owned recovery storage mechanisms.
- Multi-pass prompts may receive prior accepted state for context, but accepted runtime output is constrained to a chunk-local delta schema and is not treated as authoritative for whole-document rewrites.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At least 95% of transcripts that exceed single-pass capacity complete successfully through multi-pass summarization without user restarts.
- **SC-002**: 100% of successful multi-pass runs produce a valid structured summary document at every completed pass checkpoint and at final completion.
- **SC-003**: For transcripts requiring multiple passes, users can see preflight budget and estimated pass count before processing begins in under 2 seconds for typical meeting sizes.
- **SC-004**: In forced mid-run failure tests, 100% of runs retain the latest valid summary state and allow retry without losing completed pass progress.
- **SC-005**: User-reported confusion about long-summary progress decreases by at least 50% after release, measured via support tickets tagged to summarization progress visibility.
- **SC-006**: In regression tests with overlapping or repeated chunk content, 100% of accepted multi-pass runs avoid duplicating previously accepted summary sections in the final rendered note.
