# Specification Quality Checklist: Distance Travelled and Remaining Along the GPX Track

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-01
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Validation pass 1: all items pass. No clarification markers were needed; defaults chosen for
  units (km, two decimals), labels ("Done"/"Left"), the 30 m candidate radius, segment gaps
  (counted), and the meaning of "available height" (full screen height, matching feature 005
  FR-009) are recorded in Assumptions.
- Review round 1 (independent reviewer): BLOCKED. Fixed:
  - B1: candidates are now one point per pass (superseded in round 2).
  - B2: FR-004b adds a travel-direction filter and a tie-break, and US2-AS5 covers turning round early (superseded in round 2).
  - B3: FR-004a does not lock in while off track, US2-AS6 covers this (the off-track rule was later replaced by the user's decision, see round 2).
  - B4: digit minimum lowered to 25% of band height, one decimal from 100 km, smaller unit and labels allowed.
  - Also addressed: N1 (FR-013 restores progress on relaunch), N2/N3 (FR-010 and edge cases), N4 (US2-AS7),
    N5 (SC-003), N6 (FR-002), N7 (FR-006).
- Constitution Principle VII: an independent reviewer must return **APPROVED** before `/speckit-plan`.
- Review round 2: BLOCKED (B1': stretches that double back inside the radius gave one candidate; B2': the direction filter
  needed the 3 km/h Moving state). Resolved by making FR-004 behavioural (FR-004a–e), adding US2-AS8 (slow walk) and
  US2-AS9 (short backtrack), loosening US2-AS5 and raising the SC-003 limit to 60 m. Also recorded: N3 (second lap) in the
  edge cases. The user decided the off-track rule (FR-004d).
- Review round 3: BLOCKED. B1: FR-004d needed a rule for before progress is established (now the earliest pass). B2: the second-lap edge
  case contradicted FR-004a (fixed by adding FR-004f, which keeps progress finished). Also: defined "Near the user" and "Finished",
  gave the FR-004c grey zone limits (20 m / 200 m), and added an exception to SC-003 for the turnaround switch.
- Review round 4: BLOCKED. B1: FR-004f could lock as finished before the user had followed the track. Fixed by
  tightening "Finished" (established, previous position within 200 m of the end, on the track) and adding US2-AS10 (track
  loaded near its finish). N1–N3 applied (SC-003 wording, SC-002 turnaround exemption, loop shortcut edge case).
- Review round 5: BLOCKED. B1: the 20 m variant of US2-AS10 still finished early. Fixed: Finished now also requires that
  progress was once established more than 200 m before the end (half the length for short tracks). FR-013 saves that flag.
- Review round 6: **APPROVED** (Constitution Principle VII gate passed). Optional wording tweaks for Finished and FR-013 applied.
