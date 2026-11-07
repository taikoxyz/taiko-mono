# Spec authoring contract — rule identifiers, page map, writing rules

Status: **working contract** (Lead-authored, 2026-10-05). The authoritative registry is
`spec/index.html` §"Rule index". This file exists so that several authors can write different
specification pages without inventing rule identifiers or duplicating normative text.

## 1. Non-negotiable writing rules

1. **State each normative rule exactly once**, on exactly one page, under exactly one stable id.
   Every other artifact (spec pages, learn pages, iterations, README) links to it:
   `<a href="../spec/02-consensus.html#CONS-07">CONS-07</a>`.
2. Every rule carries an **evidence tag**: <span class="pill proven">Proven</span> (argument +
   named premises), <span class="pill assumed">Assumed</span> (justification + consequence of
   failure), <span class="pill open">Open</span> (what evidence would close it). Numbers carry
   <span class="pill derived">derived</span> / <span class="pill sourced">sourced</span> /
   <span class="pill unmeasured">unmeasured</span>.
3. Every rule states: **id — normative statement — why it exists — failure mode if violated —
   evidence tag**. A rule without a failure mode is not a rule; it is prose.
4. Never weaken an assumption into a guarantee. If a claim depends on A-CONS-1, say so at the claim.
   If a claim is not proven, say "assumed" and give the consequence of failure.
5. No rule may depend on L1 proposer lookahead or on a fixed L1 slot duration (R12). Timing is
   expressed in **seconds** or **L1 block numbers**; rounds/epochs are logical identifiers.
6. No rule may create a data-first path (D5), a staking token other than TAIKO (D7), a
   replacement contract address for the D3 surfaces, or a recovery that invalidates PoS-finalized
   history in Mode A (D2).
7. Interface sketches are **sketches**: they must be labelled as such and must not be presented as
   compiled or audited code. No gas figures unless sourced or explicitly unmeasured.
8. Terminology is fixed by `01-requirements-and-threat-model.md` §2 (status labels) and the
   glossary in `spec/09-parameters.html`. Do not introduce synonyms for statuses.

## 2. Page map and rule prefixes

| Page | Prefixes | Contents |
|------|----------|----------|
| `spec/index.html` | `GEN`, `STATUS` | scope, fixed decisions D1–D7, status labels, **complete rule index**, reading map, verdict summary |
| `spec/01-system-model.html` | `SYS`, `ROLE` | participants, channels, timing model, role catalogue (entry/duties/rewards/penalties/exit/failure) |
| `spec/02-consensus.html` | `CONS`, `LOCK`, `LC` | proposal, votes, locks, finality, fork choice, leader selection, view change, epochs/handoff |
| `spec/03-membership-staking.html` | `MEM` | TAIKO stake custody, activation, delegation, exits, unbonding, set snapshots, sybil/long-range |
| `spec/04-l1-integration.html` | `L1`, `DA`, `FI`, `MSG` | Inbox interfaces and events, proof policy, atomic data+proof, data binding, checkpoint advancement, forced inclusion, signal/bridge integration, withdrawal/replay |
| `spec/05-proof-statement.html` | `PRF` | public inputs, private witnesses, composition, recursion, program images, upgrade of guest/verifier, both backends |
| `spec/06-recovery-exceptions.html` | `REC`, `HALT`, `WH` | withholding analysis, safe halt/restart, backlog rule, and the **unselected** Mode B fallback specification |
| `spec/07-economics-slashing.html` | `ECON` | stake, rewards, funding, offence catalogue, evidence encoding, penalties, payouts, false accusations, user-loss scope |
| `spec/08-migration-upgrades.html` | `MIG`, `GOV` | migration boundary, pending state, shared-contract upgrades and storage layout, privilege removal, version/handoff of clients, program upgrades |
| `spec/09-parameters.html` | `PARAM` | glossary + parameter table with units, values, derivations, tags |
| `spec/10-assurance.html` | `INV`, `LIVE`, `LIM` | safety invariants, conditional liveness arguments, proof obligations, limitations, rejected alternatives, red-team resolution |

Rule ids are `PREFIX-NN` (two digits, zero-padded, stable forever; gaps are allowed, reuse is not).

## 3. Rule registry (draft — Phase 3/4 fills the consensus and economics families)

### GEN — general (index)
- `GEN-01` This document set is a specification, not an implementation; no claim of measurement.
- `GEN-02` Fixed decisions D1–D7 are constraints; a change requires a new user decision.
- `GEN-03` Normative rules are stated once, under stable ids; links elsewhere are references.
- `GEN-04` Every rule and number carries an evidence tag.
- `GEN-05` Domain separation and chain id appear first in every protocol hash.
- `GEN-06` Timing is in seconds or L1 block numbers; no L1 proposer lookahead; no fixed L1 slot.

### STATUS — labels (index)
- `STATUS-01`…`STATUS-08` — the eight labels of §2 of the requirements document, one rule each
  (proposed, locally execution-valid, voted, PoS-finalized (Mode A) / PoS-certified-provisional
  (Mode B), proof-ready, accepted on L1, Ethereum-finalized, withdrawal-eligible), each with
  evidence, guarantee, revocation condition, audience.
- `STATUS-09` A node must not treat local receipt of a valid block as availability for others.
- `STATUS-10` An elapsed timeout is never evidence that a certificate does not exist.

### SYS / ROLE
- `SYS-01` Participants: validators, provers, full/archive nodes, users, L1, DAO.
- `SYS-02` Channels: L2 P2P, L1 inclusion, L1→L2 observation (Ethereum-final only).
- `SYS-03` One L2 block per 2 s is a *production cadence*, not a finality or settlement latency.
- `ROLE-01`…`ROLE-08` one rule per role: entry/activation, duties+resources, rewards+funding,
  objective penalties, exit/withdrawal, behaviour when the role fails, permissionlessness, and
  barriers/concentration risks (with the explicit non-claim that per-address caps prevent monopoly).

### CONS / LOCK / LC — to be fixed in Phase 3 (family-specific), at minimum:
proposal validity; vote phases; quorum definition (stake-weighted, 2/3); vote uniqueness per
(height,epoch); certificate format and verification; commit/finality rule; fork-choice/lock rule;
unlock conditions; leader selection; view change/pacemaker; timeout derivation; epoch and
validator-set versioning; handoff at epoch boundaries; certificate validity is epoch-scoped and
permanent; equivocation definition; no-conflicting-certificate invariant.

### MEM — membership and staking (D7)
stake custody; activation queue; effective (voting) power derivation; delegation (if any) and its
risks; exit request; unbonding delay derived from the settlement pipeline; slashed-stake handling;
key rotation; withdrawal of stale keys; set snapshot definition per epoch; sybil resistance;
long-range/weak-subjectivity checkpoint and freshness.

### L1 / DA / FI / MSG — L1 integration (D5, D8…)
- `L1-01` The Inbox accepts a batch only via one function whose transaction carries both the data
  (blobs and/or calldata) and the proof; acceptance and checkpoint advancement are atomic.
- `L1-02` There is no entry point that records a proposal, batch, or checkpoint awaiting a proof.
- `L1-03` A failed verification leaves the batch unaccepted and consumes no checkpoint advance.
- `L1-04` Admission rules contain no discretionary gate and no expiry that makes a range
  permanently unprovable; any prover may submit any valid (data, proof) pair for an unsettled range.
- `L1-05` The proof's public inputs bind: chain id, predecessor checkpoint, epoch/set version,
  validator-set commitment, consensus evidence, data commitment, state commitment.
- `L1-06` Checkpoint advancement is monotone over the finalized chain (no reversion in Mode A).
- `L1-07` Ethereum-final-fact rule: L2 consensused state consumes only Ethereum-final L1 facts.
- `DA-01` Canonical data availability is the L1 transaction itself (calldata) or blobs bound to
  the proof by the KZG-opening construction of `DA-03`.
- `DA-02` Calldata path: the Inbox computes the data commitment itself over the exact calldata.
- `DA-03` Blob path: per-blob binding consisting of (i) `BLOBHASH` equality for every blob in the
  same transaction, (ii) an on-chain KZG point-evaluation check against the blob's versioned hash,
  and (iii) an in-guest equality between the polynomial evaluation of the *witness data the guest
  executed* and the value the on-chain check accepted, at a Fiat–Shamir challenge point.
- `DA-04` A private witness, committee certificate, or off-chain store is never a substitute for `DA-01`.
- `DA-05` Retention: the design states the retrievability window and the archive requirement, and
  the backlog rule keeps unsettled history inside it.
- `FI-01`…`FI-0n` forced inclusion: request format, fee/bond, delay, duty to include, hatch/escape
  path, interaction with the backlog rule, and the explicit statement that inclusion cannot
  reorder or revoke past history (R10 + D2).
- `MSG-01` Bridge/SignalService authentication anchors on the L1 checkpoint and the retained
  addresses; replay protection is domain- and chain-scoped.

### PRF — proof statement
- `PRF-01` Combined statement: one guest proves consensus evidence **and** execution.
- `PRF-02` Public inputs (exact list) and private witnesses (exact list).
- `PRF-03` The validator set is authenticated from L1-committed data; no prover-supplied witness
  defines the authoritative set.
- `PRF-04` Unique-signer and stake-weight checks (bitmap, no double counting, ≥ threshold).
- `PRF-05` Authenticated configuration/epoch transitions.
- `PRF-06` Data commitment binding (`DA-02`/`DA-03`).
- `PRF-07` Execution from the previous L1-accepted state root to the new state root.
- `PRF-08` Both RISC Zero and SP1 realise the same statement; acceptance policy (one backend vs
  two) with consequences.
- `PRF-09` Recursion/aggregation design and what it does and does not prove.
- `PRF-10` Guest/verifier program-image upgrade rules; old images remain accepted for old epochs.
- `PRF-11` Trust model for syscalls/hints/accelerators: nothing is verified unless the proof
  constrains it.

### REC / HALT / WH — exceptional paths
- `HALT-01` A correct participant stops rather than choose between two histories.
- `HALT-02` Restart rules: resume only from the highest finalized state whose data and certificate
  are reconstructible; never adopt an alternative history for the same heights.
- `HALT-03` Backlog rule: correct validators refuse new commitments beyond the unsettled-depth cap.
- `WH-01`…`WH-0n` withholding of bodies, votes, certificates, transition certificates, witnesses,
  proofs — each with the local suspicion rule, objective evidence rule, and the honest action.
- `REC-01`… : the Mode B fallback, explicitly labelled **not selected**, with triggers, invoker,
  delays, checkpoint boundaries, late-evidence handling, replay, and rollback limits (conditional,
  no invented universal economic bound).

### ECON — economics and slashing (D7)
stake ledger custody; rewards and their funding identity; offence catalogue with evidence encoding,
submitter, deadlines, collateral consumed, recipient/burn split, duplicate handling, invalid
accusation cost; slashing vs user compensation (explicit non-coverage); withdrawal delay;
concentration/borrowing/delegation analysis; TAIKO price volatility; minimum stake derivation.

### MIG / GOV
migration boundary from today's Inbox (`propose()`/`prove()` at `7718753c1`); treatment of
pending proposals, unproven batches, bonds, bridge messages, withdrawals; exact upgrade list for
SignalService/Bridge/vaults with storage-layout compatibility; removal of operational privileges
(ProverWhitelist, ProposerChecker, ownership) while keeping DAO upgrade authority; program-image and
verifier upgrades; mixed-version clients.

### PARAM — parameters
Every parameter: name, symbol, unit, proposed value, derivation or source, tag. No parameter may be
presented as a measurement.

### INV / LIVE / LIM — assurance
Safety invariants (with the premises they need), conditional liveness arguments (with the exact
point at which liveness ends), proof obligations for an implementer, limitations, rejected
alternatives, and the resolution of every red-team finding.

## 4. Evidence-quality separation (mandatory in `03` and `05`)

Every feasibility claim is classified as (1) compatibility in principle, (2) evidence from existing
implementations or published benchmarks with hardware/version/methodology, (3) analytical estimate,
or (4) unmeasured implementation question. Never merge these categories.
