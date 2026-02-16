# Data Model: Silence Auto Stop

## Entities

### 1. SilenceDetectionPolicy

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `silenceDurationSeconds` | Integer | Yes | Continuous silence duration required before warning (default `120`). |
| `warningCountdownSeconds` | Integer | Yes | Warning countdown before auto-stop (default `30`). |
| `rmsSilenceThreshold` | Number | Yes | Normalized RMS threshold below which audio is considered silent. |
| `transientToleranceSeconds` | Number | Yes | Maximum short non-silent burst duration that does not reset silence accumulation. |

### 2. SilenceDetectionState

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `sessionID` | UUID | Yes | Recording session identifier. |
| `phase` | Enum | Yes | `monitoring`, `warning_active`, `auto_stop_executed`, `canceled_by_user`, `canceled_by_speech`, `inactive`. |
| `silenceAccumulatedSeconds` | Number | Yes | Current continuous silence accumulation. |
| `warningStartedAt` | DateTime | No | Set when warning is issued. |
| `warningDeadlineAt` | DateTime | No | `warningStartedAt + warningCountdownSeconds`. |
| `pendingStop` | Boolean | Yes | Whether recording is queued for auto-stop on countdown completion. |

### 3. RecordingAlert

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `alertID` | UUID | Yes | Unique identifier for warning/notification instance. |
| `alertType` | Enum | Yes | `silence_stop_warning` or `screen_window_closed`. |
| `sessionID` | UUID | Yes | Associated recording session. |
| `message` | String | Yes | User-visible text. |
| `issuedAt` | DateTime | Yes | Timestamp when alert became active. |
| `expiresAt` | DateTime | No | Set for silence warning alerts only. |
| `actions` | Array<Enum> | Yes | Allowed actions (`keep_recording`, `acknowledge`). |
| `status` | Enum | Yes | `active`, `resolved`, `expired`. |

### 4. ScreenContextWatchState

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `sessionID` | UUID | Yes | Recording session identifier. |
| `screenContextEnabled` | Boolean | Yes | Whether screen context is active for this session. |
| `selection` | Object | No | Selected window identity (bundle ID, app name, title). |
| `windowClosedDetectedAt` | DateTime | No | First confirmed closure timestamp in current session. |
| `closureAlertIssued` | Boolean | Yes | Guards against duplicate closure alerts for same closure event. |

### 5. RecordingSessionEvent

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `eventID` | UUID | Yes | Unique event identifier. |
| `sessionID` | UUID | Yes | Recording session identifier. |
| `eventType` | Enum | Yes | `silence_warning_issued`, `keep_recording_selected`, `warning_canceled_by_speech`, `auto_stop_executed`, `manual_stop`, `recording_canceled`, `screen_window_closed_notified`. |
| `timestamp` | DateTime | Yes | Event timestamp. |
| `metadata` | Object | No | Optional event details (countdown remaining, threshold values, window title). |

## Relationships

- `SilenceDetectionPolicy` configures each `SilenceDetectionState`.
- `SilenceDetectionState` can produce zero or more `RecordingAlert` entries.
- `ScreenContextWatchState` can produce `RecordingAlert` entries of type `screen_window_closed`.
- A recording session has many `RecordingSessionEvent` entries.
- `RecordingAlert` resolution actions (`keep_recording`, `acknowledge`) append corresponding `RecordingSessionEvent` entries.

## Validation Rules

- `silenceDurationSeconds` MUST be `120` for v1.
- `warningCountdownSeconds` MUST be `30` for v1.
- `rmsSilenceThreshold` MUST be within `[0, 1]`.
- `silenceAccumulatedSeconds` MUST never be negative.
- `warningDeadlineAt` MUST be later than `warningStartedAt`.
- `RecordingAlert.expiresAt` is required when `alertType = silence_stop_warning` and forbidden when `alertType = screen_window_closed`.
- At most one active `silence_stop_warning` alert may exist per session at a time.
- For the same closure event, only one active `screen_window_closed` alert may exist until selection changes or session ends.

## State Transitions

### SilenceDetectionState

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `monitoring` | Continuous silence reaches 120s | `warning_active` |
| `warning_active` | User selects keep recording | `canceled_by_user` then `monitoring` |
| `warning_active` | Speech resumes before deadline | `canceled_by_speech` then `monitoring` |
| `warning_active` | Countdown reaches 0 with silence | `auto_stop_executed` |
| Any active state | User manually stops/cancels recording | `inactive` |

### ScreenContextWatchState

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `screenContextEnabled=true` | Selected window no longer exists | `windowClosedDetectedAt` set, `closureAlertIssued=true` |
| `closureAlertIssued=true` | User reselects a window | `closureAlertIssued=false`, `windowClosedDetectedAt=nil` |
| Any | Recording stops/cancels | Session watch state cleared |
