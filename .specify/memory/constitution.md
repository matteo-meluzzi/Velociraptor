<!--
SYNC IMPACT REPORT
==================
Version change: 1.1.0 → 1.3.0 (1.2.0 and 1.3.0 amended in sequence, uncommitted)
Modified principles:
  - II. Test Discipline: added rule that tests MUST verify behaviour, not implementation (1.3.0)
Added sections:
  - VII. Specification Review Gate (new principle)
  - Quality Gates: new planning gate 4 for spec review (old gate 4 renumbered to 5)
  - Development Workflow: specification review step
Removed sections: none
Templates requiring updates:
  ✅ .specify/templates/plan-template.md: Constitution Check reads principles at runtime
  ⚠ .specify/templates/spec-template.md: consider adding a "Review status" field (optional)
Deferred TODOs: none
-->

# Velociraptor Constitution

## Core Principles

### I. Build Integrity

The project MUST build successfully before any git commit is created. A failing build is
a blocker — no commit proceeds until `xcodebuild build` exits cleanly.

**Rationale**: A broken build breaks every team member's workflow and signals incomplete
or inconsistent changes. Catching this at commit time is far cheaper than after push.

**Gate**: Run `xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'`
and confirm exit code 0 before committing.

### II. Test Discipline

All tests MUST pass before any git commit is created. A failing test suite is a blocker —
no commit proceeds until `xcodebuild test` exits cleanly.

Tests MUST verify behaviour, not implementation. A test exercises a unit through its public
interface and asserts on observable outcomes: return values, published state, emitted events,
or effects on collaborators at a real boundary (e.g. the Bluetooth layer behind a protocol).
Tests MUST NOT assert on private state, internal call order, or how a result was computed,
and MUST NOT need to change when code is refactored without changing its behaviour.
Test doubles are permitted only at boundaries the unit does not own.

**Rationale**: Tests document intended behaviour. A passing build with failing tests means
the code compiles but does not behave correctly. Both gates MUST be green together. Tests
coupled to implementation details break on harmless refactors and can still pass when the
behaviour is wrong, so they cost maintenance without protecting correctness.

**Gate**: Run `xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'`
and confirm all tests pass before committing.

### III. Peer Review Before Commit

A reviewer agent MUST be spawned to review all staged/unstaged changes (via `git diff`)
before any git commit is created. The reviewer's sign-off is a hard prerequisite.

**Rationale**: Automated checks (build, tests) verify correctness mechanically. A reviewer
agent provides a second perspective on design, edge-cases, naming, and regressions that
tools cannot catch.

**Gate**: Before committing, run `git diff` (and `git diff --cached` for staged changes),
spawn a reviewer agent with the diff as input, and wait for explicit approval or blocking
feedback. Address all blocking feedback before proceeding.

### IV. Task Completion Gate

A task is NOT complete until it has been reviewed. When implementation is believed
to be done, the developer MUST submit the changes for review via `git diff` and
receive explicit sign-off. Self-declaration of completion is not sufficient.

**Rationale**: "Done" is a shared agreement, not a personal opinion. Requiring a review
before closing a task prevents incomplete or incorrect work from silently accumulating.

**Gate**: The review step is the final step of every task. No task transitions to
"completed" without a reviewer agent approval on the associated diff.

### VI. Plan Review Gate

Every implementation plan (`plan.md`) MUST be reviewed by a dedicated reviewer agent before
any implementation work begins. The reviewer's explicit **APPROVED** verdict is a hard
prerequisite for proceeding to `/speckit-tasks` or any coding task.

**Rationale**: A plan encodes architectural decisions, data flow, and task scope that are
far cheaper to correct before code is written. A reviewer agent provides an independent
check for gaps, missing edge cases, and constitution violations that the author may overlook.

**Gate**: After `/speckit-plan` completes, spawn a reviewer agent with the full plan and
supporting artifacts (`spec.md`, `research.md`, `data-model.md`). Wait for an explicit
**APPROVED** verdict. Address all **BLOCKED** issues and re-run the reviewer until approval
is granted. Only then proceed to implementation.

### VII. Specification Review Gate

Every feature specification produced by Spec Kit (`spec.md`, including any updates from
`/speckit-clarify`) MUST be reviewed by an independent reviewer before it is considered done.
The reviewer MUST NOT be the author of the specification. For AI-authored specifications,
this means a separate reviewer agent spawned with fresh context. The reviewer's explicit
**APPROVED** verdict is a hard prerequisite for proceeding to `/speckit-plan`.

**Rationale**: The specification defines what gets built. Ambiguities, missing requirements,
untestable acceptance criteria, or scope creep cost the least to fix at this stage. An author
reviewing their own spec tends to read what they meant rather than what they wrote.

**Gate**: After `/speckit-specify` (and `/speckit-clarify`, if run) completes, give the full
`spec.md` and any checklists under the feature directory to an independent reviewer. The
reviewer checks completeness, unambiguous and testable requirements, measurable success
criteria, and consistency with this constitution. Wait for an explicit **APPROVED** verdict.
Address all **BLOCKED** issues and re-run the review until approval is granted. A
specification without that approval is not done, and planning MUST NOT begin.

### V. SwiftUI-First

The app MUST be built exclusively with SwiftUI. UIKit and AppKit integrations are
permitted only where SwiftUI has no equivalent API (e.g., certain `UIViewRepresentable`
wrappers). Cross-platform or third-party UI frameworks are prohibited.

**Rationale**: SwiftUI is the declared technology for this project (iOS 18.2+). Mixing
paradigms increases cognitive load and complicates maintenance without material benefit.

## Quality Gates

Every code change MUST pass the following gates **in order** before a git commit is allowed:

1. `xcodebuild build` exits with code 0.
2. `xcodebuild test` exits with all tests passing.
3. A reviewer agent reviews `git diff` (staged + unstaged) and provides sign-off. The
   review MUST flag tests that assert on implementation details rather than behaviour
   (Principle II).

Skipping or reordering these gates is a constitution violation and the commit MUST NOT
proceed.

Before planning and implementation work begins, the following gates MUST also be satisfied:

4. An independent reviewer reviews `spec.md` and returns an explicit **APPROVED** verdict
   (Principle VII). Planning MUST NOT begin before that.
5. A reviewer agent reviews `plan.md` (with `spec.md`, `research.md`, `data-model.md`) and returns an explicit **APPROVED** verdict (Principle VI).

## Development Workflow

- **Specification review**: Have an independent reviewer approve `spec.md` before
  planning (Principle VII).
- **Plan review**: Have a reviewer agent approve `plan.md` before implementation (Principle VI).
- **Implementation**: Write the smallest change that satisfies the task requirements.
- **Build check**: Verify build integrity (Principle I).
- **Test check**: Verify test discipline (Principle II).
- **Review**: Submit `git diff` to a reviewer agent (Principles III & IV).
- **Address feedback**: Fix any blocking issues raised by the reviewer, then re-run gates.
- **Commit**: Only after all three gates pass and review is approved.

Tasks are tracked in `tasks.md`. A task MUST NOT be marked complete until the review
gate has been passed.

## Governance

This constitution supersedes all other practices, habits, or informal agreements within
this project. All contributors — human and AI — MUST comply.

**Amendment procedure**: Amendments require a written rationale, a version bump following
semantic versioning, and an update to this file. The `LAST_AMENDED_DATE` MUST be updated
on every change.

**Versioning policy**:
- MAJOR: Removal or redefinition of an existing principle.
- MINOR: New principle or section added.
- PATCH: Clarifications, wording, or non-semantic refinements.

**Compliance review**: Every implementation plan (`plan.md`) MUST include a Constitution
Check section verifying that the planned approach does not violate any principle before
work begins.

**Version**: 1.3.0 | **Ratified**: 2026-04-20 | **Last Amended**: 2026-10-01
