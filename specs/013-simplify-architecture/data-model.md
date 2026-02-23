# Data Model: Architecture Simplification Refactor

## Entities

### 1. WorkflowArea

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `areaId` | String | Yes | Stable identifier for a major workflow domain. |
| `name` | String | Yes | Human-readable workflow area name. |
| `scope` | String | Yes | Business scope covered by this area. |
| `entryPoints` | Array<String> | Yes | Main contributor entry points for this area. |
| `ownerModules` | Array<String> | Yes | Canonical modules that own behavior in this area. |
| `outOfScopeModules` | Array<String> | No | Adjacent modules explicitly not owned by this area. |
| `status` | Enum | Yes | `baseline`, `refactoring`, `stabilized`. |

### 2. OwnershipMapEntry

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `entryId` | String | Yes | Unique identifier for one ownership declaration. |
| `workflowAreaId` | String | Yes | Reference to `WorkflowArea.areaId`. |
| `ownedPath` | String | Yes | Source path owned by the workflow area. |
| `responsibility` | String | Yes | Plain-language statement of what this path owns. |
| `allowedDependencies` | Array<String> | No | Explicitly allowed collaboration boundaries. |
| `lastReviewedAt` | DateTime | Yes | Most recent ownership review timestamp. |
| `reviewStatus` | Enum | Yes | `draft`, `approved`, `superseded`. |

### 3. SharedBehaviorUnit

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `unitId` | String | Yes | Stable shared-behavior identifier. |
| `behaviorName` | String | Yes | Name of consolidated behavior. |
| `canonicalOwnerPath` | String | Yes | Canonical implementation location. |
| `consumers` | Array<String> | Yes | Paths consuming this behavior. |
| `replacedSources` | Array<String> | Yes | Prior duplicate implementations replaced by canonical owner. |
| `state` | Enum | Yes | `identified`, `consolidating`, `consolidated`, `verified`. |

### 4. DeadCodeFinding

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `findingId` | String | Yes | Unique finding identifier. |
| `path` | String | Yes | Candidate dead code path. |
| `category` | Enum | Yes | `unused`, `unreachable`, `redundant_duplicate`, `obsolete_scaffold`. |
| `evidence` | Array<String> | Yes | Supporting evidence for dead-code status. |
| `removalScope` | String | Yes | Scope summary for planned removal. |
| `parityCheckpointIds` | Array<String> | Yes | Required parity checks before closure. |
| `status` | Enum | Yes | `open`, `approved_for_removal`, `removed`, `rejected`. |

### 5. BehaviorParityCheckpoint

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `checkpointId` | String | Yes | Unique checkpoint identifier. |
| `workflowAreaId` | String | Yes | Reference to covered workflow area. |
| `scenario` | String | Yes | Behavior scenario to validate. |
| `verificationType` | Enum | Yes | `automated_test`, `manual_regression`, `both`. |
| `beforeResult` | Enum | Yes | `pass`, `fail`, `not_run`. |
| `afterResult` | Enum | Yes | `pass`, `fail`, `not_run`. |
| `status` | Enum | Yes | `pending`, `in_progress`, `passed`, `failed`. |
| `notes` | String | No | Optional evidence and context. |

### 6. RefactorWorkItem

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `workItemId` | String | Yes | Unique work-slice identifier. |
| `title` | String | Yes | Work-slice title. |
| `workflowAreaId` | String | Yes | Target workflow area. |
| `changes` | Array<String> | Yes | Planned structural/code changes. |
| `sharedBehaviorUnitIds` | Array<String> | No | Shared behavior units affected by this work item. |
| `deadCodeFindingIds` | Array<String> | No | Dead-code findings addressed by this work item. |
| `checkpointIds` | Array<String> | Yes | Required parity checkpoints. |
| `status` | Enum | Yes | `planned`, `in_progress`, `blocked`, `ready_for_review`, `completed`. |

### 7. MigrationNoteEntry

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `noteId` | String | Yes | Unique migration-note entry identifier. |
| `changeType` | Enum | Yes | `moved`, `renamed`, `deleted`, `consolidated`. |
| `oldLocation` | String | No | Prior location for moved/renamed/deleted elements. |
| `newLocation` | String | No | New location for moved/renamed/consolidated elements. |
| `impactSummary` | String | Yes | Contributor-facing impact summary. |
| `effectiveVersion` | String | Yes | Version/tag tied to this migration entry. |

## Relationships

- A `WorkflowArea` has many `OwnershipMapEntry` records.
- A `WorkflowArea` has many `BehaviorParityCheckpoint` records.
- A `RefactorWorkItem` targets one `WorkflowArea` and references zero or more `SharedBehaviorUnit` and `DeadCodeFinding` records.
- A `DeadCodeFinding` references one or more `BehaviorParityCheckpoint` records that must pass before closure.
- A `MigrationNoteEntry` is produced by one or more completed `RefactorWorkItem` records.

## Validation Rules

- Every active `WorkflowArea` MUST have at least one `OwnershipMapEntry` with `reviewStatus = approved`.
- Each `OwnershipMapEntry.ownedPath` MUST belong to one primary `WorkflowArea` only.
- A `SharedBehaviorUnit` can be marked `verified` only if all listed consumer paths use the canonical owner.
- A `DeadCodeFinding` can move to `removed` only when all linked `BehaviorParityCheckpoint` records are `passed`.
- A `RefactorWorkItem` can move to `completed` only when all its `checkpointIds` are `passed`.
- A `MigrationNoteEntry` MUST include an `impactSummary` and at least one location field (`oldLocation` or `newLocation`).

## State Transitions

### WorkflowArea

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `baseline` | First approved refactor work item starts | `refactoring` |
| `refactoring` | All scoped work items complete and parity checkpoints pass | `stabilized` |
| `stabilized` | New simplification slice opened | `refactoring` |

### SharedBehaviorUnit

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `identified` | Canonical owner selected | `consolidating` |
| `consolidating` | Duplicate paths removed and consumers switched | `consolidated` |
| `consolidated` | Parity checkpoints pass | `verified` |

### DeadCodeFinding

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `open` | Review confirms dead-code evidence | `approved_for_removal` |
| `approved_for_removal` | Code removed + required checkpoints pass | `removed` |
| `open` or `approved_for_removal` | Review disproves dead-code status | `rejected` |

### RefactorWorkItem

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `planned` | Implementation begins | `in_progress` |
| `in_progress` | External dependency or parity issue blocks progress | `blocked` |
| `blocked` | Blocker resolved | `in_progress` |
| `in_progress` | Changes complete and checkpoints pass | `ready_for_review` |
| `ready_for_review` | Review approved and migration note updated | `completed` |
