# Phase 0 Research — Token Budget and Multi-Pass Summarization

## Decision 1: Use conservative preflight budget with fixed reserve

- Decision: Compute a pass token budget from model context limits using a fixed reserve for output and safety margin; do not consume full theoretical context in a single pass.
- Rationale: This lowers risk of runtime aborts when actual backend capacity is lower than nominal context capacity and keeps behavior predictable across machines.
- Alternatives considered:
  - Use full context every pass: rejected due to higher crash risk and lower predictability.
  - Static hard-coded budget only: rejected because it ignores model-specific context differences.

## Decision 2: Use deterministic chunk ordering with overlap guards

- Decision: Build an ordered pass plan from tokenized transcript slices and enforce non-overlapping chunk identity plus merge deduplication guards.
- Rationale: Deterministic chunk ordering and stable dedupe behavior reduce repeated facts and make reruns reproducible.
- Alternatives considered:
  - Semantic chunking only: rejected because it can be less deterministic and harder to verify.
  - No overlap/deduplication handling: rejected due to repeated summary content risk.

## Decision 3: Persist last valid summary checkpoint after each successful pass

- Decision: After each pass produces valid structured output, treat it as the new canonical checkpoint and atomically update the summary document.
- Rationale: Preserves user-visible progress and guarantees rollback target on later failure.
- Alternatives considered:
  - Update only at final pass: rejected because failures lose all intermediate progress.
  - Keep checkpoints in memory only: rejected because crashes/restarts lose recoverable state.

## Decision 4: Resume from checkpoint with remaining chunk set

- Decision: Retry resumes from the last successful pass checkpoint and processes only uncompleted transcript chunks.
- Rationale: Reduces wasted computation and aligns with user expectation that prior successful work is kept.
- Alternatives considered:
  - Full restart for every retry: rejected as inefficient for long meetings.
  - Resume from nearest heuristic chunk: rejected because it may skip or duplicate coverage.

## Decision 5: Allow estimate drift but keep stable progress semantics

- Decision: Preflight exposes an estimated pass count; runtime may adjust remaining pass count if tokenization/runtime constraints differ, while preserving monotonic pass completion status.
- Rationale: Capacity can vary at execution time; stable user progress semantics are more important than rigid initial estimates.
- Alternatives considered:
  - Lock fixed pass count regardless of runtime drift: rejected because it can force failures or invalid chunk sizes.
  - Hide estimates entirely: rejected because users asked for up-front predictability.

## Decision 6: Keep contracts local and technology-agnostic at boundary

- Decision: Define formal contracts for preflight, pass execution, status, and resume as internal service contracts (documented via OpenAPI for clarity), without introducing network behavior.
- Rationale: Clear behavioral contracts improve implementation consistency and testability while preserving local-only constraints.
- Alternatives considered:
  - No explicit contracts: rejected because multi-step orchestration becomes ambiguous.
  - Introduce external API runtime: rejected due to product constraints and unnecessary complexity.

## Clarification Resolution Summary

All technical unknowns from planning were resolved during research. No unresolved `NEEDS CLARIFICATION` items remain.
