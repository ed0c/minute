# Data Model: Settings Information Architecture Refresh

## Overview

This feature introduces a single-window workspace model where settings replaces the currently visible content in the same main window, while recording and in-progress session work remain continuous.

## Entities

### 1) WorkspaceRouteState

Represents which full-window workspace is currently displayed in the main app window.

| Field | Type | Required | Rules |
|---|---|---|---|
| `activeWorkspace` | Enum (`pipeline`, `settings`) | Yes | Exactly one workspace is active at a time. |
| `previousWorkspace` | Enum (`pipeline`, `settings`) | No | Tracks prior workspace for deterministic return behavior. |
| `changedAt` | Timestamp | Yes | Updated each time workspace changes. |

Validation rules:
- Switching to `settings` must occur in the existing main window.
- Route updates must not spawn additional application windows.

### 2) SettingsCategoryDefinition

Metadata for sidebar categories.

| Field | Type | Required | Rules |
|---|---|---|---|
| `id` | String | Yes | Stable identifier used for selection and persistence. |
| `title` | String | Yes | User-facing category name; must be non-empty. |
| `sortOrder` | Integer | Yes | Unique ordering value within visible categories. |
| `isVisible` | Boolean | Yes | Computed from capability/feature rules. |
| `description` | String | No | Optional helper text for discoverability. |

Validation rules:
- `id` values must be unique.
- Exactly one visible category is selected in settings workspace.
- Hidden categories cannot be selected.

### 3) SettingsWorkspaceSelection

Tracks current sidebar selection while in settings.

| Field | Type | Required | Rules |
|---|---|---|---|
| `selectedCategoryId` | String | Yes | Must match a currently visible category `id`. |
| `lastVisitedCategoryId` | String | No | Used for continuity when reopening settings. |
| `updatedAt` | Timestamp | Yes | Updated on category selection changes. |

Validation rules:
- If the selected category becomes hidden, fallback to first visible category by `sortOrder`.

### 4) WorkContinuitySnapshot

Captures continuity-critical state that must survive workspace switching.

| Field | Type | Required | Rules |
|---|---|---|---|
| `isRecordingActive` | Boolean | Yes | `true` if recording is currently active. |
| `pipelineStage` | String | Yes | Current pipeline stage/status label. |
| `activeSessionId` | String | No | Present when a session is in progress. |
| `unsavedWorkPresent` | Boolean | Yes | Indicates in-progress session data not yet finalized. |
| `capturedAt` | Timestamp | Yes | Timestamp for comparison before/after route switch. |

Validation rules:
- Route transitions must not mutate continuity fields unless a pipeline event occurred independently.

## Relationships

- `WorkspaceRouteState.activeWorkspace = settings` requires `SettingsWorkspaceSelection.selectedCategoryId` to resolve to a visible `SettingsCategoryDefinition`.
- `WorkContinuitySnapshot` is orthogonal to workspace selection and must remain valid across route transitions.
- Category visibility influences valid selection; workspace route does not alter continuity snapshot.

## State Transitions

### Workspace transitions

- `pipeline -> settings`: Main window content switches to settings workspace; no additional window created.
- `settings -> pipeline`: Main window returns to pipeline workspace.
- `settings -> settings` (re-open action): Idempotent; no new window and no state reset.

### Category transitions

- `category A -> category B`: Selection updates and detail pane changes accordingly.
- `category X hidden while selected`: automatic fallback to first visible category.

### Continuity invariants across route transitions

For `pipeline <-> settings` transitions:
- `isRecordingActive` must remain unchanged.
- `activeSessionId` must remain unchanged when session exists.
- `pipelineStage` must remain unchanged unless a separate pipeline event occurs.
- `unsavedWorkPresent` must remain unchanged.

## Derived View Models

- `SettingsSidebarViewState`: visible categories, selected category, and ordering.
- `SettingsWorkspaceViewState`: active workspace + selected category detail content.
- `ContinuityGuardState`: before/after continuity snapshot used by tests and diagnostics.
