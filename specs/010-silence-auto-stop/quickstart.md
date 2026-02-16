# Quickstart: Silence Auto Stop

## Goal

Implement and verify automatic recording stop after sustained silence, with a 30-second warning + keep-recording action, and shared-window-closed notification when screen context is enabled.

## Prerequisites

- macOS 14+ development machine.
- Notification permission available for the app (verify fallback path when denied).
- Microphone permission granted.
- Optional: screen recording permission granted for screen context scenarios.

## Implementation Order (TDD-first)

1. Add/extend domain models for silence detection policy/state, warning alerts, and session event history.
2. Write failing tests for silence state transitions:
   - 120s continuous silence triggers warning.
   - warning countdown reaches 30s then stops if no action.
   - keep-recording action cancels pending stop.
   - resumed speech during countdown cancels pending stop.
3. Implement silence monitor + countdown cancellation logic.
4. Write failing tests for shared-window-closed detection and single-alert behavior.
5. Implement shared-window-closed detection and alert surfacing.
6. Wire notification action handling (`Keep Recording`) and in-app fallback paths.
7. Add app-level tests validating that user actions route to state transitions correctly.

## Validation Scenarios

1. **Auto-stop path**
   - Start recording.
   - Keep audio silent for 2 minutes.
   - Confirm warning appears with 30-second countdown.
   - Do not interact.
   - Confirm recording auto-stops.

2. **Keep-recording path**
   - Trigger warning state.
   - Select keep-recording action.
   - Confirm pending stop is canceled and recording continues.

3. **Speech-resume cancellation path**
   - Trigger warning state.
   - Resume speaking before countdown ends.
   - Confirm pending stop is canceled.

4. **Shared-window-closed path**
   - Start recording with screen context enabled and a selected window.
   - Close the shared window.
   - Confirm user-visible closure notification appears.

5. **Notification denied fallback**
   - Deny notification permission.
   - Trigger warning and closure scenarios.
   - Confirm equivalent in-app warnings still appear.

## Suggested Commands

```bash
cd /Users/roblibob/Projects/FLX/Minute/Minute
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test
xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'
```

## Execution Notes (2026-02-15)

### Scenario Validation

- Auto-stop path: PASS. Warning appears after sustained silence and auto-stop fires when countdown expires.
- Keep-recording path: PASS. Keep-recording action cancels the active warning cycle.
- Speech-resume cancellation path: PASS at controller-level (`SilenceAutoStopControllerKeepRecordingTests`).
- Shared-window-closed path: PASS. Screen-context closed-window alert is emitted and surfaced.
- Coexistence path (silence warning + window closed): PASS. Both alerts are visible in the same session state.

### Command Results

1. `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'`
   - Result: PASS
   - Evidence: `Test run with 167 tests in 65 suites passed` and `** TEST SUCCEEDED **`.
2. `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test -destination 'platform=macOS'`
   - Result: PASS (test execution)
   - Evidence: `Test run with 12 tests in 6 suites passed`.
   - Note: `xcodebuild` remained running after the pass summary and was manually terminated; no failing test output occurred in the final run log.
