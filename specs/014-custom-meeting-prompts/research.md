# Phase 0 Research: Custom Meeting Prompt Authoring

## Research Task 1: Define Full Prompt Components That Reach Inference

**Decision**: Compose inference prompts from a deterministic `PromptDefinition` model with two layers:
- **Authorable components**: meeting objective, summary focus, decisions rule, action-item rule, open-questions rule, key-points rule, and extra guidance.
- **Runtime components**: language-processing instruction, output-language instruction, meeting date header, and timeline payload.

**Rationale**: Current hardcoded strategies already separate system and user prompts; converting to structured components keeps that shape while making prompt authoring possible without free-form string concatenation drift.

**Alternatives considered**:
- Keep one large free-text prompt blob per type: rejected because partial editing and validation become brittle.
- Expose only final generated prompt text: rejected because users cannot safely edit intent-specific sections.

## Research Task 2: Built-In Prompt Editing Strategy

**Decision**: Keep built-in meeting types as immutable identities and allow editable prompt overrides on top of shipped defaults, with one-click restore per built-in type.

**Rationale**: This preserves backward compatibility (existing meeting type names/IDs) and matches the user request to edit defaults without duplicating baseline meeting types.

**Alternatives considered**:
- Convert built-ins into editable custom copies only: rejected because it breaks consistency and creates duplicate type management.
- Allow renaming/deleting built-ins: rejected because pipeline defaults and historical compatibility depend on stable built-in identities.

## Research Task 3: Custom Meeting Type Data and Validation

**Decision**: Custom meeting types require:
- unique display name,
- prompt component set,
- stable internal identifier,
- optional classifier profile (autodetect participation toggle + cues/examples).

Validation defaults:
- case-insensitive unique names,
- required non-empty objective/focus content,
- whitespace-trimmed content,
- safe limits for text length and classifier cue counts.

**Rationale**: A stable identifier is needed for persistence and pipeline selection; optional classifier profile avoids forcing classifier complexity on every custom type.

**Alternatives considered**:
- Name-as-identifier: rejected because rename operations would break stored selections.
- Always include all custom types in autodetect: rejected because large candidate lists degrade classifier quality.

## Research Task 4: Settings UI for Prompt-Part Authoring

**Decision**: Add a dedicated **Meeting Types** section in Settings for prompt-library authoring, with:
- a type list (built-in + custom) and status badges,
- detail editor with sectioned prompt components,
- classifier profile controls for custom types,
- generated prompt preview (system + user prompt preview),
- actions: create, duplicate, save, restore built-in default, delete custom.

**Rationale**: Users need to create prompt parts, not just single text blocks. A sectioned editor maps directly to the structured component model and reduces malformed prompt risk.

**Alternatives considered**:
- Add prompt editing inline in stage card: rejected because creation/management is multi-step and does not fit session-stage density.
- Hide prompt parts behind a single advanced textarea: rejected because it is harder to validate and less approachable.

## Research Task 5: End-to-End Classifier Flow with Custom Meetings

**Decision**: Keep two-pass flow but route through a prompt-library resolver:
1. If selection is manual (built-in/custom), skip classification and use selected type directly.
2. If selection is autodetect, classify against built-ins plus only custom types marked autodetect-enabled.
3. Parse classifier output to a stable type ID; fallback to built-in `general` if unmatched/uncertain.

Classifier prompt composition will include custom label names and their cue summaries when enabled.

**Rationale**: This gives custom types classifier participation without sacrificing conservative fallback behavior established in existing autodetect behavior.

**Alternatives considered**:
- Keep autodetect limited to built-ins forever: rejected because it does not satisfy end-to-end custom meeting support.
- Add a separate classifier pass for custom-only after built-ins: rejected because it increases latency/complexity and can create conflicting classifications.

## Research Task 6: End-to-End Inference Flow for Custom Meetings

**Decision**: Introduce a `ResolvedPromptBundle` created immediately before summarization containing:
- resolved meeting type ID and display label,
- final system prompt,
- final user prompt preamble,
- metadata about source (built-in default, built-in override, custom).

Summarization service consumes this bundle so inference path is unified for built-in and custom types.

**Rationale**: A single resolution point prevents drift between manual selection and autodetect paths and ensures the exact prompt reaching inference is inspectable/testable.

**Alternatives considered**:
- Keep strategy factory for built-ins and add side path for custom prompts: rejected because dual paths increase regression risk.
- Resolve prompt too early at UI time: rejected because runtime language/output settings and timeline data are finalized at processing.

## Research Task 7: Persistence and Migration from Enum-Based Meeting Type

**Decision**: Migrate stage selection persistence from raw enum values to stable meeting-type selection IDs while preserving legacy values via migration mapping:
- `autodetect`, `general`, `standup`, `design_review`, `one_on_one`, `presentation`, `planning` map to built-in IDs.
- unknown/removed custom IDs fall back to `autodetect` for stage defaults and block processing only when a stale deleted custom type is explicitly selected in a pending meeting.

**Rationale**: Custom types cannot be represented by the current fixed enum alone. Stable IDs preserve renamed custom types and future extensibility.

**Alternatives considered**:
- Extend enum with dynamic associated payload persisted ad hoc: rejected because existing stores/tests depend on simple Codable/CaseIterable behavior.
- Store only display names: rejected because name collisions/renames break references.

## Research Task 8: Testing and Quality Gates for Prompt Library

**Decision**: Add test-first coverage for:
- prompt component validation and deterministic composition order,
- built-in override restore behavior,
- custom type create/rename/delete rules,
- classifier label-set construction and fallback parsing,
- pipeline resolution behavior (manual vs autodetect with custom-enabled types),
- legacy preference migration.

**Rationale**: The feature modifies prompt and type-resolution logic that directly affects summarization behavior; deterministic tests are required to protect output reliability.

**Alternatives considered**:
- Rely on manual QA only: rejected due to high regression risk in classifier/inference pathways.
- Snapshot only final prompt strings without component tests: rejected because validation bugs can be hidden until runtime.
