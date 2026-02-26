# Data Model: Custom Meeting Prompt Authoring

## Entities

### 1. MeetingTypeDefinition

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `typeId` | String | Yes | Stable unique identifier used for persistence and pipeline selection. |
| `displayName` | String | Yes | User-facing meeting type name. |
| `source` | Enum | Yes | `built_in` or `custom`. |
| `isDeletable` | Boolean | Yes | `false` for built-ins, `true` for custom types. |
| `isEditableName` | Boolean | Yes | Whether user can rename this type. |
| `autodetectEligible` | Boolean | Yes | Whether this type participates in classifier candidate labels. |
| `promptComponents` | PromptComponentSet | Yes | Authorable prompt parts for this type. |
| `classifierProfile` | ClassifierProfile | No | Cues/examples used when autodetect is enabled. |
| `updatedAt` | DateTime | Yes | Last update timestamp. |
| `status` | Enum | Yes | `active`, `archived`, `deleted`. |

### 2. PromptComponentSet

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `objective` | String | Yes | Role and goal statement for this meeting type. |
| `summaryFocus` | String | Yes | Guidance for what the summary should prioritize. |
| `decisionRules` | String | No | Rules for extracting or suppressing decision items. |
| `actionItemRules` | String | No | Rules for extracting action items and ownership language. |
| `openQuestionRules` | String | No | Rules for unresolved topics. |
| `keyPointRules` | String | No | Rules for notable facts/constraints/context. |
| `noiseFilterRules` | String | No | Rules for ignoring filler/non-substantive content. |
| `additionalGuidance` | String | No | Optional extra instructions from user. |
| `version` | Integer | Yes | Revision number for deterministic tracking. |

### 3. BuiltInPromptOverride

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `typeId` | String | Yes | Built-in type being overridden. |
| `defaultComponents` | PromptComponentSet | Yes | Shipped baseline prompt components. |
| `overrideComponents` | PromptComponentSet | Yes | Current user-edited components. |
| `isOverridden` | Boolean | Yes | Whether override differs from default. |
| `updatedAt` | DateTime | Yes | Last override edit timestamp. |

### 4. ClassifierProfile

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `label` | String | Yes | Classifier label text for this type. |
| `strongSignals` | Array<String> | Yes | Concise cues that indicate this type. |
| `counterSignals` | Array<String> | No | Cues that should bias away from this type. |
| `positiveExamples` | Array<String> | No | Short representative snippets for this type. |
| `negativeExamples` | Array<String> | No | Examples that should map to another type/general. |

### 5. MeetingTypeLibrary

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `definitions` | Array<MeetingTypeDefinition> | Yes | Full active library (built-in + custom). |
| `defaultTypeId` | String | Yes | Default stage selection identifier (`autodetect`). |
| `libraryVersion` | Integer | Yes | Monotonic version incremented for any mutation. |
| `updatedAt` | DateTime | Yes | Last library mutation timestamp. |

### 6. MeetingTypeSelection

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `selectionMode` | Enum | Yes | `manual` or `autodetect`. |
| `selectedTypeId` | String | Yes | Manual selection target, or `autodetect` marker. |
| `resolvedTypeId` | String | No | Type chosen after classifier resolution for processing run. |
| `resolutionSource` | Enum | No | `manual`, `classifier`, `fallback_general`. |

### 7. ResolvedPromptBundle

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `typeId` | String | Yes | Resolved meeting type used for inference. |
| `typeDisplayName` | String | Yes | User-facing resolved type label. |
| `systemPrompt` | String | Yes | Final assembled system prompt sent to model. |
| `userPromptPreamble` | String | Yes | User-level instruction block before timeline payload. |
| `runtimeLanguageMode` | String | Yes | Effective language-processing mode metadata. |
| `runtimeOutputLanguage` | String | Yes | Effective output language metadata. |
| `sourceKind` | Enum | Yes | `built_in_default`, `built_in_override`, `custom`. |

## Relationships

- A `MeetingTypeLibrary` contains many `MeetingTypeDefinition` records.
- A built-in `MeetingTypeDefinition` can have zero or one active `BuiltInPromptOverride`.
- Every `MeetingTypeDefinition` references exactly one `PromptComponentSet` (default or customized effective set).
- A `MeetingTypeDefinition` can have zero or one `ClassifierProfile`.
- A `MeetingTypeSelection` resolves to one `ResolvedPromptBundle` at processing time.
- A `ResolvedPromptBundle.typeId` must match an active `MeetingTypeDefinition.typeId`.

## Validation Rules

- `displayName` MUST be unique case-insensitively across active meeting types.
- Built-in types MUST NOT transition to `deleted`.
- Custom types MUST provide non-empty `objective` and `summaryFocus` prompt components.
- `autodetectEligible = true` requires a non-empty `ClassifierProfile.label` and at least one `strongSignals` entry.
- `selectedTypeId` in `MeetingTypeSelection` MUST exist in active library definitions unless explicitly equal to `autodetect`.
- If a selected custom type is deleted before processing, selection MUST be treated as invalid and require user replacement.
- Prompt bundle assembly order MUST remain deterministic for identical inputs.

## State Transitions

### MeetingTypeDefinition

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `active` | User deletes custom type | `deleted` |
| `active` | User archives custom type | `archived` |
| `archived` | User restores type | `active` |
| `deleted` | N/A | terminal |

### BuiltInPromptOverride

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `isOverridden = false` | User edits built-in components and saves | `isOverridden = true` |
| `isOverridden = true` | User restores built-in default | `isOverridden = false` |

### MeetingTypeSelection

| Current State | Trigger | Next State |
|--------------|---------|------------|
| `manual` | User switches to autodetect | `autodetect` |
| `autodetect` | Classifier returns eligible type | `resolvedTypeId = classifier result` |
| `autodetect` | Classifier output invalid/uncertain | `resolvedTypeId = general` |
| `manual` | Selected type missing at processing | `invalid (requires replacement)` |
