# Etna current-rule interleavings design

Direct continuation authorizes one seven-task group after completed Y01–Y07.
The controlling source is the exact SPEC/ACCEPTANCE/SWITCH bundle at
`f556fa94186b0ab604573e8d3a4c4d4fa835dc84`. Historical product scope `2e6763e2`
and every older raw run retain their identities.

## Approach and evidence boundary

Extend verification with small executable finite transition systems for new
rules, rather than silently modifying old pinned models or inventing production
interfaces. Replaying old products would miss changed guards. Waiting for absent
client/contracts would leave modelable interactions unexamined. This selected
approach tests current rule interactions now; current implementation, proof,
cryptography, transaction atomicity and deployment correspondence remain WAITING.
A Python immutable transition models transaction atomicity as a premise; it does
not verify EVM rollback. Cryptographic roots, signatures, finalized L1 and usable
bridge proofs must be explicit authenticated inputs or separately identified
encoding components, never fabricated implementation evidence.

Seven deliverables cover generation-bound schedules; permanent bond forfeiture;
recovery exclusions/replay; canonical positional snapshots; final-R selection;
permissionless origin; and two-chain replacement deadlines. Each needs reachable
positive histories, independently specified full-state observations, omitted-guard
controls, a real baseline/fault/restoration comparison and independent review.
Do not manufacture a protocol defect. Report discovered verification defects
separately. Test success is not a completion percentage or unconditional liveness.

## Common contracts

New Python code lives under `formal/etna/current_rules/`, tests under
`formal/etna/tests/test_current_*.py`. Use standard-library immutable dataclasses
and tuples, explicit call inputs and explicit refusal. No network, keys, signing,
module fetching or external side effects. Reuse only unchanged pure encoding
helpers when required, with their actual source identity recorded. Source labels
must bind all three original document byte streams, not a caller-provided SHA.
The existing source-only obligation ledger, inventories and legacy selectors
remain unchanged; new model evidence is a separate selected-scope artifact.

The finite explorer visits all reachable states for its declared action bank,
checks every accepted edge and records refusal reasons and shortest witnesses.
An exhausted bounded graph is distinguished from a state cap, exception or
missing witness. A cap or missing control is INCONCLUSIVE, never PASS. Report
actual bounds, premises, explored edges and source identities. Keep event results
on edges, avoiding an unbounded event-history variable. No silent fairness or
protocol liveness claim follows from a progress witness.

## Special source constraints

Rollback increments recoveryNonce but retains generation. Generation-matching
schedule calls can still execute after rollback. A successful recover does not
reserve a committee; only final R snapshot selects it, and an empty eligible set
may prevent signing even when count is nonzero. Local fork configuration is a
node trust check; do not falsely add it to the guest's narrower checks. A valid
replacement acknowledgment can coexist temporarily with split L1/L2 configuration;
a missed phase-B deadline leaves signing closed, without guaranteed migration.

## Scope limits

No production/SPEC/Notion edits, live operations, private keys, fresh signatures,
new dependencies, merge, ready conversion, or automatic eighth task. Continue the
existing draft branch and hourly feedback-first checks. Verify/review before
normal push. Preserve the worktree, private ledgers and raw evidence while the
PR is open. Actual zero-evidence/import/runtime/guest/resource and public-history
obligations remain open; this group concentrates on recovery and switching state
machines rather than representing those missing integrations.
