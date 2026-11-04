# Etna design verification

The current authorities are `SPEC.md`, `ACCEPTANCE.md`, `ANCHORLESS.md` and `SWITCH.md`
under `packages/protocol/docs/etna`, pinned to main
`1135c9b24fd03f50cb48eab250879435fd54f528` (2026-11-03).

This package proves conditional decoded-design safety. Exact claims live in
`EtnaStatements/Current.lean`, with composition in `EtnaProofs/Headline/Current.lean`.
The [round-five review report](reports/review-round-five.md) records the latest feedback,
proofs and remaining boundaries; [latest alignment](reports/latest-design-alignment.md)
records validation. Production conformance, liveness and launch acceptance are separate.

## Current safety contracts

H1 derives one retained header/parent chain for all Etna signals, reachable authenticated
roots, actual execution-time landing suffixes, one-shot origin writing and start freezing.
Ordinary Unzen proofs must strictly advance proposals and match their decoded boundary
parent to the stored finalized hash. The upstream header-extension primitive then derives
a monotone legacy frontier and strict separation of the legacy and Etna signals emitted by this modeled execution.
H1 also exports `SwitchingFence`: after a first Etna landing, retained legacy heights
are at or below the current start S and Etna heights are above S. The Unzen lane starts
with no legacy signals, zero finalized/checkpoint data and the configured nextProposal;
pre-deployment SignalService checkpoints are not represented.
Unzen proposal creation/DAO recovery and actual Unzen guest execution remain external.

H2 separates general historical identity/funding from normal at-risk accountability.
For an entire execution with no rollback since fresh deployment, and a physical candidate
chain above the current checkpoint whose checkpoint hash
matches the node's actual Inbox checkpoint, it derives snapshot monotonicity, the selection
cutoff bound, an issued/live/unconfirmed bond for every quorum-overlap member, and retention for the configured evidence window. **The deployment must separately
ensure a positive evidence window no longer than the immutable withdrawal delay
(PARAM-11-11).** This is an explicit deployment premise, not a contract initialization
check or a derived parameter choice. Bond status and snapshot/cutoff inequalities are
derived. H2 also exports retention of every member of a valid authenticated candidate
committee, independent of a particular overlap or round. Within the window, a liability has already exhausted its principal
or has an executable funded slash. The proof does not promise new collateral after a
previous punishment. Cross-round agreement additionally requires the declared honest
locking/minority, signature attribution and codec assumptions.

Exceptional verifier-failure rollback is outside that normal retention result. As
RECOV-8-35 states, money already withdrawn using a bad checkpoint cannot be recovered.
A regression constructs that loss and rejects treating it as normal execution.
There is no restart theorem after a rollback; the normal guarantee then remains
inapplicable for that deployment. The normal result covers heights above the actual
checkpoint only. Historical liability also does not assert that legitimately withdrawn old stake remains
escrowed forever. Temporal agreement uses an actual closed common cutoff in one generation.

H3 derives exact FIFO intervals from complete closed journals, due-only skipping, early
position-zero inclusion from the complete decoded transaction list, actual proof-image
support for every selected ruleset, exact positive fees/refunds and pending recovery bounds.
Ordinary recovery preserves the checkpoint/records/head and constructs its exact new origin.
Import closes readiness/trust, preserves signing state and installs the full original-
generation numeric header interval. Actual EL header contents/indexes, earlier ancestor
context and stock stores required by SPEC 5.4 remain an explicit abstraction gap.

## Reference and archive authority

Reference hashes bind the complete supplied closed L1 prefix, including Inbox balances.
A certificate's archive is a hash-bound physical parent chain from the authenticated
origin through its actual batch parent and actual blocks. Its anchors and derived selection
snapshot cannot exceed the reference. The obsolete `archiveAuthenticated` field is removed; concrete conditions are
mandatory for certificates and node replay.

The semantic certificate still requires complete origin-to-parent ancestry. This is a
stronger input domain than PROOF-6.2-13's at-most-L+2 historical-header guest budget. A
bounded ordinary decision-window extraction is checked separately; no theorem yet refines
the complete accepted-certificate interpreter to an L+2-only guest. That implementation
and completeness gap remains deferred, including separate L1 ancestry/recovery material.

Pure `Certifies` uses only that immutable reference view. General transport theorems prove
reuse under equal statements and bound prefixes. Applying it to a live World additionally
uses a storage footprint (configuration, parameters, start and closed registry prefix)
that is now derived from actual deployment history and the pure certificate's generation
binding. It is absent from `ImageCertifies` and from verifier soundness. Raw `Trace ∧ land`
alone is insufficient: an unsound verifier can accept a stale pre-recovery reference. The
operational theorem therefore uses pure verifier soundness, actual trace and fresh registry
provenance, then derives the footprint, committees and per-block validation. Equality of a statement alone does not grant arbitrary live-world compatibility.
Tests close a later changed block and exercise actual `take` truncation, as well as reachable
rollback followed by another accepted landing.

## DAO upgrade and deployment scope

`Trace` specifies admissible decoded operations. `correctStart` and verifier rollback
represent DAO implementation upgrades, not public Solidity functions that can read the
ghost fields `everLanded` or `activeSnapshots`. `Governance.DeployedTrace` exposes raw
upgrade execution; a separate **per-history** `AuthorizedUpgrades` condition records the
historical correction/restore duties. `Headlines.deployed_claims` derives initialized
endpoint claims through that explicit refinement. Owner identity alone is insufficient.
It does not authenticate the complete last-trusted-before-first-bad target-selection policy.

The main profile starts with raw empty `RegistryMachine.Genesis`. It does not cover the
existing-registry retarget opening in START-10-16a. Seeded identity/funding preservation
helpers accept a separately verified nonempty opening; they do not create its historical
provenance or prove that deployment procedure.

## Joint-premise realizations

All fifteen primitive/deployment premises hold together in independently checked profiles.
Their restrictions are part of the evidence, not production implementations:

| Profile                       | Nonempty conclusion                                                                                                                            | Deliberate restrictions                                                                                                                                                                                                                                                   |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NonVacuity.Current`          | Paid registration/FI, accepted landing, recovery then generation-1 landing, reachable rollback then landing                                    | One funded key, ruleset 0/image 11, two static statement templates and two authenticated votes; Unzen/import adapters refuse; base engine is not honest. It does not positively exercise conflicting quorums, agreement or import.                                        |
| `NonVacuity.CurrentSwitch`    | Actual legacy proof, recovery into generation 1 before the first Etna landing, disjoint legacy/Etna checkpoints and paid FI advancement        | Fixed upstream proposal set and one legacy proof; `UnzenExtension` has no true antecedent in this profile; one static Etna statement/image, ruleset 0; import refuses and base engine is not honest. No running Unzen implementation or complete switch rehearsal.        |
| `NonVacuity.CurrentRisk`      | Real paid stake and conflicting quorums above the genesis checkpoint; at-risk overlap and successful decoded import with readiness/trust false | L1 proofs and EL catalogue refuse; Byzantine engine; fixed key/votes/parameters. Import adapter accepts decoded authenticated flags; only numeric header publication is represented. It does not demonstrate EL landing, post-landing snapshot derivation or real stores. |
| `NonVacuity.CurrentAgreement` | All fifteen premises, honest locking/attribution/minority, and agreement of a nonempty valid chain with itself                                 | Same restricted base environment; separate all-honest single-value round-0 engine. It is a decoded execution normalization, not a production CometBFT refinement; no distinct chain inputs or later-round unlock is positively exercised.                                 |

Header/state/prefix commitments in these profiles have globally injective structural Nat
interpretations. They are ideal models, not fixed-width Keccak implementations. Their
verifiers are fixed functions of proof inputs/statements, with global reachable-world
soundness proofs. No verifier is an oracle for a desired World or headline outcome.
All positive accepted certificate fixtures use empty prebatch `prior` lists. None
positively exercises a nonempty archive prefix or ordinary L+2 cutoff selection.
The accepting, switching, equivocation, import and honest-agreement contracts are mandatory
audit obligations. Finite ordinary fixtures using fewer premises are not substitutes.

## Exact traceability and deferred scope

`rule-coverage.json` names each reviewed rule/theorem edge. Shared paragraphs do not give
neighboring rules evidence. Supporting guards are separate; generic conservation, list,
encoding and transport helpers have no protocol source credit. A narrow partial fragment
never verifies the entire rule.

The current inventory is **38 partial / 528 deferred clauses**, and **41 narrow partial /
35 supporting / 527 deferred binding rules**, plus 32 deferred assumption/limitation rows.
SWITCH has narrow first-fence/root evidence. All 93 current ANCHORLESS and 45 ACCEPTANCE
clauses remain deferred. Margin arithmetic, bridge resolver/EIP-4788/storage migration,
production parsing/crypto/EL/guest/token/Solidity/Comet/store refinement, operational
availability, measured resources and full launch/switch/recovery acceptance remain separate.

Historical `Etna.Design` results outside `Current`, their 1,216 unchanged contract records
and eight conformance files use the archived 2026-10-30 authorities. They do not establish
current conformance. New executable displacement vectors are separately generated into
`testdata/etna_current_conformance`; current implementation harness adoption is not claimed.

## Verification

Use pinned Lean 4.35.0-rc4, Init/Std only. From `formal/etna`, run serially:

```sh
python3 scripts/lint_sources.py
python3 scripts/check_imports.py
python3 scripts/check_spec_coverage.py
python3 scripts/rule_coverage.py --check
lake build
python3 scripts/check_vectors.py
python3 scripts/check_current_vectors.py
python3 scripts/generate_artifacts.py
python3 scripts/generate_artifacts.py --check
python3 scripts/audit_proofs.py
python3 -m unittest discover -s tests -v
```

The audit checks exact types, mechanical roles, allowed transitive axioms, premise use,
mandatory joint-premise profiles and fresh whole-kernel replay. CI checks pins before
building and has a 90-minute job budget. Local results and hosted CI outcomes are reported
separately in the latest alignment; the previous 504-test local pass was not hosted success.
