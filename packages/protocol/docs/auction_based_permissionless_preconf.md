# Auction-Based Permissionless Preconfirmation for Taiko

**Status:** Research report & design proposal — draft for review. An adversarial design review has been completed; its Critical/High findings (reorg-robust stall evidence, real escape-hatch enforcement, bond escrow + sizing) are integrated in §4.4/§4.5/§4.8.
**Scope:** An alternative to the URC (Universal Registry Contracts) based permissionless-preconf stack for Taiko Alethia, using an **ETH auction** for preconfer/proposer rights at epoch granularity, **TAIKO staking with slashing** for liveness, and an **automatic backup/fallback ladder** so the chain never stalls when the current preconfer is offline. Liveness is the #1 design goal; efficiency comes second.
**Related:** [PR #22012 — URC production-readiness review](https://github.com/taikoxyz/taiko-mono/pull/22012); [eth-fabric/urc](https://github.com/eth-fabric/urc); parked branch `permissionless-preconf`; in-repo precedents `ProverAuction` (worktree `multi-prover-auction`) and `LibBonds.settleLivenessBond`.

---

## 0. Bottom line

1. **The URC-based permissionless design is blocked** on three fronts (detailed in PR #22012): the URC contract is not production-ready (2 High + 3 Medium findings, frozen repo, unaudited-at-HEAD, zero production deployments), and the design's *consensus-layer dependencies* (beacon validator lookahead, hard-coded slot anatomy, RLP header parsing, proposer commitments) are exactly the parts Ethereum is about to reshape (ePBS, FOCIL, shorter slots, eventually Orbit SSF/SSLE).
2. **Taiko does not need the consensus layer for permissionless preconfirmation.** Taiko already has all the primitives that matter: (a) *based, permissionless inclusion* — any L1 proposer can include a Taiko proposal; (b) *forced inclusion* — users can force their txs into the next proposal; (c) *TAIKO bonds with liveness slashing* (prover liveness bonds, `LibBonds.settleLivenessBond`); and (d) an in-repo auction pattern to copy (`ProverAuction` on the `multi-prover-auction` worktree).
3. **Proposed design ("Preconfer Auction"):** an L1 contract runs a **perpetual standing-bid auction** for the exclusive right to propose/preconfirm: the top ETH bid is the winner **until outbid, quit, or expiry**, with control changes quantized to epoch boundaries (32 slots, 384 s) behind a short bid-freeze, and the bonded runner-up inheriting automatically (empty list → total permissionless mode). The winner must additionally post a **TAIKO liveness bond** and is **slashed on liveness faults** (stall without proposing). If the winner stalls, a **ladder of backups** takes over automatically — first the bonded runner-up, then any bonded operator, then *anyone* (permissionless fallback), with forced inclusion as the final guarantee. All liveness faults are provable from **L1 state only** (a checker-maintained `lastProposalAt` timestamp written atomically with each proposal, plus a 1-epoch refute window before stall slashes settle) — no beacon lookahead, no consensus structures.
4. **The chain's liveness never depends on the auction winner.** It inherits Ethereum's liveness, exactly as based sequencing does today. The auction only determines *who gets the privileged, profitable right to sequence first*; the fallback ladder guarantees someone else can always step in.
5. **Migration is incremental** and reuses the deployed `PreconfWhitelist` as a bootstrap: enforce the existing (but unenforced) permissionless escape hatch → deploy the auction in shadow mode → switch `proposerChecker` → open bidding to everyone.

---

## 1. Requirements

From the product brief:

- **Permissionless:** anyone (not a permissioned set) must be able to become the preconfer/proposer. No governance whitelist as the long-term mechanism.
- **Auction-based rights:** ETH stakers/holders auction the right to be the preconfer/proposer **at the correct granularity** (this report argues: a **perpetual auction** — incumbent keeps the right until outbid, quit, or expiry — with control changes quantized to epoch boundaries, and intra-epoch resale possible later).
- **TAIKO staking for liveness:** participants must place TAIKO stake; **liveness faults must be slashable**.
- **Liveness #1:** if the current preconfer/proposer goes offline, another party must be able to serve as backup automatically. Efficiency (MEV capture, ordering quality) is secondary to the chain never stalling.
- **No consensus-layer dependence:** the design must not depend on knowing future L1 proposers (lookahead), on proposer commitments, or on the current block anatomy, because ePBS/FOCIL/SSF are coming.

---

## 2. Current state of the system (repo-grounded)

### 2.1 The protocol (Shasta / "Alethia" v3)

- `Inbox.propose(bytes _lookahead, bytes _data)` (`packages/protocol/contracts/layer1/core/impl/Inbox.sol`) accepts **one proposal per L1 block** (`block.number > _lastProposalBlockId`), stores a **hash-only ring buffer** (mainnet: 21,600 = 3 days at 1 proposal/slot), and emits `Proposed`.
- Every proposal carries `endOfSubmissionWindowTimestamp` — "the last slot timestamp where the current preconfer can propose; 0 for whitelisted preconfirmations" (`packages/protocol/docs/Derivation.md`). This is the existing hook for window-based fallback.
- **Proposer authorization** goes through `IProposerChecker.checkProposer(msg.sender, _lookahead)`, called **unconditionally** inside `_buildProposal`. Today on mainnet the checker is the permissioned `PreconfWhitelist` (proxy `0xFD01...b2ac`, 4 operators added).
- **Forced inclusion** (`LibForcedInclusion`, `saveForcedInclusion`): users pay a fee (mainnet base 0.001 ETH, scaling linearly with queue length, doubling threshold 50) to force their txs into the next proposal; a proposer must consume due inclusions (up to 10/proposal). Delay: 576 s (1.5 epochs).
- **Permissionless escape hatch (designed but not enforced):** `permissionlessInclusionMultiplier: 160` on mainnet (~25.6 h) — the intent was that if forced inclusions are overdue by `forcedInclusionDelay × multiplier`, *anyone* may propose. The current Inbox calls `checkProposer` unconditionally and the knob is stored but never enforced (kimi-k3 audit finding I-01; the test `test_propose_RevertWhen_NonProposerEvenIfForcedInclusionTooOld` codifies that this is currently disabled). **Enforcing this escape hatch is a prerequisite for any liveness-first design.**
- **TAIKO bonds & liveness slashing already exist for provers:** `LibBonds.settleLivenessBond` debits the **proposer's** bond when proving is late and credits the prover, **50/50 payee/burn** (`packages/protocol/contracts/layer1/core/libs/LibBonds.sol`). Tokenomics whitepaper (`packages/protocol/docs/tokenomics-whitepaper.tex`): Liveness, Validity, and Contestation bonds in TAIKO; forfeited bonds go to the Taiko Treasury. *(Note: mainnet currently deploys with `minBond = 0` / `livenessBond = 0` while the prover whitelist is in use — the mechanism exists and is tested but is dormant on mainnet today; see `MainnetInbox.sol`.)*
- **Prover auction precedent (worktree `multi-prover-auction`, branch `taiko-alethia-protocol-v3.0.0-prover-auction-2`):** `ProverAuction.sol` already implements, in-repo: TAIKO bond requirement (`requiredBond = livenessBond × bondMultiplier × 2`), a fee undercutting auction (min reduction 5%), pooled multi-prover weighted selection, **vacancy fee-doubling for liveness**, exponential moving-average floor to stop manipulation, per-failure slashing (`slashProver`, `rewardBps` to challenger), ejection below a bond threshold, and withdrawal delays. This is the mechanical template for the preconfer auction.

### 2.2 The permissioned preconf system (live)

`PreconfWhitelist` (`packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol`):

- An owner/ejecter-managed set of operators (`proposer` + `sequencer` addresses).
- One operator per epoch, chosen **pseudo-randomly from the beacon block root** (EIP-4788 contract) with a 2-epoch randomness delay — i.e., even the *permissioned* system already has a consensus-layer touchpoint.
- `checkProposer` reverts unless the caller is the current epoch's operator; returns `endOfSubmissionWindowTimestamp = 0` ("slashing not enabled for whitelisted preconfers").
- **Liveness gap:** if the selected operator is offline, no one else can propose for the rest of the epoch (6.4 min), and forced inclusions wait for the next epoch's operator. There is no automatic intra-epoch fallback. (An "ejecter" can remove an operator, but only with another active operator remaining, and only between epochs.)
- **Client history:** the client previously maintained an L1 proposer *lookahead* sliding window for preconf validation; that was replaced by the sequencer allowlist (#21329), and the permissionless lookahead work moved to the parked branch (#21908).

### 2.3 The parked permissionless design (URC-based)

Branch `permissionless-preconf` (moved off main 2026-07-04) implements the "lookahead" design:

- `LookaheadStore` derives proposer eligibility **from the beacon proposer schedule**: operators register BLS keys + collateral in a URC registry; an off-chain builder maps the beacon lookahead (1-2 epochs ahead) to opted-in operators; sparse per-slot entries are posted on-chain (hash only) and enforced by slashing challenges against **EIP-4788 beacon roots and RLP-parsed execution headers** (`PreconfSlasherL1/L2`, `LookaheadSlasher`, `UnifiedSlasher`, `LibBeaconMerkleUtils`, `LibBlockHeader`).
- Submission windows are derived from each operator's own beacon slot ("advance proposals" allowed; deadline = the operator's slot). Empty lookaheads fall back to a whitelisted "fallback preconfer" (`isFallback`). Blacklist overseers for subjective faults.
- A dedicated libp2p preconf gossip network (`packages/preconfirmation-p2p`) and a Rust preconfirmation driver exist.
- The full design doc: `packages/protocol/docs/preconfirmation_lookahead.md` (on the branch), including its own §10 review listing known bugs (blacklist eligibility, non-domain-separated poster signatures, fallback posting not slashable).

**Consensus-layer dependencies of the parked design** (each one is a future liability):

| Dependency | Where | Why it's fragile |
|---|---|---|
| Beacon proposer lookahead (2 epochs) | off-chain builder + `LookaheadStore`; client keeps a sliding lookahead window | EIP-7917 (Fusaka) made the lookahead deterministic + EVM-readable, but ePBS (Glamsterdam, H2 2026) splits proposer from builder, APS/execution tickets separate the execution proposer entirely, and SSLE (Beam Chain, ~2029+) encrypts the schedule — lookahead is a shrinking, eventually dead assumption |
| Exact slot timing (`SLOT_TIME = 12`) | `LibPreconfConstants`, slashers | EIP-7782-style slot shortening breaks hard-codes |
| Execution-header anatomy (RLP field indices) | `LibBlockHeader`, slashers | ePBS changes payload/block anatomy |
| EIP-4788 beacon roots + Merkle proofs | `LibEIP4788`, `LibBeaconMerkleUtils` | survives, but everything built on top of it is fork-coupled |
| BLS12-381 precompiles (EIP-2537) | `LibBLS12381`, URC | fine technically, but URC's signing scheme is non-RFC-9380 and needs the unmerged `signing-domain` branch |
| Proposer commitments to include preconf'd txs | URC commitment semantics | ePBS moves enforcement onto proposer→builder; URC `Delegation`/`Commitment` schema has no builder/constraints notion and is frozen at deploy |

And on top of all that, the URC contract itself is not production-ready (PR #22012): frozen main ~13 months; README still says "not audited and is not ready for production use"; both audits predate HEAD and are unpublished; two High bugs (self-triggerable global slash-window escape → permanent immunity; opt-in `slashCommitment` has no replay guard → collateral can be burned repeatedly), three Mediums (delegation doesn't bind the slasher; cross-deployment signature replay → wrongful equivocation slashing; getters misreport slashability); no canonical deployment; zero production users.

### 2.4 What this report reuses

- `Inbox` + `IProposerChecker` + `endOfSubmissionWindowTimestamp` semantics — the fallback mechanism slots into the existing interface.
- `LibBonds` TAIKO bond ledger (deposit/withdraw/withdrawal-delay) — the liveness stake.
- Forced inclusion + its fee scaling — the ultimate liveness/censorship guarantee (unchanged).
- `ProverAuction` mechanics — the auction/bond/slash/ejection template.
- The p2p preconf gossip network + Rust preconf driver — the winner's service, unchanged (only *who runs it per epoch* changes).
- `PreconfWhitelist` — repurposed as a bootstrap "designated fallback" set during migration; its per-epoch beacon-random rotation becomes unnecessary, so the design also *removes* a consensus touchpoint.


---

## 3. External research synthesis

### 3.1 The URC, precisely (what it is and isn't)

From a fresh clone of [eth-fabric/urc](https://github.com/eth-fabric/urc) at `132bc79`:

- **The URC repo is small:** `src/Registry.sol` + `IRegistry.sol`, `ISlasher.sol`, `lib/BLS.sol` + `lib/BLSUtils.sol`, `lib/MerkleTree.sol`, and two *example* slashers (`InclusionPreconfSlasher`, `StateLockSlasher`). **There is no "gateway", "forwarder", or "lookahead" in URC** — those live in eth-fabric's constraints-specs / Commit-Boost work and in *Taiko's own* contracts (`LookaheadStore` etc.).
- **Enforcement model:** operators stake ≥1 ETH and register BLS keys; three fault classes — registration fraud, equivocation (two commitments, same slot), and commitment breaks — enforced through pluggable `ISlasher` contracts, with half-burn/half-reward for fraud/equivocation and full burn for commitment breaks; 7200 s windows.
- **Consensus-layer coupling (verified in code):** EIP-2537 BLS precompiles (`evm_version = prague`), hard-coded `SLOT_TIME = 12` and beacon genesis timestamps, EIP-4788 beacon-root lookups, and reorg/finality assumptions (`JUSTIFICATION_DELAY = 32` slots, `blockhash` 256-block lookback). The *validator lookahead* dependency is not in URC itself — it is in Taiko's `LookaheadStore`/`LibEIP4788` (SSZ Merkle proofs against the beacon proposer schedule, anchored to EIP-4788).
- **Production readiness:** agrees with PR #22012 — last commit 2025-07-07 (~13 months frozen), README disclaims production use, "Audit 3" incomplete, unmerged `signing-domain` branch, no deployment addresses, no git tags, zero production users.
- **Taiko wiring today:** the URC pin exists in `packages/protocol/package.json` (`urc#main`), but the URC-importing contracts live **only on `origin/permissionless-preconf`**; commits #21887/#21908 moved the permissionless stack out of `main`. **Current main has zero URC references** — only the whitelist-based `PreconfWhitelist` (no slashing), plus an empty `urcindexer-rs/` placeholder. Taiko has, in effect, already pivoted the shipped path away from URC.

**Conclusion:** the URC is a plausible *future standard* (its core is fork-agnostic), but it is not available today, and Taiko's consensus-coupled parts (lookahead store + slashers) are the fragile layer — not just legally/operationally (unaudited) but structurally (ePBS/ET split "who proposes" from "who controls inclusion"; FOCIL breaks the liveness-vs-safety fault taxonomy; SSF reshapes slot/epoch/finality constants). The full verified deep-dive (component tables, code quotes, fault mechanics, fork impact) is kept as a companion: `packages/protocol/docs/urc_research_report.md`.

### 3.2 Auction-based sequencing precedents (synthesis)

- **MEV-Boost / PBS:** per-slot *sealed-bid first-price* block-space auction via trusted relays; bids paid through the block coinbase; no on-chain durable assignment. Proven: auctions internalize MEV. Wrong layer for Taiko (relay trust; no rights registry). ([Flashbots guide](https://writings.flashbots.net/beginners-guide-mevboost), [trust assumptions](https://collective.flashbots.net/t/what-trust-assumptions-exist-in-proposer-builder-separation-pbs/151))
- **ePBS (EIP-7732):** enshrines per-slot builder auctions — builders bid in ETH via `ExecutionPayload`, proposer picks the highest, forced payment + Payload Timeliness Committee + builder-less fallback. Validates the "auction decides who builds; protocol enforces timeliness with a fallback" pattern. ([EIP-7732](https://eips.ethereum.org/EIPS/eip-7732))
- **Execution tickets (Neuder/Drake) & SUAVE:** auction *execution rights at epoch granularity* to third parties; proceeds go to the protocol; secondary ticket market. The epoch-granularity rationale (amortize overhead, smooth MEV variance, enable planning) transfers directly to this design. ([Execution Tickets](https://ethresear.ch/t/execution-tickets/17944), [economic analysis](https://ethresear.ch/t/economic-analysis-of-execution-tickets/18894), [execution auctions alternative](https://ethresear.ch/t/execution-auctions-as-an-alternative-to-execution-tickets/19894), [SUAVE](https://writings.flashbots.net/the-future-of-mev-is-suave))
- **Spire Labs based-stack:** the closest live precedent — auctions **based-sequencing "preconf slots"**, preconfers post collateral, bids in **ETH on L1**, revenue to protocol, **fallback = anyone-can-propose** plus fallback preconfers. ([Spire based sequencing](https://docs.spire.dev/based-stack/based-sequencing), [preconfirmations](https://docs.spire.dev/based-stack/preconfirmations))
- **Espresso marketplace:** shared-sequencing rights auctioned per period, permissionless BFT fallback. ([The Block](https://www.theblock.co/post/283558/espresso-raises-28-million-in-series-b-round-for-shared-sequencing-marketplace))
- **Liveness-first design lineage:** Max Resnick's **MEV-Boost+/++** — proposers commit to blocks and are *slashed for missed commitments* instead of trusting relays; "liveness over efficiency". ([EigenLayer forum](https://forum.eigenlayer.xyz/t/mev-boost-liveness-first-relay-design/14197), [proposer slashing](https://research.eigenlayer.xyz/t/how-does-proposer-slashing-work-in-mev-boost/30))
- **Ahead-of-Time Block Auctions** ([ethresearch 21345](https://ethresear.ch/t/ahead-of-time-block-auctions-to-enable-execution-preconfirmations/21345)) and **multi-round MEV-Boost** ([20091](https://ethresear.ch/t/based-preconfirmations-with-multi-round-mev-boost/20091)) — auctioning *future* block rights to enable execution preconfirmations; supports the same conclusion: the *auction/marketplace layer can be an L1 contract*.
- **Based-preconf literature:** Justin Drake's [Based preconfirmations](https://ethresear.ch/t/based-preconfirmations/17354) — L1 proposer as shared sequencer, preconfer commits and is slashed for violations; the enforcement half is the consensus-coupled part, which this design replaces with economic (bond) enforcement.
- **Liveness mechanisms elsewhere:** Arbitrum delayed inbox (~24 h force-inclusion), Optimism forced transactions, Cosmos downtime slashing → jail. Taiko's forced inclusion + fee-doubling is already in the same family; the *combination* of auction + bond + ranked fallback + anyone-can-propose is what this proposal adds.

**Common pattern across precedents:** auctioned = sequencing/preconf rights for a *window*; granularity per-slot→per-epoch; bid asset ETH; revenue → protocol/treasury/burn; fallback = anyone-can-propose or BFT committee; slashing = separate collateral from the bid. **Taiko's niche: the only design where the entire auction + collateral + slashing + fallback lives in the rollup's own L1 contracts**, reusing `ProverAuction` + `settleLivenessBond` + `LookaheadStore` primitives.

### 3.3 What the consensus layer can and cannot provide (long-term)

**Fork timeline (as of this report):** Pectra (May 2025) → **Fusaka (Dec 3, 2025 — live)** → **Glamsterdam (H2 2026)** — ePBS (EIP-7732) + Block-level Access Lists (EIP-7928) + gas-limit raise; publicly in "final devnet" stage with slippage risk ([CoinDesk, Jun 2026](https://www.coindesk.com/tech/2026/06/16/ethereum-s-biggest-protocol-overhaul-in-years-moves-into-its-final-development-stage), [thirdweb](https://blog.thirdweb.com/ethereum-glamsterdam-upgrade-explained-how-epbs-and-eip-7732-will-transform-block-production-for-developers/)) → **Hegotá (late 2026)** — FOCIL (EIP-7805) ([KuCoin](https://www.kucoin.com/news/flash/ethereum-to-introduce-censorship-resistant-focil-in-2026-hegota-upgrade); PR #22012's internal "~2027" is the conservative read) → **Beam Chain / Orbit SSF ~2029+** — single-slot finality and likely Single Secret Leader Election (SSLE) ([Orbit SSF](https://ethresear.ch/t/orbit-ssf-in-practice/20943)).

**Safe to rely on (long-term):**

1. **L1 inclusion of any paying tx** — whoever builds/proposes L1 blocks includes profitable txs, independent of proposer identity. This is what based sequencing rides on.
2. **Bonded-collateral slashing via an on-chain registry** — the *only* enforcement primitive that exists for broken preconf commitments. It is **consensus-independent**: ePBS, FOCIL, SSF and SSLE do not touch it. Consensus-layer slashing of validators for broken preconfs **does not exist and is not on any roadmap** (ePBS only deducts builder stake in-protocol; FOCIL only withholds attestations).
3. **Stable EVM primitives:** EIP-4788 beacon roots (as randomness/anchoring), `block.timestamp`/`block.number`/`blockhash`, KZG blob commitments — stable across all known forks.
4. **Inclusion lists (EIP-7547 → FOCIL/EIP-7805, Hegotá):** fork-choice-enforced ILs = protocol-level forced inclusion of mempool txs; the right future backstop for based rollups (composes with Taiko's forced inclusion).
5. **EIP-7917 deterministic proposer lookahead (shipped in Fusaka):** makes the 2-epoch lookahead deterministic and EVM-readable via beacon-root Merkle proofs — *if* a design ever needs proposer knowledge (this one doesn't). ([EIP-7917](https://eips.sh/eip/7917), [Magicians](https://ethereum-magicians.org/t/eip-7917-deterministic-proposer-lookahead/23259))
6. **BALs (EIP-7928, Glamsterdam):** a canonical, proof-friendly record of per-tx state changes — drastically cheaper on-chain proofs of *broken execution* preconfs (useful for v2 promise enforcement, §4.6). ([BALs for Proposer Commitments](https://ethresear.ch/t/bals-for-proposer-commitments/23095))
7. **Neutral commitment middleware** (Commit-Boost) and restaking rails (EigenLayer/Symbiotic) — mature, consensus-agnostic (used by Bolt, Primev, Luban, Puffer). ([Commit-Boost](https://ethresear.ch/t/commit-boost-proposer-platform-to-safely-make-commitments/20107))

**Unsafe / must not hard-depend on:**

1. **Plaintext or long-horizon proposer identity.** The lookahead is only ~2 epochs and EIP-7917 makes it readable, but **SSLE (~2029+) will encrypt the schedule**, and **APS/execution tickets would separate the execution proposer from the validator entirely**. Nethermind's *Future-Proofing Preconfirmations* identifies SSLE and APS/ePBS as the largest compatibility threats to proposer-identity-based preconf designs, and FOCIL/ILs as broadly compatible. ([22618](https://ethresear.ch/t/future-proofing-preconfirmations/22618))
2. **"The L1 validator includes my execution."** Under ePBS the beacon proposer commits to a builder's *bid* without seeing the payload (builders are staked ~1 ETH entities; enforcement = fork-choice via Payload Timeliness Committee + balance deduction — **no slashing**). A preconf design should commit against *inclusion*, not against validator-controlled execution.
3. **In-protocol slashing of L1 validators for broken preconfs** — has never existed; do not assume it. Slashing must live in opt-in collateral + an EL registry contract.
4. **Fork-timing precision** — treat H2 2026 (Glamsterdam) / late 2026 (Hegotá) as near-term but date-uncertain; the design must work *today* (post-Fusaka, pre-ePBS/FOCIL).

**Implication for this design:** the Preconfer Auction deliberately uses **only items 1-3 of the safe set** (inclusion, registry-collateral slashing, stable EVM primitives) and treats items 4-7 as optional future upgrades (Phase 4). That is precisely the *inverse* of the parked URC design, which hard-depends on the unsafe set. The community literature supports the framing: Drake's based-preconf blueprint prices **liveness faults** for accident risk and fully slashes **safety faults**; Barnabé's *Preconfirmations under the NO lens* warns that slot-exact guarantees and preconf oracles are economically fragile — which is why this design sells *epoch-level sequencing rights* and enforces promises economically rather than promising slot-exact inclusion. ([Based preconfirmations](https://ethresear.ch/t/based-preconfirmations/17354), [NO lens](https://ethresear.ch/t/preconfirmations-under-the-no-lens/19975))

---

## 4. Proposed design: "Preconfer Auction" (PA)

### 4.1 Principles

1. **Inclusion stays based and permissionless forever.** `propose` ultimately remains callable by anyone (subject to the fallback rules below). Chain liveness = Ethereum liveness.
2. **The auction sells a *privilege*, not a necessity:** the exclusive right to propose during a window, i.e. the right to capture sequencing fees/tips/MEV first. The protocol never *needs* the winner.
3. **Economic security in TAIKO, bids in ETH.** The auction price internalizes expected sequencing revenue (ETH-denominated); the TAIKO bond is the slashable liveness collateral (no yield, no "built-in PoS reward", consistent with `tokenomics_objective_metrics.md`).
4. **Every liveness fault is provable from L1 state alone.** No beacon structures, no RLP, no lookahead.
5. **Fault isolation and anti-griefing rules** are adopted from the URC post-mortem (per-fault replay guards, per-fault windows — never a self-triggerable global window — domain-separated signatures, bounded slasher set).

### 4.2 Roles and components

| Component | Type | Role |
|---|---|---|
| `PreconferAuction` | new L1 contract | auction + winner registry + backup ranking + liveness-fault slashing |
| `PreconfStaking` (or reuse the `LibBonds` ledger inside the auction) | new L1 contract | TAIKO bond ledger: deposit/withdraw with delay, slash, eject |
| `PreconfCommitments` | new L1 contract (v1) | registry of per-block promise roots (cheap), used by disputes; replaced by proving-layer enforcement in v2 |
| `Inbox` (`IProposerChecker` integration) | modified (small) | enforce the window/fallback semantics + escape hatch; gas-isolated checker call |
| Preconfer service | existing infra | `taiko-client-rs` whitelist-preconf driver + `preconfirmation-p2p`, run by the winner |
| Forced inclusion | unchanged | ultimate liveness/censorship guarantee |
| `PreconfWhitelist` | repurposed | bootstrap fallback set during migration; later retired |

### 4.3 The auction

**What is auctioned:** the ongoing right to be the *sole* proposer/preconfer. Rather than a discrete auction per epoch (13,500/yr, forced rebidding, boundary churn), the auction is **perpetual**: a ranked list of standing bids lives on-chain; the **top bid is the winner** and the **second is the runner-up**. Tenure lasts until one of four events: (1) **outbid**, (2) **voluntary quit**, (3) **expiry**, or (4) **slashing/ejection**. The right includes exclusive `checkProposer` passage during tenure, sequencing revenue (L2 basefee share, priority tips), and the preconf franchise.

**Why perpetual, with control changes quantized to epoch boundaries (the "correct granularity"):**

- **Per-slot auctions (12 s):** maximum MEV granularity but ~7,200 auctions/day, per-slot bid-sniping MEV, no infrastructure amortization. Rejected.
- **Per-epoch auctions (384 s):** fresh price discovery, but ~13,500 auctions/yr of pure overhead and forced rebidding churn — the earlier draft of this report; **too short and too frequent**, per the product brief.
- **Perpetual standing-bid (this recommendation):** near-zero overhead in steady state (a tx only when someone actually wants to displace), automatic succession via the ranked list (no re-auction when a winner leaves), continuous price discovery (outbid anytime), and expiry as the safety valve. This is also the pattern Taiko already ships — `ProverAuction` is a standing pool where members join/leave/undercut anytime.
- **Control changes are quantized to epoch boundaries:** bids are continuous, but the **winner for epoch E+1 is fixed by the snapshot at `freeze(E) = end(E) − BID_FREEZE slots`** (`BID_FREEZE = 4` ≈ 48 s). Displacement, quit, and expiry all take effect at the next epoch boundary, never mid-epoch. Why: (a) handover stability for preconf UX — promises remain epoch-bounded (§4.6), and the outgoing winner serves until the boundary, so in-flight promises complete inside their tenure; (b) the new winner has from bid-time to the boundary (≥ the freeze window) to boot, on top of the L1 `STALL_GRACE`; (c) it matches the existing epoch-based client/infra and `endOfSubmissionWindowTimestamp` semantics; (d) the freeze window contains boundary races. **This is the recommendation.**
- **Intra-epoch resale (extension):** the winner may later transfer/sell individual slots on-chain (execution-ticket-style resale), recovering per-slot granularity without per-slot auctions. Deferred to Phase 4.

**Standing-bid mechanics:**

- **List:** up to `MAX_LIST_SIZE` (16, mirroring `ProverAuction`'s pool cap) entries, ordered by bid amount; each entry records bidder, ETH amount, and `joinedAt`. **Every listed bidder must hold the required TAIKO bond** (bond locked while their bid stands) — so the ranked list doubles as the bonded backup pool, and succession never depends on an unbonded runner-up.
- **Outbid:** a new bid must exceed the current top by ≥ `minIncrementBps` (5%, mirroring `ProverAuction.minFeeReductionBps`); the bidder must hold the bond at bid time. Bids landing before `freeze(E)` change the winner for E+1; bids after the freeze affect E+2. The displaced winner keeps the current epoch (their bids for past epochs are already spent/settled) and may re-bid anytime.
- **Quit:** the winner (or any listed bidder) withdraws their standing bid; effective at the next boundary. A quitting winner must keep serving until the boundary — quitting and then going dark before handover is a stall (slash), so clean handover is the only cheap exit.
- **Expiry:** each winning bid lapses after `tenureMax` (e.g., 1 day = 225 epochs, configurable). On lapse the entry is removed, the list re-ranks (the runner-up inherits at the next boundary), and the former winner may immediately re-bid at ≥ max(their previous bid, current reserve floor). Expiry's job is dead-bidder cleanup and re-confirmation; repricing pressure comes from the reserve floor + outbidding.
- **Unassigned state (no bidders at all):** if the list is empty at the freeze, the epoch is *unassigned*: any bonded operator may propose first-come, then **anyone** — i.e., the protocol falls back to **total permissionless mode** (rung 2 → 3, §4.5) until a bid arrives and wins the next boundary. Chain liveness is unaffected, because liveness never depends on the auction.
- **Reserve price:** dynamic floor = `max(initialFloor, movingAverageMultiplier × EMA(winning bids))` (the `ProverAuction` moving-average pattern); bids below the floor do not enter the list.
- **Bid asset:** ETH (per the brief; wrapped ETH acceptable). **Why ETH and not TAIKO:** sequencing revenue is ETH-denominated (basefee share + tips), so ETH bids are a natural, currency-risk-free payment; keeping the *stake* in TAIKO keeps token utility while separating "pay for the right" from "bond for behavior". (Standing bids are public — sealed commit-reveal doesn't apply to a perpetual list; the freeze window + min increment + bond requirement are the anti-sniping/anti-churn tools instead.)
- **Proceeds:** to the protocol treasury, earmarked for **prover rewards / L2 cost subsidy** (the tokenomics doc's stated equilibrium: proposer fees vs prover rewards; forfeited bonds already go to treasury). Alternative splits (burn %, public-goods funding) are listed as open questions (§8).

### 4.4 TAIKO liveness stake & slashing

**Stake:** to bid, an operator must hold a TAIKO bond ≥ `requiredBond = livenessBond × bondMultiplier × 2` (mirror `ProverAuction`: ejection threshold `livenessBond × bondMultiplier`, required ×2). Withdrawal requires the standard delay (1 week on mainnet). Bond is never "locked for yield"; it is pure collateral. **Winning locks the required bond for the epoch plus the withdrawal delay** (mirror `ProverAuction.checkBondDeferWithdrawal`), and the bond must be visible to the Inbox's bond ledger so the existing late-proof `settleLivenessBond` flow (fault V1) and the auction's stall slashing (fault L1) draw on the same TAIKO balance — one stake, two slash paths. **Escrow, not ledger-minimum:** the auction must hold the winner's required bond in its own escrow for the tenure + refute window — `LibBonds.withdraw` enforces `minBond` *only while the withdrawal delay is still running* (`LibBonds.sol`), so an operator who requested withdrawal early can drain the ledger before stalling (adversarial-review finding). The escrow's own withdrawal path is `owner-only after (epoch end + refute window + withdrawal delay)`; the Inbox-visible balance for fault V1 can be the same escrow exposed via a view.

**Fault classes (all slashing is in TAIKO):**

| # | Fault | Proof | Slash | Trigger |
|---|---|---|---|---|
| L1 | **Stall (liveness fault):** winner produced no proposal during `[epochStart, epochStart + STALL_GRACE]` or goes silent for `STALL_GRACE` mid-window | `block.timestamp - max(epochStart(E), checker.lastProposalAt) > STALL_GRACE` — the checker writes `lastProposalAt = block.timestamp` inside `checkProposer`, i.e. **atomically with the proposal tx** (a reorg rolls the record back with the proposal); pure L1 state, no consensus structures | `livenessBond`; challenger reward, remainder burned — **escrowed for a 1-epoch refute window before settling** | the backup's `propose` fires the ladder immediately; the slash settles after the refute window (§4.5) |
| L2 | **Window violation:** proposal attempted outside own window / by non-winner during exclusive window | checker state | none needed (revert) | rejected at `checkProposer` |
| P1 | **Broken preconf promise** (v1): a signed promise's tx not included in the promised block/order | signed promise + promise root on `PreconfCommitments` + non-inclusion evidence (dispute window v1; proving pipeline v2) | per-promise slash ≤ `min(promiseValue, livenessBond)`, user compensated first | user dispute |
| S1 | **Equivocation / signed-invalid block:** two different signed blocks for the same `(blockNumber, parentHash)`, or a signed block violating a cheaply-checkable property (timestamp outside the winner's submission window, duplicate block for the same slot, gasLimit > max) | the block signature(s) themselves — recover the signing key, check it is the epoch winner's registered key, then check the property violation from the signed payload + epoch context | full `livenessBond`, 50/50 challenger/burn, same digest + refute-window machinery | challenger dispute on `PreconferAuction` (§4.11) |
| V1 | **Invalid/unprovable proposal** (proposer submitted junk that can't be proven) | existing proving pipeline (proposal fails to finalize) | existing proposer liveness-bond flow (`settleLivenessBond`) | prover, on late/failed proof |

**Fault taxonomy note:** this catalogue follows the ethresearch distinction between **liveness faults** (offline/stall — slashable but *priced for accident risk*: grace periods, bounded slashes) and **safety faults** (equivocation, invalid blocks — fully slashable). The L1 stall fault is a liveness fault with built-in grace (`STALL_GRACE`), so honest operators are not slashed for transient L1 congestion; S1 equivocation/invalid blocks are **safety faults** (fully slashable); P1 promise breaks sit between the two — bounded by the promise value, with the user compensated first. See [Based preconfirmations](https://ethresear.ch/t/based-preconfirmations/17354) and [Avoiding accidental liveness faults](https://ethresear.ch/t/avoiding-accidental-liveness-faults-for-based-preconfs/).

**Slash split:** the in-repo precedents differ — `settleLivenessBond` uses **50/50 payee/burn**; `ProverAuction.slashProver` gives `rewardBps` (constructor param, e.g. 6000 bps = 60%) to the challenger and locks/burns the rest. **Recommendation: follow `settleLivenessBond`'s 50/50 payee/burn** for consistency with the deployed bond ledger (challenger = the backup proposer who fired the fault), with the tokenomics-whitepaper option of routing the burned half to the treasury instead.

**Anti-griefing rules (learned from the URC review, applied by construction):**

- *No global slash window:* each fault has its own digest (`keccak256(epoch, faultType, evidence)`) recorded in a `slashedBefore` mapping — replaying one fault cannot burn more than once, and one fault's window cannot release the operator from another (fixes URC H-1/H-2 classes).
- *Bounded slasher set:* only the auction contract and the checker can slash (no arbitrary opt-in slasher contracts; fixes URC M-1 class).
- *Domain-separated signatures:* EIP-712 with `chainid` + verifying contract in every signed promise/registration (fixes URC M-2/D-1 classes).
- *Getters report true slashability:* view functions reflect pending slashes (fixes URC M-3).
- *Ejection:* bond below threshold → automatic removal from the operator set + withdrawal delay (mirror `ProverAuction`).
- *Reorg safety (two layers — adversarial-review fix):* (i) the stall clock measures from `max(epochStart, lastProposalAt)`, where `lastProposalAt` is written in the same transaction as the accepted proposal, so a reorg rolls the record back together with the proposal it describes; (ii) **stall slashes settle only through a 1-epoch refute window**: the slash is escrowed at fault time, and if the winner re-proposes within the window or the fault condition no longer holds against the canonical chain at settlement, the escrow is released. Liveness (fallback proposing) fires immediately at grace expiry; *punishment* is deferred — so an honest winner whose block was reorged out can never be slashed, and a deep-reorg 'lost block race' cannot harm them.

**Who can be slashed and when — liveness accounting example:** winner of epoch `E` proposes nothing; at `epochStart(E) + STALL_GRACE` the runner-up calls `propose`; the checker verifies the stall from its own state (`block.timestamp - max(epochStart(E), lastProposalAt) > STALL_GRACE`), **escrows** the winner's slash, records the fault digest, and accepts the runner-up's proposal — all in one transaction. The escrow settles only after a 1-epoch refute window: if the winner re-proposes before settlement (e.g., they were reorged out, not offline) the escrow is released. Liveness is immediate; punishment is reorg-robust. The evidence is unambiguous contract state, not consensus state.


### 4.5 The backup/fallback ladder

For epoch `E` with winner `W` (top bid) and runner-up `R` (second bid):

```
[ epoch E start ]...............................................[ epoch E end ]
 |--- exclusive window of W -----------------------------------------|
      W proposes 1 block per L1 block (as today)
      W issues preconfirmations (off-chain, signed, gossiped via p2p)
      if W goes silent for STALL_GRACE (e.g. 4 slots = 48s):
        R may propose  (first one does; triggers W's slash escrow) <- designated backup, bonded
      if R is also silent for BACKUP_GRACE (e.g. 4 slots):
        any bonded operator may propose              <- open backup
      if no bonded operator proposes for FALLBACK_GRACE (e.g. 8 slots):
        ANYONE may propose (permissionless)          <- based fallback (liveness floor)
      users can always saveForcedInclusion()          <- censorship floor (fee-scaled)
```

- **Rung 0 (winner):** exclusive; `checkProposer` returns `endOfSubmissionWindowTimestamp = epochEnd(E)`.
- **Silence measurement:** the stall clock measures from `max(epochStart(E), lastProposalAt)` — within an epoch the timer counts from the epoch's first proposal (or the epoch start), and `lastProposalAt` tracks the last proposal by *any* proposer. 'Silent for `STALL_GRACE`' means no proposal for that long within the epoch; each epoch's winner gets the full grace from epoch start, removing the boundary race where a new winner inherits a partially-expired clock.
- **Rung 1 (runner-up):** pre-approved, bonded, and *incentivized* (collects the challenger share of W's slash when it fires). No new auction needed — liveness is not delayed by bidding. Optional extension: a **top-K ranked backup pool** (mirroring `ProverAuction`'s pooled provers and `LookaheadStore`'s `isFallback`) for stronger redundancy.
- **Rung 2 (any bonded operator):** first-come.
- **Rung 3 (anyone):** permissionless — identical to today's based inclusion. The checker returns a short windowEnd so the Inbox records it and the next rung can follow.
- **Rung 4 (forced inclusion):** unchanged; also, *enforce the existing `permissionlessInclusionMultiplier` escape hatch* so that even a buggy checker cannot permanently block proposing (fixes kimi-k3 I-01 / PR #22012 E-4).
- **Unassigned periods** (no standing bids at the freeze): skip straight to rung 2 (any bonded operator, first-come), then rung 3 — total permissionless mode until a bid wins the next boundary. This is exactly the no-bidder fallback; chain liveness is unaffected.

The Inbox change needed (a hard requirement — `checkProposer` is unconditional today in `_buildProposal`, the interface mandates revert-for-invalid, and `_permissionlessInclusionMultiplier` is stored but never read): (a) wrap `checkProposer` in a bounded-gas `try/catch` (a revert in the callee rolls back the checker's writes too, so the catch path is state-clean) so a buggy checker cannot halt the rollup — PR #22012 finding E-3; (b) on catch, apply rung-3 rules **from Inbox state**: accept the proposal only if the oldest forced inclusion is overdue beyond `forcedInclusionDelay × permissionlessInclusionMultiplier` — finally wiring the escape hatch the knob was designed for (kimi-k3 I-01 / E-4) — or if a minimum no-proposal time has elapsed; (c) otherwise everything lives in the checker, so the hot path stays one external call plus the try/catch overhead.

**Rung-3 DoS note:** opening rung 3 to everyone widens the ring-buffer fill attack surface (mainnet ring buffer holds ~3 days of proposals; `NotEnoughCapacity` halts proposing while proving is stalled). Mitigations: require a small bond or a permissionless-inclusion fee for rung-3 proposals (the original intent of the unenforced `permissionlessInclusionMultiplier` knob), or enable `minBond`. A spec-time parameter choice, not a design blocker — but it must not be skipped.

**Why liveness is guaranteed:** the only way the chain stalls is if *no one* submits a proposal for `STALL_GRACE + BACKUP_GRACE + FALLBACK_GRACE` (e.g. ~2 min) while L1 is live — and rung 3 costs nothing to enter and pays the proposer's normal fees. If even that fails, forced-inclusion fees scale until proposing is profitable. This is strictly stronger than the current whitelist (offline operator stalls the epoch) and matches the "liveness-first" lineage (MEV-Boost++).

### 4.6 Preconfirmation promises (user-facing)

- The winner's sequencer signs promises: `(epoch E, seqNo, txHash, tip, targetBlock)`, gossiped over the existing p2p network; wallet/RPC users verify against the winner's key published on-chain (checker getter → sequencer address).
- Promised txs are included by the winner in their proposals for epoch E. **If the winner is replaced mid-epoch (rungs 1-3), the backup proposer includes the *published* preconf'd txs in order** — the winner's ordered promise set is public (gossiped + promise-root per block on `PreconfCommitments`), so ordering is recoverable by anyone. Promises are therefore *not* lost on failover; at worst their fulfillment timing slips one block.
- **Block signatures:** every block the winner builds is signed (secp256k1, EIP-712) over its header fields — see §4.11. The signature does **not** affect validity or canonicality (derivation ignores it; the prover still enforces block properties); it exists for p2p authenticity, failover verification, binding the winner to the ordering they built (strengthening P1 disputes), and S1 equivocation/invalid-block slashing.
- **v1 enforcement:** dispute window on `PreconfCommitments`: user proves (a) signed promise, (b) promise root committed, (c) tx absent/misordered in the derived chain; the winner may refute by paying the promised compensation; no refutation within the window → slash + compensate. Slash ≤ `min(promiseValue, livenessBond)`; user compensated first.
- **v2 enforcement (recommended end-state):** move promise fulfillment into the ZK-proven pipeline — a small L2 preconf-registry contract is part of the proven state; broken promises settle there automatically (compensation escrow funded by the winner), with L1 slashing via the bridge signal. No L1 header parsing, no consensus structures; the prover does the expensive verification work, once. When BALs (EIP-7928, Glamsterdam) ship, proofs of a broken *execution* preconf get dramatically cheaper — v2 should be specced against BALs as the evidence substrate.
- **Consensus-coexistence note (FOCIL):** promises must be order-compatible with mandatory IL txs (a winner can never promise to *exclude* an IL-mandated tx) — the same obligation already documented for the parked design (PR #22012 §4, D-1).

### 4.7 Consensus-layer independence analysis

| Ethereum change | Effect on this design |
|---|---|
| ePBS (EIP-7732, Glamsterdam H2 2026) | **None.** The design never names a future L1 proposer. `propose` is an ordinary tx: whoever builds L1 blocks (builder or proposer) includes it if it pays. ePBS splits proposer/builder and moves preconf enforcement onto proposer→builder — irrelevant to a design with no proposer commitments. |
| FOCIL / fork-choice ILs (EIP-7805, Hegotá late 2026) | **Positive.** ILs + forced inclusion compose; the only obligation is the ordering note above. Fork-choice enforcement (no slashing) suffices as an inclusion backstop. |
| Orbit SSF / shorter slots / SSLE (~2029+) | **None structurally.** Windows are timestamp-based; no `SLOT_TIME` hard-codes in fault proofs (only seconds-based grace periods). Slot-shortening just changes cadence. SSLE would encrypt the proposer schedule — fatal for lookahead-based designs, irrelevant to this one. |
| Execution tickets | **Complementary** (both are auctions of execution rights); no dependency. |
| EIP-7251 MaxEB | **None.** Eligibility is bond-based, not validator-set-based. |
| EIP-7917 deterministic lookahead (Fusaka) | **Unused, optional.** Available if Phase 4 ever adds L1 proposer commitments. |
| BALs (EIP-7928, Glamsterdam) | **Helpful** for v2 promise enforcement: proof-friendly per-tx state-change records make broken-execution-preconf proofs cheaper. |
| MEV-Boost relay changes | **None** (out-of-scope by construction). |

The only remaining consensus touchpoints are `block.timestamp`/`blockhash` (stable across all forks) and — optionally, for anything needing randomness — EIP-4788 roots, which persist.

### 4.8 MEV & incentive analysis

- **Internalization:** the bid is a market price for the epoch's expected sequencing revenue (L2 basefee share — mainnet `basefeeSharingPctg = 75` — plus priority tips plus L2 MEV). Competition drives bids toward expected value minus operating cost minus risk premium — the same mechanism as PBS, at the rollup layer, without trusted relays.
- **Auction-level MEV:** bounded by the `BID_FREEZE` window and the 5% min increment; residual = copying/front-running a bid tx to win the next boundary — mitigated by the freeze (late bids affect E+2, not E+1) and by the fact that displacing a winner costs a bonded commitment to actually serve (or be slashed).
- **Winner-side MEV:** full L2 MEV + tips within its epoch (the franchise being sold); cross-domain L1 MEV (timing `propose` vs the L1 proposer) unchanged from today.
- **Last-look / multi-block MEV** (the main hazard of window auctions per the execution-tickets literature): mitigated by (a) the auction price internalizing it, (b) promise commitments + slashing for misbehavior, and (c) short windows with frequent re-auction.
- **Censorship economics:** refusing a tx either violates a promise (slash + compensation) or delays it to rung 2/3 (someone else includes it, winner loses the fee). **Bond sizing is the binding constraint** (adversarial-review finding): if `livenessBond × bondMultiplier <` the value of censoring/MEV-gaming an epoch, winning-and-misbehaving becomes profitable — a pay-to-censor channel. Rule of thumb: total slashable bond ≥ `k ×` expected epoch sequencing revenue (k ≥ 2), re-priced by governance as volumes grow.
- **Collusion/cartel risk:** outbid-anytime (min increment 5%) + reserve floor + expiry + open fallback + bond requirement keep the barrier low; a cartel that suppresses bids is broken by any outsider bidding +1 increment.
- **No built-in yield:** the TAIKO bond earns nothing — consistent with the tokenomics principle ("No Built-In PoS Reward"); operators profit from sequencing, not staking.

### 4.9 Gas & cost model

- **Per proposal (hot path):** one external `checkProposer` call: a few SLOADs, an epoch boundary computation, one SSTORE (`lastProposalAt`), and comparisons — target **< 30 k gas**, comparable to today's whitelist checker (which already does an epoch computation + beacon-root lookup; the auction checker actually *removes* the EIP-4788 staticcall from the hot path).
- **Per epoch:** ~1-10 auction bids (commit + reveal, one SSTORE-heavy tx each), one winner settlement, at most one slash settlement. Amortized over 32 slots, negligible.
- **No per-slot overhead**, no lookahead posting, no BLS verification on the hot path (BLS only in user-facing promise verification, off-chain).

### 4.10 Parameter table (initial proposal; all values tunable before deploy)

| Parameter | Value | Rationale |
|---|---|---|
| Auction | perpetual standing-bid list (≤ 16, all bonded); control quantized to epoch boundaries | §4.3 |
| Bid freeze | `BID_FREEZE` = 4 slots before each epoch end | winner for E+1 fixed ≥ 48 s ahead; boot time + boundary-race protection |
| Min bid increment | 5% | mirrors `ProverAuction.minFeeReductionBps` |
| Tenure expiry | `tenureMax` (e.g., 1 day = 225 epochs), configurable | dead-bidder cleanup + re-confirmation |
| Reserve floor | `max(initialFloor, 2 × EMA(winning bids))` | `ProverAuction` moving-average pattern |
| Required TAIKO bond | `livenessBond × bondMultiplier × 2` | mirrors `ProverAuction` |
| `STALL_GRACE` / `BACKUP_GRACE` / `FALLBACK_GRACE` | 4 / 4 / 8 slots | ≈48 s/48 s/96 s: sub-epoch failover, tolerant to L1 congestion |
| Slash per liveness fault | `livenessBond` (TAIKO) | mirrors prover liveness bond |
| Slash split | 50/50 challenger/burn | mirrors `settleLivenessBond` |
| Bond withdrawal delay | 1 week | matches mainnet Inbox `withdrawalDelay` |
| Stall evidence | checker `lastProposalAt`, clock from `max(epochStart, lastProposalAt)` (tx-atomic with proposals) | reorg-safe by construction; grace periods absorb shallow reorgs |
| Stall-slash refute window | 1 epoch | punishment is reorg-robust while liveness fallback fires immediately |
| Bond sizing rule | slashable bond ≥ 2 × expected epoch revenue | closes the pay-to-censor arbitrage (adversarial review) |
| Promise-break slash | `min(promiseValue, livenessBond)` | bounded, compensating |
| Block signature | secp256k1, EIP-712 over `(blockNumber, parentHash, timestamp, coinbase, gasLimit, txRoot)` | S1 dispute evidence + p2p authenticity; verified off-chain, on-chain only in disputes |

---

### 4.11 Operator-signed blocks (the S1 fault class)

**Current state (verified in-repo):** Taiko L2 blocks are **not** proposer-signed. A derived block is just a `BlockManifest` (timestamp, coinbase, anchor, gasLimit, transactions — `Derivation.md`); canonicality comes from L1 inclusion order, block properties are enforced by the ZK prover, and proposer attribution is the on-chain `Proposed.proposer` field. The only signatures in today's stack are on **preconf commitments** (`SignedCommitment`, secp256k1, in `preconfirmation-p2p`) — not on blocks. This works fine *without* block signatures because there is no L2 consensus to attribute: derivation + proving do the work.

**Recommendation:** the Preconfer Auction should add an **operator signature over each built block**, used narrowly:

- **Not** part of L2 validity or canonicality — derivation ignores it, the prover keeps enforcing block properties, and no new consensus mechanism is introduced (based-ness unchanged).
- **Used for:** (1) **S1 slashing** — the signature is the dispute input that makes equivocation and provably-malformed blocks cheap to punish (below); (2) **p2p authenticity + failover** — the backup (rungs 1-3) and nodes verify a forwarded block came from the winner without L1 lookups, supporting block re-inclusion after failover (§4.5/§4.6); (3) **promise binding** — the signed block is the artifact the winner promised, strengthening P1 disputes.

**Signature spec (draft):**
- **Key:** per-operator secp256k1 **block-signing key**, registered at bid time alongside the proposer/sequencer keys (same pattern as `PreconfWhitelist`'s proposer+sequencer pair). A hot, rotatable key — never the bond key.
- **Message:** EIP-712 domain (`chainid` + `PreconferAuction` address + epoch) over `(blockNumber, parentHash, timestamp, coinbase, gasLimit, txRoot)` — domain separation per the URC M-2 lesson.
- **Verification:** off-chain in p2p gossip; on-chain **only inside dispute/slash functions**, never on the `propose` hot path (the <30 k gas budget is untouched).

**Why S1 is worth having (the user's "wrong timestamp" example):** a challenger submits the signed block; the slasher (a) recovers the key, (b) checks it equals the epoch winner's registered signing key, (c) checks the property violation from the signed payload + epoch context alone — e.g., timestamp outside the winner's submission window, two different blocks for the same `(blockNumber, parentHash)` (equivocation), or gasLimit over the cap. If it holds, the full liveness bond is slashed (50/50 challenger/burn) through the same digest + refute-window machinery as L1. Without signatures, equivocation is nearly unpunishable today (the losing branch just doesn't finalize) and malformed blocks are only caught indirectly when the proposal fails to prove (V1) — slower and coarser.

**Scope discipline:** only properties provable from the signed payload + epoch context are S1-slashable. Everything the ZK prover checks (state transitions, anchor correctness, execution) stays on the proving path (V1). Total per-epoch slashing is capped at `livenessBond` so S1 and V1 cannot double-count the same misbehavior.

---

## 5. Alternatives considered

| Option | Liveness | Permissionless | Preconf UX | Consensus dependence | MEV capture | Complexity / time-to-ship |
|---|---|---|---|---|---|---|
| **A. Preconfer Auction (this proposal)** | Strong (ladder + forced inclusion + escape hatch) | Yes (open standing bids, anyone with bond) | Good (perpetual franchise, epoch-bounded promises; survive failover) | None (L1-state-only faults) | Internalized via standing-bid auction | Medium; mostly new checker+auction contracts on existing infra |
| B. Parked URC/lookahead design | Good (fallback + slashers) but depends on opt-in coverage | Yes (opt-in) | Best-case (slot-level promises) | **High** (lookahead, headers, BLS, commitments) | Slot-level via lookahead | Already built, but blocked (URC not production-ready; ePBS reshapes commitments); would be first/only URC deployment |
| C. Status quo (`PreconfWhitelist`) | Weak (offline operator stalls the epoch) | No (permissioned) | Good (dedicated operator) | Low (beacon-root randomness only) | Operator-captured | Deployed |
| D. Consensus-native preconf (wait for ePBS + Constraints API + FOCIL) | Strong | Yes | Best-case | **Total** (it *is* the consensus layer) | Enshrined | Parts land H2 2026 (ePBS) / late 2026 (FOCIL), but the enforcement spec (Constraints API) is unproven; full stack realistically 2027+ |
| E. Out-of-protocol auction (MEV-Boost-style relays for L2 sequencing) | Depends on relay operators | Semi (relay policy) | Good | Medium (relay↔builder↔validator) | Good | Relies on trusted infra Taiko doesn't control; new trust assumptions |
| F. Execution-ticket-style L1 auction (as L1 consensus change) | Strong | Yes | n/a (L1-level) | Total | Enshrined | Out of Taiko's control; research-stage |

**Recommendation: A, with D as a future enhancement layer** (when proposer commitments/Constraints API exist, the auction winner can *additionally* buy L1 inclusion guarantees; nothing in A needs to change).

---

## 6. Migration path

- **Phase 0 — Safety (now):** enforce the already-designed Inbox escape hatch (`permissionlessInclusionMultiplier`) and gas-isolate the checker call (kimi-k3 I-01; PR #22012 E-3/E-4). This improves liveness *today* with zero protocol economics changes.
- **Phase 1 — Shadow (testnet):** deploy `PreconferAuction` + `PreconfStaking` + `PreconfCommitments` on Hoodi; checker accepts whitelist operators as the fallback rung; run auctions with play money; fuzz the stall/slash state machine; audit.
- **Phase 2 — Transition (mainnet):** switch `proposerChecker` to the auction checker with `PreconfWhitelist` as rung-1 backup; existing operators bid like everyone else; keep rung 3 (anyone) live from day one.
- **Phase 3 — Permissionless:** drop the whitelist dependency entirely; enable promise-slash v1; wire proving-layer enforcement (v2) when ready.
- **Phase 4 — Optional futures:** intra-epoch slot resale; FOCIL IL coexistence spec; ePBS proposer-commitment upgrades; sealed-bid extension if boundary sniping proves material.

**Sunset of URC:** keep `permissionless-preconf` parked; the URC adoption gates from PR #22012 (signing-domain merge, Audit 3, schema decision, ePBS certification) become *optional* — the Preconfer Auction does not block on them.

---

## 7. Open questions & decisions needed

1. **Auction proceeds destination** (treasury → prover subsidy vs burn vs split) — needs tokenomics/governance sign-off.
2. **Bond sizing in TAIKO** — absolute `livenessBond`/multiplier values (economic security analysis vs circulating supply). Consider sizing the bond against an ETH-denominated target (governance re-pricing) to hedge TAIKO price risk.
3. **Auction parameters** — `BID_FREEZE`, `tenureMax`, `MAX_LIST_SIZE`, and displacement/sniping behavior; validate against bid-sniping MEV on Hoodi.
4. **`STALL_GRACE` values** — latency budget for the winner's propose loop; validate against worst-case L1 congestion; plus the refute-window duration (1 epoch proposed).
5. **Preconf promise compensation cap and dispute-bond requirements** (v1).
6. **Whether `checkProposer` should return per-rung windowEnds** or the Inbox should own the ladder — checker-owned ladder plus Inbox-side catch/escape-hatch is now the recommendation (adversarial review); the exact catch-path condition (forced-inclusion-overdue vs no-proposal-time) needs a decision.
7. **Interaction with `ProverAuction` rollout** (both touch bonds/fees; sequence the deployments).
8. **Regulatory review** of auctioned proposer rights (tokenomics doc's "no built-in PoS reward" principle must be preserved).

---

## 8. Appendix

### 8.1 Liveness fault catalogue (checker state machine)

- Perpetual list of bonded standing bids (≤ 16). `assign(E+1) ← top of list at freeze(E) = end(E) − BID_FREEZE slots`; `backup(E+1) ← second`; `unassigned` if the list is empty. Transitions: outbid → boundary handover; quit → boundary handover (must serve until then); expiry (`tenureMax`) → entry lapse + re-rank; slash/eject → immediate rung-1 takeover.
- At `propose` in epoch E: resolve rung by (`block.timestamp`, stall evidence from the checker's `lastProposalAt` record, sender ∈ {winner, backup, bonded set, anyone}).
- Slash transitions: winner-stall → escrow+digest → settle after refute window (reward to challenger); promise-break → dispute window → slash+compensate; eject when bond < threshold.
- Every slash: per-fault digest, one-shot, no global window, EIP-712 domains, withdrawal delays.

### 8.2 In-repo anchors

- `packages/protocol/contracts/layer1/core/impl/Inbox.sol` (propose, `_buildProposal`, forced inclusion, bonds)
- `packages/protocol/contracts/layer1/core/iface/IProposerChecker.sol`
- `packages/protocol/contracts/layer1/core/libs/LibBonds.sol`, `LibForcedInclusion.sol`
- `packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol`
- `.worktrees/multi-prover-auction/packages/protocol/contracts/layer1/core/impl/ProverAuction.sol`
- `packages/protocol/docs/Derivation.md`, `tokenomics_objective_metrics.md`, `tokenomics-whitepaper.tex`
- Branch `permissionless-preconf`: `packages/protocol/docs/preconfirmation_lookahead.md`, `LookaheadStore.sol`, slashers, `packages/preconfirmation-p2p`
- PR #22012: `packages/protocol/docs/urc_production_readiness_review.md` (diff)

### 8.3 References

**In-repo / Taiko**

- [PR #22012 — URC production-readiness review](https://github.com/taikoxyz/taiko-mono/pull/22012)
- Taiko Alethia whitepaper: `packages/whitepaper/whitepaper_taiko_alethia_v2.0.0.pdf`
- [Taiko preconfirmation docs](https://docs.taiko.xyz/protocol/preconfirmations), [economics docs](https://docs.taiko.xyz/protocol/economics)
- Taiko issues [#19206](https://github.com/taikoxyz/taiko-mono/issues/19206), [#14452](https://github.com/taikoxyz/taiko-mono/issues/14452)

**Preconfirmation / auctions**

- [eth-fabric/urc](https://github.com/eth-fabric/urc) and [URC docs](https://eth-fabric.github.io/website/development/l1-components/urc)
- Justin Drake, [Based preconfirmations](https://ethresear.ch/t/based-preconfirmations/17354) and [L1 as shared sequencer with preconfs](https://notes.ethereum.org/@JustinDrake/rJ2eXRcKa)
- [Ahead-of-Time Block Auctions](https://ethresear.ch/t/ahead-of-time-block-auctions-to-enable-execution-preconfirmations/21345)
- [Based preconfirmations with multi-round MEV-Boost](https://ethresear.ch/t/based-preconfirmations-with-multi-round-mev-boost/20091)
- [Execution Tickets](https://ethresear.ch/t/execution-tickets/17944); [economic analysis](https://ethresear.ch/t/economic-analysis-of-execution-tickets/18894); [execution auctions alternative](https://ethresear.ch/t/execution-auctions-as-an-alternative-to-execution-tickets/19894)
- [The Future of MEV is SUAVE](https://writings.flashbots.net/the-future-of-mev-is-suave)
- [MEV-Boost beginner's guide](https://writings.flashbots.net/beginners-guide-mevboost); [PBS trust assumptions](https://collective.flashbots.net/t/what-trust-assumptions-exist-in-proposer-builder-separation-pbs/151)
- [EIP-7732 (ePBS)](https://eips.ethereum.org/EIPS/eip-7732); [EIP-7547 (ILs)](https://eips.ethereum.org/EIPS/eip-7547)
- Max Resnick, [MEV-Boost++ liveness-first](https://forum.eigenlayer.xyz/t/mev-boost-liveness-first-relay-design/14197); [proposer slashing in MEV-Boost](https://research.eigenlayer.xyz/t/how-does-proposer-slashing-work-in-mev-boost/30)
- [Vanilla based sequencing](https://ethresear.ch/t/vanilla-based-sequencing/19379)
- [Spire based-stack: based sequencing](https://docs.spire.dev/based-stack/based-sequencing) and [preconfirmations](https://docs.spire.dev/based-stack/preconfirmations); [based-stack repo](https://github.com/spire-labs/based-stack)
- [Espresso shared-sequencing marketplace](https://www.theblock.co/post/283558/espresso-raises-28-million-in-series-b-round-for-shared-sequencing-marketplace)
- [Unichain docs](https://docs.unichain.org/); [Gate on based rollups & preconfs](https://www.gateweb3.net/learn/articles/why-do-based-rollups-require-preconfirmation-preconfs-technology)

**Consensus roadmap & proposer commitments**

- [EIP-7732 (ePBS)](https://eips.sh/eip/7732) · [EIP-7805 (FOCIL)](https://eips.sh/eip/7805) · [EIP-7917 (deterministic proposer lookahead, Fusaka)](https://eips.sh/eip/7917) · [EIP-7251 (MaxEB, Pectra)](https://eips.sh/eip/7251)
- [Fusaka guide — Alchemy](https://www.alchemy.com/overviews/ethereum-fusaka-upgrade-dev-guide-to-12-eips) · [Glamsterdam final devnet — CoinDesk](https://www.coindesk.com/tech/2026/06/16/ethereum-s-biggest-protocol-overhaul-in-years-moves-into-its-final-development-stage) · [FOCIL in Hegotá — KuCoin](https://www.kucoin.com/news/flash/ethereum-to-introduce-censorship-resistant-focil-in-2026-hegota-upgrade)
- [Future-Proofing Preconfirmations — Nethermind](https://ethresear.ch/t/future-proofing-preconfirmations/22618) · [BALs for Proposer Commitments](https://ethresear.ch/t/bals-for-proposer-commitments/23095) · [Deterministic proposer lookahead — Magicians](https://ethereum-magicians.org/t/eip-7917-deterministic-proposer-lookahead/23259)
- [Credibly Neutral Preconfirmation Collateral: the Preconfirmation Registry (mteam/Spire)](https://ethresear.ch/t/credibly-neutral-preconfirmation-collateral-the-preconfirmation-registry/19634) · [Spire preconfirmation-registry repo](https://github.com/spire-labs/preconfirmation-registry)
- [A Taxonomy of Preconfirmation Guarantees and Their Slashing Conditions in Rollups](https://ethresear.ch/t/a-taxonomy-of-preconfirmation-guarantees-and-their-slashing-conditions-in-rollups/22130) · [Preconfirmations under the NO lens (Barnabé Monnot)](https://ethresear.ch/t/preconfirmations-under-the-no-lens/19975) · [Avoiding Accidental Liveness Faults for Based Preconfs](https://ethresear.ch/t/avoiding-accidental-liveness-faults-for-based-preconfs/) · [Uncrowdable Inclusion Lists (RIG)](https://ethresear.ch/t/uncrowdable-inclusion-lists-the-tension-between-chain-neutrality-preconfirmations-and-proposer-commitments/19372)
- [Commit-Boost](https://ethresear.ch/t/commit-boost-proposer-platform-to-safely-make-commitments/20107) · [Bolt (Chainbound)](https://github.com/chainbound/bolt) · [mev-commit (Primev)](https://github.com/primev/mev-commit) · [Luban/LingLong — Lido](https://research.lido.fi/t/introducing-luban-and-its-pre-settlement-layer-linglong/10162) · [Puffer-Preconf](https://github.com/PufferFinance/Puffer-Preconf)
- [MEV-Boost ~93% share — Flashbots](https://collective.flashbots.net/t/the-6-99-without-pbs/5283) · [Orbit SSF in Practice](https://ethresear.ch/t/orbit-ssf-in-practice/20943) · live dashboards: [relayscan.io](https://relayscan.io), [mevboost.pics](https://mevboost.pics)

**Liveness references**

- [Arbitrum sequencer docs](https://docs.arbitrum.io/sequencer); [Optimism forced transactions](https://docs.optimism.io/op-stack/transactions/forced-transaction); [Cosmos slashing](https://docs.cosmos.network/main/build/modules/slashing)
- [Sealed-bid auction design (Starknet RFP)](https://strk20.starknet.io/rfp/sealed-bid-auctions)


