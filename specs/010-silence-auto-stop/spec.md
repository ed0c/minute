# Feature Specification: Silence Auto Stop

**Feature Branch**: `010-silence-auto-stop`  
**Created**: 2026-02-15  
**Status**: Draft  
**Input**: User description: "I need to implement a Silence Detection feature to automatically stop the recording (or notify the user) when a meeting ends. After 2 minutes of silence (using root mean square). Send a notification that notifies the user that the recording will stop in 30 seconds. The notification has a action to keep recording. The notification should also show if the user uses screen context functionality and the shared window is closed."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Auto-stop after sustained silence (Priority: P1)

As a user recording a meeting, I want the app to detect when the meeting has likely ended and stop recording automatically after sustained silence so I do not keep recording empty time.

**Why this priority**: This is the core user value of the feature and directly reduces unnecessary recording time and post-processing.

**Independent Test**: Start a recording, provide normal speech, then keep audio silent for at least 2 minutes and do not interact with warnings; confirm that recording stops automatically after the warning countdown ends.

**Acceptance Scenarios**:

1. **Given** an active recording session, **When** continuous silence reaches 2 minutes, **Then** the user is warned that recording will stop in 30 seconds.
2. **Given** a 30-second stop warning is active, **When** no user action occurs and silence continues, **Then** recording stops automatically at the end of the countdown.

---

### User Story 2 - Continue recording from warning (Priority: P2)

As a user, I want to keep recording from the warning notification so recording is not stopped when the meeting is still in progress.

**Why this priority**: Preventing accidental stop is essential for trust and usability of an automated stop behavior.

**Independent Test**: Trigger the 30-second warning, choose the keep-recording action, and verify recording continues and no stop occurs from that warning cycle.

**Acceptance Scenarios**:

1. **Given** a 30-second stop warning is shown, **When** the user selects the keep-recording action, **Then** recording continues and the pending auto-stop is canceled.
2. **Given** a pending auto-stop warning, **When** meaningful speech resumes before countdown ends, **Then** the pending auto-stop is canceled.

---

### User Story 3 - Screen context closure warning (Priority: P3)

As a user sharing a screen context window during recording, I want to be notified if the shared window closes so I know recording context has changed.

**Why this priority**: This prevents silent loss of screen context and improves user awareness of what is being captured.

**Independent Test**: Start recording with screen context enabled, close the shared window, and verify the user receives a notification about the closure.

**Acceptance Scenarios**:

1. **Given** screen context is enabled with a shared window, **When** that window is closed, **Then** the user is notified that shared window context ended.
2. **Given** a silence warning and shared-window-closed event happen close together, **When** notifications are shown, **Then** the user can understand both conditions and still access keep-recording action.

### Edge Cases

- Background noise remains above the silence threshold for long periods after the meeting ends.
- Short intermittent sounds occur during a silence period (for example keyboard clicks).
- Notification permissions are unavailable; the user still needs an in-app warning before auto-stop.
- The user reopens or changes shared window selection after the original shared window closes.
- Recording is manually stopped by the user while a silence countdown is active.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST evaluate recording audio continuously for silence using root mean square (RMS) level.
- **FR-002**: The system MUST treat silence as continuous low-audio input lasting 2 minutes without interruption.
- **FR-003**: The system MUST issue a user-visible warning when 2 minutes of silence is reached.
- **FR-004**: The warning MUST state that recording will stop in 30 seconds unless the user keeps recording.
- **FR-005**: The warning MUST provide a keep-recording action that the user can trigger during the 30-second period.
- **FR-006**: If the user triggers keep-recording, the system MUST cancel the pending stop and continue recording.
- **FR-007**: If no keep-recording action is taken and silence continues through the full warning period, the system MUST stop recording automatically.
- **FR-008**: If speech resumes during the warning period, the system MUST cancel the pending auto-stop.
- **FR-009**: When screen context capture is enabled, the system MUST detect when the currently shared window is closed.
- **FR-010**: When a shared window closes during screen context capture, the system MUST notify the user that screen context is no longer active.
- **FR-011**: If both silence warning and shared-window-closed conditions occur in the same recording session, the system MUST surface both without hiding the keep-recording action.
- **FR-012**: The system MUST record enough session-level event history to verify why recording stopped or continued (silence auto-stop, keep-recording action, resumed speech, or manual stop).

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid blocking the UI thread.
- **NFR-004**: UX changes MUST align with the pipeline state machine and provide clear user status/errors without leaking internal details.
- **NFR-005**: Silence and shared-window state evaluation MUST not degrade recording responsiveness during long sessions.

### Key Entities *(include if feature involves data)*

- **Recording Session State**: Tracks whether recording is active, warning countdown state, and final stop reason.
- **Silence Window**: Represents the current continuous low-audio interval used to decide whether warning and auto-stop should trigger.
- **Stop Warning**: Represents the 30-second pending-stop notice, countdown timing, and user response (keep recording or no action).
- **Screen Context State**: Represents whether screen context is enabled and whether the selected shared window is still open.
- **Session Event Log Entry**: Represents user-visible state changes relevant to this feature (warning shown, keep recording selected, window closed, auto-stop executed).

## Assumptions

- Silence timing is based on continuous silence; any meaningful speech resets the 2-minute timer.
- The keep-recording action applies only to the currently active warning cycle.
- If system notifications are unavailable, an equivalent in-app warning is shown.
- Shared-window closure notification is only required when screen context capture is enabled for the current recording session.

## Dependencies

- Permission to show user notifications.
- Reliable detection of shared-window lifecycle events when screen context is enabled.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In validation sessions with 2 or more minutes of continuous silence, at least 95% present a stop warning before recording stops.
- **SC-002**: In validation sessions where no user action is taken after the warning, at least 95% stop within 5 seconds of the 30-second warning period ending.
- **SC-003**: In validation sessions where users choose keep recording during the warning, at least 99% continue recording without unintended stop from that warning cycle.
- **SC-004**: In validation sessions using screen context, at least 99% of shared-window closure events produce a user-visible notification.
- **SC-005**: At least 90% of test users can correctly explain why recording stopped or continued based on the surfaced warning/notification messages.
