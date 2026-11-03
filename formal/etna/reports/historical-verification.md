# Historical verification before the 2026-11-03 alignment

> **Historical report.** This document describes the original model and the baseline identified below. Any use of “current” refers to that historical baseline. For the current `Etna.Design.Current` claims and evidence, read the [current scope](../README.md) and [latest alignment](latest-design-alignment.md).

This report describes only the archived authorities in `legacy/2026-10-30`.
See [current scope](../README.md) and [alignment evidence](latest-design-alignment.md).

# Etna design verification

This package is a Lean 4 model of the Etna specification and the proofs about it. The
specification is [`packages/protocol/docs/etna/SPEC.md`](../../packages/protocol/docs/etna/SPEC.md)
at commit `b7ca989c8e343073daa628771102bdee7fe7101b` (2026-10-30). Both it and
[`ACCEPTANCE.md`](../../packages/protocol/docs/etna/ACCEPTANCE.md) are independently
pinned by path, revision, source commit and SHA-256 in `spec-coverage.json`. The pin and the clauses
cover the text with the rule-reference markers removed (`**[ID]**` prefixes and `// [ID]` lines, see
[`rules/README.md`](../../packages/protocol/docs/etna/rules/README.md)), and a spec line written
`spec L…` is a line of that marker-free text. Any edit to the spec fails the coverage check until the clause links are
reviewed against the new text and the pin is updated.

**The result is three headline theorems**, fund safety, accountable finality and
forced-inclusion integrity, each proved for every deployment and environment that satisfy one
premise record, `Premises`. To trust the result, read the statements and the premises
(`EtnaStatements/`) and the model definitions they use (`EtnaModel/`); the Lean kernel checks the
proofs. The package says nothing about the production contracts, client or guests beyond the
conformance vectors below.

The clause inventory (405 source clauses: 313 SPEC/ACCEPTANCE plus 92 independently pinned
ANCHORLESS clauses), the theorem roles and the 34 narrow claims in
`spec-coverage.json` are a **traceability report, not the verification result**. They record
which spec clauses some theorem speaks to, and CI keeps them consistent. A clause marked
partial is not proved. [`reports/rule-coverage.md`](rule-coverage.md) keys the same
evidence by the stable rule IDs of `packages/protocol/docs/etna/rules/INDEX.md`; where several
rule IDs share one cited clause, a reviewed narrowing keeps only the rules some theorem
statement speaks to. Without a narrowing, every rule of a clause lists every theorem that cites
the clause: FI-7.3-1 and FI-7.3-2 both list H3 and `honest_anchor_chain_sees_due`, although H3
does not claim the 7.3 bound and the chain theorem speaks only to it.

## The headline theorems

`EtnaProofs/Headline/` proves, in namespace `Etna.Proofs`:

```lean
theorem fund_safety : FundSafety
theorem accountable_finality : AccountableFinality
theorem forced_inclusion_integrity : ForcedInclusionIntegrity
theorem claims : Claims   -- Claims := FundSafety ∧ AccountableFinality ∧ ForcedInclusionIntegrity
```

The audit requires each type to be exactly the claim constant (nothing unfolded, added or
dropped) and the axioms to be `propext`, `Classical.choice` and `Quot.sound` only. The claims
are stated in `EtnaStatements/Claims.lean` (copied verbatim below) with these terms:

- `Environment` (`EtnaStatements/Environment.lean`): everything outside the L1 contracts, fixed
  once per deployment. It holds the eight guest relations that `Deployment.build` takes (vote
  signatures, anchor, committee, forced-inclusion (FI) witness and history authentication, EL
  execution, payload and blob decoding), `headerHash` (the EL hash of a decoded header),
  `genesisHeader` (block 0's header) and `submits` (the `land` calls landers make).
- `ProtocolState.Trace w0 w`: any sequence of protocol steps: landings, registrations, registry
  edits, FI enqueues, fee sweeps, governance recoveries and verifier-failure rollbacks.
- `Run env w0 w`: a trace in which every landing is one that `env` submits. The claims that need
  the verifier (fund safety and the consumption part of forced-inclusion integrity) range over
  runs; the others range over all traces. A verifier premise over every trace could never hold:
  `land` accepts any two accepting proofs, so some trace lands a statement no valid batch has.
  Runs differ from traces only in which landings `env` submits: every run is a trace
  (`run_trace`), and `Run`'s side condition on other steps excludes nothing — for an
  environment that submitted every landing `land` accepts on a reachable World, every trace
  from the initialized World would be a run (`trace_run`). No environment satisfying the
  verifier premise submits all of them, so this does not extend the run-based claims to every
  trace.
- `Built env w r`: `r` is a rule set that `Deployment.build` derives on World `w` from the stored
  configuration and the environment's relations, for some anchor archive and some reference
  block: the definition is existential over both. "Valid" in a claim always means valid under
  such rules, and so under the environment's relations as they are. `Premises` constrains some
  of them (signatures, FI witnesses below an accepted anchor's tail, EL execution, the header
  hash) and leaves `anchorAuthenticated` (which anchors are accepted), the forced-witness flags
  and `singleton` result, `historyAuthenticated`, `committeeAuthenticated`, `payloadValid` and
  `batchPayloadValid` unconstrained: a block is valid under whatever those relations accept, and the theorems hold
  for every choice of them.

### H1, fund safety

```lean
def FundSafety : Prop :=
  ∀ (env : Environment) (w0 : ProtocolState.World), Premises w0 env → ∀ w, Run env w0 w →
    ∃ H : Checkpoint → BlockValidity.Header,
      (∀ child ∈ w.inbox.records, HeaderOf H child ∧
        (child = w0.inbox.checkpoint ∧ H child = env.genesisHeader ∨
          ∃ parent ∈ w.inbox.records, parent.height = child.parent ∧ parent.height < child.height ∧
            Extends env w0 w child.generation (H parent) (H child))) ∧
      ∀ g ∈ w.inbox.signals, ∃ child ∈ w.inbox.records, child.height = g.height ∧ child.elHash = g.hash ∧
        (H child).stateRoot = g.stateRoot
```

Along every run from the initialized World there is a map `H` that gives each landing record
L1 keeps (slot 285) the header of its block (`HeaderOf`: same height, EL hash, CometBFT hash and
FI cursor). Block 0's record gets block 0's header. Every other record has a retained parent
record at a lower height, and blocks valid under the rules built for its generation lead from
exactly the parent's header to exactly its own (`Extends`). Every SignalService checkpoint names
a record, and its state root is that record's header's state root. Following parents ends at
block 0, so every state root L1 recognizes, which withdrawals use, is reached from the genesis
state by consecutive chains of valid blocks, each starting at the very header where the one
before ended. This holds across governance recoveries and across any rollback to a retained
record.

### H2, accountable finality

```lean
def AccountableFinality : Prop :=
  ∀ (env : Environment) (w0 : ProtocolState.World), Premises w0 env →
  ∀ w, ProtocolState.Trace w0 w → ∀ r, Built env w r →
    (∀ h round a b votesA votesB,
      Consensus.CommitValid r.consensus r.signature h round a votesA →
      Consensus.CommitValid r.consensus r.signature h round b votesB → a ≠ b →
      Committee.totalPower r.consensus.unit (Consensus.activeAt r.consensus h).members <
        3*Committee.totalPower r.consensus.unit (signedBoth (Consensus.activeAt r.consensus h).members votesA votesB) ∧
      ∀ m ∈ signedBoth (Consensus.activeAt r.consensus h).members votesA votesB,
        ∃ va ∈ votesA, ∃ vb ∈ votesB, va.key = m.key ∧ vb.key = m.key ∧
          ∃ sigA sigB, Slashable w (Accountability.evidence va) (Accountability.evidence vb) sigA sigB m.key) ∧
    (∀ h round (honest : Hash → Bool),
      (∀ m ∈ (Consensus.activeAt r.consensus h).members, honest m.key = true →
        ¬ Equivocates r.consensus r.signature h round m.key) →
      3*Committee.totalPower r.consensus.unit
          ((Consensus.activeAt r.consensus h).members.filter fun m => !honest m.key) <
        Committee.totalPower r.consensus.unit (Consensus.activeAt r.consensus h).members →
      ∀ a b votesA votesB, Consensus.CommitValid r.consensus r.signature h round a votesA →
        Consensus.CommitValid r.consensus r.signature h round b votesB → a = b)
```

Take any World that a trace reaches from the initialized World, and any rule set built on it.
If two valid commits at the same height and round are for different blocks, the members whose
keys signed both (`signedBoth`) hold more than 1/3 of the active committee's voting power, and
each of them is `Slashable` from then on with one vote from each commit: in every later World,
every live bond with positive remaining principal under that key can be slashed for its
whole balance (effective stake plus pending top-up). Prior DAO forfeiture does not erase
admissible double-sign evidence; only the principal still held can be slashed. So if the members that
sign conflicting precommits at a height and round (`Equivocates`) hold less than 1/3 of the
power, any two valid commits there are for the same block. This is same-round safety only, and
it bites only on bonds that are still live.

### H3, forced-inclusion integrity

```lean
def ForcedInclusionIntegrity : Prop :=
  ∀ (env : Environment) (w0 : ProtocolState.World), Premises w0 env →
    (∀ w t, ProtocolState.Trace w0 w → ProtocolState.Step w t →
      ∀ j entry, (j, entry) ∈ w.queue → (j, entry) ∈ t.queue ∨ Blanks w t j entry) ∧
    (∀ w t, ProtocolState.Trace w0 w → ProtocolState.Step w t →
      t.inbox.checkpoint.height ≤ w.inbox.checkpoint.height → t.inbox.head ≤ w.inbox.head) ∧
    (∀ w i leaves e s, Run env w0 w → env.submits w i leaves e → w.l1Block ≤ e.blockNumber →
      Etna.Design.land w.inbox i leaves e = some s →
      ∃ r q bs, Built env w r ∧ Links r w.inbox.checkpoint s.checkpoint i.lastStateRoot q bs ∧
        q.cursor = w.inbox.head ∧
        (∀ j, w.inbox.head ≤ j → j < s.head → ∃ x ∈ pairs q bs, x.1.cursor = j ∧ x.2.header.cursor = j+1) ∧
        ∀ x ∈ pairs q bs, ServesQueue w r x.1 x.2)
```

The statement has three parts.

- (a) Along every trace, no step removes or changes a queue entry, except that a governance
  recovery can blank an entry its fiToClear lists (`Blanks`: txHash becomes keccak256(""),
  timestamp and L1 block stay).
- (a′) Along every trace, a step that does not advance lastCheckpoint (every step but a
  landing) never advances the FI head.
- (b) For each submitted landing of a run, the landed blocks are valid under the rules built on
  that World and start at the current checkpoint, whose FI cursor is the head. They consume
  every entry in [head, new head), and every block serves the queue (`ServesQueue`): it advances
  the cursor only by a `Forced.step` inclusion or legal skip whose witness shows the World's real
  queue entry, and it consumes the entry at its parent's cursor whenever its anchor shows that
  entry pending and due.

Part (b) covers only blocks inside landed segments, and H3 does not claim the maxAnchorAge bound
of 7.3 (spec L465; see the anchor-honesty theorems below). It judges "pending" and "due" against each block anchor's own tail and
timestamp. `AnchorValid` checks the anchor's Inbox fields only through the environment's
`anchorAuthenticated`, and no premise requires an accepted anchor to report the Inbox's actual tail and timestamp
(`authenticatedInputs` uses it only as an antecedent and binds FI witnesses, not anchor fields),
so part (b) holds relative to the tail and timestamp an accepted anchor reports: the
`AnchorTail` counterexample passes a due entry under an anchor that understates the tail. That
accepted anchors show the Inbox's actual queue is an implementation obligation
([premise responsibilities](premise-responsibilities.md)). Part (a) is about (index, entry) pairs staying present; that each index holds
one entry is the separate queue invariant of `ProtocolState.Core`.

Separate theorems turn that gap into explicit hypotheses, without changing `Premises` or H3.
`EtnaModel/AnchorHonesty.lean` defines them: an L1 clock that never runs backwards and queue
entries that record their enqueue block's timestamp (stand-ins for the L1 clock the model's
steps do not carry; the contract records `block.timestamp`), and accepted anchors that report
their own block's timestamp and count every entry enqueued at or before that block (the guest
obligation). Under them,
`EtnaProofs/Headline/AnchoredQueue.lean` proves:

- `honest_anchor_chain_sees_due` (7.3's bound, spec L465): in every block of a valid chain
  whose rules have a positive FI delay, take the entry at the parent's cursor. If the block's
  timestamp is at least `entry.timestamp + forcedInclusionDelay + maxAnchorAge`, the anchor
  shows that entry pending and due. This is a block-time implication, not a wall-clock deadline.
- `honest_anchor_queue_service` (supporting, like `landing_consumes_queue`): with part (b)'s
  conclusions, every landed block consumes the queue-head entry of the Inbox's actual queue once
  it is due by the anchor's time, and in particular once the bound above holds.

`AnchorHonestyRegression` shows the hypotheses hold together with the premises in the
non-vacuity deployment and exclude `AnchorTail`'s anchor for every clock. No entry becomes due
on that run (FI delay 60 s, maxAnchorAge 1200 s, times below 22), so the due-entry conclusions
are not exercised there. Authenticating
anchors stays a guest obligation.

## Premises

`Premises w0 env` (`EtnaStatements/Premises.lean`) has seven fields. Each constrains only the
initialized World `w0` or the environment, never the records, signals or queue progress the
claims are about. "Used by" is the audit's premise-use result: the headline proofs that read the
field.

| Field                 | What it assumes                                                                                                                                                                                                                                                                                                                                                                               | Spec source                                                                                       | Used by    |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ---------- |
| `genesis`             | `w0` is the World right after Inbox initialization (`Deployment.Genesis`), made with block 0's EL hash and stateRoot from `env.genesisHeader`, which has height 0, CometBFT hash 0 and FI cursor 0.                                                                                                                                                                                           | §10 steps 4-5 (spec L556-L557); Appendix B slot 285 (spec L777); 6.1 (spec L294); 7.2 (spec L426) | H1, H2, H3 |
| `verifierSound`       | Two proofs, at least one sound: every proof pair the Inbox accepts contains a sound backend, and a sound backend approves a submitted landing only if its statement is `Certifies`, i.e. the statement of a batch valid under the rules `Deployment.build` derives from the guest's uint256 opening of the stored commitments. Equivalently: every submitted landing that lands is certified. | §1 "Funds" (spec L12); §1 "Upgrades and trust" (spec L16); §8 "Verifier failure" (spec L487)      | H1, H3     |
| `authenticatedInputs` | For a submitted landing that lands, an authenticated FI witness for an index below the anchor's tail, under an authenticated anchor from the current generation's origin L1 block up to the landing's block, shows the World's real queue entry. It constrains no anchor field.                                                                                                               | 3.3 (spec L90); 7.2 (spec L427)                                                                   | H3         |
| `hashSeparation`      | The stored committeeConfigHash has exactly one uint256 opening (`Representable`): the deployment's own configuration.                                                                                                                                                                                                                                                                         | 6.2 item 1 (spec L360)                                                                            | H1, H3     |
| `headerHashes`        | An EL hash is the hash of the header it names: when the EL accepts a block on a parent, both EL hashes are `headerHash` of the decoded headers, and so is block 0's.                                                                                                                                                                                                                          | 3.4 rules 1 and 9 (spec L104, L112); 6.2 item 4 (spec L363)                                       | H1         |
| `headerSeparation`    | Collision resistance, idealized: equal EL hashes mean equal height, stateRoot, timestamp and the whole decoded anchor.                                                                                                                                                                                                                                                                        | 3.2 (spec L72, L76-L80); 6.2 item 4 (spec L363)                                                   | H1         |
| `signatureAgreement`  | The registry's signature check accepts every vote in this deployment's domain that the consensus signature relation accepts.                                                                                                                                                                                                                                                                  | 3.1 (spec L43); 4.1 (spec L160)                                                                   | H2         |

The audit fails if any field is read by no headline proof.

[Premise responsibilities](premise-responsibilities.md) classifies each field into
external primitive/dependency trust and Etna-owned implementation contracts. Mixed fields retain
both responsibilities; the classification changes no field or claim type.

## What is not covered

- **Liveness.** No claim says a block, a landing or a due FI entry ever happens (§1 "Liveness",
  spec L14).
- **Deployed CometBFT refinement.** H2 remains a same-round statement. The separate
  `Locking.commitValid_agreement` now derives cross-round design safety from decoded
  prevote/PoLC/lock transitions and weighted quorum intersection. Relating the actual engine,
  signatures and nonnil commit decoding to that interface remains external. The original
  `height_agreement`/`CrossRoundAccountable` contracts remain unchanged. Cross-round faults
  do not acquire automatic slashing (§1 "Slashing scope", spec L18).
- **Checkpoint permanence across rollback.** Along traces without verifier-failure rollback,
  the records at or below the starting checkpoint never change and SignalService checkpoints
  are only appended (`ordinary_trace_preserves_settled_records`, `ordinary_trace_signals_prefix`);
  governance recovery keeps the settled prefix. The model's verifier-failure rollback may return
  to any retained record, and H1 holds across it; that a DAO upgrade is the only such exception
  (spec L13) is a governance promise, not a theorem.
- **The bridge.** H1 ends at SignalService state roots. That the Bridge pays only against them
  (storage proofs, QuotaManager, pausing) is not modelled.
- **What happens after verifier failure.** Without `verifierSound` nothing is claimed
  (`NoVerifierSoundness` shows the premise is needed). The containment of §8 (pausing, the
  rollback upgrade restoring the last trusted values) is not enforced by the model: its rollback
  step takes any retained record and any slot-284 snapshot. `confirmed_key_absent_above_checkpoint` excludes a confirmed key from the
  committees active at or above lastCheckpoint only under the explicit condition
  `SnapshotTrusted`, on the World where the exit is confirmed; it says nothing about later
  Worlds, withdrawals, commits or slashing. A rollback done as §8 says, using the source-history conditions below, satisfies it (see "Rollback trust" below); pausing and loss containment
  are not modelled.
- **Anchor honesty.** In the original H3/free anchor predicate, nothing proves that an accepted
  anchor reports the Inbox's actual tail and its L1 block's timestamp (`AnchorValid` itself
  checks the generation and bounds the checkpoint height by U); H3's part (b) is relative to
  what it reports (`AnchorTail`). With that honesty as explicit hypotheses,
  `honest_anchor_queue_service` gives part (b) against the actual queue. The supplementary
  `ActualQueue.history_queue_timed`, `ActualQueue.end_block_covers` and
  `ActualQueue.local_chain_byte_service` derive semantic queue timing, end-block tail coverage
  and local include/skip service from original timestamped transaction journals, end-block cuts
  and raw authenticated openings, under their explicit clock and chain assumptions. Real L1
  and storage authentication remain external.
- **Reentrancy.** The model's reentrancy flag `entered` is never set, so no theorem speaks to
  cross-function reentrancy during recovery (RECOV-8.3-19 is deferred); the contracts' own tests
  are the only evidence.
- **A wall-clock FI deadline.** H3 gives none, and §1 says the design gives none either
  (spec L15). H3 does not claim the maxAnchorAge bound of 7.3 (spec L465);
  `honest_anchor_chain_sees_due` proves it, as a block-time implication, under honest anchors.
- **Real cryptography, MPT, KZG and the EL.** Hashes are opaque numbers. Signatures, storage
  proofs, blob decoding, payload decoding and EL execution are relations of `Environment`. The
  premises idealize some of them and leave others open: history and committee authentication
  (`historyAuthenticated`, `committeeAuthenticated`), payload decoding (`payloadValid`) and the
  blob binding (`batchPayloadValid`) are not constrained at all, so "valid" means valid under
  whatever those relations accept, and the theorems hold for every such choice.
  `headerSeparation` assumes collision resistance over the whole decoded anchor, although the
  real EL header carries only the anchor's block number (extraData) and stateRoot
  (parentBeaconBlockRoot); the other anchor fields agree only because both headers read them
  from that authenticated L1 block. `hashSeparation` is Keccak
  separation over uint256 openings (the unbounded `Deployment.opening_unique` is vacuous:
  `opening_separation_unsatisfiable`). Proof completeness (spec L16), complete durable signer and node
  trust (8.2), and PoS issuance and market-economic guarantees remain out of scope. The launch-capital
  arithmetic below is separately checked under supplied valuation and committee inputs.
- **Rollback trust (a dropped premise).** A `trustedRollback` premise was considered: the
  restored slot-284 snapshot is below the rollback's block (`SoundStep.rollback`). No headline
  proof needs it. H1 holds across any rollback to a retained record, because a rollback drops
  the records and signals above one height together. So it was dropped. What it would protect
  is H2's slashability after a rollback: in `UntrustedRollback` a rollback restores a snapshot
  no landing wrote, and the committee confirms its exit and withdraws while it still signs; its
  conflicting commits are then unslashable. Even `snapshot < now` is too weak, since a later
  rollback can restore an untrusted value below its own block. A premise that protects H2 must
  be the spec's duty (spec L487): the restored snapshot is a value a trusted landing or the
  initialization wrote. `SnapshotTrusted` (slot 284 is not ahead of the cutoff of the committee
  active at lastCheckpoint) is the condition `confirmed_key_absent_above_checkpoint` needs, as
  an explicit hypothesis rather than a premise. Within the restored landing's generation, the
  spec's duty implies it (`EtnaProofs/TrustedRollback.lean`). A trusted landing is one whose
  certificate is the statement computed under rules the deployment builds (every `Certifies`
  landing qualifies; later landings may be forged). `trusted_rollback_snapshot_trusted`: a
  rollback that restores the checkpoint and slot 284 such a landing wrote keeps slot 284 equal
  to the cutoff of the committee active at the restored lastCheckpoint, for every context whose
  anchor archive agrees with that landing's below the checkpoint.
  `trusted_landing_values_stay_trusted` carries this to every later World that still shows those
  values in that generation. `initial_rollback_snapshot_trusted` covers restoring the
  initialization values. `trusted_rollback_excludes_confirmed_keys` composes these with the
  registry's recheck and the exclusion theorem: after such a rollback, and along later steps
  that never lower slot 284 except by rollback (`SnapshotTrace`), every confirmed exit's key,
  including exits confirmed after the rollback as in `UntrustedRollback`, is absent from every
  committee active at or above the restored checkpoint.
  `certified_values_trusted_across_recoveries` and `certified_rollback_excludes_confirmed_keys`
  cover arbitrarily many later actual recoveries. They require a genuine `CanonicalHistory.Run`
  for the trusted source, whose raw archive/reference facts derive snapshot < source L1 block;
  the later `ProtocolState.Trace` may contain forged landings. Construction and certificate
  equality alone are insufficient for this cross-generation result, as the concrete
  `weak_source_lacks_reference_bound` regression shows. Initialization has a separate result.
  `rollback_interval_rejects_landing` covers the whole interval while origin.height exceeds
  the restored checkpoint and no new recovery has executed. The missing origin record prevents
  constructing a node target there. Rollback closes session trust while preserving HRS, retired
  domains and authenticated-generation knowledge. Stake withdrawn before rollback is not recovered
  (8.1, spec L498); timely governance action and physical persistence remain outside the proof.
  The regressions show that where the untrusted rollback lets an exit be confirmed the condition
  fails and the key stays active, that an ordinary confirming World satisfies it together with
  every other hypothesis of that theorem, and (`TrustedRollbackRegression`) that a rollback on
  the non-vacuity run restoring the first landing's values satisfies every hypothesis of the new
  theorems, while a snapshot no landing wrote at the same checkpoint does not. That run has no
  exit and no forged landing, so the exclusion holds vacuously there.
  `CrossGenerationRollbackRegression` adds a nonvacuous exit, forged snapshot confirmation,
  two recoveries, rollback, new recovery, valid landing, reconfirmation and actual trust-revalidated
  sign. A cleared exit cannot reconfirm under the restored snapshot; recovery preserves that
  snapshot too, so the valid landing must advance it first. The restored and later contexts
  exclude the exited key. These are decoded L1/crypto/EL fixtures, not adapter implementation proofs.

## Witnesses

### Non-vacuity

A premise record can be contradictory, which would make every claim true for nothing.
`EtnaWitnesses/NonVacuity/Premises.lean` shows it is not:

- `premises_satisfiable`: one deployment and one environment satisfy every field, with
  non-trivial relations: an injective header hash over height, stateRoot, timestamp and the
  anchor; an injective config hash; one fixed L1 history for anchors and FI witnesses; a
  signature relation that accepts exactly the votes the one validator cast; landers that submit,
  on the run's landing Worlds, any certified call. Under them a run goes through an FI enqueue, two submitted landings in
  generation 0 (the first consumes the queued entry), a governance recovery and a submitted
  landing in generation 1. The theorem states the outcome (the records' heights, generations
  and cursors, the new generation, the head past the enqueued entry); its docstring explains why
  only those events produce it.
- `finality_hypothesis_satisfiable`: the signature relation cannot be forged, and on the World
  after the recovery H2's finality hypothesis holds (no member equivocates) next to a valid
  commit.
- `byzantine_minority_finality`: a second deployment with three keys of stake 3, 2 and 1, where
  the smallest (1/6 of the power) signs two blocks at one height and round. H2 still gives
  agreement. This deployment submits no landings, so `verifierSound` and `authenticatedInputs`
  hold there trivially; the first deployment covers them.

`EtnaWitnesses/Headline/FundSafetyRun.lean` is a concrete run for H1 through every way the
records change (two landings, a recovery, a landing in generation 1 and a rollback that voids
it), with the chain-of-custody property at every World.

### Counterexamples

`EtnaWitnesses/Counterexamples/` holds seven scope counterexamples and the repaired
`StaleDaoAuthorization` regression. `RecoveryCapture` has its own deployment (n_max 5, four honest parties); the others use the non-vacuity deployment. These are not failures of H1-H3: they show what a premise carries or what remains outside the claims.

- **`NoVerifierSoundness`.** If both proof backends accept a false statement, a checkpoint lands
  that no valid chain reaches, and SignalService publishes its fake state root. Every other
  premise holds, so `verifierSound` is what H1 rests on. The spec already takes verifier
  soundness as an assumption (spec L16, L487); no fix is needed.
- **`UntrustedRollback`.** A verifier-failure rollback restores slot 284 to a value no trusted
  landing wrote. The exit of the committee's only validator is then confirmed and its stake
  withdrawn while the built rules still make it the whole committee; its conflicting commits are
  valid and unslashable. A realistic withdrawalDelay only postpones this. Fix: the rollback duty
  above; within the trusted landing's generation, `trusted_rollback_excludes_confirmed_keys`
  proves it restores the exclusion, also for exits confirmed after the rollback.
- **`RecoveryCapture`.** Four honest validators each hold 1/4 of the power, so a recovery
  authorization passes the modelled nonempty-set and concentration checks at authorization.
  A newcomer registers 9 TAIKO before execution and receives 9/13 (over 2/3) of the committee
  the decoded call elects at R, alone producing valid commits. SPEC 8.1 (spec L500) requires
  these checks **before scheduling and executing**. This witness omits the execution-time
  recheck, which would reject that concentration; it demonstrates that the decoded call is
  not bound to the earlier committee, not a SPEC-compliant recovery-capture attack. Nonce
  invalidation permits cancellation but does not bind a committee. The mandatory concentration
  check remains separate from the economic reassessment that adds no capital veto. A
  protocol-level ordering or activation attack needs a separate trace showing the required
  pre-execution recheck still passes; binding a registry cutoff would be an additional
  protocol rule, not a fix established by this witness.
- **`ForcedPoisonResubmit`.** After a recovery blanks an unprovable ("poison") FI entry, anyone
  can enqueue the same transaction again for the normal fee and stall the cursor again. The
  spec now records this as section 12 item 20, and §1 no longer says recovery handles such a
  transaction. A blocklist of blanked hashes would stop only a verbatim copy.
- **`AnchorTail`.** Entry 0 is due at the head of the queue. Under an anchor that reports
  tail 0, a block that keeps the cursor at 0 passes `Forced.step` with no witness and serves
  the queue; under the honest tail 1 it does not. `InputsAuthenticated` constrains no witness
  for that anchor, and by inspection of the premises nothing but the environment's
  `anchorAuthenticated` rules it out (the witness is a concrete instance, not a run under the
  premises). H3's part (b) is therefore relative to the tail an accepted anchor reports; a premise or an
  implementation obligation that accepted anchors report the Inbox's actual tail and timestamp closes it.
  `honest_anchor_queue_service` proves part (b) against the actual queue with that obligation
  as explicit hypotheses, which this anchor violates for every clock.
- **`StaleDaoAuthorization` (repaired).** The old model allowed an authorization voided by
  a landing to revive after rollback. The current model increments the _current_ nonce on
  rollback, recover and explicit invalidation, and checks that nonce plus expiry on execution.
  `stale_authorization_never_revives` exercises the same forged-landing/rollback prefix and
  now proves rejection. `consumed_authorization_never_revives` proves rejection along every
  future whole-machine trace. Deadline equality, initialization and uint256 overflow are
  covered by kernel-checked regressions.
- **`HistoricalEscrow`.** An ordinary initialized rotation, without recovery or rollback,
  excludes an exiting key, confirms it and pays its remaining principal after the full delay.
  Historical height-1 signatures still verify; the old key alone cannot commit at fresh height 13. This is the intended checkpoint/weak-subjectivity boundary, not a fresh-signing exploit.

- **`SigningViewLag`.** The node's own finalized view is at L1 26 with checkpoint 0 and local
  tip 9; newer L1 reaches checkpoint 12 and pays withdrawal at 30. A properly retained HRS log,
  full typed prefix, bound engine request and actual signer produce a fresh round-1 nil
  precommit at local height 10. The newer confirmation cannot precede or be included in the
  old view. This is a freshness boundary, not an extension above the newer checkpoint.

## Trajectory conservation and signing/exit consistency

`Accounting.protocol_trajectory_conservation` covers every original protocol trace. Given
zero principal in initially released slots, it proves initial held TAIKO plus accepted deposits
equals final effective/pending principal plus withdrawals, slash bounty and slash/forfeit sink
payouts. Receipts come from accepted inputs and actual staking results, not balance differences.
The initialization condition is derived from empty lifecycle states. Recovery and rollback
do not recreate payouts; genuine failed calls add zero-flow stutters. ETH fees remain a separate
conserved asset under the existing `Core` invariant. Exact real token transfers remain external.

`SigningEscrow` proves confirmation clocks, the full block-based withdrawal delay, lifetime
key uniqueness, and permanent historical exclusion at every cutoff from a finite effective
exit onward, including after withdrawal/reuse/recovery/rollback. Snapshot coverage needs an
explicit snapshot discipline; a built committee's exclusion additionally needs its cutoff to
follow the covered snapshot. Signer-generation retirement holds across arbitrary later signer
operations. None of these changes the headline premises.

The typed `SigningBridge` now connects an actual successful `Signer.sign`, its exact decoded
request and immutable key, a valid own-finalized prefix, and an included confirmation checkpoint.
It derives the cutoff bound and binds a fresh signature/log append, with a genuine initialized
positive witness. Its exclusion results take snapshot coverage (`Covered`: every retained
confirmation has exitAt at most slot 284) as an input; `NormalSigning.run_covered` derives it
along a normal run. Appending future headers preserves covered historical cutoffs. Real producer,
encoding/key and L1/EL authentication remain adapter obligations.

A fully slashed member can retain current fixed committee power, so continuous positive backing
is false; the spec records this as section 12 item 19. `slashed_key_absent_from_later_committees`
(`EtnaProofs/SlashedExclusion.lean`) says which committees can still hold that power: after a
successful double-sign slash at L1 block b the entry has no principal, and its key is absent from
every committee selected at a cutoff at or after b, in every later World and after slot reuse.
When such a committee takes effect is a liveness question it does not answer.
`SlashedExclusionRegression` runs it on a real slash: the committee selected at cutoff 12 keeps
key 9, the one selected at cutoff 16 on a later World excludes it. A full typed lagging-view witness also freshly signs an old-height nil precommit after
newer withdrawal: own-finalized trust does not imply current global checkpoint freshness.
Causal confirmation-to-view ordering and either same-prefix inclusion or authentic retained
normal-recovery history are explicit requirements, as
are post-rollback revalidation and actual producer enforcement. An available evidence period
does not guarantee timely evidence delivery or governance action. See
[the signer/prefix connection](signing-prefix-connection.md),
[trajectory assurance](trajectory-assurance.md) and
[signing/escrow analysis](signing-escrow-analysis.md) for precise statements and checked
counterexamples.

## Normal rotation, recovery and actual signing

`NormalSigning.fresh_signing_connection` derives confirmation coverage along a provenance-rich
normal run and connects it to the actual next-height committee and successful fresh signer
call. `ConfirmationSource` supports either exact replay inclusion or retained history through
an actual normal recovery. Thus a confirmation checkpoint below the new fixed origin need not
appear in that generation's replay. Original ordinary steps preserve the old complete record;
actual recovery/L1 ordering derives the new selector's cutoff bound. Withdrawal and slot reuse
do not revive the lifetime key. No desired cutoff inequality, live-bond or positive-collateral
premise is added.

The initialized witness confirms key 7 at checkpoint 12, withdraws it, lands through checkpoint
14, recovers at L1 40, crosses a recovered-generation H+2 handover, reuses the old slot at L1 48
and actually signs height 23 with key 8 while retaining its previous signer log. The selected
historical committee stays key 8; key 7's EngineRequest is rejected for all phases/nil choices.
A second initialized witness supplies a normal-recovery source before the first landing.

"Normal" means only "without verifier-failure rollback": a recovery here is any accepted
`recover` call, including one whose reselection a late registration captured
(`RecoveryCapture`). No theorem lifts a headline `Run` to `NormalSigning.Run`. Under `Premises`,
a submitted landing supplies `built`, `valid` and `binding` (`submitted_landing_certified`), but
each landing's prior-snapshot source and reference bound, and the absence of rollback, are
separate raw input contracts. `CanonicalHistory.run_normal` now derives the complete
normal provenance from an initialized accepted history with authenticated archive/header and
reference bindings. `submitted_history_landing` connects that history to the original submitted
batch theorem without constraining the old free predicates. Its initialized witness lands
generation-1 blocks 15–22 after recovery and actually signs height 23. `SnapshotSource.normalRecovery` names an actual recovery, but the bound it yields
reads only its clock, time order, kept snapshot, generation and origin, that is
`s.snapshot < ctx.originBlock` one generation above `before`. Initial key and
exit-history invariants, actual authentication/request/key/persistence behavior and causal view
coverage remain explicit. See [normal signing composition](normal-signing-composition.md)
and [premise responsibilities](premise-responsibilities.md). Global freshness,
continuous collateral and production implementation certification remain outside these results.
The separate TrustState, certified cross-generation rollback and Locking modules cover the
design-level session, rollback and lower-level locking obligations described in
[design safety composition](design-safety-composition.md).

## Back-pressure accounting

`EtnaProofs/BackPressure.lean` proves 6.4's accounting along `OrdinaryTrace`, the traces whose
steps are original `Step`s other than verifier-failure rollback (6.4's stated exception). Its
edges are `OrdinaryStep`s, which repeat every `Step` constructor except rollback with the same
premises (`ordinary_step_is_step`, `step_ordinary_or_rollback`). An operation is left out for
what it is, not for its result: an owner nonce invalidation whose result equals a rollback that
keeps the current checkpoint and snapshot is still ordinary
(`OrdinaryTraceRegression.invalidation_is_ordinary`).

- `ordinary_trace_checkpoint_monotone`: lastCheckpoint.height never decreases. A landing
  advances it; registration, registry edits, FI enqueue and sweep, recovery and nonce
  invalidation leave it unchanged.
- `anchored_count_not_undercounted`: if a block's anchor shows the checkpoint of an earlier
  World, the block's height above any later lastCheckpoint is at most its height above the
  anchor's checkpoint.
- `anchored_unsettled_bound`: with a valid anchor (3.4 rule 5 is a conjunct of `AnchorValid`),
  the block is at most U blocks above every later lastCheckpoint, so a landing stall permits at
  most U further blocks.
- `rollback_restores_trusted_checkpoint`: the exception; rollback makes the trusted retained
  record lastCheckpoint, which may be lower.

That the anchor shows the checkpoint of a World on the trace is an explicit hypothesis, not a
premise: real anchor authentication (L1 headers and storage proofs) stays outside the model.

## Settled prefix, round agreement and a trusted slot 284

These results add no premise and change no headline theorem; each new assumption is an explicit
hypothesis of its own theorem.

- **Settled prefix** (`EtnaProofs/Permanence.lean`): along every `OrdinaryTrace`, records at or
  below the starting lastCheckpoint never change and SignalService checkpoints are only
  appended. `anchored_checkpoint_stays`: the record at the checkpoint height a valid anchor
  shows is unchanged later, and the block stays within U of the later lastCheckpoint.
- **Agreement across rounds** (`EtnaProofs/RoundSafety.lean`): `same_round_agreement` restates
  H2's finality argument for any consensus context. `height_agreement` extends it to every
  round at a height under `CrossRoundAccountable`, a predicate stating CometBFT's cross-round
  accountability for its locking rules at each height: if the members that sign conflicting
  precommits in some round or break the locking rules at that height hold less than 1/3 of the
  power, all valid commits at that height are for the same block. The theorem adds no slashing: automatic double-sign slashing
  compares one round only (§1 "Slashing scope", spec L18).
- **Derived locking safety** (`EtnaModel/Locking.lean`, `EtnaProofs/Locking.lean`):
  `polc_after_commit` derives lock persistence by per-key round induction and excludes the
  first later conflicting certificate by weighted honest quorum intersection.
  `commitValid_agreement` applies this to actual Etna `activeAt` committees and arbitrary
  commit rounds. Honest keys have monotone local round/phase histories; keys may occupy
  different rounds concurrently, and phases or rounds may be skipped. The mode is a fixed
  proof reading of CometBFT v0.40.0's
  [markdown specification](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/spec/consensus/consensus.md)
  and [paper algorithm](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/spec/consensus/consensus-paper/consensus.tex),
  pinned to commit `0880b4d378f347ab16e54ec677ff50d803f37d62`, not a new deployment setting: markdown mode
  requires locked-block prevotes and allows nil-PoLC unlock at precommit; paper mode permits
  locked nil prevotes but retains locks on nil certificates. These permissions cannot be
  freely combined. The proof accepts both coupled readings and models nil separately from
  every block hash, including zero. Each actual commit needs its own nonnil event attribution;
  decoded `CommitValid` alone is insufficient. `shared_history_commitValid_agreement`
  derives committee equality from shared raw history/configuration in the same deployment,
  generation and fixed origin. At H+2 it needs the first `t*epochLen-1` anchor entries;
  recovery bootstrap needs none, but still needs registry history through the fixed origin.
  Existing canonical recovery/landing history exercises this prefix bridge. Authentication
  of actual header/MPT bytes and upstream implementation refinement remain external.
- **A trusted slot 284** (`EtnaProofs/TrustedSnapshot.lean`): under `SnapshotTrusted` (slot 284
  is not ahead of the cutoff of the committee active at lastCheckpoint), a key whose exit was
  confirmed is absent from every committee that the context built on the same World activates
  at or above lastCheckpoint. Section 8 requires the rollback to restore the last trusted
  landing's value; `trusted_rollback_snapshot_trusted` proves this implies the condition within
  that landing's generation (see "Rollback trust" above). The theorem says nothing about later
  Worlds, withdrawals, commits or slashing.
  `EtnaWitnesses/Regressions/TrustedSnapshot.lean` shows that right after the untrusted rollback
  lets key 7's exit be confirmed, the context built on that World violates the condition and
  still activates key 7 above lastCheckpoint; and that on an ordinary run from the initialized
  deployment the confirming World, with the context built on it, satisfies every hypothesis of
  the theorem.

## Registry, recovery and capital alignment

Top-ups have separate pending principal and a ready L1 block. Deposit and maturity do not
change effective stake or its history; explicit activation writes a normal checkpoint.
Withdrawal and double-sign slashing use all remaining principal, including pending funds.
DAO forfeiture uses the deployment's fixed ceiling rate, consumes effective stake first,
forces exit without resetting the confirmation clock, and leaves a lifetime entryKey flag.
The registry models no forfeiture nonce, revocation or extra delay. Correct attribution,
owner authentication, real token transfers and EVM journaling remain external boundaries.

Recovery expiry is measured in L1 Unix seconds; readiness and evidence delays use L1 blocks.
`ProtocolState.rollback` is the checked upgrade boundary and rejects nonce overflow.
`applyRollback` and `Recovery.rollbackInbox` are success-state transformers, like
`applyRecovery`; every rollback `Step` requires the checked initialization/reentrancy/nonce
conditions. A raw transformer invocation alone does not establish an executable transaction.
H1-H3 quantify over traces including top-ups, forfeiture and recovery-nonce invalidation.

`EtnaModel/Capital.lean` and its proofs check the checklist's ceiling-derived S_MIN_TOTAL,
integer blocking-power capital bound and strict entry/common-control concentration checks
on supplied selected effective stake. Pending and unselected funds do not count. Snapshot
provenance, price policy/current valuation and controller classification remain supplied
operating evidence. These checks are not guards on build, rotation, recovery or signing;
they prove neither acquisition cost, irreversible loss nor timely governance response.

## Conformance

The generator emits schema 2 for the Inbox/registry families (including top-up, forfeiture and
nonce cases) and schema `etna-client-conformance-1` for the client-rule families. Both
implementation PRs run these vectors from stamped copies: the contracts from formal commit
`2d06eeb66`, the client from `4ec05bbe2` (its families have not changed since).

`lake exe etna-vectors --write <dir> --random <seed> [--count <n>]` writes opt-in random
vectors (`random-land.json`, `random-forced.json`) for differential testing: random call
sequences whose setups are always accepted (tested on seeds 0 to 9) and whose final call is
unconstrained, decided by the same model transitions; half the final landings are honest, so
both outcomes are common. Landings in their setups can skip grid points, so they reach cases the
enumerated families do not, such as a parent grid point with no record. Each file's `generator`
header names the seed and count; `--provenance` and `--families` do not apply, and nothing is
written unless every file renders. They are not committed and CI does not check them;
`check_vectors.py` still finds the committed files equal to a default run.

The vectors in `testdata/etna_conformance/` are generated from the model (`EtnaVectors`) and
record only what it decides on concrete inputs; that directory's README has the schema and how
to run them. Each implementation keeps its own copy, stamped with the formal commit it was
generated at, and its own list of known divergences next to its harness, so an implementation
change never needs a generator change.

**Contract conformance (#22286 at `a15ca613c`).** 414 vectors in four families: forced 114,
land 98, recover 70, registry 132. The generator now emits two more land vectors (a frontier leaf
whose Comet hash differs from the slot-285 record, and two landings in one L1 block), so the
committed land family has 100; the contracts' stamped copy predates them. The Foundry harness
`packages/protocol/test/layer1/etna/conformance/EtnaConformance.t.sol` deploys `EtnaInbox` and
`EtnaStakingRegistry` per vector, replays the setup, and compares the call's revert decision,
results and resulting state (the Inbox, the SignalService checkpoints and the whole registry,
down to every checkpoint's entries root). Verifier-failure rollback is not a contract call, so
the harness writes the model's rollback into the appendix-B slots as a fixture. 406 vectors
agree; eight are known divergences listed in the harness, each with its recorded contract
behaviour:

1. Free-slot reuse order: the model reuses the oldest freed slot, the contract the most recent.
   The spec does not say.
2. Withdrawal to address 0: the contract refuses, the model (which has no recipient) accepts.
   The spec does not restrict `to`.
3. Withdrawal, slash, recovery exclusion and a top-up ready at L1 block 2^48 − 1 (four vectors):
   the contract keeps every stored block below its no-exit sentinel and reverts. Unreachable.
4. Recovery origin timestamp 2^48 (spec L781): "range checks" names no range; the contract uses
   2^48, the model only the 2^256 word bound. Unreachable.
5. Slashing an entry whose effective stake a forfeiture already zeroed: the entry is unchanged,
   the model writes no checkpoint, and `slashDoubleSign` writes one repeating the previous count
   and root (`forfeit` skips it). The spec does not say.

The first run also found two generator mistakes, since fixed: an uninitialized Inbox carried the
genesis checkpoint hash (slot 271 is zero until `init`), and
`registry.hw.top-up-rejected-after-forfeit` forfeited before the entry was active, so it did not
test the forfeiture.

Out of reach of these vectors: the guest and node rules for FI due and skip and for U
back-pressure, reentrancy, the initialization inputs, reference blocks 257 to 8,191 blocks old
whose hash the EIP-2935 history contract still serves (ages 257 and 8,192 are covered) and the
encodings.

**Rust client conformance (#22280 at `bce302828`).** 340 vectors on node rules: forced_step 151,
schedule 83, block_rules 92 and block_size 14. The harness
`packages/taiko-client-rs/crates/abci/tests/etna_conformance.rs` (part of `just unit`) builds
each block vector as a whole envelope on a committed chain, with real L1 anchor headers,
EIP-1186 Inbox and registry proofs and a committee holding the proposer, and judges it with
`validate_block`, the validation ProcessProposal, FinalizeBlock and the lander share;
`forced_step` adds `verify_forced` with an engine that builds the singleton, and `schedule`
verifies real registry checkpoint witnesses with `verify_snapshot` and derives the committee
with `committee::derive`. 339 vectors agree; one is a known divergence: the model's
`HeaderValid` rejects L2 height 2^48, while section 3.4 states no height bound (only `land`
bounds heights, spec L287) and the client accepts it. It is a spec ambiguity at a height no
chain reaches.

Out of reach of the client vectors: the lander's landing grid and cut leaves, recovery
generations (the schedule family is generation 0 only), the checks ProcessProposal and
FinalizeBlock add to `validate_block`, and variations of the hash-dependent rules, which the
harness satisfies by construction.

## Review surface

To trust the result, read:

- `EtnaStatements/` (about 390 lines): `Environment`, `Run` and `Built`; `Premises` with
  `Certifies`, `VerifierSound` and `InputsAuthenticated`; and the claims.
- The `EtnaModel/` definitions those statements use (about 1,900 lines in all): landing (6.1),
  forced inclusion (7), recovery and rollback (8), the registry and its history (4.1), committee
  election and schedule (4.2-4.3), block validity and settlement (3, 6.2), and the deployment
  construction (`Deployment.build`, `Deployment.Genesis`).
- The explicit hypotheses of the supplementary theorems: `EtnaModel/AnchorHonesty.lean` and the
  hypothesis lists of the theorems in `EtnaProofs/Headline/AnchoredQueue.lean`,
  `EtnaProofs/TrustedRollback.lean` and `EtnaProofs/SlashedExclusion.lean`.

`EtnaProofs/` need not be read: the kernel checks it, and the audit checks the headline types
and axioms. `EtnaWitnesses/` shows what the claims rule out and what they leave open.

Modelling choices a reviewer should know:

- Hashes are opaque numbers. The World holds fixed hash adapters that no caller chooses, and
  every transition keeps them.
- Deployment storage/configuration values (L, genesisCutoff, maxAnchorAge, FI delay, fee and
  threshold, maxBatchBlocks, protocolFeeRecipient, registry minimum stake, delays, bounty and
  forfeiture rate) are immutable, never per-call choices. The original fixed-version World
  also keeps code constant K fixed. The separate conditional `UpgradeBoundary` model permits
  a code-version K change at a common-grid H with compatible unchanged U/maxBatchBlocks;
  this is not an original `ProtocolState.Trace` step or an available activation mechanism.
- `Deployment.build` derives the rules from the World: it checks the config and committee-0
  openings against the stored commitments, recomputes committee 0 from registry history, and
  enforces the §10/§11 initialization constraints. The openings are ghost authenticated inputs,
  not storage slots. The registry's Inbox-address and chain-id check is not modelled.
- Reentrancy is a decoded transaction boundary, not an ERC20 callback model. Registry
  edits reject an entered Inbox; the low-level registration function has no Inbox argument.
  All traces from initialized Worlds retain entered=false. Actual callback exclusion on
  registration, transfer authenticity and Solidity modifier wiring remain implementation
  conformance obligations, not conclusions of H1-H3.
- `EtnaProofs/Contracts.lean` and the deployment and history proof modules pin the definitions
  the claims rest on (block, commit and node validity, the committee schedule and election,
  landing, forced inclusion, the registry, recovery, rollback, `Deployment.build`, `Genesis`,
  the step and trace relations) by restating them with `_root_`-qualified names, so silently
  weakening a pinned definition breaks the build. Changing a definition, its pin and its tests
  together still needs review.

## The gate

CI (`.github/workflows/formal--etna.yml`) runs, in order:

1. `scripts/lint_sources.py`, before Lean is installed: rejects build-time code and trust
   escapes (`#` commands, macros and `elab`, `initialize`, `unsafe`/`partial`/`opaque`,
   `implemented_by`/`extern`, `native_decide`, `axiom`, `sorry`) and attributes outside an
   allowlist; pins the lakefile, the toolchain and the imports.
2. `scripts/check_imports.py`: the five libraries, imports pointing down only (Witnesses →
   Proofs → Statements → Model; Vectors → Model), every module built from its library root, and
   no `theorem` in Model or Statements.
3. `lake build`; the tree must then be unmodified.
4. `scripts/check_vectors.py`: the committed vectors equal a fresh generator run (no missing,
   extra or stale file; it compares `*.json` only).
5. `scripts/generate_artifacts.py` and `--check`: write `Audit.lean` and the clause inventory to
   the ignored `.scratch/generated`; `--check` verifies deterministic rendering only.
6. `scripts/check_spec_coverage.py`: the traceability report's consistency (every claim edge is
   a manifest edge to a partial clause, roles, the pinned spec revision); prints the clause
   statuses. `scripts/rule_coverage.py --check` then checks the rule-ID view: the raw-byte pins of
   `SPEC.md` (markers included) and `rules/INDEX.md`, one row per live INDEX ID, the reviewed
   overrides in `rule-coverage.json` and a fresh `reports/rule-coverage.md`.
7. `scripts/audit_proofs.py`, whose logic is `scripts/EtnaAudit.lean`, compiled separately so
   model code cannot change it: the checks below, transitive axioms, `leanchecker --fresh` over
   every library, and a replay of `tests/*.lean` with zero diagnostics.
8. `python3 -m unittest discover -s tests`: mutation and regression tests of the gate; the tree
   must then be unmodified.

What the audit checks, each with its documented limit:

- **Headline.** `Etna.Proofs.claims` and the three headline theorems have exactly their claim
  types and only the standard axioms.
- **Exact types.** Each of the 954 manifest entries carries a full expected type, parsed as one
  term (no `by`, `sorry` or `%`-elaborators) and compared with the kernel's. The manifest is a
  reviewed artifact; the gate does not compare it with prose.
- **Rule P** (needed for the `property` role). The statement is quantified, and every conjunct,
  disjunct and existential body of its conclusion uses an outer bound variable and is not
  trivially true; a statement-layer definition is read as its body. Limit: it is syntactic, so
  `x ≤ x`, an `↔` with one trivial side or a Boolean encoding can still pass.
- **Derived** (also needed for `property`). The live proof uses induction on a recursive type or
  another derived Etna theorem; unused bindings are dropped first, and the chain is written to
  `.scratch/generated/derivation-chains.json`. Limit: it is a proxy. A per-step case split that
  cites an induction lemma counts, and a substantive result proved without induction does not.
  For example, H3 is `property` through part (a′): the recorded chain is
  `forced_inclusion_integrity -> head_advances_only_in_landings -> genesis_trace_invariants ->
trace_preserves_immutables -> Trace.rec`, an induction that preserves the deployment
  immutables, which is itself an instance of this limit: the chain records only the first
  induction the proof uses. Part (a′) does rest on a real induction: its rollback case needs
  `trace_record_cursors_monotone` (record cursors are monotone in record height along every
  trace), proved by induction on the trace. Part (b)'s theorem
  (`landing_consumes_queue`) is `supporting` (Rule P fails; so is `honest_anchor_queue_service`), and part (a) is a per-step case
  split, so what only part (a) speaks to (§1's "no deletion" sentence, 7.2 "Blanked entries",
  8 step 3) is partial through a conjunct that is not itself derived.
- **Premise use.** Every `Premises` field is read by a headline proof or an Etna theorem it uses.
  Limit: it looks for projections. It over-approximates: reads are counted per structure, not
  per hypothesis, and a projection that appears only in a binder type or in an ignored argument
  still counts. A field taken apart by `cases` or `obtain` is not counted, so the check fails
  closed there.
- **Library contents.** Model and Statements hold no proofs; Proofs holds no public
  non-theorem; `Etna.Proofs.*` lives only in `EtnaProofs/Headline/`. Limit: source declarations
  are told apart by their declaration ranges, and range-less constants are taken as
  Lean-generated, which relies on the lint forbidding metaprogramming. A definition whose type
  is not a proposition may carry proof terms; the role and premise-use checks never enter
  definitions, so such a proof never counts (fails closed).
- **`constant` role.** The statement, read through statement-layer definitions, must be
  closed. Residual: a theorem typed by another definition that unfolds to `∀` (a Model
  definition, or an `Etna.Statements.*` name declared outside EtnaStatements) can still be
  labelled `constant`.
- **Shadowing and placement.** New shadowing of enclosing-namespace names must match
  `manifests/shadowing-allowlist.json`; each entry's module must own the declaration and be in
  Proofs or Witnesses.

## Run locally

Use the compiler pinned in `lean-toolchain` (Lean 4.35.0-rc4). From `formal/etna`:

```sh
python3 scripts/lint_sources.py
python3 scripts/check_imports.py
lake build
python3 scripts/check_vectors.py
python3 scripts/generate_artifacts.py
python3 scripts/generate_artifacts.py --check
python3 scripts/check_spec_coverage.py
python3 scripts/audit_proofs.py
python3 -m unittest discover -s tests -v
```

Only Lean's standard library and Python's are needed. After a model change that moves the
vectors, regenerate them with `lake exe etna-vectors --write ../../testdata/etna_conformance`
(and refresh the contracts' and the client's copies as that directory's README describes). Generated
`Audit.lean`, the full clause inventory and the audit results go to the ignored
`.scratch/generated`. Execution plans are not tracked.

## Layout

Five Lake libraries. Imports only point down: Witnesses → Proofs → Statements → Model, and
Vectors → Model.
Declarations keep their `Etna.Design.*` names, so a model file and its proof file share a
namespace (for example `EtnaModel/Deployment.lean` and `EtnaProofs/Deployment.lean`).

- `EtnaModel/`: definitions, structures, inductives and instances. No theorems.
- `EtnaStatements/`: `Environment`, `Run`, `Premises` and the claims. No proofs.
- `EtnaProofs/`: every theorem about the model, the pins in `Contracts.lean`, and
  `Headline/` (namespace `Etna.Proofs`): the chain-of-custody invariant behind H1, the
  proofs of H1, H2, H3 and `claims`, and the anchor-honesty theorems (`AnchoredQueue.lean`). `EtnaProofs/Deployment.lean` imports
  `EtnaStatements.Premises` for `Representable`.
- `EtnaWitnesses/`: `Regressions/` (concrete traces), `Headline/` (the H1 run),
  `NonVacuity/` (the premise witness) and `Counterexamples/` (seven scope counterexamples and the repaired nonce regression).
- `EtnaVectors/`: the conformance-vector generator (`lake exe etna-vectors`). It imports only
  the model and nothing imports it; the lint lets only its plain string literals contain `{`,
  and the audit admits its root `main` as the one declaration outside `Etna`.
- `manifests/design.json`: the theorem contracts; `manifests/shadowing-allowlist.json`.
- `spec-coverage.json`: the 34 narrow claims (traceability). `rule-coverage.json`: the raw
  pins, reviewed overrides and reviewed narrowings (38 shared clauses) of the rule-ID view.
- `scripts/`, `tests/`: the gate and its tests. `reports/`: review history. `legacy/v9`:
  historical V9 material outside the build.

## Numbers

- 1,216 theorem contracts: 248 property, 3 constant, 508 supporting, 457 regression.
  All original 954 declaration/type pairs remain exact. Twenty-five exact named plumbing
  contracts are UNSOURCED; no generic allowlist expansion is used.
- 248 property derivation chains, checked against the live proof terms.
- 405 source clauses: 101 partial, 301 deferred, 3 design-pending; 34 narrow claims.
  The original 313 SPEC/ACCEPTANCE clauses remain identifiable beside the 92 ANCHORLESS clauses.
- 600 SPEC/INDEX rule IDs, including 568 binding rules, 21 limitations and 11 assumptions.
  ANCHORLESS has its own source IDs and is not folded into these rule IDs.
- 377 Python mutation/regression tests and 21 kernel-replayed Lean regression modules.
- Current vectors: 416 Inbox/registry and 340 client rule vectors. The contracts ran the 414 of
  `2d06eeb66` (406 agree, 8 known divergences) and the Rust client the 340 (339 agree, 1 known
  divergence).

The clause counts and the claims are traceability: "partial" means some induction-derived
theorem (or a closed constant) speaks to the clause, not that the clause is proved.

## Reports

[Review corrections](review-corrections.md) records every correction pass, ending with
the headline-theorem restructure; [history/state results](history-state-verification.md),
[first-batch results](first-batch-verification.md) and
[design findings](design-findings.md) are historical. [Rule coverage](rule-coverage.md)
is generated. Old report counts and line-number
source IDs describe their original revisions.

## Public settled EL reconstruction

`Reconstruction` adds an executable public-input model and conditional reconstruction
success proofs: full encoded EL headers and ordered transaction bytes, canonical L1
landing/recovery records, and complete authenticated starting state. It derives overlap
agreement backward from the accepted frontier cut, applies only the new suffix, and
checks the returned EL state and public checkpoint. Trace proofs cover ordinary recovery
origins and exactly-once state application. Fixed codec/crypto/full-block EL semantics and
original-blob availability remain explicit external contracts; private consensus history
is not an algorithm input. See [the verification report](public-reconstruction-verification.md)
for theorem scope, non-vacuous fixtures and semantic mutation evidence.

## Conditional protocol upgrade boundaries

`UpgradeBoundary` proves disabled activation without a supplied authority and conditional
height/rule/image/job/session safety under an ideal exact-plan and current-checkpoint
authenticator. It preserves arbitrary previous piecewise rule history through H, checks all
interior heights and recorded boundaries even when rule IDs recur, retains old replay
materials and immutable job identities, and uses actual `land` and `TrustState.sign` calls.
Signing classifies fresh versus exact cached requests before persistence and keeps the
original encoder, domain, generation and HRS log. A retired-generation high HRS is retained.
Atomic switch failure leaves the entire prior state intact. Code-version K is distinguished
from deployment immutables.

The plan must be staged before represented current-generation production crosses H;
activation requires the actual authenticated current checkpoint at H and closed old jobs.
These are one modeled device/history and conditional policy guards, not global signer
coordination or a DAO/timelock implementation. The three activation clauses remain
**design-pending**. Per-switch preservation accepts an arbitrary prior schedule; the
prepare/activate trace theorem keeps settlement history fixed, with settlement/signing
proved through separate adapters. [Design safety composition](design-safety-composition.md)
maps all eight work items, witnesses, mutations and remaining primitive dependencies.
