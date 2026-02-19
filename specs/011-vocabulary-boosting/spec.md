# Feature Specification: Vocabulary Boosting Controls

**Feature Branch**: `011-vocabulary-boosting`  
**Created**: 2026-02-18  
**Status**: Draft  
**Input**: User description: "Specify new feature for word boosting. This specification prefix is 011. Step 0: Upgrade fluidaudio package to latest version. 1. Global setup (Settings -> AI, in Minute/Sources/Views/Settings/ ModelsSettingsSection.swift) - Add a Vocabulary Boosting block shown only when backend is FluidAudio. - Controls: - Toggle: Enable vocabulary boosting - Multi-term editor (comma/newline separated words and phrases) - Optional Strength segmented control: Gentle / Balanced / Aggressive (no raw numeric weights in UI) - If required CTC vocab models are missing, show an inline status row like existing model download UI. 2. Per-session override (RecordingSessionCardView in Minute/Sources/Views/Pipeline/Stage/ SessionViews.swift) - Add a compact row: Vocabulary: Off / Default / Custom. - Custom opens a small popover to add meeting-specific terms (project names, people, - Hide/disable this UI when backend is Whisper. - Keep advanced internals out of UI; expose simple terms + strength only. - Show a short hint near the control: Use for names, acronyms, product terms. If you want, I can implement this exact UX as an MVP with: 1. global term list + enable toggle 2. per-session quick override 3. backend-aware gating and labels"

## Clarifications

### Session 2026-02-18

- Q: What happens if required vocabulary models are missing when a recording session starts? → A: Allow session start, run without vocabulary boosting, and show a clear warning/status.
- Q: What happens when a session is set to Custom but no custom terms are provided? → A: Treat empty Custom terms as Default and apply global vocabulary settings.
- Q: How should duplicate and case-variant vocabulary entries be handled? → A: Trim whitespace, remove blank entries, and deduplicate case-insensitively while preserving first-entered order/casing.
- Q: In Custom mode, do session terms replace or add to global terms? → A: Session custom terms are additive and combine with global terms for that session.
- Q: How long should Custom session terms persist? → A: Persist for that session until completed/cancelled, and do not copy to new sessions.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure global vocabulary boosting (Priority: P1)

As a user who relies on local transcription, I want to define a reusable vocabulary list and boosting strength in Settings so recurring names, acronyms, and product terms are transcribed more accurately.

**Why this priority**: Global setup is the base workflow and enables the feature's core value without requiring per-session changes.

**Independent Test**: Select the FluidAudio backend, open AI settings, enable vocabulary boosting, add multiple terms and phrases separated by commas/new lines, choose a strength, save, and confirm the configuration persists and is reused in subsequent sessions.

**Acceptance Scenarios**:

1. **Given** FluidAudio is selected, **When** the user opens AI settings, **Then** a Vocabulary Boosting section is visible with an enable toggle, term editor, and strength control.
2. **Given** vocabulary boosting is enabled, **When** the user enters terms separated by commas and line breaks, **Then** the system stores each term/phrase as a separate vocabulary entry.
3. **Given** the user selects Gentle, Balanced, or Aggressive strength, **When** the selection is saved, **Then** that level is retained and shown on return to settings.

---

### User Story 2 - Override vocabulary per recording session (Priority: P2)

As a user preparing a specific meeting, I want quick per-session vocabulary controls so I can disable boosting or add meeting-specific terms without changing my global defaults.

**Why this priority**: Session-level overrides prevent global setting churn and support meeting-specific context.

**Independent Test**: Start a recording session, set Vocabulary to Off, Default, and Custom in separate runs, enter custom terms in the popover for Custom, and verify each mode applies only to that session.

**Acceptance Scenarios**:

1. **Given** a session card with FluidAudio backend, **When** the user views controls, **Then** a compact Vocabulary row is shown with Off, Default, and Custom options.
2. **Given** the user chooses Custom, **When** they add meeting-specific terms and confirm, **Then** those terms are combined with global terms and applied only to that session.
3. **Given** the user chooses Custom with no custom terms, **When** the session runs, **Then** the system applies Default behavior using global vocabulary settings.
4. **Given** the user chooses Off, **When** the session runs, **Then** vocabulary boosting is not applied for that session even if global boosting is enabled.
5. **Given** the user chooses Default, **When** the session runs, **Then** global vocabulary boosting behavior is applied unchanged.

---

### User Story 3 - Understand availability and readiness (Priority: P3)

As a user, I want vocabulary controls to appear only when supported and clearly indicate missing prerequisites so I know when the feature can be used.

**Why this priority**: Backend-aware gating and readiness messaging reduce confusion and setup failures.

**Independent Test**: Switch between Whisper and FluidAudio backends, verify vocabulary controls hide/disable for Whisper, and simulate missing required vocabulary models to confirm inline readiness status appears.

**Acceptance Scenarios**:

1. **Given** Whisper is selected, **When** the user opens Settings or the session card, **Then** vocabulary boosting controls are hidden or disabled and cannot be edited.
2. **Given** FluidAudio is selected and required vocabulary models are unavailable, **When** the user views global vocabulary settings, **Then** an inline status row communicates missing models and available action.
3. **Given** FluidAudio is selected, **When** the user views vocabulary controls, **Then** a hint is shown: "Use for names, acronyms, product terms."
4. **Given** required vocabulary models are missing at session start, **When** the user starts recording, **Then** recording proceeds with vocabulary boosting disabled and a clear warning/status is shown.

### Edge Cases

- The user enables vocabulary boosting but leaves the term list empty.
- The term list includes duplicates, mixed separators, blank lines, or extra whitespace.
- The user switches backend from FluidAudio to Whisper after configuring global or per-session vocabulary settings.
- Custom terms persist while a session remains active, but are not copied to newly created sessions.
- A session is set to Custom with no custom terms; the system should fall back to Default behavior.
- Required vocabulary models become unavailable after previously being ready.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST support vocabulary boosting capabilities using the latest supported FluidAudio package version before this feature is considered release-ready.
- **FR-002**: The system MUST show a global Vocabulary Boosting section in AI settings only when the active transcription backend supports vocabulary boosting.
- **FR-003**: The global section MUST provide an enable/disable toggle for vocabulary boosting.
- **FR-004**: The global section MUST provide a multi-term editor that accepts words and phrases separated by commas and/or new lines.
- **FR-005**: The system MUST store and reuse the parsed global vocabulary terms for future recording sessions when global boosting is enabled.
- **FR-006**: The global section MUST provide strength choices labeled Gentle, Balanced, and Aggressive.
- **FR-007**: The UI MUST not expose raw numeric boosting weights to users.
- **FR-008**: When required vocabulary models are missing for the active backend, the global section MUST display an inline status row that indicates missing prerequisites and available remediation action.
- **FR-009**: Each recording session card MUST provide a Vocabulary selector with Off, Default, and Custom options when the active backend supports vocabulary boosting.
- **FR-010**: Selecting Custom MUST allow entry of meeting-specific vocabulary terms in a compact popover.
- **FR-011**: Per-session Custom terms MUST apply only to the current session and MUST not overwrite global terms.
- **FR-011A**: In Custom mode, the session vocabulary set MUST be constructed as global terms plus session-specific custom terms for that session.
- **FR-011B**: Session-specific Custom terms MUST persist for the lifetime of that session (until completion or cancellation) and MUST NOT be carried into newly created sessions.
- **FR-012**: Selecting Off for a session MUST disable vocabulary boosting for that session regardless of global settings.
- **FR-013**: Selecting Default for a session MUST apply global vocabulary settings without modification.
- **FR-014**: When the active backend does not support vocabulary boosting, global and per-session vocabulary controls MUST be hidden or disabled.
- **FR-015**: The per-session vocabulary control area MUST include a short usage hint for names, acronyms, and product terms.
- **FR-016**: If required vocabulary models are missing when a session starts, the system MUST allow recording to start, disable vocabulary boosting for that session, and surface a clear warning/status.
- **FR-017**: If a session is set to Custom and no custom terms are provided, the system MUST treat the session as Default and apply global vocabulary settings.
- **FR-018**: The system MUST normalize vocabulary term input by trimming surrounding whitespace, removing blank entries, and deduplicating entries case-insensitively while preserving first-entered order and display casing.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid blocking the UI thread.
- **NFR-004**: UX changes MUST align with the pipeline state machine and provide clear user status/errors without leaking internal details.
- **NFR-005**: Vocabulary settings and per-session overrides MUST remain understandable to first-time users without exposing internal model tuning concepts.

### Key Entities *(include if feature involves data)*

- **Global Vocabulary Configuration**: User-defined default state containing enabled/disabled flag, term list, and strength level.
- **Session Vocabulary Override**: Per-session selection of Off, Default, or Custom, plus optional session-specific terms for Custom mode and lifecycle limited to that session.
- **Vocabulary Readiness Status**: Current availability state of required vocabulary prerequisites for the active backend.
- **Vocabulary Term Entry**: A single word or phrase parsed from comma/newline input, normalized for consistent use.

## Assumptions

- FluidAudio is the only backend in scope for vocabulary boosting in this release.
- Whisper remains unsupported for vocabulary boosting and should not expose these controls.
- Session-level strength follows the global strength setting; per-session customization in this release is limited to mode selection and terms.
- Existing configured global terms remain saved even when users temporarily switch to an unsupported backend.

## Dependencies

- Availability of a FluidAudio package version that supports vocabulary boosting and required vocabulary model handling.
- Existing model readiness/download status mechanisms in Settings to surface missing prerequisite models.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At least 95% of users in usability testing can configure global vocabulary boosting (toggle, terms, strength) without assistance in under 90 seconds.
- **SC-002**: At least 95% of tested sessions correctly apply the selected session vocabulary mode (Off, Default, Custom) on first attempt.
- **SC-003**: At least 99% of sessions using Custom mode keep global vocabulary settings unchanged after session completion.
- **SC-004**: In readiness-state validation, 100% of missing prerequisite model conditions surface a visible inline status message before the user starts processing.
- **SC-005**: At least 90% of beta users report that the vocabulary controls are easy to understand and helpful for names/acronyms/product terms.
