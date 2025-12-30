# Inbox Micro-Refactor Design

## Goal

Refactor `Inbox.sol` for gas efficiency, fewer lines, and clearer (non-verbose)
comments without changing any behavior, revert order, events, or ABI. No
new tests will be added; existing tests will be relied on for verification
per user direction.

## Design

This refactor is strictly behavior-preserving. The guiding constraint is:
no changes to external interfaces, revert ordering/messages, event emission
order, or state mutation order. The focus is micro-level: reduce redundant
loads, compress trivial blocks, and tighten comments while keeping all logic
intact. The main candidates are `propose`, `prove`,
`_consumeForcedInclusions`, `_dequeueAndProcessForcedInclusions`, and small
view helpers. Planned changes include caching reused values once per scope
(e.g., state fields and computed values), merging simple `if` blocks where it
does not alter side effects, and removing repeated or boilerplate comments in
favor of short, precise statements that explain the “why” rather than
restating the “what.”

Gas wins will come from reduced storage reads, fewer temporary variables, and
shorter execution paths in hot functions (especially `propose`). LOC
reductions will come from eliminating redundant intermediate variables and
consolidating trivial wrappers without changing evaluation order. All changes
must preserve existing `unchecked` scopes and external call placement to
avoid behavior changes. No new custom errors or event changes will be
introduced. The result should be easier to read, easier to audit, and
slightly cheaper to execute, with all invariants and safety checks kept
exactly as they are today.
