# Etna design verification

This package is a Lean 4 model of the Etna specification and the proofs about it. The
specification is [`packages/protocol/docs/etna-pos-zk/sources/spec.md`](../../packages/protocol/docs/etna-pos-zk/sources/spec.md)
at revision 2026-10-28, pinned by SHA-256 in `spec-coverage.json`. A spec line written `spec L…`
is a line of that file. Any edit to the spec fails the coverage check until the clause links are
reviewed against the new text and the pin is updated.

**The result is three headline theorems**, fund safety, accountable finality and
forced-inclusion integrity, each proved for every deployment and environment that satisfy one
premise record, `Premises`. To trust the result, read the statements and the premises
(`EtnaStatements/`) and the model definitions they use (`EtnaModel/`); the Lean kernel checks the
proofs. The package says nothing about the production contracts, client or guests beyond the
conformance vectors below.

The clause inventory (308 spec clauses), the theorem roles and the 16 narrow claims in
`spec-coverage.json` are a **traceability report, not the verification result**. They record
which spec clauses some theorem speaks to, and CI keeps them consistent. A clause marked
partial is not proved.

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
  of them (signatures, the anchor and FI witnesses, EL execution, the header hash) and leaves
  `historyAuthenticated`, `committeeAuthenticated`, `payloadValid` and `batchPayloadValid`
  unconstrained: a block is valid under whatever those relations accept, and the theorems hold
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
every live staked bond with that key can be slashed for its whole stake. So if the members that
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

Part (b) covers only blocks inside landed segments, and it does not claim the maxAnchorAge bound
of 7.3 (spec L436). Part (a) is about (index, entry) pairs staying present; that each index holds
one entry is the separate queue invariant of `ProtocolState.Core`.

## Premises

`Premises w0 env` (`EtnaStatements/Premises.lean`) has seven fields. Each constrains only the
initialized World `w0` or the environment, never the records, signals or queue progress the
claims are about. "Used by" is the audit's premise-use result: the headline proofs that read the
field.

| Field | What it assumes | Spec source | Used by |
| --- | --- | --- | --- |
| `genesis` | `w0` is the World right after Inbox initialization (`Deployment.Genesis`), made with block 0's EL hash and stateRoot from `env.genesisHeader`, which has height 0, CometBFT hash 0 and FI cursor 0. | §10 steps 4-5 (spec L531-L532); Appendix B slot 285 (spec L740); 6.1 (spec L273); 7.2 (spec L400) | H1, H2, H3 |
| `verifierSound` | Two proofs, at least one sound: every proof pair the Inbox accepts contains a sound backend, and a sound backend approves a submitted landing only if its statement is `Certifies`, i.e. the statement of a batch valid under the rules `Deployment.build` derives from the guest's uint256 opening of the stored commitments. Equivalently: every submitted landing that lands is certified. | §1 "Funds" (spec L12); §1 "Upgrades and trust" (spec L16); §8 "Verifier failure" (spec L457) | H1, H3 |
| `authenticatedInputs` | For a submitted landing that lands, an authenticated FI witness under an authenticated anchor, from the current generation's origin L1 block up to the landing's block, shows the World's real queue entry. | 3.3 (spec L86); 7.2 (spec L401) | H3 |
| `hashSeparation` | The stored committeeConfigHash has exactly one uint256 opening (`Representable`): the deployment's own configuration. | 6.2 item 1 (spec L338) | H1, H3 |
| `headerHashes` | An EL hash is the hash of the header it names: when the EL accepts a block on a parent, both EL hashes are `headerHash` of the decoded headers, and so is block 0's. | 3.4 rules 1 and 9 (spec L99, L107); 6.2 item 4 (spec L341) | H1 |
| `headerSeparation` | Collision resistance, idealized: equal EL hashes mean equal height, stateRoot, timestamp and the whole decoded anchor. | 3.2 (spec L68, L72-L76); 6.2 item 4 (spec L341) | H1 |
| `signatureAgreement` | The registry's signature check accepts every vote in this deployment's domain that the consensus signature relation accepts. | 3.1 (spec L42); 4.1 (spec L150) | H2 |

The audit fails if any field is read by no headline proof.

## What is not covered

- **Liveness.** No claim says a block, a landing or a due FI entry ever happens (§1 "Liveness",
  spec L14).
- **Cross-round safety.** H2 compares commits at one height and one round only. Commits at
  different rounds of one height are not compared, and CometBFT's locking rules are not
  modelled (§1 "Slashing scope", spec L18: slashing covers only same-round double signing).
- **Checkpoint permanence.** No claim says a landed checkpoint stays. Governance recovery
  discards the blocks above the checkpoint, and the model's verifier-failure rollback may return
  to any retained record. H1 holds across both; §1's "nothing at or below a checkpoint can be
  rolled back except by a DAO upgrade" (spec L13) is a governance promise, not a theorem.
- **The bridge.** H1 ends at SignalService state roots. That the Bridge pays only against them
  (storage proofs, QuotaManager, pausing) is not modelled.
- **What happens after verifier failure.** Without `verifierSound` nothing is claimed
  (`NoVerifierSoundness` shows the premise is needed). The containment of §8 (pausing, the
  rollback upgrade restoring the last trusted values, cancelling pending recovery
  authorizations) is not proved: the model's rollback step takes any retained record and any
  slot-284 snapshot.
- **A wall-clock FI deadline.** H3 gives none, and §1 says the design gives none either
  (spec L15). H3 does not claim the maxAnchorAge bound of 7.3 (spec L436).
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
  `opening_separation_unsatisfiable`). Proof completeness (spec L16), durable signer and node
  trust (8.2), and PoS issuance and economics are also out of scope.
- **Rollback trust (a dropped premise).** A `trustedRollback` premise was considered: the
  restored slot-284 snapshot is below the rollback's block (`SoundStep.rollback`). No headline
  proof needs it. H1 holds across any rollback to a retained record, because a rollback drops
  the records and signals above one height together. So it was dropped. What it would protect
  is H2's slashability after a rollback: in `UntrustedRollback` a rollback restores a snapshot
  no landing wrote, and the committee confirms its exit and withdraws while it still signs; its
  conflicting commits are then unslashable. Even `snapshot < now` is too weak, since a later
  rollback can restore an untrusted value below its own block. A premise that protects H2 must
  be the spec's duty (spec L457): the restored snapshot is a value a retained landing or the
  initialization wrote.

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

`EtnaWitnesses/Counterexamples/` holds five kernel-checked runs. Four start from the
non-vacuity deployment; `RecoveryCapture` has its own (n_max 5, four honest parties). None is a
failure of H1-H3: each shows what a premise carries or what an open design issue leaves outside
the claims.

- **`NoVerifierSoundness`.** If both proof backends accept a false statement, a checkpoint lands
  that no valid chain reaches, and SignalService publishes its fake state root. Every other
  premise holds, so `verifierSound` is what H1 rests on. The spec already takes verifier
  soundness as an assumption (spec L16, L457); no fix is needed.
- **`UntrustedRollback`.** A verifier-failure rollback restores slot 284 to a value no trusted
  landing wrote. The exit of the committee's only validator is then confirmed and its stake
  withdrawn while the built rules still make it the whole committee; its conflicting commits are
  valid and unslashable. A realistic withdrawalDelay only postpones this. Fix: the rollback duty
  above, stated as a premise if H2 is to cover rollbacks.
- **`RecoveryCapture`.** Four honest validators each hold 1/4 of the power, so a recovery
  authorization passes the modelled parts of the DAO's check (8.1, spec L470: nonempty, no party
  at or above 1/3). A newcomer registers 9 TAIKO between authorization and execution and ends up
  with 9/13 (over 2/3) of the recovery committee, alone producing valid commits. The DAO cannot
  stop the scheduled call at execution, and its exclusion list is fixed. Suggested fix: bind the
  authorization to a registry bound, such as a `maxActiveFromL1` in the recover call.
- **`ForcedPoisonResubmit`.** After a recovery blanks an unprovable ("poison") FI entry, anyone
  can enqueue the same transaction again for the normal fee and stall the cursor again.
  Suggested fix: let the guest skip unprovable content, or narrow the §1 and §8 wording. A
  blocklist of blanked hashes stops only a verbatim copy.
- **`StaleDaoAuthorization`.** A landing voids a recovery authorization, but a later
  verifier-failure rollback restores the checkpoint and the voided authorization becomes
  executable again: the Inbox binds an authorization only to (generation, checkpoint), and the
  spec relies on the DAO cancelling it, which Taiko's DAO cannot do for an approved proposal.
  The model shows the Inbox side only. Suggested fix: an Inbox rollback counter or nonce that
  recover must match.

## Conformance

The vectors in `testdata/etna_conformance/` are generated from the model (`EtnaVectors`) and
record only what it decides on concrete inputs; that directory's README has the schema and how
to run them. Each implementation keeps its own copy, stamped with the formal commit it was
generated at, and its own list of known divergences next to its harness, so an implementation
change never needs a generator change.

**Contracts.** 334 rule-level vectors (285 generated from the model's transitions, 49
hand-written from spec lines) in four families: forced 114, registry 74, land 98, recover 48. A
Foundry harness in the Etna contracts PR (#22286),
`packages/protocol/test/layer1/etna/conformance/EtnaConformance.t.sol`, runs them against
`EtnaInbox`, `EtnaStakingRegistry` and `LibEtnaForcedInclusion`. All agree except six known
divergences listed in that harness, none a contract bug. The first two are reachable; the other
four need an L1 block at 2^48 − 1 or a timestamp at 2^48:

1. Free-slot reuse order (spec L139): the model reuses the oldest freed slot, the contract the
   most recent. The spec does not say; it should pick one (suggested: most recent), and the
   model then follows. The set key is fixed per key (spec L169), so the choice decides only
   which bond id a registration gets, not elections.
2. Withdrawal to address 0 (spec L142): any owner can call `withdraw(id, address(0))`; the
   contract refuses (stricter), while the model, which has no recipient, accepts. The spec
   could say "to ≠ 0".
3. Withdrawal at L1 block 2^48 − 1: the contract is stricter than the spec. Unreachable.
4. Slash at L1 block 2^48 − 1 (spec L151): the spec's formula gives the no-exit value; the model
   follows it, the contract refuses (safer). Unreachable.
5. Recovery exclusion at L1 block 2^48 − 1 (spec L460): the same kind. Unreachable.
6. Recovery origin timestamp 2^48 (spec L744): the spec asks for "range checks" without naming
   the range; the contract uses 2^48, the model only the 2^256 word bound. The spec should name
   2^48. Unreachable.

Out of reach of these vectors: the verifier-failure rollback (a DAO upgrade, not a call), the
guest and node rules for FI due and skip and for U back-pressure, reentrancy, Inbox calls before
initialization and the initialization inputs (the registry's calls against an uninitialized
Inbox are covered), reference blocks 257 to 8,191 blocks old whose hash the EIP-2935 history
contract still serves (an unavailable hash at age 257 and age 8,192 are covered), the 4,096-slot
registry capacity and encodings.

**Rust client.** 340 vectors on pure node rules: forced_step 151, schedule 83, block_rules 92 and
block_size 14. A Rust harness in the Etna client PR (#22280),
`packages/taiko-client-rs/crates/abci/tests/etna_conformance.rs`, runs them in `just unit`
against the client's public rules: `forced::check` with `verify_forced` and a scripted engine,
`Schedule` with `committee::derive`, the header and anchor rules of `rules`, and
`check_execution_size`. All four families run. All vectors agree except one known divergence,
listed in that harness: the model's `HeaderValid` rejects L2 height 2^48, while section 3.4
states no height bound (only the Inbox's `land` bounds heights, spec L266) and the client accepts
it. It is a spec ambiguity at a height no chain reaches; the spec could state the bound in 3.4.

Out of reach of the client vectors: the lander's landing grid and cut leaves, recovery
generations (the schedule family is generation 0 only), hash-dependent rules (parent hash,
`chain_id`, witnesses, MPT binding) and the request handlers (`validate_block`, ProcessProposal,
FinalizeBlock), which need a committed app state and an execution engine; the harness composes
the public rules in `validate_block`'s order instead.

## Review surface

To trust the result, read:

- `EtnaStatements/` (about 390 lines): `Environment`, `Run` and `Built`; `Premises` with
  `Certifies`, `VerifierSound` and `InputsAuthenticated`; and the claims.
- The `EtnaModel/` definitions those statements use (about 1,900 lines in all): landing (6.1),
  forced inclusion (7), recovery and rollback (8), the registry and its history (4.1), committee
  election and schedule (4.2-4.3), block validity and settlement (3, 6.2), and the deployment
  construction (`Deployment.build`, `Deployment.Genesis`).

`EtnaProofs/` need not be read: the kernel checks it, and the audit checks the headline types
and axioms. `EtnaWitnesses/` shows what the claims rule out and what they leave open.

Modelling choices a reviewer should know:

- Hashes are opaque numbers. The World holds fixed hash adapters that no caller chooses, and
  every transition keeps them.
- Every value the spec fixes at deployment (L, genesisCutoff, K, maxAnchorAge, the FI delay,
  fee and threshold, maxBatchBlocks, protocolFeeRecipient, the registry's minimum stake, delays
  and bounty) is an immutable of the World, never a per-call input.
- `Deployment.build` derives the rules from the World: it checks the config and committee-0
  openings against the stored commitments, recomputes committee 0 from registry history, and
  enforces the §10/§11 initialization constraints. The openings are ghost authenticated inputs,
  not storage slots. The registry's Inbox-address and chain-id check is not modelled.
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
   statuses.
7. `scripts/audit_proofs.py`, whose logic is `scripts/EtnaAudit.lean`, compiled separately so
   model code cannot change it: the checks below, transitive axioms, `leanchecker --fresh` over
   every library, and a replay of `tests/*.lean` with zero diagnostics.
8. `python3 -m unittest discover -s tests`: mutation and regression tests of the gate; the tree
   must then be unmodified.

What the audit checks, each with its documented limit:

- **Headline.** `Etna.Proofs.claims` and the three headline theorems have exactly their claim
  types and only the standard axioms.
- **Exact types.** Each of the 614 manifest entries carries a full expected type, parsed as one
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
  (`landing_consumes_queue`) is `supporting` (Rule P fails), and part (a) is a per-step case
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
  `Headline/` (namespace `Etna.Proofs`): the chain-of-custody invariant behind H1 and the
  proofs of H1, H2, H3 and `claims`. `EtnaProofs/Deployment.lean` imports
  `EtnaStatements.Premises` for `Representable`.
- `EtnaWitnesses/`: `Regressions/` (concrete traces), `Headline/` (the H1 run),
  `NonVacuity/` (the premise witness) and `Counterexamples/` (the five runs above).
- `EtnaVectors/`: the conformance-vector generator (`lake exe etna-vectors`). It imports only
  the model and nothing imports it; the lint lets only its plain string literals contain `{`,
  and the audit admits its root `main` as the one declaration outside `Etna`.
- `manifests/design.json`: the theorem contracts; `manifests/shadowing-allowlist.json`.
- `spec-coverage.json`: the 16 narrow claims (traceability).
- `scripts/`, `tests/`: the gate and its tests. `reports/`: review history. `legacy/v9`:
  historical V9 material outside the build.

## Numbers

- 614 theorem contracts: 93 property, 3 constant, 301 supporting, 217 regression.
- 93 property derivation chains (52 use induction directly, 41 through derived Etna theorems).
- 308 spec clauses: 56 partial, 249 deferred, 3 design-pending; 16 narrow claims.
- 140 formal tests.
- Conformance: 334 contract vectors (6 known divergences), 340 client vectors (1 known
  divergence).

The clause counts and the claims are traceability: "partial" means some induction-derived
theorem (or a closed constant) speaks to the clause, not that the clause is proved.

## Reports

[Review corrections](reports/review-corrections.md) records every correction pass, ending with
the headline-theorem restructure; [history/state results](reports/history-state-verification.md),
[first-batch results](reports/first-batch-verification.md) and
[design findings](reports/design-findings.md) are historical. Old report counts and line-number
source IDs describe their original revisions.
