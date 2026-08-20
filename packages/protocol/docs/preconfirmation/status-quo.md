# Taiko Based Preconfirmation — Status Quo Assessment

> **Deliverable 1 of the preconfirmation redesign effort.** This document captures the current
> preconfirmation design and its actual implementation status across the monorepo, as of
> 2026-08-20 (`main` @ `44b3f57`). It is the factual baseline that the redesign proposal
> (`redesign-proposal.md`) builds on and diverges from.
>
> Sources: the two reference design docs (converted in [`reference/`](reference/)), the contracts
> and clients in this repository, the parked `permissionless-preconf` branch, and PRs
> [#22012](https://github.com/taikoxyz/taiko-mono/pull/22012) and
> [#22019](https://github.com/taikoxyz/taiko-mono/pull/22019).

---

## 1. Executive summary

Taiko preconfirmation today is a **whitelist-era system**: a permissioned set of operators takes
turns (one operator per 384-second beacon epoch, chosen by beacon-root randomness) being the
exclusive party allowed to call the Shasta inbox's `propose()`. Preconfirmations are emitted
off-chain over P2P by that operator and imported optimistically by nodes; **nothing about
preconfirmations is enforced on-chain**. There is no slashing, no bond at stake, no lookahead
validation, and no fair-exchange enforcement — trust in whitelisted operators substitutes for all
of it.

A complete **permissionless "Phase 2" stack was designed and built** (URC-based validator opt-in,
LookaheadStore, lookahead + preconfirmation slashers, a blacklist with overseers) — and then
**deliberately evicted from `main` in July 2026** (PR #21887, −4371 LOC) to a parked branch,
`permissionless-preconf`. The URC production-readiness review (PR #22012, open) concludes the URC
is not production-ready and recommends staying on the whitelist until multiple gates clear. This
is the strategic opening for the redesign: the Phase-2 path is blocked on an external dependency
(URC) and on L1 validator adoption; the redesign removes both dependencies.

Key facts a redesign must respect:

- The Shasta inbox is live and minimal: blob-only DA, zero on-chain content validation, atomic
  prove-and-finalize, one proposal per L1 block, bonds present but zeroed.
- The derivation rules (not the inbox) bound how *stale* a proposal's content may be:
  block timestamps may lag L1 inclusion by at most **6144 s (16 epochs) on mainnet** / 1536 s
  (4 epochs) on Hoodi, and anchors may lag the origin block by at most **512 L1 blocks on
  mainnet** / 128 on Hoodi. A 1–3 epoch delayed proposal window fits inside these bounds on
  mainnet without touching the proof system.
- The proposer-authorization surface is a single, clean seam: the immutable
  `IProposerChecker.checkProposer(proposer, lookaheadData) → endOfSubmissionWindowTimestamp`
  hook called by `Inbox.propose()`. Swapping the whitelist for an auction is, mechanically, the
  replacement of one `IProposerChecker` implementation (plus new slashing infrastructure).

---

## 2. The two reference design documents

### 2.1 Post-Whitelist Design Doc ([converted](reference/post-whitelist-design.md))

The "Phase 2" high-level design (authored ~Q1–Q2 2025). Goals: open participation ([G1]), cheap
registration ([G2]), modular contracts ([G3]). Mechanism summary:

- **URC integration**: L1 validators register batches of BLS keys (Merkle root only on-chain,
  optimistic BLS verification with challenge-based `slashRegistration`), and opt into Taiko's
  slasher contracts via URC `SlasherCommitment`s. Collateral is ETH held by the URC.
- **Preconfirmation publication/reception**: the elected preconfer's sidecar publishes a signed
  commitment to a `PreconfirmationHeader` (domain separator, chain id, L1 proposal slot
  timestamp, batch id, block hash, `eop` end-of-preconf flag) plus the tx list, over P2P. Nodes
  verify signatures against the lookahead and advance their local head optimistically.
- **Preconfirmation slashing**: equivocation between preconfirmed block hashes and the
  eventually-verified L1 batch is provable (Merkle proof against the verified L2 state showing
  `TaikoAnchor` stores a different block hash) and slashable via the URC.
- **Lookahead handling**: first preconfer of each epoch posts next epoch's lookahead
  optimistically; wrong lookaheads are retroactively slashable. EIP-7251 (MaxEB) makes the
  next-epoch proposer set unstable, which motivated EIP-7917 (deterministic proposer lookahead
  in the beacon state, co-proposed with Justin Drake); until 7917 lands, an overseer can
  overwrite invalid lookaheads.
- **Fair exchange**: the deepest unsolved problem — a preconfer can withhold preconfs to farm
  MEV. Two approaches: an overseer (governance-elected slasher key) and user oversight (nodes
  stop forwarding order flow to withholding preconfers). Suggested path is incremental,
  starting with a whitelisted overseer key.
- The PDF export is truncated: the "Inactive Preconfers" section is missing.

### 2.2 Post-Shasta Preconfirmation Slashing ([converted](reference/post-shasta-preconf-slashing.md))

A later (~09/2025), Shasta-specific slashing design:

- Two contracts: **`PreconfSlasherL2`** on Taiko (does all condition checks) and
  **`PreconfSlasherL1`** on Ethereum (executes the slash via the URC), connected by the native
  bridge. Preconfers opt into `PreconfSlasherL1` through the URC.
- Slashing reasons: **LivenessFault** (preconf'd block landed later than its submission
  window), **SafetyFault** (preconf'd content ≠ proposed content), **InvalidEOP** (blocks
  proposed after an end-of-preconf signal), **MissingEOP** (no EOP on the last block of a
  period). L1-side check drops liveness-type slashes when the preconfer's dedicated L1 slot was
  reorged out (no beacon block root).
- Requires the L1 `Proposal` struct to carry `endOfSubmissionWindowTimestamp` (**this landed**
  — see `IInbox.Proposal`), and requires `ShastaAnchor` to store per-block
  `endOfSubmissionWindowEnd` values (**this did not land** — the current L2 `Anchor` stores
  only block hashes and checkpoints).

---

## 3. What is actually implemented on `main` today

### 3.1 L1 contracts: `PreconfWhitelist` is the only live preconf contract

`packages/protocol/contracts/layer1/preconf/` contains only `IPreconfWhitelist`,
`PreconfWhitelist` (+ layout), `LibPreconfConstants`, `LibPreconfUtils`.

- **Election**: one operator per beacon epoch (384 s), selected uniformly at random from active
  whitelist operators. Randomness = `uint256(beaconRoot)` at the start of the epoch **two epochs
  earlier** (`RANDOMNESS_DELAY = 2`, EIP-4788), so the current *and* next epoch's operators are
  deterministically computable on-chain/off-chain — this **is** the lookahead in whitelist mode.
- **Membership**: `addOperator(proposer, sequencer)` (active after `OPERATOR_CHANGE_DELAY = 2`
  epochs), `removeOperator*` (immediate; reshuffles the modulo → the elected operator can change
  mid-epoch), plus an `ejecters` role set managed by owner/ejectorManager for fast ejection of
  misbehaving operators. Owner is the DAO (`controller.taiko.eth`).
- **Authorization**: `PreconfWhitelist.checkProposer(proposer, _lookahead)` requires
  `proposer == operator-of-current-epoch`, ignores `_lookahead`, and returns
  `endOfSubmissionWindowTimestamp = 0` ("Slashing is not enabled for whitelisted preconfers").
- **Deployed**: mainnet proxy `0xFD019460881e6EeC632258222393d5821029b2ac` (impl upgraded to
  Shasta by DAO Proposal0009, 2026-03-31); Hoodi proxy `0x8B969Fcf37122bC5eCB4E0e5Ad65CEEC3f1393ba`.
  Wired as the Shasta inbox's immutable `proposerChecker` in the deploy scripts.

### 3.2 The Shasta inbox (`layer1/core/impl/Inbox.sol`)

One monolithic contract handles propose, prove/finalize, forced inclusion, and bonds:

- **propose(bytes lookahead, bytes data)**: gated by `IProposerChecker`; **one proposal per L1
  block**; ring-buffer capacity (mainnet 21,600 ≈ 3 days of slots); blob-only derivation
  sources (forced inclusions first, proposer's source last); optional `deadline`; optional
  min-bond balance check (`minBond = 0` today → inert). Contents are **not validated on-chain**;
  only `keccak256(proposal)` is stored in the ring buffer, full data emitted in `Proposed`.
- **prove(bytes data, bytes proof)**: a single proof finalizes a contiguous range of proposals
  **atomically** — no stored transitions, no contest window, no cooldown. Chain-linking via
  `lastFinalizedBlockHash` + ring-buffer proposal hash. Prover gating: `ProverWhitelist` (when
  non-empty, only whitelisted provers; bond settlement skipped entirely). Proof composition
  post-Unzen: `ZkRequiredVerifier` — 2 sub-proofs, at least one ZK (SGX_GETH|SGX_RETH + RISC0|SP1,
  or RISC0+SP1).
- **Bonds** (`IBondManager` embedded, TAIKO token, gwei-denominated ledger): optimistic — no
  debit at propose; a single lazy **liveness-bond settlement** at prove time (late proof ⇒ debit
  proposer, 50% to actual prover, 50% burned); two-step withdrawal with 1-week delay. **All
  zeroed on mainnet today** (`minBond = 0`, `livenessBond = 0`, "During prover whitelist, bonds
  are not necessary").
- **Forced inclusion**: permissionless `saveForcedInclusion` (1 blob, 1 L2 block), dynamic fee
  (0.001 ETH base, doubling at 50 pending), due after 576 s (1.5 epochs), mandatory consumption
  of due items (≤10 per proposal), fees paid to the consuming proposer; per-source isolation so
  a malicious proposer cannot invalidate forced content.
- **Configured but unenforced** (flags exist, no code path uses them):
  `permissionlessProvingDelay` (5 days, intended security-council window),
  `permissionlessInclusionMultiplier` (~25.6 h, intended permissionless-proposing escape hatch
  for stale forced inclusions), and the `_proposalAge` parameter plumbed into verifiers.

### 3.3 Derivation rules — the real constraints on delayed proposing

The inbox accepts any blob content; the **derivation spec** (`docs/Derivation.md`, enforced by
node + validity proof; violations degrade a source to an empty "default manifest" rather than
reverting) is what binds preconf time to proposal time:

| Rule | Mainnet | Hoodi |
| --- | --- | --- |
| Block timestamp lower bound: `≥ proposal.timestamp − TIMESTAMP_MAX_OFFSET` | 6144 s (16 epochs) | 1536 s (4 epochs) |
| Block timestamp upper bound | `proposal.timestamp` | same |
| Anchor max age: `≥ proposal.originBlockNumber − MAX_ANCHOR_OFFSET` | 512 L1 blocks (~102 min) | 128 (~25.6 min) |
| Anchor must not be in the future | `≤ proposal.originBlockNumber` | same |
| Anchor must advance per proposer source | yes (forced inclusions exempt) | same |
| Per-source block cap | 768 (post-Unzen) | same |

**Implication**: proposing epoch-N blocks in a window `[T + 384·d, T + 384·(d+s))` is compatible
with current derivation for `d + s ≲ 14` on mainnet (leaving anchor-freshness headroom), but only
`d + s ≲ 2–3` on Hoodi unless Hoodi's constants are raised. The L2 `Anchor` contract and the
proof system need no changes for delay alone.

### 3.4 L2 side

`layer2/core/Anchor.sol` (`anchorV4`) only maintains ancestor-hash commitments, parent block
hashes, and saves L1 checkpoints. **No bond management, no per-block submission-window storage,
no slashing hooks exist on L2.** (An earlier Shasta iteration's L2 `BondManager` survives only as
a stale layout file and Go binding.) The slashing design doc's `ShastaAnchor` changes were never
merged.

### 3.5 The parked permissionless stack (`permissionless-preconf` branch)

Built Sep–Nov 2025, removed from `main` 2026-07-04 (#21887). Architecture (verified from the
branch):

- **`LookaheadStore`** (implements `IProposerChecker` + `ILookaheadStore`): per-epoch lookahead
  of `LookaheadSlot {committer, timestamp, registrationRoot, validatorLeafIndex}` for slots whose
  L1 proposer opted in via URC; only a 26-byte hash stored per epoch (503-entry ring buffer),
  full data re-supplied as calldata. First preconfer of each epoch must post next epoch's
  lookahead (signed as a URC commitment; whitelist fallback posts unsigned). Submission windows:
  a slot-i preconfer may propose from just after the previous opted-in slot through its own slot
  (advance/cross-epoch proposing supported). Eligibility: URC registration age, not slashed, not
  opted out, **min collateral 1 ETH**, not blacklisted.
- **Fallback**: when the lookahead is empty/exhausted or the scheduled operator is blacklisted,
  the **`PreconfWhitelist` operator of the current epoch** becomes the preconfer — i.e. the
  whitelist remains load-bearing even in the permissionless design.
- **Slashers**: `LookaheadSlasher` (EIP-4788 inclusion proofs of the true beacon proposer;
  evidence for invalid/missing operators), `PreconfSlasherL1`/`PreconfSlasherL2` (liveness vs
  safety fault amounts, bridge-paired), `UnifiedSlasher` (single URC `ISlasher` entry),
  `Blacklist` (owner-managed overseers eject operators). Slashed URC funds are **burned**.
- Off-chain: `overseer-rs` + URC indexer service (PR #20532, closed 2025-11).

### 3.6 PR #22012 — URC production-readiness review (open, draft)

Documentation-only PR by dantaik adding `docs/urc_production_readiness_review.md`: a review of
`eth-fabric/urc@132bc79` concluding **"Not production-ready at main HEAD"** on three grounds:
(1) process/state — repo frozen ~13 months, audits predate HEAD and are not public, no canonical
deployment, zero production users; (2) contract bugs at HEAD — notably **H-1** (self-triggerable
`slashWindow` escape granting permanent slashing immunity) and **H-2** (the opt-in
`slashCommitment` path Taiko uses lacks replay protection → one evidence pair can burn an
operator's entire collateral), plus medium/low findings; (3) immutability vs ePBS — the frozen
commitment schema has no builder/constraints notion. Recommendation: keep `PreconfWhitelist`
until the URC gates clear; keep the permissionless stack parked.

**Consequence for the redesign**: the Phase-2 path is doubly blocked — on URC maturity and on L1
validator opt-in adoption. A design that (a) does not require preconfers to be L1 validators and
(b) does not depend on the URC removes both blockers. This is precisely the redesign's premise.

### 3.7 PR #22019 — proposer auction (implementation reference only)

Open draft PR by dantaik: "Preconfer Auction — permissionless standing-bid proposer auction"
(+5,894 LOC; `ProposerAuction.sol` + design doc + 90+ tests; no deploy-script wiring yet). Per the
redesign brief, this PR is treated **only as smart-contract implementation reference**, not as a
design input. Summary of what it implements:

- A **perpetual standing-bid list** (≤16 entries, TAIKO-bonded): top ETH bid wins, second is
  designated backup; bids are a **per-epoch ETH rate** charged lazily from a prepaid balance;
  ≥5% outbid increment, EMA-based decaying reserve floor, tenure expiry + cheap `renew()`.
- Every transition takes effect at `placedEpoch + 2` epochs, so current and next epoch
  assignments are always final (≥1 epoch handover notice) — an O(1) lazy "promote, don't
  recompute" epoch-snapshot cache with bounded resumable catch-up.
- `ProposerAuction implements IProposerChecker`; a **fallback ladder** gates on winner absence:
  winner → (after ~48 s) backup → (later) any bonded operator → (later) anyone; empty list ⇒
  bonded operators immediately.
- Slashing on L1: **stall** (escrow-then-refute, refutation = canonical proposal preimage vs the
  Inbox ring buffer), **signed invalid block** and **equivocation** (EIP-712 `SignedBlock` with
  per-epoch `seqNo`); one-shot fault digests; challenger rewards; auto-ejection below bond
  threshold. Preconf *promise* slashing explicitly out of scope (future `PreconfCommitments`).
- Inbox integration: `checkProposer` wrapped in `try/catch` with a 3M gas cap and a
  permissionless escape hatch when a forced inclusion is overdue beyond ~25.6 h — this wires the
  previously-dead `permissionlessInclusionMultiplier` knob.

**Reusable patterns for the redesign implementation** (regardless of design divergence): the
pending-update overlay ("current+next are final" as a structural invariant), lazy epoch-snapshot
cache, bounded catch-up with observable skips, escrow-then-refute against ring-buffer preimages,
one-shot fault digests, fail-open checker with gas isolation, verify-time EIP-712 domains.

### 3.8 Go client (`packages/taiko-client`): preconfirmation and handover handling

The client is Shasta-only (Pacaya surface removed in v2.4.0). Preconfirmation lives in the
driver's **preconf block server** (`driver/preconf_blocks/`):

- **Block intake**: `POST /preconfBlocks` (JWT-authed) receives an `ExecutableData` payload from
  the operator's sequencing stack, validates it (first tx must be a valid golden-touch anchor tx;
  exactly one zlib-compressed RLP tx list; parent's proposal ID must not predate the latest
  on-chain proposal), inserts it into the L2 EE, then signs and gossips the envelope. An
  `endOfSequencing` flag marks the operator's final block of an epoch.
- **P2P**: forked op-node gossip stack (`taikoxyz/optimism`), four topics: payload, request-
  by-hash, request-response, end-of-sequencing request. Envelope import handles orphans, missing
  ancestors (recursive request-by-hash), and reorgs. Operator identity = the address derived
  from the node's P2P sequencer key.
- **Handover is a pure client-side convention.** `--preconfirmation.handoverSkipSlots`
  (default **8**) splits each 32-slot epoch: the epoch's operator sequences slots 0–23, and
  **the *next* epoch's operator takes over the last 8 slots** of the current epoch. Gossip
  accepts **both** the current and next operators as valid signers during the window
  (`P2PSequencerAddresses() → [CurrOperator, NextOperator]`). The lookahead loop polls
  `getOperatorForCurrentEpoch`/`getOperatorForNextEpoch` from the whitelist every ~4 s and
  computes the local slot ranges.
- **A→B handover sequence**: A posts its last block with `endOfSequencing: true` (cached per
  epoch, gossiped, WS-notified); when B's window opens, if B hasn't seen A's end-of-sequencing
  block it broadcasts a request for it; only the current operator answers; B imports it and
  builds on A's tip. `CanShutdown` on `/status` refuses shutdown within 8 slots of an owned
  window (k8s preStop integration).
- **Reconciliation with L1**: for each `Proposed` event the driver re-derives the blocks and
  compares block-by-block with the canonical (preconf) chain. Match ⇒ only L1Origin metadata is
  updated (preconf honored). Mismatch ⇒ derived blocks are inserted, **reorging out** the
  divergent preconf blocks, and the preconf server resets its unsafe-head watermark
  (`PreconfChainReorged`). L1 reorgs of the proposal itself roll the head L1 origin back.
- **The only protocol-side handover datum the client consumes** is
  `endOfSubmissionWindowTimestamp` from the `Proposed` event. Note the plumbing dead-end: the
  driver threads it all the way into `AssembleAnchorV4Tx`, but the actual `anchorV4` contract
  call only passes the checkpoint — **the deadline never reaches L2 state** (the missing piece
  the slashing design needs). The client enforces **no** anchor-recency or timestamp-vs-slot
  checks at preconf time — those bite later, at derivation of the on-chain proposal.
- The Go proposer proposes from mempool content and gates on
  `GetPreconfWhiteListOperator() == own address`; in production the operator's own sequencing
  stack proposes the preconf'd blocks (outside this repo).

**Redesign-relevant consequences**: (a) the handover machinery keys entirely off "who is the
operator of epoch E / E+1" reads from a contract — an auction contract exposing the same
current/next queries slots in with modest client changes; (b) the reorg-reconciliation path
already handles "on-chain proposal ≠ preconf'd blocks", which is exactly what a forced
re-proposal by a successor preconfer would look like to nodes (only if content matches is the
preconf chain preserved); (c) end-of-sequencing markers exist and map naturally onto EOP-style
handover semantics.

### 3.9 Rust client (`packages/taiko-client-rs`) and other packages

The Rust client is Shasta-only with three roles: `proposer`, `driver`, and
`whitelist-preconfirmation-driver` (no prover crate). Its preconf sidecar reaches near-parity
with the Go server on the data plane — same P2P topic strings (native libp2p gossipsub + discv5),
same REST/WS API shape, envelope validation, orphan/ancestor recovery, stale-boundary
enforcement — but **deliberately has no lookahead and no handover loop**: "Catalyst owns
handover" — the external sequencer stack supplies build parent hashes, and the driver only
*serves* end-of-sequencing requests, never issues them. Gossip signatures are validated against
the **whole whitelist roster** (any operator accepted), not the specific epoch's operator. A
coarse time-based shutdown guard (`HAND_OVER_WINDOW_SLOTS = 8`) substitutes for lookahead
awareness. Its proposer gates on `getOperatorForCurrentEpoch() == self`, with a permissionless
bypass when the oldest forced inclusion is overdue. Well-documented invariants
(`docs/agents/whitelist-preconfirmation-invariants.md`, WLP-INV-001..010) govern the preconf and
event-sync paths. Its permissionless-preconf support was likewise moved to a branch (#21908).

Also relevant: **`packages/ejector`** — a Rust watchdog service run by operators/governance that
monitors L2 progress and reorgs and sends L1 transactions to eject misbehaving operators from
`PreconfWhitelist` (config: `HANDOVER_SLOTS` default **4** — inconsistent with the clients' 8 —
`EJECT_AFTER_SECONDS = 96`, `MIN_OPERATORS = 3`). The ejector embodies the current
social-slashing substitute: detection off-chain, punishment = removal, no economic loss.

**Redesign-relevant consequences**: the Rust sidecar's "handover-free, roster-validated,
passive importer" architecture is *closer* to what an auction design needs than the Go client's
whitelist-coupled lookahead loop; and the ejector's role (watch, then punish on L1) is the
natural seed of the redesign's *observer* role — but with on-chain slashing instead of ejection.

---

## 4. Observations that shape the redesign

1. **The `IProposerChecker` seam is the integration point.** Everything preconf-specific on L1
   funnels through one immutable hook returning one number (`endOfSubmissionWindowTimestamp`),
   which is already stored per proposal and emitted. An auction-based checker slots in without
   touching the inbox core — though the redesign's delayed windows and forced re-proposal rules
   need more than the current hook exposes.
2. **Bond machinery exists but is L1-side and dormant.** The redesign wants bonds and slashing on
   L2 with TAIKO; nothing on L2 exists today for that — it must be designed fresh (the slashing
   doc's L2-check/L1-execute split is prior art, but it slashes URC ETH collateral via the
   bridge, the opposite of the redesign's direction).
3. **No enforcement of preconf promises exists anywhere on-chain today**; the whitelist plus
   social/ejection pressure is the entire security model. Any redesign with real slashing is a
   strict improvement on this axis, even with small bonds.
4. **Derivation timing bounds, not the inbox, cap the delayed-window parameters** (`d + s`) —
   mainnet has ample room; Hoodi as configured does not.
5. **The whitelist-fallback pattern is deeply embedded** (contracts and clients): the parked
   permissionless design still falls back to the whitelist. The redesign replaces this with a
   "Total Anarchy" permissionless fallback — a materially different liveness posture that the
   clients' operator-resolution logic must learn.
6. **Fair exchange remains unsolved in every prior design** — overseer/user-oversight were the
   proposals; the redesign must either address preconf withholding/timeliness or explicitly
   scope it out.

---

## 5. Validation of the redesign premises against the current system

The redesign brief proposes: a perpetual auction open to anyone (not just L1 validators);
per-epoch preconfing rights with a **delayed proposal window** `[T + 384·d, T + 384·(d+s))` for
epoch `[T, T+384)`; proofs carried inside `propose()`; slashing by observers on L2 with TAIKO
bonds; forced re-proposal of a failed epoch by the successor (rewarded with 50% of the slash);
Total Anarchy fallback when no preconfer exists; and a proof-gate co-signature on proofs
initially. Verification against the code:

**Verified feasible as-is:**

- *Delayed windows fit mainnet derivation bounds.* `TIMESTAMP_MAX_OFFSET` (16 epochs) and
  `MAX_ANCHOR_OFFSET` (512 L1 blocks) allow `d + s ≲ 14`. Hoodi (4 epochs) needs its constants
  raised — a config change, not a design change. Anchors are chosen at preconf time, so L1→L2
  deposit latency *at the preconf level* is unchanged by delay.
- *The auth seam is ready.* An auction contract implementing `IProposerChecker` replaces the
  whitelist without touching the inbox core; `endOfSubmissionWindowTimestamp` already flows into
  proposals, events, and the anchor tx.
- *Sequential proposal chain gives "successor must fill the gap" for free.* Proposals form a
  hash-linked chain; epoch N+1's proposals cannot exist until epoch N's slots in the chain are
  filled. The "next preconfer must propose FOR the failed one, else his own can't land" rule is
  structural, not an added enforcement.
- *The client reorg-reconciliation path already handles re-proposals.* Nodes re-derive every
  on-chain proposal and keep the preconf chain only if content matches — exactly the behavior a
  successor's faithful re-proposal needs.
- *Proof-carrying proposals would even permit an all-L2 auction.* Because `prove()` (today)
  saves L2 checkpoints on L1, and proof-carrying proposals make finalization instant, an L1
  `checkProposer` could verify "X is the winner for epoch N" via a Merkle proof against a
  finalized L2 checkpoint — so an auction/bond ledger hosted on L2 is *technically feasible*,
  with the transition delay `q` absorbing the finalization lag. **Note:** this is a
  feasibility observation only; the resolved decision (§6, and the redesign proposal §4) is
  the opposite placement — the **auction and bond ledger live on L1**, and only the slashing
  *conditions* are checked/proven on L2 — because the auction must keep operating even when
  the L2 itself is degraded or halted, which an L2-hosted auction cannot guarantee.

**Challenges the design must answer (to be treated in the proposal's game-theory section):**

1. **Proving latency becomes consensus-critical.** With `d = 2, s = 1`, the proof of epoch N's
   last block must be on-chain within ~12.8 min of epoch end. Feasible with current zkVMs but
   tight; a prover outage converts into a liveness slash. Parameter choice (`d = 3` or `s = 2`)
   and/or an explicit grace path matter. The successor's burden doubles during recovery (prove
   two epochs in one window).
2. **"Re-propose the same proposals" is only enforceable for published data.** If the failed
   preconfer withheld its blocks entirely, the successor cannot reproduce them; the design needs
   a deterministic gap-seal (e.g. forced-inclusion-only proposals) plus slashing of the
   withholder via users' signed preconf commitments.
3. **Bond floor is bounded below by attack economics, not gas.** The bond must exceed (a) the
   successor's recovery cost (blobs + gas + proving two epochs; the 50% reward must clear this)
   and (b) the MEV extractable by equivocating on one epoch of preconfs. "Small initially" is
   fine only while preconf'd value is small; the proposal must state the scaling rule.
4. **Forced-inclusion timing interacts with delay.** A preconfer must know, at preconf time,
   every forced inclusion that will be *due* during its proposal window; this requires
   `forcedInclusionDelay ≥ (d + s + 1)·384 s` (≈ 26 min for d=2, s=1 — up from 9.6 min today).
5. **Proof-gate liveness.** If the gate key goes silent, nobody — including Total Anarchy
   proposers — can propose. The gate's failure policy (halt vs. timeout-bypass vs. DAO hot-swap)
   must be explicit.
6. **Wealth-based incumbency.** A perpetual auction has no built-in rotation; a deep-pocketed
   bidder can hold the seat indefinitely. This is an accepted trade (vs. L1-validator alignment)
   but should be stated, and mitigations (fee escalation, tenure caps) considered.
7. **Fair exchange (timely preconf release) is still unsolved** — the auction slashes provable
   equivocation and missed windows, but not withholding-before-L1-submission. Scope decision
   required.
8. **Handover changes meaning.** Today's `handoverSkipSlots = 8` exists so the outgoing operator
   can land its proposal before losing rights; with delayed windows that motivation disappears —
   handover becomes a pure sequencing-tip handoff (plus retained proposal windows for the
   outgoing preconfer's final epochs). Client logic simplifies but must be rewritten around
   "sequencing epoch" vs. "proposal window" as distinct concepts.

## 6. Open questions — resolved

The four design-shaping questions were put to the project owner (2026-08-20) and answered:

1. **Auction pricing** → the winning bid is a **per-epoch fee in ETH, paid to the
   treasury/DAO** (the TAIKO bond is a separate, slashable security deposit).
2. **Placement of auction + bonds** → **auction and bond ledger live on L1**; slashing
   *conditions* are checked/proven **on L2**, and the verdicts are bridged/proven up to L1
   where the bond is seized.
3. **Fair-exchange scope** → **out of scope for v1**. Rely on reputation and order-flow response
   initially; the design keeps hooks (timestamped signed commitments) so timeliness enforcement
   can be added later.
4. **Proof gate** → **removed entirely**. Instead of a co-signature on proofs, the bootstrap
   safety mechanism is a **temporary allowlist on auction participation**: only allowlisted
   addresses can join the auction (and, during this phase, act in the permissionless fallback);
   the allowlist is removed entirely once the proof system and protocol mature.

Assumptions confirmed by silence (stated in the assessment and not corrected): single standing
seat (per-epoch granularity, winner persists across epochs until outbid/quit with delay
`q·384 s`); the `PreconfWhitelist` rotation contract is fully retired (the temporary bidder
allowlist is a different, simpler object); Hoodi derivation constants raised toward mainnet
values; initial `d`, `s`, `q` fixed in the proposal.
