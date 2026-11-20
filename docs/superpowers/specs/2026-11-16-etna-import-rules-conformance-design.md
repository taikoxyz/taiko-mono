# Etna third five-increment design

User authorizes exactly five further verification increments with model and real
code work in parallel. Continue autonomously under the previous workflow; stop
on an independently supported protocol/specification/production implementation
issue for user confirmation. Repair and separately classify model/assertion/
exporter/adapter problems. No sixth increment before retrospective.

## Authority, preservation and scope

Normative SPEC commit d18357214fab30ea512ae9858a11699806d72ba1,
blob649548c58d6629dd85143b33efd3644a3bb71509; current main SPEC content was
refreshed2026-11-16 and remains identical. Contract implementation pin
89f419915de4b73bb57c53bf970f6dea9e8e8c8c and its564-file selected inventory
remain authoritative for concrete replay. Existing local baseline is
7f1f6f52ed97138f786cdd0da96f8f96d239d3a8 on codex/etna-tla-settlement.
Preserve212 existing default configs, prior module/checker semantics and all19
historical incomplete configs. Reuse formal/etna and the existing isolated
worktree; no new project or worktree.

This batch adds two thin models and three real-contract replay suites. It is
finite evidence on pinned revisions, not full model composition, universal
refinement, weighted consensus, actual zkVM cryptography or live deployment.
Current code has no concrete importer or corrective rollback migration API;
those stay explicit implementation GAPs. No production behavior is modified.

## M10-A: authenticated import transaction and admission

Build a thin standalone import module. Literal EXTENDS of EtnaL1Trust cannot
represent two non-origin checkpoints in the same generation under its fixed
snapshot table; EtnaAppCrash assumes an initially empty generation. Preserve
both and document interface correspondence rather than silently refactoring or
claiming composition. Use fixed origin o=2, retained import s=4, latest target
4 or6; a separate s=o profile follows genesis. A newer authenticated generation
may invalidate admission.

Represent independent raw L1 records, candidate header/envelope/EL state and
validator preimage components, not enums that predetermine verdict. Bad candidate
hashes reject; missing data waits; contradictions after authentication halt.
Durably stage separate EL/app/Comet/evidence stores with signer disconnected,
then publish one completed installation. Compare actual store identities/content
and publication receipts against separately captured expected data; ready flags
alone are insufficient. Crashes cannot expose partly aligned stores. Preserve
fixed genesis identity, HRS, landed priorities/proposers, FI cursor, required fixed
ancestor/evidence sets and AppHash=EL(s), not header(s).AppHash=EL(s-1).
Completion does not grant trust/signing; older s must normally continue to the
latest target. Cryptography, exact stock window-minimality/evidence arithmetic,
actual importer/EL indexes and post-import full ABCI execution are out of scope.

## C04: close literal displaced/withdrawn recovery profiles

Export actual frozen M08 PublicAttempt records for Displaced and Withdrawn,
Unheld and Mixed requests, each with None/SecondRegistry failure:8 attempts.
Construct source-valid switching history only through public APIs. Use old
registration eff3 units at block87, top-up1 at92 (ready97), exit93,
4095 filler bonds of5 units and replacement5 at93, init95/cutoff94,
50% forfeiture at95 yielding eff1/pending1, confirm95, origin97.
Withdrawn calls actual withdraw at98 after delay3, before FI enqueue98/99.
Keep time monotone. Preserve exact93/95/97 metadata rather than relabel it.
Token unit MIN_STAKE; fee unit1gwei; symbolic ids0/1/2 map0/4096/4097 and
selected slot0; subtract explicitly inventoried filler custody only from the
projected vault while independently checking filler/actual custody preservation.

Switching requires S>0: choose S=6 and map all L2 heights H(q)=S+6q,
including origin/authorization/checkpoint/retained parents. Stop-grid quantities
are offsets/multiples, not H(q). Use T(t)=1200\*t for Unix timestamps as in C03,
leaving L1 blocks/nonces/exits/ready/confirmation unscaled. Actual legacy Unzen
finalization is a disclosed test-premise boundary, not a fake Etna registry state.
Verify all mapped public pre/post fields, actual withdrawal/confirmation effects,
key lifetime/forfeiture/replacement and reverting atomicity. Abstract callback
coverage remains a GAP; this task closes only the two literal profile gaps.

## M11-A and C05: rule schedule and observation boundary

M11 has one authoritative public L1 schedule action implementation and exports
raw PublicAttempt receipts for C05. Wrap actual existing settlement Recover
where feasible; avoid creating a duplicate registry/FI engine. Public schedule
receipts include before/after five fields, operation/original arguments, L1 time,
caller/init/registry-lock context, return outcome, packed event and relevant
recovery counters/origin. Operational predicates never consult observation data.
Keep L1 clock/slot293 history separate from candidate L2 timestamp and valid
carried/inherited anchor. Choose at least two historical schedules. L2 selection
uses the anchor's schedule and candidate timestamp; planned stop uses parent
height/time and original S. Unsupported rules wait/refuse, then resume after
support, never silently choosing latest L1 schedule.

Check strict notice-lock equality, earliest allowed time, equal-rule reschedule,
max48 cancellation, stop zero/correct grid, failed promotion atomicity, rules0
recovery preserving pending fields/clearing stop, and nonzero recovery choosing
exactly nextRules+1. Initial Unzen migration and structural K-upgrade code are
separate scopes. Sparse finite time domains must not enumerate the uint48 range.

C05 consumes actual M11 public execution, not Python copies of its guards. Map
normalized maxAnchorAge=1 exactly to physical1152 and normal timestamps with
an explicit affine map using scale1152; map stored zero sentinel to0 and the
cancellation sentinel to actual uint48 max separately. A scale1200 would mask
strict equality against actual maxAnchorAge1152 and is not acceptable here.
Compare real scheduleRules/scheduleStop/recover outcomes, raw five-field storage,
selected RulesScheduleUpdated event and failed-call unchanged state. L2 ruleset
installation has no Solidity API and remains model-only. Supplement actual ABI/
48-bit boundary checks explicitly as concrete cases rather than pretend they
came from a tiny model.

## C06: responsibility-aware landing identity replay

Export finite actual EtnaCheckpointIdentity action outcomes/records, keeping its
existing source unchanged. Include compatible overlap/divergent suffix,
EL/Comet/FI/Val frontier mismatches, leaf-count/range/origin checks and fixed
recovery-origin reuse. Separate contract frontier/origin validation from proof
binding: frontier-negative tests configure the verifier to accept the supplied
candidate statement, so an unrelated proof rejection cannot hide a missing
Solidity guard. Assert exact frontier rejection stage. Statement-binding tests
instead retain the original approved statement and demonstrate verifier failure
for mutation; label them integration under a mock, not actual STF/circuit proofs.
Public historical parentVal remains distinct from fresh genesis execution state.
Check complete selected before/after retained records, counter/origin and queue
state, actual success and exact failed-call atomicity. No assumption that every
identity condition belongs in Solidity rather than the guest.

## Workflow and finish

Root owns design/plan/shared reports/worklist and final verdict. New model files,
configs/module docs belong to model owner; each replay's exporter/fixtures/tests
belong to its code owner. Independent adversarial review and independent behavior
challenges gate each task, at most two coherent fix waves. Root may run focused
TLC and select actual Forge mutants through the dedicated Solidity tester.
Keep proofs/normal searches, negative controls, code replay, mocks and unavailable
checks separate. Preserve exact incomplete larger candidates before changing
workloads. Setup alone is not completion. A final accumulated stable-input TLC
suite and focused code/adapter checks conclude the batch; stop after five.
