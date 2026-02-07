# Copilot Review Agent Instructions — Minute

## Review Focus

When reviewing pull requests in this repository, optimize for **contract safety, local-only privacy, determinism, and test-gated core logic**, per:

- `AGENTS.md`
- `.specify/memory/constitution.md`
- Source-of-truth product constraints: `docs/overview.md` (and `docs/tasks/` plans)

## Specs (`specs/` directory)

- **DO NOT** review, nitpick, or suggest edits to files in `specs/` (planning docs).
- **DO** read relevant specs to understand intent and verify the implementation matches the planned behavior.
- If code deviates from a spec, **flag the deviation in the implementation review** and ask whether it’s intentional.

## Code Review Priorities (in order)

### 1) Output Contract & Determinism (NON-NEGOTIABLE)

Verify the app still writes **exactly three files per processed meeting** with the exact paths:

- `Meetings/YYYY/MM/YYYY-MM-DD HH.MM - <Title>.md`
- `Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav`
- `Meetings/_transcripts/YYYY-MM-DD HH.MM - <Title>.md`

Requirements:

- Markdown is rendered **deterministically** from **JSON-only** model output.
- **Atomic file writes** for all vault output.
- Any change that affects paths or rendering rules **must update docs and tests in the same PR**.

### 2) Local-Only Processing & Privacy

- No outbound network calls **except model downloads**.
- Avoid logging raw transcripts by default (use `OSLog`; keep user-facing errors concise).
- Ensure transcript content is stored in its dedicated transcript file (not embedded by accident).

### 3) Audio Contract

- WAV output **must be mono, 16 kHz, 16-bit PCM**, and format must be **verified** after conversion.
- Prefer an `ffmpeg` conversion step to guarantee format (per repo policy).

### 4) Architecture Boundaries (MinuteCore-first)

- UI stays thin (SwiftUI views should not contain business logic).
- Business logic belongs in **MinuteCore**, behind clear interfaces.
- Pipeline behavior should align with the **single source-of-truth state machine** approach described in `docs/tasks/`.

### 5) Concurrency & Cancellation

- Prefer `async`/`await`.
- Long-running operations **must support cancellation**.
- Use `@MainActor` only for UI state updates; prefer `actor`/immutable structs for shared state.

### 6) Error Handling

- Use a small set of domain errors (`MinuteError`), mapping OS/framework errors at boundaries.
- User-visible messages: short and actionable; debug details only in logs/debug UI.

### 7) Tests (TDD + Contract Safety)

Per constitution: **TDD is non-negotiable**.

- New features / contract-affecting changes **must include Swift Testing tests** (MinuteCore).
- Prioritize:
  - Markdown renderer **golden tests**
  - Filename sanitization tests
  - File contract path generation tests
  - JSON decoding + validation tests
- Tests must be deterministic and order-independent.

## Process Checklist for Each PR

1. Identify which implementation areas changed (`Minute/` vs `MinuteCore/`).
2. Read any relevant `specs/` to understand intent (do not review the spec text).
3. Validate contract invariants (3-file output, paths, determinism, atomic writes).
4. Validate local-only + privacy constraints (networking, logging).
5. Validate concurrency/cancellation and architecture boundaries.
6. Confirm tests exist and meaningfully cover the change (especially in MinuteCore).

## Example Review Comments (Minute-specific)

✅ **Good — Output Contract**:

> “The PR changes the meeting note path format. Per constitution, path changes require updating docs and adding/adjusting contract tests (path generation + golden render).”

✅ **Good — Deterministic Rendering**:

> “This summarization output is parsed from free-form text. The contract requires JSON-only model output to keep rendering deterministic—can this be switched to strict JSON decoding + validation?”

✅ **Good — Local-only/Privacy**:

> “This log statement includes full transcript text. Per privacy constraints, avoid logging raw transcripts by default; consider logging only counts/IDs and keep content out of OSLog.”

✅ **Good — Audio Contract**:

> “The WAV export doesn’t verify mono/16k/16-bit PCM after conversion. The audio contract requires verification—please add a format check and a unit test around the validator.”

✅ **Good — Concurrency/Cancellation**:

> “Transcription runs in a Task but doesn’t check cancellation. Long-running operations must support cancellation; please propagate `Task.checkCancellation()` and handle cancellation cleanly.”

❌ **Avoid — Reviewing Specs**:

> “The spec in `specs/.../spec.md` has wording issues.”

❌ **Avoid — Suggesting Spec Changes**:

> “Update the spec to match the implementation.” (Instead: flag the deviation and ask if it should be aligned.)
