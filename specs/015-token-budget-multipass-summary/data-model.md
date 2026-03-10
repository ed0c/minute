# Data Model — Token Budget and Multi-Pass Summarization

## 1. TokenBudgetEstimate

- Purpose: Represents preflight capacity guidance for a summarization run.
- Fields:
  - `run_id` (string): Stable identifier for the summarization run.
  - `model_id` (string): Selected summarization model identifier.
  - `context_window_tokens` (integer): Effective context capacity used for planning.
  - `reserved_output_tokens` (integer): Tokens reserved for generated output.
  - `safety_margin_tokens` (integer): Additional conservative reserve.
  - `prompt_overhead_tokens` (integer): Tokenized static prompt and instruction overhead.
  - `available_input_tokens_per_pass` (integer): Maximum transcript tokens accepted per pass.
  - `estimated_total_input_tokens` (integer): Total transcript token count at preflight.
  - `estimated_pass_count` (integer): Initial estimated number of passes.
  - `created_at` (datetime): Timestamp of estimate generation.
- Validation Rules:
  - `available_input_tokens_per_pass > 0`
  - `estimated_pass_count >= 1`
  - `context_window_tokens > reserved_output_tokens + safety_margin_tokens + prompt_overhead_tokens`

## 2. SummarizationPassPlan

- Purpose: Defines deterministic transcript chunk sequencing for a run.
- Fields:
  - `run_id` (string)
  - `chunks` (array of `TranscriptChunkPlan`)
  - `planned_from_estimate` (`TokenBudgetEstimate` reference)
  - `created_at` (datetime)
- TranscriptChunkPlan Fields:
  - `chunk_id` (string): Deterministic chunk identifier.
  - `pass_index` (integer): 1-based sequence order.
  - `token_start` (integer): Inclusive token offset in full transcript.
  - `token_end` (integer): Exclusive token offset in full transcript.
  - `token_count` (integer)
- Validation Rules:
  - `pass_index` values are contiguous and unique.
  - Chunk token ranges are ordered and non-overlapping.
  - `token_count <= available_input_tokens_per_pass`.

## 3. SummaryStateSnapshot

- Purpose: Last valid structured summary state accepted after a pass.
- Fields:
  - `run_id` (string)
  - `completed_pass_index` (integer)
  - `summary_payload` (object): Structured summary JSON matching extraction schema.
  - `source_chunk_ids` (array of string): Chunks included in this snapshot.
  - `updated_document_at` (datetime): Time summary document was atomically updated.
  - `checksum` (string): Digest of canonical payload for idempotency checks.
- Validation Rules:
  - `summary_payload` must pass schema validation.
  - `source_chunk_ids` must map to planned chunk IDs up to completed pass.
  - `completed_pass_index >= 0` (0 means pre-run empty checkpoint).

## 3a. SummarizationPassDelta

- Purpose: Chunk-local structured output accepted from a single multi-pass summarization call.
- Fields:
  - `title` (string, optional): Better title candidate only when the current chunk materially improves it.
  - `date` (string, optional): Better date candidate only when the current chunk materially improves it.
  - `summary_points` (array of string): Short, atomic net-new facts from the current chunk only.
  - `decisions` (array of string): Net-new decisions from the current chunk only.
  - `action_items` (array of object): Net-new or improved action items from the current chunk.
  - `open_questions` (array of string): Net-new unresolved questions from the current chunk.
  - `key_points` (array of string): Net-new salient bullets from the current chunk.
- Validation Rules:
  - Arrays may be empty when the current chunk adds no material information.
  - Values must not restate unchanged previously accepted content verbatim.
  - Payload must decode without fallback freeform text extraction.

## 3b. DeterministicMergeState

- Purpose: Canonical application-owned accumulation of accepted multi-pass deltas before final rendering into `MeetingExtraction`.
- Fields:
  - `title` (string)
  - `date` (string)
  - `summary_points` (array of string)
  - `decisions` (array of string)
  - `action_items` (array of object)
  - `open_questions` (array of string)
  - `key_points` (array of string)
  - `meeting_type` (string)
- Validation Rules:
  - Merge order is deterministic and stable for the same pass sequence.
  - Duplicate or containment-equivalent items collapse to one canonical item.
  - Richer wording may replace an earlier item only when it adds information without changing meaning.

## 4. PassExecutionRecord

- Purpose: Operational status and outcome for each pass.
- Fields:
  - `run_id` (string)
  - `pass_index` (integer)
  - `chunk_id` (string)
  - `status` (enum): `pending | running | completed | failed | cancelled | skipped`
  - `started_at` (datetime, optional)
  - `finished_at` (datetime, optional)
  - `error_code` (string, optional)
  - `error_message` (string, optional user-safe)
- Validation Rules:
  - `running` must have `started_at`.
  - terminal states (`completed|failed|cancelled|skipped`) must have `finished_at`.
  - One active `running` record max per `run_id`.

## 5. SummarizationRunState

- Purpose: Top-level orchestration state across all passes.
- Fields:
  - `run_id` (string)
  - `meeting_id` (string)
  - `status` (enum): `initialized | planning | running | paused_for_retry | completed | failed | cancelled`
  - `current_pass_index` (integer)
  - `total_pass_count` (integer)
  - `last_valid_snapshot` (`SummaryStateSnapshot` reference)
  - `records` (array of `PassExecutionRecord`)
- Validation Rules:
  - `current_pass_index <= total_pass_count`
  - `completed` requires final snapshot covering all planned chunks.
- `paused_for_retry` requires a non-nil `last_valid_snapshot`.

## 6. SummarizationContextWindowPreference

- Purpose: Stores the user's selected context-window preset and resolves it against local hardware for both preflight and runtime summarization.
- Fields:
  - `preset` (enum): `automatic | low | balanced | high | maximum`
  - `recommended_preset` (enum): Hardware-derived default recommendation for the current Mac.
  - `resolved_context_window_tokens` (integer): Effective requested context window after applying the preset to the hardware profile.
- Validation Rules:
  - `resolved_context_window_tokens > 0`
  - `automatic` must resolve deterministically for a given hardware profile.
  - `resolved_context_window_tokens` must be used consistently by preflight and runtime configuration for the same run.

## Relationships

- `TokenBudgetEstimate 1 -> 1 SummarizationPassPlan`
- `SummarizationPassPlan 1 -> many PassExecutionRecord`
- `SummarizationRunState 1 -> many PassExecutionRecord`
- `SummarizationRunState 1 -> 1 last_valid SummaryStateSnapshot`
- `SummaryStateSnapshot many -> many chunk_id` (through source chunk list)
- `SummaryStateSnapshot 1 -> 1 DeterministicMergeState`
- `DeterministicMergeState 1 -> many SummarizationPassDelta`

## State Transitions

- Run State:
  - `initialized -> planning -> running`
  - `running -> completed`
  - `running -> paused_for_retry` (on pass failure after at least one successful checkpoint)
  - `paused_for_retry -> running` (resume)
  - `running -> failed` (no valid checkpoint available)
  - `running -> cancelled`
- Pass Record State:
  - `pending -> running -> completed`
  - `pending -> running -> failed`
  - `pending -> running -> cancelled`

## Determinism and Recovery Notes

- Chunk IDs must be generated deterministically from transcript token ranges.
- Snapshot writes are atomic and only occur after schema-valid output.
- Retry always starts from `last_valid_snapshot.completed_pass_index + 1`.
- Multi-pass repair may attempt JSON repair, but if the repaired payload still fails schema validation the pass is rejected and the previous snapshot remains authoritative.
