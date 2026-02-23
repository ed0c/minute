# Quickstart: Architecture Simplification Refactor

## Goal

Implement the architecture simplification backlog so the system is easier to understand and navigate, avoids multi-layered abstractions, and removes dead code while preserving product behavior and output contracts.

## Prerequisites

- macOS 14+ development machine.
- Clean build/test environment for app target and package tests.
- Familiarity with current hotspots called out in the specification (pipeline flow, meeting notes flow, model setup flow, shared utility duplication, repeated test setup).

## Recommended Implementation Sequence (TDD-first)

1. Baseline ownership map and parity checkpoints.
2. Add failing parity tests for target workflows before structural changes.
3. Refactor one workflow slice at a time:
   - split mixed-responsibility modules by ownership,
   - consolidate duplicated behavior into canonical owner,
   - remove replaced and dead paths.
4. After each slice, run parity checks and update ownership map.
5. Consolidate repeated test fixtures in high-volume suites.
6. Publish migration note entries for moved/renamed/deleted surfaces.
7. Remove temporary migration scaffolding before completion.

## Suggested Work Slices

1. **Pipeline and status ownership slice**
   - Separate session lifecycle logic, status presentation mapping, and defaults synchronization responsibilities.
2. **Meeting notes ownership slice**
   - Separate note IO, speaker naming operations, and transcript/frontmatter transformations.
3. **Model setup ownership slice**
   - Consolidate duplicated model download/validation lifecycle between onboarding and settings.
4. **Shared utility consolidation slice**
   - Centralize repeated path normalization and capture wrapper behavior.
5. **Test architecture slice**
   - Introduce shared fixture builders for repetitive setup while keeping scenario assertions explicit.

## Validation Scenarios

1. **Contributor navigation scenario**
   - Locate owners for recording lifecycle, processing orchestration, notes editing, and model setup from ownership map and source structure.
2. **Behavior parity scenario**
   - Verify recording, processing, notes, settings, and recovery flows behave identically before and after each slice.
3. **Duplicate consolidation scenario**
   - Change one shared behavior and confirm it is updated in only one canonical location.
4. **Dead code removal scenario**
   - Confirm removed paths have parity evidence and no remaining references.
5. **Migration note scenario**
   - Confirm contributors can map old locations to new locations using migration entries.

## Suggested Commands

```bash
cd /Users/roblibob/Projects/FLX/Minute/Minute
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test
xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'
```

## Completion Criteria

- Ownership map is complete and approved for all targeted workflow areas.
- All required parity checkpoints are passed.
- Duplicated behaviors in scoped areas are consolidated to canonical owners.
- Dead-code findings in scoped areas are removed or explicitly rejected with rationale.
- Migration note is published and temporary scaffolding is absent.

## Execution Evidence (2026-02-23)

- `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` passed.
- `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` passed (`48` tests, `0` failures).
- `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` passed (`203` tests, `0` failures).
- Consolidation checkpoints:
  - model lifecycle owner: `ModelSetupLifecycleController`
  - vault path owner: `VaultPathNormalizer`
  - ScreenCaptureKit wrapper owner: `ScreenCaptureKitAdapter`
  - meeting-note parsing owner: `MeetingNoteParsing`
