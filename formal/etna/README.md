# Etna design verification

The current authorities are `SPEC.md`, `ACCEPTANCE.md`, `ANCHORLESS.md` and `SWITCH.md`
under `packages/protocol/docs/etna`, pinned to main commit
`1135c9b24fd03f50cb48eab250879435fd54f528` (2026-11-03).

The current result concerns conditional decoded-design safety. It does not establish
production conformance, liveness, measured capacity or launch readiness. Read the exact
claims in `EtnaStatements/Current.lean`, their primitive premise record, and the composition
in `EtnaProofs/Headline/Current.lean`; [latest alignment](reports/latest-design-alignment.md)
records the specific evidence and remaining boundaries. The [review disposition](reports/current-review-corrections.md)
addresses each supplied critical, important and minor finding.

## Current evidence

The closed machine in `EtnaModel/CurrentProtocol.lean` defines actual calls, failed-call
rollback and complete closed L1 snapshots. Its traces receive no caller-supplied custody,
slashability or queue-service conclusion. Current proofs address:

- Custody of retained checkpoints and signals, a common retained parent chain, exact Unzen
  first-fence evidence, start freezing, and checkpoint-associated rollback snapshots.
- Actual issued-bond committee provenance, principal/token accounting, historical evidence
  retention, and conditional same-round accountability and cross-round chain agreement.
- Exact FIFO service, complete decoded payload position-zero binding, due-qualified skips,
  nondue inclusion, head bounds, pending recovery indices, and atomic admission fees/refunds.
- Complete original-generation header-number intervals, closed trust/readiness and preserved
  signer anti-double-sign state. The importer does not represent the actual original EL
  header contents, execution indexes or complete stock-store installation required by SPEC 5.4.

Reference commitments cover the supplied complete closed L1 prefix. Current proof-image
certificates name the rulesets implemented by the actual declared image; each decoded block
selects its own anchored ruleset. A batch may cross a ruleset timestamp boundary. A declared
image missing any selected ruleset cannot certify that complete batch under the soundness
contract. This is a guest/refinement obligation, not a claim that L1 decodes the batch.

The complete decoded execution transaction list is passed to the selected fixed payload
adapter, and the FI inclusion field equals that list's head. Canonical EIP-2718 parsing,
raw body decoding, hash/signature authentication, singleton full-budget execution and
pinned EL/Comet implementations remain explicit refinement boundaries. The byte predicates
are relative to those fixed interpreters; finite test adapters do not prove their
production implementations correct.

Unknown DAO-installed code, supported-image availability, raw MPT/KZG/crypto decoders,
node-engine refinement, outage/recovery loss bounds and operational acceptance measurements
remain outside these conditional claims. Honest-round/minority assumptions apply to the
agreement conclusion; H1 and H3 do not acquire committee-honesty assumptions.

## Accepting realization of all current premises

`Etna.Design.Current.Protocol.NonVacuity.accepting_deployment` in
`EtnaWitnesses/NonVacuity/Current.lean` exhibits the complete 13-field current Premises
record together with a reachable successful landing that advances the FI head. The trace
contains an actual registered and funded bond and nonzero admission fees. Its state-root
encoding is injective over the full decoded `Snapshot` type, and its verifier soundness is
proved for every reachable World, not inferred from a finite accepted fixture.

This is a restricted new-network interpretation: the verifier accepts only the declared
image and two fixed certified statement templates. It establishes joint satisfiability of the
current primitive assumptions and nonempty service. It does not realize a switching
network, arbitrary rulesets/verifiers or production cryptography and EL implementations.
The same complete-premise environment also witnesses a successful landing followed by
recovery and a generation-1 successful landing, and a rollback followed by another landing.

## Exact traceability

[Rule traceability](reports/rule-coverage.md) inventories every live rule ID. Schema 2 in
`rule-coverage.json` names each reviewed rule-to-theorem edge explicitly. Shared source
paragraphs do not give evidence to neighboring rules. A `partial` row is a narrow derived
property or constant, never proof of the entire rule. A `supporting` row exposes a guard or
projection separately. Generic list/arithmetic/encoding plumbing carries no protocol source
edge, even if its mechanical theorem role is `property`.

The clause inventory contains 315 SPEC clauses and **251 clauses in the other three
in-repository authorities**: 113 in SWITCH, 93 in ANCHORLESS and 45 in ACCEPTANCE. The
review's 251-clause concern is valid. SWITCH has only narrow direct evidence for the
decoded accepted first fence and authenticated custody root at lines 117–128. Its proposal
and FI margin arithmetic, off-chain originWriter/node duties, bridge migration and complete
switch procedure remain deferred. All 93 current ANCHORLESS clauses and all 45 ACCEPTANCE
clauses remain deferred: the current proof does not establish the bridge root resolver,
EIP-4788 writes/cache/storage migration, deployment ordering, measured resources, real guest
performance, launch gates or operational switch/recovery rehearsal. These counts describe
an inventory, not a verification percentage.

External normative dependencies, including the adopted zk-gas revision, CometBFT and
Ethereum data formats, additionally remain implementation/refinement boundaries. The
header-number importer is also an abstraction gap relative to SPEC 5.4's authenticated
original EL headers, installed indexes and full stock stores; proving its numeric range
does not implement those contents or stores.

## Historical results

The original machine, theorem contracts, seven-premise headlines and JSON conformance
vectors are retained against the independently pinned `legacy/2026-10-30` authorities.
They do not establish current conformance. Historical reports are labelled at their entry
point; their use of “current” refers to the historical baseline named in that report.
See [historical verification](reports/historical-verification.md) and the
[historical rule map](reports/historical-rule-coverage.md).

## Verification

Use the exact compiler in `lean-toolchain`: Lean 4.35.0-rc4, Init/Std only. From `formal/etna`:

```sh
python3 scripts/lint_sources.py
python3 scripts/check_imports.py
python3 scripts/check_spec_coverage.py
python3 scripts/rule_coverage.py --check
lake build
python3 scripts/check_vectors.py
python3 scripts/generate_artifacts.py
python3 scripts/generate_artifacts.py --check
python3 scripts/audit_proofs.py
python3 -m unittest discover -s tests -v
```

Run builds/audits and the Python suite serially because they use shared compiled artifacts.
The audit checks exact current and historical theorem types, mechanically computed roles,
transitive axioms, premise use, library placement and fresh whole-kernel replay. Authority
pins and exact rule evidence are checked before the expensive CI build. A changed exact
contract must be reviewed and re-exported; no numerical pass total in an older report
substitutes for running these commands on the final tree.
