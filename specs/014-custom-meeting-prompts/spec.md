# Feature Specification: Custom Meeting Type Prompts

**Feature Branch**: `014-custom-meeting-prompts`  
**Created**: 2026-02-23  
**Status**: Draft  
**Input**: User description: "As a user I want to create my own custom meeting types where I can customize the prompt. I also want the possibility to edit the default prompts."

## Clarifications

### Session 2026-02-23

- Q: Where should users manage custom and default meeting prompts in Settings? → A: In a dedicated "Meeting Types" section (not mixed into general AI/model controls).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create Custom Meeting Types (Priority: P1)

As a user, I want to create my own meeting types with custom prompts so summaries match my team workflows and meeting formats.

**Why this priority**: This is the primary value request and enables personalization beyond built-in options.

**Independent Test**: Create a new custom meeting type with a unique name and prompt, select it for a meeting, process the meeting, and verify the custom type is available and applied.

**Acceptance Scenarios**:

1. **Given** a user is managing meeting types, **When** the user creates a custom meeting type with a valid name and prompt, **Then** the new type is saved and appears in available meeting type choices.
2. **Given** a custom meeting type exists, **When** the user selects it for a meeting before processing, **Then** processing uses that custom type's prompt.
3. **Given** the user attempts to create a custom meeting type with missing or invalid required fields, **When** the user saves, **Then** the system blocks the save and explains what must be fixed.

---

### User Story 2 - Edit Default Prompts (Priority: P2)

As a user, I want to edit prompts for built-in meeting types so default behavior can be tuned to my organization without creating duplicate types.

**Why this priority**: Editing defaults reduces setup effort and keeps common meeting categories consistent with team preferences.

**Independent Test**: Edit a built-in meeting type prompt, save, process a meeting using that type, and confirm the edited prompt is used; then restore default and verify the original prompt is used again.

**Acceptance Scenarios**:

1. **Given** a built-in meeting type, **When** the user updates and saves its prompt, **Then** future meetings using that type use the updated prompt.
2. **Given** a built-in meeting type prompt has been edited, **When** the user restores the default prompt, **Then** future meetings use the original shipped prompt.
3. **Given** a built-in meeting type prompt is edited, **When** the user views meeting type choices, **Then** built-in type identity and naming remain intact.

---

### User Story 3 - Maintain Prompt Library Safely (Priority: P3)

As a user, I want to manage custom meeting types safely over time so prompt changes do not break active workflows.

**Why this priority**: Ongoing usability depends on safe rename/delete behavior and predictable handling of existing meeting selections.

**Independent Test**: Rename and delete custom meeting types, verify expected confirmations and fallbacks, and confirm built-in types cannot be deleted.

**Acceptance Scenarios**:

1. **Given** a custom meeting type exists, **When** the user renames it with a valid unique name, **Then** the updated name appears everywhere that type is selectable.
2. **Given** a custom meeting type exists, **When** the user deletes it and confirms the action, **Then** the type is removed from future meeting type choices.
3. **Given** a built-in meeting type, **When** the user tries to remove it, **Then** removal is not allowed and a clear explanation is shown.
4. **Given** a meeting references a custom type that was later deleted, **When** the user tries to process that meeting, **Then** the system requires a valid replacement selection before processing.

### Edge Cases

- A user creates or renames a custom meeting type using a name that already exists (including case-only variations).
- A user enters a prompt with only whitespace or no meaningful content.
- A user deletes a custom meeting type that is currently selected for an unprocessed meeting.
- A user edits a default prompt after older meetings were already processed; historical meeting outputs should not change retroactively.
- A user rapidly saves multiple prompt edits and expects the last confirmed save to be the one applied.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a dedicated "Meeting Types" section in Settings where users can view built-in and custom meeting types and their prompts.
- **FR-002**: Users MUST be able to create a custom meeting type with a name and prompt.
- **FR-003**: The system MUST require custom meeting type names to be unique across all meeting types, including case-insensitive matches.
- **FR-004**: The system MUST require custom meeting type name and prompt fields to contain non-empty meaningful content before save.
- **FR-005**: Users MUST be able to edit prompt content for any existing custom meeting type.
- **FR-006**: Users MUST be able to rename custom meeting types.
- **FR-007**: Users MUST be able to delete custom meeting types with explicit confirmation.
- **FR-008**: The system MUST allow users to edit prompt content for built-in meeting types.
- **FR-009**: The system MUST allow users to restore any built-in meeting type prompt to its original default value.
- **FR-010**: Built-in meeting types MUST remain protected from deletion.
- **FR-011**: Meeting type selection options for new or unprocessed meetings MUST include both built-in and user-created custom meeting types.
- **FR-012**: When a meeting is processed, the system MUST use the prompt associated with the selected meeting type at processing start.
- **FR-013**: Prompt edits and meeting type changes MUST affect only meetings processed after the change is saved.
- **FR-014**: If a selected custom meeting type is no longer available at processing time, the system MUST prevent processing until the user selects a valid meeting type.
- **FR-015**: The system MUST preserve all meeting type and prompt customizations across app restarts.
- **FR-016**: The system MUST keep summary output compatible with the existing meeting note output contract.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: The feature MUST preserve local-only processing and MUST not introduce outbound network calls except permitted model downloads.
- **NFR-002**: Prompt management and meeting type selection interactions MUST provide user feedback quickly enough to feel immediate during normal use.
- **NFR-003**: Prompt editing and meeting type management flows MUST be understandable to non-technical users without relying on internal model terminology.
- **NFR-004**: Validation and error messages MUST be clear, actionable, and consistent across create/edit/rename/delete flows.
- **NFR-005**: The feature MUST not reduce reliability of existing summarization behavior for users who continue using only built-in defaults.

### Key Entities *(include if feature involves data)*

- **Meeting Type Definition**: A selectable meeting type record containing type name, built-in/custom classification, availability status, and associated prompt.
- **Meeting Prompt**: User-editable instruction content used to guide meeting summarization for a meeting type.
- **Meeting Prompt Assignment**: The selected meeting type and effective prompt used for a specific meeting processing run.

## Assumptions

- Existing built-in meeting types remain available and continue to serve as baseline options.
- The feature is scoped to a single local user profile and does not include sharing prompt libraries across users/devices.
- Prompt customization affects summarization guidance only and does not change the required meeting note file outputs.
- Meeting type selection behavior from existing workflows remains in place and is extended to include custom types.

## Dependencies

- Existing meeting processing flow that accepts a selected meeting type for summarization.
- Existing meeting type selection surfaces where users choose or change meeting type before processing.
- Existing persistent settings/state storage used for user customizations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance testing, at least 90% of users can create and save a custom meeting type and use it for processing within 2 minutes on first attempt.
- **SC-002**: In acceptance testing, 100% of processed meetings use the prompt tied to the selected meeting type at processing start.
- **SC-003**: In acceptance testing, at least 90% of users can edit a built-in prompt and restore its default without assistance in under 90 seconds.
- **SC-004**: In regression testing, 100% of built-in meeting types remain available and non-deletable while still allowing prompt edits and default restore.
- **SC-005**: In regression testing, no critical defects are introduced in existing meeting processing for users who do not create custom meeting types.
