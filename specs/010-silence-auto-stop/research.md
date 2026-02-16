# Phase 0 Research: Silence Auto Stop

## Research Task 1: RMS silence detection boundary for active recording

**Decision**: Treat the incoming normalized level stream as the RMS signal source and classify a frame as silent when level is below a configurable threshold for a continuous 120-second window. Use a short hysteresis buffer so brief spikes (keyboard taps/clicks) do not reset the full silence window.

**Rationale**: Existing capture flow already computes normalized RMS-like levels in `DefaultAudioService` and delivers them through `AudioLevelMetering`, which allows adding silence logic without duplicating capture taps or introducing a second audio analysis pipeline.

**Alternatives considered**:
- Compute RMS from recorded temp files on an interval: rejected because it introduces I/O latency and complicates real-time decisions.
- Use peak amplitude instead of RMS: rejected because peak is too sensitive to transients and can cause false resets.
- Use VAD model inference: rejected for v1 due to higher complexity and unnecessary model/runtime overhead.

## Research Task 2: 30-second warning and keep-recording notification UX

**Decision**: Use an actionable local notification with a dedicated category/action for “Keep Recording”, and mirror the same warning state in-app if notification authorization is denied/unavailable.

**Rationale**: The project already has `UNUserNotificationCenter` delegate plumbing and category/action handling patterns in `MinuteApp` and `MicActivityNotificationCoordinator`, enabling a consistent extension for this feature while preserving usability when banners are not permitted.

**Alternatives considered**:
- In-app-only warning (no OS notification): rejected because users may not be focused on the app window while recording.
- Notification-only warning (no in-app fallback): rejected because denied permissions would create silent auto-stops without warning.
- Modal confirmation dialog: rejected because modal interruptions during recording are intrusive.

## Research Task 3: Countdown execution and cancellation safety

**Decision**: Model countdown as explicit recording-session state with cancelable task ownership tied to recording lifecycle. Cancel countdown immediately on keep-recording action, resumed speech, manual stop, or recording cancel.

**Rationale**: The existing pipeline/view-model uses async tasks and cancellation heavily; matching this pattern avoids orphan timers and race conditions that could stop recordings after state has changed.

**Alternatives considered**:
- Use detached timers independent of recording state: rejected due to race risk and cleanup complexity.
- Poll-only approach without explicit state: rejected because observability and testability are weaker.

## Research Task 4: Shared-window-closed detection for screen context

**Decision**: Detect shared-window closure by validating current selection against active shareable windows during capture failures and emit a user-visible closure alert once per closure event until selection changes or recording restarts.

**Rationale**: Current `ScreenContextCaptureService` logs capture failures but does not distinguish transient capture errors from window closure. A closure-specific check enables precise user messaging while avoiding noisy repeated alerts.

**Alternatives considered**:
- Treat every capture error as window closed: rejected because transient failures would create false alerts.
- No closure detection (status quo): rejected because it misses an explicit requirement and leaves users unaware of lost screen context.

## Research Task 5: Session event history for stop rationale

**Decision**: Record session-scoped event entries for warning-issued, keep-recording-selected, speech-resumed-cancel, auto-stop-executed, manual-stop, and shared-window-closed-notified.

**Rationale**: Requirements and success criteria need traceability for why recording stopped or continued. Session-level event history provides deterministic verification without changing vault file contracts.

**Alternatives considered**:
- Only store final stop reason: rejected because it loses key transition evidence for QA/debugging.
- Persist event history into vault output files: rejected due to output-contract change risk and unnecessary user-facing data expansion.
