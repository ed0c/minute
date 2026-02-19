# Packaging, Sandbox, Signing, and QA

This checklist is required before releasing a build.

## Packaging and Signing

- [ ] Build a Release app bundle from `Minute.xcodeproj` using the `Minute` scheme.
- [ ] Verify app sandbox entitlements are present and match expected runtime behavior.
- [ ] Confirm notarization succeeds and stapling is applied to the distributed artifact.
- [ ] Validate update metadata and release notes are prepared.

## Privacy and Network Policy

- [ ] Confirm meeting audio is captured and processed locally.
- [ ] Confirm transcription and summarization execution remains local-only.
- [ ] Confirm no outbound network requests occur during normal capture + processing flows except model download operations.

## Manual QA (Core Flows)

- [ ] Recording starts and stops normally for microphone-only and microphone + system-audio modes.
- [ ] Meeting note, transcript, and optional audio outputs are written to the expected vault paths.
- [ ] Screen-context enabled sessions continue to capture timeline entries and processing succeeds.
- [ ] Canceling a recording while active returns UI to idle without stale processing state.

## Manual QA (Silence Auto-Stop)

- [ ] After approximately 2 minutes of continuous RMS silence, a 30-second stop warning appears.
- [ ] Warning includes a keep-recording action in the notification and in-app fallback UI.
- [ ] If no action is taken and silence continues through countdown, recording stops automatically.
- [ ] If keep-recording is selected, pending auto-stop is canceled and recording continues.
- [ ] If speech resumes during countdown, warning is canceled and no auto-stop occurs from that cycle.
- [ ] Session event history includes reason transitions (`silence_warning_issued`, `keep_recording_selected`, `warning_canceled_by_speech`, `auto_stop_executed`, `manual_stop`, `recording_canceled`).

## Manual QA (Screen Context Window Closure)

- [ ] With screen context enabled for a specific window, closing that window surfaces a user-visible closure alert.
- [ ] Shared-window-closed alert can coexist with silence warning without hiding keep-recording actions.
- [ ] Dismissing the window-closed alert does not stop recording by itself.

## Manual QA (Vocabulary Boosting)

- [ ] With FluidAudio backend selected, global vocabulary controls (toggle, terms editor, strength selector) are visible in Settings.
- [ ] With Whisper backend selected, vocabulary controls are hidden/disabled in Settings and session card.
- [ ] Session card vocabulary row supports `Off`, `Default`, and `Custom`; custom opens term popover.
- [ ] Custom session terms are additive with global terms; empty custom input falls back to default behavior.
- [ ] If vocabulary model readiness is missing, session still starts and shows a non-blocking warning that boosting is disabled.

## Notification Permission Fallback

- [ ] With notification permission denied, silence warning is still visible in-app.
- [ ] With notification permission denied, shared-window-closed state is still visible in-app.

## Test Command Verification

- [ ] `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'` passes.
- [ ] `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test -destination 'platform=macOS'` passes.
