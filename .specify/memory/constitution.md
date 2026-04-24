<!--
SYNC IMPACT REPORT
==================
Version change: 0.0.0 → 1.1.0
Added sections:
  - I. Build Integrity (new)
  - II. Test Discipline (new)
  - III. Peer Review Before Commit (new)
  - IV. Task Completion Gate (new)
  - V. SwiftUI-First (new)
  - Quality Gates (new)
  - Development Workflow (new)
  - Governance (updated from template)
Removed sections: none (initial creation from template)
Templates requiring updates:
  ✅ .specify/memory/constitution.md — this file
  ✅ .specify/templates/plan-template.md — Constitution Check section covers build/test/review gates
  ✅ .specify/templates/tasks-template.md — task completion discipline aligns with Principle IV
  ✅ .specify/templates/spec-template.md — no structural changes required
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

**Rationale**: Tests document intended behaviour. A passing build with failing tests means
the code compiles but does not behave correctly. Both gates MUST be green together.

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
3. A reviewer agent reviews `git diff` (staged + unstaged) and provides sign-off.

Skipping or reordering these gates is a constitution violation and the commit MUST NOT
proceed.

Before implementation work begins, the following planning gate MUST also be satisfied:

4. A reviewer agent reviews `plan.md` (with `spec.md`, `research.md`, `data-model.md`) and returns an explicit **APPROVED** verdict (Principle VI).

## Development Workflow

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

**Version**: 1.1.0 | **Ratified**: 2026-04-20 | **Last Amended**: 2026-04-24
