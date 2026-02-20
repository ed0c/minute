# Data Model: Vocabulary Boosting Controls

## Overview

This feature introduces persistent global vocabulary preferences and per-session vocabulary overrides. Effective vocabulary behavior is determined by backend capability, model readiness, global configuration, and session override mode.

## Entities

### 1) GlobalVocabularyConfiguration

Represents reusable vocabulary boosting defaults.

| Field | Type | Required | Rules |
|---|---|---|---|
| `enabled` | Boolean | Yes | Controls whether global boosting is active when session mode is `Default`. |
| `strength` | Enum (`gentle`, `balanced`, `aggressive`) | Yes | UI-facing strength only; no raw numeric weights exposed. |
| `terms` | Array of `VocabularyTermEntry` | Yes | Parsed from comma/newline input; normalized before persistence. |
| `updatedAt` | Timestamp | Yes | Last modification timestamp for deterministic change tracking. |

Validation rules:
- `terms` normalization: trim whitespace, remove blank entries, dedupe case-insensitively.
- Preserve first-entered order and display casing after normalization.

### 2) SessionVocabularyOverride

Represents vocabulary behavior for a single recording session.

| Field | Type | Required | Rules |
|---|---|---|---|
| `sessionID` | String | Yes | Unique recording session identifier. |
| `mode` | Enum (`off`, `default`, `custom`) | Yes | Determines effective vocabulary source. |
| `customTerms` | Array of `VocabularyTermEntry` | Conditional | Used only when `mode = custom`; empty resolves to effective `default`. |
| `createdAt` | Timestamp | Yes | Session override creation timestamp. |
| `expiresAt` | Timestamp | Conditional | Set on session completion/cancellation; override is not reused for new sessions. |

Validation rules:
- `customTerms` uses same normalization pipeline as global terms.
- `mode = custom` with empty `customTerms` must resolve to effective `default`.
- Overrides persist only for the current session lifetime.

### 3) VocabularyReadinessStatus

Represents whether vocabulary boosting prerequisites are available for current backend.

| Field | Type | Required | Rules |
|---|---|---|---|
| `backend` | Enum (`fluidAudio`, `whisper`) | Yes | Active transcription backend. |
| `isSupported` | Boolean | Yes | True only for backend variants that support vocabulary boosting. |
| `state` | Enum (`ready`, `missing_models`) | Yes | Ready means required vocab models are available. |
| `message` | String | Conditional | Human-readable inline status when not ready. |

Validation rules:
- `isSupported = false` implies vocabulary controls hidden/disabled.
- `state = missing_models` must provide non-empty `message`.

### 4) VocabularyTermEntry

Normalized representation of one word or phrase.

| Field | Type | Required | Rules |
|---|---|---|---|
| `displayText` | String | Yes | Preserves first-entered visible casing. |
| `normalizedKey` | String | Yes | Case-folded comparison key used for dedupe. |
| `source` | Enum (`global`, `session_custom`) | Yes | Tracks where the term originated. |

Validation rules:
- `displayText` cannot be empty after trimming.
- `normalizedKey` must be unique within a normalized set.

## Relationships

- `GlobalVocabularyConfiguration` is reused by many sessions.
- `SessionVocabularyOverride` belongs to one active session.
- `VocabularyReadinessStatus` gates whether global/session vocabulary controls are actionable.
- Effective session vocabulary is derived from:
  - `mode = off` -> no vocabulary boosting.
  - `mode = default` -> global terms (if global enabled and readiness ready).
  - `mode = custom` -> global terms + session custom terms (or default if custom list empty).

## State Transitions

### Session vocabulary mode transitions

- `default -> off`: disable boosting for that session.
- `default -> custom`: enable additive session custom behavior.
- `custom -> default`: discard custom effect for current run; keep saved custom terms for session lifetime.
- `custom(empty) -> effective default`: custom mode selected but no terms entered, so effective behavior is default.
- `any -> off` when backend unsupported or user explicitly chooses off.

### Readiness transitions

- `ready -> missing_models`: required vocabulary model files become unavailable.
- `missing_models -> ready`: required models downloaded/validated.
- At session start with `missing_models`: recording continues, vocabulary boosting disabled, warning/status shown.

## Derived View Models (for UI)

- `VocabularyControlAvailability`: visible/hidden + enabled/disabled status per backend.
- `EffectiveSessionVocabularySummary`: `Off` / `Default` / `Custom` label with short hint text.
- `VocabularyWarningBanner`: inline status text and action when prerequisites missing.
