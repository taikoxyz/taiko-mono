# Etna PoS + ZK — Economics and Staking Design Inputs (raw)

Status: **research input, not a specification.** Phase 2 artifact for `04-architecture-decision.md` and `spec/index.html` (`ECON-*`, `PARAM-*` rules).
Pinned repository revision: `7718753c1cece7d7705afaf33e6f9680115086dd` (verified `git rev-parse HEAD`, 2026-10-05).
External sources retrieved: **2026-10-05** unless stated. Every external claim carries a source in §6.
Scope: economics and staking design inputs only. **This document does not design consensus rules.**

## 0. How to read this file

| Label | Meaning |
|---|---|
| **SOURCED** | A number or claim taken from a named external source or from this repository at the pinned revision. |
| **FORMULA** | A relation that must hold. Contains no invented quantity. |
| **UNMEASURED** | A quantity that no source available to this author provides. Must be measured before use. |
| **UNVERIFIED** | A claim encountered but not confirmable from a primary source. **Must not be hard-coded.** |
| **ANALYTICAL** | An argument of this author, offered as reasoning, not evidence. |

**Hard rule for this file and everything that consumes it:** no price, market capitalisation, or yield in this
document is measured. §3.5 records what would have to be measured, and §4 records why the protocol must not
bake any of it into a constant.

---

# 1. Repository facts at `7718753c1`

## 1.1 TaikoToken (L1 canonical TAIKO)

| Property | Fact | Citation |
|---|---|---|
| Name / symbol / decimals | `"Taiko Token"` / `"TAIKO"` / 18 | `TaikoToken.sol:37`, `TaikoTokenBase.sol:32-34` |
| Initial and current supply | **1,000,000,000 ether** minted once in `init`; no other mint path on L1 | `TaikoToken.sol:41` |
| Mint authority after init | **None exposed.** The only `_mint` in the L1 token path is `init`. No public `mint` / `burn` exists in `TaikoToken.sol` or `TaikoTokenBase.sol` | `TaikoToken.sol:35-42`; absence verified by grep over `contracts/shared/governance/` and the L1 token |
| Burn authority | **None exposed on L1.** `burn`/`_burn` exist only on the L2 bridged representation | `layer2/mainnet/BridgedTaikoToken.sol:42-49` |
| Upgradeable? | **Yes.** `EssentialContract is UUPSUpgradeable, Ownable2StepUpgradeable`; `_authorizeUpgrade` is `onlyOwner` | `EssentialContract.sol:10`, `EssentialContract.sol:207` |
| Proxy | Deployed behind a proxy at `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` (`token.taiko.eth`) | `TaikoToken.sol:12-13`; `LibL1Addrs.sol:73` |
| Ownership | `Ownable2StepUpgradeable`; owner set in `init(_owner, _recipient)`. There is also a public `acceptOwnershipOf(address)` on the shared `Controller` that **anyone** may call to complete a pending ownership transfer on any contract | `TaikoToken.sol:35-36`; `Controller.sol:42-44` |
| Snapshot / votes | **ERC20Votes (yes), ERC20Snapshot (no).** Snapshot was removed and its 50 slots are tombstoned as `__slots_previously_used_by_ERC20SnapshotUpgradeable` | `TaikoTokenBase.sol:8-14`, `TaikoTokenBase.sol:19`; `TaikoToken_Layout.sol:21` |
| Vote checkpoints | `_delegates`, `_checkpoints`, `_totalSupplyCheckpoints` present (ERC20Votes layout) | `TaikoToken_Layout.sol:36-38` |
| Clock | `clock() = block.timestamp`, `CLOCK_MODE = "mode=timestamp"` (EIP-6372); checkpoints are **time-based**, not block-based | `TaikoTokenBase.sol:22-30` |
| Pause | Inherited `pause()`/`unpause()`, authorised `onlyOwner` | `EssentialContract.sol:150-165`, `EssentialContract.sol:209` |
| Non-voting accounts (hard-coded) | `address(0)`, `TAIKO_FOUNDATION_TREASURY` `0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da`, `TAIKO_DAO_CONTROLLER` `0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3`, `TAIKO_ERC20_VAULT` `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | `TaikoToken.sol:17-21`, `TaikoToken.sol:130-136` |
| Voting-power renunciation | `renounceVotingPower()` is irreversible; balance and total supply are unchanged; inbound delegators silently lose their votes until they re-delegate | `TaikoToken.sol:53-74` |
| Delegation | `delegate(address)` overridden to block non-voting accounts as either party | `TaikoToken.sol:83-90` |

**Consequences for a staking design (ANALYTICAL).**

1. The token is **fixed-supply on L1** unless the DAO upgrades the token. Any "staking reward" paid in TAIKO
   is therefore either (a) a transfer from an existing balance (treasury, fee pool), or (b) a **new mint**,
   which requires a token upgrade and therefore a DAO vote. There is no existing emission schedule to reuse.
2. The token already carries **ERC20Votes with time-based checkpoints that ignore the four non-voting
   accounts**. Reusing this surface for consensus stake would couple governance weight and consensus weight;
   see §2.6 and §4.
3. `getPastVotes`/`getVotes` overrides are **not** suitable as a consensus stake oracle: `renounceVotingPower`
   makes votes zero while the balance is intact (`TaikoToken.sol:92-96`), so votes != balance and votes != stake.
   A staking design must measure a **separate, explicit bonded-balance ledger**, not `balanceOf` or `getVotes`.
4. `acceptOwnershipOf` being callable by anyone (`Controller.sol:42-44`) is only safe because a two-step transfer
   must have been *initiated* by the current owner. Any new staking contract owned through the DAO controller
   inherits this pattern and must not use single-step `transferOwnership` into a controller.

## 1.2 MainnetDAOController

| Property | Fact | Citation |
|---|---|---|
| Role | "maintains ownership of all contracts and assets, and is itself owned by the TaikoDAO"; the DAO does not own contracts directly | `MainnetDAOController.sol:9-12` |
| Type | `Controller` (abstract), which is `EssentialContract` -> UUPS + `Ownable2Step` | `MainnetDAOController.sol:14`; `Controller.sol:11` |
| Init | `init(address _taikoDAO)` sets the owner to the DAO | `MainnetDAOController.sol:17-19` |
| Only privileged entry point | `execute(bytes _actions)` — `onlyOwner`, `nonReentrant` | `MainnetDAOController.sol:24-31` |
| Execution semantics | Decodes `Action{target, value, data}[]` and performs a raw `.call{value}` for each; reverts with the extracted error on failure; emits `ActionExecuted` | `Controller.sol:16-20`, `Controller.sol:58-75` |
| Anyone-callable helpers | `acceptOwnershipOf(address)`; `dryrun(bytes)` (always reverts, `payable`) | `Controller.sol:42-44`, `Controller.sol:46-53` |
| Replay guard | `lastExecutionId` (uint64) is public state | `Controller.sol:28`; `MainnetDAOController_Layout.sol:22` |
| Ether | `receive() external payable` — the controller can hold and forward ETH | `Controller.sol:36` |

**Decision-relevant discrepancy (SOURCED).** Two different addresses are asserted in-tree to be "the DAO controller":

| Source | Address | Label in source |
|---|---|---|
| `TaikoToken.sol:19` | `0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3` | `daocontroller.taiko.eth` (a **non-voting** account) |
| `LibL1Addrs.sol:12` | `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` | `DAO_CONTROLLER` |

Neither is wrong on its face (several controllers may exist), but **a new staking contract's owner must be
pinned to one of them deliberately, with the choice recorded**, because the two values imply different
upgrade authorities. This is a Phase 4 (`GOV-*`) item.

## 1.3 Tokenomics documents

`packages/protocol/docs/tokenomics-whitepaper.tex` (dated **Dec 6, 2023**; written for the Based Contestable Rollup era):

| Claim | Citation |
|---|---|
| Token is "a fundamental component for governance and operational efficacy" | `tokenomics-whitepaper.tex:23` |
| Design uses "Liveness, Validity, and Contestation Bonds **in Taiko tokens**" | `tokenomics-whitepaper.tex:29` |
| Bonds are "posted on L1"; **"Forfeited bonds are not lost but are redirected to Taiko's Treasury on L1"** | `tokenomics-whitepaper.tex:39` |
| Governance: token holders "democratically influence network upgrades and manage the Taiko treasury" | `tokenomics-whitepaper.tex:42` |
| "total supply ... is **fixed at 1 billion**, with 18 decimals. The minting or burning of TKO tokens is strictly governed" | `tokenomics-whitepaper.tex:45` |

`packages/protocol/docs/tokenomics_objective_metrics.md` (attributed to Brecht and Hugo/zkpool; **no date in file**):

| Objective | Citation |
|---|---|
| "primarily revolve around our Taiko token, rather than other tokens"; equilibrium "between proposer fees and prover rewards", maintaining "or even slightly decreas[ing]" supply | `tokenomics_objective_metrics.md:11` |
| Provers must not waste computation on unprofitable tasks; waste raises the average proof price | `tokenomics_objective_metrics.md:13` |
| "**Cheaper Proofs over Faster Proofs**"; "In the case of time delays within a specific upper limit, say, one hour, the less expensive proof should also be prioritized" | `tokenomics_objective_metrics.md:15` |
| "**Prover Redundancy/Decentralization**" — incentivise multiple active provers | `tokenomics_objective_metrics.md:17` |
| **"No Built-In PoS Reward**: To prevent being classified as a security, our tokenomics design should not offer tokens to stakers as rewards. A prover may establish a staking-based reward system allowing token holders to delegate their power, but this should not be considered as part of our tokenomics." | `tokenomics_objective_metrics.md:19` |
| Simplicity; minimal L1 cost; "**Immediate Proof Submission**" (provers must not withhold proofs to time submissions) | `tokenomics_objective_metrics.md:21-25` |

**Three direct conflicts a staking design must confront (ANALYTICAL, but each is anchored in a citation above).**

1. **"No Built-In PoS Reward" vs D7.** D7 requires slashable stake denominated in TAIKO. A validator set
   secured only by slashing and fees (no issuance) is permitted by this objective; an **inflationary staking
   reward is not** without an explicit, recorded reversal of `tokenomics_objective_metrics.md:19`. That line
   is the strongest existing in-repo constraint on the reward design, and it is *stronger* than a mere preference.
2. **"Forfeited bonds are redirected to the Treasury"** (`tokenomics-whitepaper.tex:39`) vs the current code,
   which **burns 50%** of a settled liveness bond (`LibBonds.sol:161-165`). The whitepaper is stale relative to
   the code. A new design must pick one and record it.
3. **"Cheaper Proofs over Faster Proofs" with a one-hour tolerance** (`tokenomics_objective_metrics.md:15`) is
   *compatible* with D6 (minutes to 30 min) but sets an explicit design ceiling on how much the protocol should
   pay for latency. Any reward term that pays for speed must be justified against this stated preference.

## 1.4 What bonding / staking exists **today**

Grep over `packages/protocol/contracts` (`--include=*.sol`) at `7718753c1`:

| Token | Matches | Where |
|---|---|---|
| `stake` | **0** | — |
| `unbond` | **0** | — |
| `slash` | 7, in 4 files | `IBondManager.sol`, `Inbox.sol`, `LibBonds.sol`, `LibNames.sol` |
| `bond` | 108, in 11 files | `IBondManager.sol`, `IInbox.sol`, `Inbox.sol`, `LibBonds.sol`, `LibInboxSetup.sol`, `DevnetInbox*.sol`, `MainnetInbox*.sol`, `TaikoToken.sol`, `layer2/core/BondManager_Layout.sol` |
| `BondManager` | 27, in 4 files | interface + `Inbox` + `LibBonds` + **an orphan layout file** |
| `ProverWhitelist` | 19, in 4 files | `IProverWhitelist.sol`, `IProverWhitelist`-users, `ProverWhitelist.sol`, `ProverWhitelist_Layout.sol` |

**There is no staking contract, no validator registry, no unbonding queue, and no equivocation slashing anywhere
in the tree.** What exists is a *bond ledger embedded inside the Inbox*:

| Mechanism | Fact | Citation |
|---|---|---|
| Ledger | `mapping(address => Bond)` where `Bond{uint64 balance (gwei); uint48 withdrawalRequestedAt}`; **one slot per bond** | `LibBonds.sol:25-27`; `IBondManager.sol:13-19` |
| Token | An ERC-20 supplied as an Inbox constructor argument; on mainnet, TAIKO | `Inbox.sol:84`, `Inbox.sol:160`; `LibL1Addrs.sol:73` |
| Units | Bond amounts are **in gwei**, converted by `amount * 1 gwei` | `LibBonds.sol:18`, `LibBonds.sol:203-205` |
| Deposit | `deposit(uint64)`, `depositTo(address,uint64)`; deposit cancels a pending withdrawal only for the self-deposit path | `Inbox.sol:402-410`; `LibBonds.sol:35-54` |
| Withdrawal | `requestWithdrawal()` stamps `withdrawalRequestedAt`; `withdraw` skips the `_minBond` floor only **after** `withdrawalRequestedAt + _withdrawalDelay` | `Inbox.sol:412-425`; `LibBonds.sol:76-89`, `LibBonds.sol:92-106` |
| Activation gate | `hasSufficientBond` = `balance >= _minBond && withdrawalRequestedAt == 0` — **requesting a withdrawal immediately deactivates the account for bond-restricted actions** | `LibBonds.sol:130-141`; `IBondManager.sol:84-90` |
| Slash (liveness only) | `settleLivenessBond`: debit up to `_livenessBond` **best effort**; **50% credited to the actual prover, 50% burned**; emits `LivenessBondSettled` | `LibBonds.sol:148-170` |
| Slash trigger | Only if `block.timestamp > max(transition.timestamp + _provingWindow, lastFinalizedTimestamp + _maxProofSubmissionDelay)` | `Inbox.sol:729-743` |
| No equivocation slash | There is **no** double-sign, surround-vote, or conflicting-certificate slashing path — grep for `slash` finds only the liveness path above | `LibNames.sol:14` defines `B_PRECONF_SLASHER` as a *name*, but no such contract is in this tree |

**Mainnet configuration (`MainnetInbox`, SOURCED).** This is the decisive table for §3, because it shows the
bond mechanism is currently **switched off**:

| Parameter | Value in code | Citation |
|---|---|---|
| `minBond` | **0** — "During prover whitelist, bonds are not necessary" | `MainnetInbox.sol:37` |
| `livenessBond` | **0** | `MainnetInbox.sol:38` |
| `withdrawalDelay` | **1 week** | `MainnetInbox.sol:39` |
| `provingWindow` | **4 hours** ("internal target is still to submit every ~2 hours") | `MainnetInbox.sol:40` |
| `permissionlessProvingDelay` | **5 days** | `MainnetInbox.sol:42` |
| `maxProofSubmissionDelay` | **3 minutes** | `MainnetInbox.sol:43` |
| `ringBufferSize` | **21,600** (3 days at 1 proposal/L1 slot) | `MainnetInbox.sol:16-18` |
| `basefeeSharingPctg` | **100** (raised from 75 by Proposal0026; whole basefee to the block's coinbase) | `MainnetInbox.sol:45-46` |
| `forcedInclusionDelay` | 576 s (1.5 epochs) | `MainnetInbox.sol:47-48` |
| `forcedInclusionFeeInGwei` | 1,000,000 (0.001 ETH) | `MainnetInbox.sol:49` |
| `permissionlessInclusionMultiplier` | 160 (-> ~25.6 h) | `MainnetInbox.sol:51-52` |

Because `_minBond == 0`, the check at `Inbox.sol:604-607` is **skipped entirely**; because `_livenessBond == 0`,
`settleLivenessBond` debits **0** and returns at `LibBonds.sol:159`. **Today no TAIKO is at risk in the system.**

**Access control on proving today:**

| Mechanism | Fact | Citation |
|---|---|---|
| `ProverWhitelist` | `mapping(address => bool)`; `proverCount`; owner **or** an immutable `_proverManager` may `whitelistProver` | `ProverWhitelist.sol:18`, `ProverWhitelist.sol:25-30`, `ProverWhitelist.sol:45-48`, `ProverWhitelist.sol:74-95` |
| Auto-disable | `isProverWhitelisted` returns `false` for everyone when `proverCount == 0` | `ProverWhitelist.sol:98-107` |
| Enforcement | `_checkProver` reverts `ProverNotWhitelisted` when the whitelist is non-empty; a zero-address whitelist disables the check | `Inbox.sol:768-779` |
| Proposer gating | `_proposerChecker.checkProposer(...)`; the live mainnet checker is `PreconfWhitelist` | `Inbox.sol:601-603`; `LibL1Addrs.sol:38`; `layer1/preconf/impl/PreconfWhitelist.sol` |

## 1.5 Who pays proposers and provers **today**

| Actor | Payment | Source of funds | Citation |
|---|---|---|---|
| L1 block coinbase (the L1 proposer, *not* the Taiko proposer) | `basefeeSharingPctg` (=100) of the L2 basefee, carried in the `Proposal` and emitted in `Proposed` | L2 basefee | `Inbox.sol:107-108`, `Inbox.sol:619`, `Inbox.sol:747-756` |
| Taiko proposer | Forced-inclusion fees: `_feeRecipient.sendEtherAndVerify(totalFees * 1 gwei)` where `_feeRecipient` is the proposer | ETH paid by forced-inclusion requesters | `Inbox.sol:637-638`, `Inbox.sol:701-710` |
| Prover | On-time proving: **nothing**. Late: 50% of the (currently zero) liveness bond, 50% burned | Bond ledger | `Inbox.sol:723-743`; `LibBonds.sol:148-170` |
| Anyone | No protocol-level prover reward exists in this tree | — | (grep: `reward` has **0** matches in `Inbox.sol`) |

**Conclusion (SOURCED + ANALYTICAL).** At `7718753c1` the protocol pays provers **nothing on L1**; provers are
currently assumed to be funded off-protocol, and proving permission is granted by a **whitelist**, not by stake.
The existing `minBond`/`livenessBond`/bond-ledger machinery is **present but inactive** (both parameters zero)
and is the natural in-place host for a staking design — but it has three properties a validator-stake design
cannot inherit unchanged:

1. `hasSufficientBond` deactivates an account the moment a withdrawal is *requested*
   (`LibBonds.sol:139-140`), so a validator cannot "announce exit and keep validating during the delay".
2. The slash is **best-effort** (`LibBonds.sol:158-159` returns if the debit is zero) and there is no
   accounting of *which* offence is being settled — fine for a liveness bond, unsafe for equivocation, where
   double-settlement and evidence replay must be impossible.
3. `Bond.balance` is `uint64` **gwei** (`IBondManager.sol:13-15`, `LibBonds.sol:18-19`), i.e. a ceiling of
   `2^64 - 1` gwei ~ **1.845e10 TAIKO** and ~18.4 TAIKO of granularity. Both are fine for a bond; **neither is
   a sound basis for a consensus stake ledger** without an explicit decision (see §4).

## 1.6 Contracts and addresses a new staking design must coexist with

All from `LibL1Addrs.sol` (mainnet) and `TaikoToken.sol` (SOURCED):

| Address | Name | Why it matters to staking |
|---|---|---|
| `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` | TAIKO token | The staked asset (D7). Lives behind an upgradable proxy (`TaikoToken.sol:12-13`). |
| `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | INBOX | Current home of the bond ledger; D5 settlement surface. |
| `0xEa798547d97e345395dA071a0D7ED8144CD612Ae` | PROVER_WHITELIST | Today's proving permission. A stake-based design must define its relationship (replace, keep as bootstrap, or run in parallel). |
| `0xFD019460881e6EeC632258222393d5821029b2ac` | PRECONF_WHITELIST | Today's proposer checker. |
| `0x05d88855361808fA1d7fc28084Ef3fCa191c4e03` | FORCED_INCLUSION_STORE | Censorship-resistance path (R10). |
| `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | ERC20_VAULT (also `TAIKO_ERC20_VAULT`) | A **non-voting** token holder; any staking contract must not break bridge accounting through it. |
| `0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da` | TAIKO_FOUNDATION_TREASURY | **Non-voting**; the whitepaper's intended recipient of forfeited bonds (`tokenomics-whitepaper.tex:39`). Candidate destination for slashed stake if a burn is not chosen. |
| `0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3` | `TAIKO_DAO_CONTROLLER` (token's label) | **Non-voting.** Candidate owner for a new staking contract. |
| `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` | `DAO_CONTROLLER` (`LibL1Addrs`) | The other candidate owner. **Resolve the discrepancy before selecting an owner.** |
| `0x9CDf589C941ee81D75F34d3755671d614f7cf261` | DAO | Ultimate owner; DAO governs upgrades only (R2). |
| `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | SHARED_RESOLVER | Cross-contract discovery, if the staking contract must be resolvable. |
| `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` + vaults | BRIDGE, ERC721/1155 vaults | R3 / D3: addresses must be preserved by in-place upgrade. |
| `0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec` etc. | Verifier set (ZK_REQUIRED, RISC0, SP1, SGX geth/reth) | **Proof latency is a verifier-and-prover property, not a staking property**; the staking design consumes only the resulting latency bound (D6). |
| — | `layer2/core/BondManager_Layout.sol` | An **orphan layout document** for a `BondManager` with `bond` + `processedSignals` mappings; `git log` shows the contract itself was deleted and reintroduced/removed across commits. **Do not treat this as a live contract.** |

**Also present and relevant:** `LibNames.sol:14` defines `B_PRECONF_SLASHER = "preconf_slasher"` but no such
contract exists in this tree at `7718753c1`; the name is a reserved registry key.

---

# 2. External research: slashable-stake PoS economics

## 2.1 How misbehaviour is encoded objectively

Ethereum's consensus specs define the entire slashable surface with **two** predicates. This is the strongest
available precedent for "objective evidence" (R11).

| Offence | Exact predicate | Source (retrieved 2026-10-05) |
|---|---|---|
| Proposer equivocation | two signed headers with **equal `slot`**, **equal `proposer_index`**, and **different header content**, both BLS-verified under the proposer's pubkey | `process_proposer_slashing`, phase0 `beacon-chain.md` L2399-2418 |
| Attester **double vote** | `data_1 != data_2` **and** `data_1.target.epoch == data_2.target.epoch` | `is_slashable_attestation_data`, L1145-1147 |
| Attester **surround vote** | `data_1.source.epoch < data_2.source.epoch` **and** `data_2.target.epoch < data_1.target.epoch` | `is_slashable_attestation_data`, L1149-1150 |
| Slashability precondition | `(not validator.slashed) and (activation_epoch <= epoch < withdrawable_epoch)` | `is_slashable_validator`, L1133-1135 |
| Per-block capacity | `MAX_PROPOSER_SLASHINGS = 16`; `MAX_ATTESTER_SLASHINGS = 2` | phase0 `beacon-chain.md` L664-665 |

**Property worth copying (ANALYTICAL).** Each offence is a *pure function of two signed messages* and one
epoch comparison. There is no "was it really malicious?" judgement, no non-receipt argument, no timing
inference. This satisfies the repo's ban on non-receipt-as-misconduct
(`01-requirements-and-threat-model.md:213`) exactly.

Cosmos reaches the same conclusion through a different route: the SDK accepts CometBFT
`DuplicateVoteEvidence` and `LightClientAttackEvidence`, converts both to a single `Equivocation` type, and
requires only `Evidence.Timestamp >= block.Timestamp - MaxEvidenceAge` for validity
(Cosmos SDK `x/evidence/README.md`, sections "Evidence Handling", "Equivocation"; retrieved 2026-10-05).
Polkadot's offence list is larger but each item is still a byte-level predicate on signed statements —
GRANDPA/BEEFY votes for different chains in one round, BABE blocks in one slot, double-seconding
(`docs.polkadot.com`, "Offenses and Slashes", retrieved 2026-10-05).

## 2.2 Who can submit, and what they are paid

| Chain | Submitter | Reward split | Source |
|---|---|---|---|
| Ethereum | Anyone can construct the object; a **block proposer** must include it | `whistleblower_reward = effective_balance // WHISTLEBLOWER_REWARD_QUOTIENT` (512); `proposer_reward = whistleblower_reward // PROPOSER_REWARD_QUOTIENT` (8). So of the reward pool, the **proposer gets 1/8 and the whistleblower 7/8**; if no whistleblower is named, the proposer is the whistleblower and receives the whole amount | `slash_validator`, phase0 `beacon-chain.md` L1707-1714; constants L639-640 |
| Cosmos | Evidence arrives **through consensus** (CometBFT block evidence), not as a user transaction with a bounty; `x/evidence` "does not contain any parameters" | No bounty is defined by the module | `x/evidence/README.md` section "Parameters" |
| Polkadot | Offences detected on-chain; a `unapplied` slash state exists with a **27-day grace period during which governance may reverse it** | Slashed DOT goes to the protocol's Dynamic Allocation Pool (from the March 2026 runtime, v2.1.0) | `docs.polkadot.com`, "Slashing" and "Equivocation Slash" |

**Design consequence (ANALYTICAL).** A bounty is not decoration: it is what makes the *detection* assumption
self-enforcing. Ethereum pays the reporter 7/8 of a pool sized at 1/512 of the offender's effective balance
(~0.195% of a 32 ETH validator). A chain with neither a bounty nor a covering consensus layer that propagates
evidence must state who is expected to pay the cost of *detecting and submitting*, or `A-ECO-1` fails for the
detection half of the assumption.

## 2.3 Penalty structure and the proven convexity properties

| Chain | Immediate penalty | Correlated / convex penalty | Source |
|---|---|---|---|
| Ethereum | `effective_balance // MIN_SLASHING_PENALTY_QUOTIENT_BELLATRIX` = **EB/32** (<= 1 ETH on a 32 ETH validator) | `adjusted_total_slashing_balance = min(sum(state.slashings) * PROPORTIONAL_SLASHING_MULTIPLIER_BELLATRIX, total_balance)`; per-validator `penalty = EB * adjusted_total / total_balance`, applied `EPOCHS_PER_SLASHINGS_VECTOR // 2` epochs after the slash | `slash_validator` L1702-1705; `process_slashings` L2223-2239; `MIN_SLASHING_PENALTY_QUOTIENT_BELLATRIX = 32`, `PROPORTIONAL_SLASHING_MULTIPLIER_BELLATRIX = 3` (bellatrix `beacon-chain.md` L125-126) |
| Cosmos | `SlashFractionDoubleSign` = **5%** (module default/example); downtime **1%** | Tombstone cap: **only the first double-sign is punished**; multiple infractions before evidence executes are "punished for single worst infraction, but not cumulatively" | `x/slashing/README.md` section Parameters, sections Tombstone Caps, Staking Tombstone |
| Polkadot | Level rubric: <=0.1% / <=1% / <=10% / <=100% of the validator slot | `min((3x/n)^2, 1)` where `x` = offenders, `n` = active set: 1/100 -> **0.09%**; 20/100 -> **36%** + chill. "rewards grow linearly ... slashing grows exponentially" | `docs.polkadot.com`, "Equivocation Slash", "Slash Calculation for Equivocation" |

**The proven property to carry across (ANALYTICAL, but a direct reading of the formulae).** Both Ethereum and
Polkadot make the *marginal* cost of joining a coordinated attack **super-linear**:

- Ethereum: with multiplier 3, a coalition slashing a fraction `f` of total stake causes each member to lose
  `min(3f, 1)` of effective balance **in addition** to EB/32. At `f = 1/3` the correlated penalty saturates at
  **100%**. The 1/3 safety threshold and the 1/3 confiscation threshold coincide by construction.
- Polkadot: `min((3x/n)^2, 1)` is quadratic in offenders; `x/n = 1/3` also gives 1.

**This is the single most transferable mechanism in this document.** It converts "we assume Byzantine stake
< 1/3" from an assumption about intent into a statement about *loss given attack*, and it is what makes the
bribe argument in §2.8 expensive rather than cheap.

**Deliberate relaxation worth noting (ANALYTICAL).** Cosmos' tombstone and "single worst infraction"
protection exist because honest key duplication is a real failure mode (the Polkadot docs list three real
incidents: era 774, Kusama 3329, Kusama 3995, all caused by cloned keystores). A design that adopts
Ethereum-style correlated penalties on a **small** validator set inherits a much larger *honest-mistake*
tail: with few validators, one operator running a duplicated key triggers a correlated penalty on a
non-trivial fraction of the set. **Mitigation is operational (slashing-protection DBs, remote signers, key
custody), and its absence is not fixable by parameter choice.** The repo's threat model already lists
"unintentional misconfiguration" as out of scope for prevention (F3,
`01-requirements-and-threat-model.md:148`).

## 2.4 Deadlines and evidence windows

| Chain | Explicit deadline? | Binding constraint | Source |
|---|---|---|---|
| Ethereum | **No explicit submission deadline.** | Evidence can be included at any time while the validator is *slashable*: `activation_epoch <= epoch < withdrawable_epoch`. A slashed validator's `withdrawable_epoch` is pushed to at least `epoch + EPOCHS_PER_SLASHINGS_VECTOR` = **8192 epochs ~ 36.4 days**, and the correlated penalty is only applied at `withdrawable_epoch - 4096` epochs. | `is_slashable_validator` L1133-1135; `slash_validator` L1699-1701; `process_slashings` L2231-2233; `EPOCHS_PER_SLASHINGS_VECTOR = 8192` L630 |
| Ethereum (bounded, practical) | A validator cannot be slashed twice (`not validator.slashed`). | Per-block inclusion caps (16 proposer / 2 attester slashings) bound *throughput*, not the window. | L1133; L664-665 |
| Cosmos | **Yes:** `Evidence.Timestamp >= block.Timestamp - MaxEvidenceAge` | `MaxEvidenceAge` is a **CometBFT consensus parameter** (`max_age_num_blocks`, `max_age_duration`), not an SDK param. | `x/evidence/README.md` section Equivocation |
| Polkadot | Offences are detected on-chain, so there is no "submission window"; there is instead a **27-day reversal grace period** before a slash applies. | Governance can cancel within the grace period. | `docs.polkadot.com`, "Slashing" |
| Cosmos (design intent) | — | "**there can be a delay between an infraction occurring, and evidence of the infraction reaching the state machine (this is one of the primary reasons for the existence of the unbonding period)**" | `x/slashing/README.md`, "Staking Tombstone" -> Abstract |

**That last quote is the load-bearing sentence for §3.3.** The unbonding period is not a UX choice; it is the
window in which late-arriving evidence must still be able to confiscate the stake that *caused* the offence.

**Stake-at-offence-time rule (SOURCED).** Cosmos: "the validator's stake is reduced ... of what their stake was
when the infraction occurred, rather than when the evidence was discovered. We want to 'follow the stake'."
(`x/evidence/README.md` section Equivocation). Ethereum does the same via `state.slashings[epoch % ...]` and the
`withdrawable_epoch` clamp. **A design that slashes only the *current* balance lets an offender withdraw
first and be slashed on a remainder — this is a real, documented failure mode that both chains
specifically engineered against.**

## 2.5 Unbonding / withdrawal delay: the reasoning, and how to derive it from *this* pipeline

| Chain | Delay | Stated reasoning | Source |
|---|---|---|---|
| Ethereum (minimum) | `MIN_VALIDATOR_WITHDRAWABILITY_DELAY = 256 epochs` = **98,304 s ~ 27.3 h**; plus a churn-limited exit queue; plus `EPOCHS_PER_SLASHINGS_VECTOR = 8192` epochs ~ 36.4 days for the correlated penalty to fully apply | The validator must remain slashable after it stops validating. Exit is queued: `exit_queue_epoch = max(max(existing exit_epochs), compute_activation_exit_epoch(current))`, incremented while `exit_queue_churn >= get_validator_churn_limit` | L692; L1660-1681; L630; churn `max(4, active_count / 65536)` L1481-1489, L701-702 |
| Ethereum (upper bound reasoning) | **Weak subjectivity period** | "the number of recent epochs within which there must be a Weak Subjectivity Checkpoint to ensure that an attacker who takes control of the validator set at the beginning of the period is slashed at least a minimum threshold in the event that a conflicting `Checkpoint` is finalized". `SAFETY_DECAY = 10`; the tolerated loss in the 1/3 margin is bounded so the residual safety margin is **>= 1/3 - 10/100 = 0.2333**. Formula: `MIN_VALIDATOR_WITHDRAWABILITY_DELAY + max(churn-term, top-up-term)` | `weak-subjectivity.md` L71-78, L100-125 |
| Ethereum (modern) | Exit *initiation* is now permissionless from the execution layer (EIP-7002, 0x01 credentials) with its own queue and fee-based rate limiting (`TARGET_WITHDRAWAL_REQUESTS_PER_BLOCK`) — **the delay is not removed** | — | EIP-7002 (eips.ethereum.org), retrieved 2026-10-05 |
| Ethereum (activation side) | EIP-7514 caps **activation churn** at `MAX_PER_EPOCH_ACTIVATION_CHURN_LIMIT = 8` validators/epoch, deliberately converting exponential into linear validator-set growth while reward-curve research continues | — | EIP-7514, retrieved 2026-10-05 |
| Cosmos | `UnbondingTime` param; SDK default example **259,200,000,000,000 ns = 3 days**. Chain-specific. | "`UnbondingDelegation` ... where shares **can be reduced if Byzantine behavior is detected**"; "Delegators ... must wait the duration of the UnbondingTime, **during which time they are still slashable for offences of the source validator if those offences were committed during the period of time that the tokens were bonded**" | `x/staking/README.md` section Parameters; sections UnbondingDelegation, Validator states |
| Polkadot | **Not verified from a primary source in this pass.** (The commonly cited 28-day unbonding is **UNVERIFIED** here.) | — | — |

**Cosmos Hub's own 21-day unbonding period could NOT be verified from a primary source in this pass. Mark
UNVERIFIED.** The SDK's default example (3 days) and the Hub's live parameter are different numbers and must
not be conflated.

**The derivation rule (ANALYTICAL, synthesised from the two primary quotes above).** The withdrawal delay
must be derived from the **settlement pipeline**, not from nominal proving time:

    D_withdraw  >=  W_evidence_detect + W_evidence_submit + T_L1_include(p) + T_L1_final + T_settle + M
    (FORMULA)

where each term is defined in §3.2/§3.3. The critical point for Etna PoS + ZK specifically:

- D5 requires **data and proof in the same L1 transaction**, so there is **no data-first window** in which a
  third party could inspect a published batch and object *before* settlement. Detection therefore cannot rely
  on "the data was on L1 for N hours before the proof arrived".
- Consequently the delay must cover evidence that is generated **only after** the batch is settled, or is
  generated concurrently on L2 and must then be carried to L1. That makes `T_L1_include` and `T_L1_final`
  load-bearing terms rather than rounding errors, and it makes **30 minutes of proving latency a lower bound
  on nothing** — the proof latency delays settlement, but the evidence window starts at the *offence*, which
  happens at L2 consensus time, potentially hours before the batch is provable.
- Therefore `D_withdraw >= (proof latency bound) + (L1 inclusion bound) + (L1 finality bound) + (processing)`
  **is necessary but not sufficient**: it must additionally cover the case where the offence is detected only
  when the batch is *settled*, i.e. add `T_replay`, the time for an independent party to re-execute or re-prove.
  This is why `A-DA-4` ("an independent prover can reconstruct the witness") is an **economic** assumption,
  not just a liveness one.

## 2.6 Delegation

| Question | Evidence | Source |
|---|---|---|
| Are delegators slashed? | Cosmos: yes, pro rata and automatically. Slashing reduces `validator.Tokens()`, so **every delegator share is worth less** — "Rather than iteratively slashing the tokens of every delegation entry, instead the Validator's total bonded tokens can be slashed, effectively reducing the value of each issued delegator share." | `x/staking/README.md` section Delegator Shares |
| Are *unbonding* delegations slashed? | Yes — this is the whole point of the unbonding period. | `x/staking/README.md` sections UnbondingDelegation, Validator states |
| Are *redelegating* shares slashed? | Yes — "their shares can be slashed if their tokens have contributed to a Byzantine fault committed by the source validator". | `x/staking/README.md` section Redelegation |
| Polkadot | Nominators are slashed **proportionate to the amount staked to the offending validator**; a nominator with a large bond could be hit by several validators. | `docs.polkadot.com`, "Slashing" |
| **Polkadot's 2026 reform** | "After the implementation of the staking reforms in 2026, **nominators are expected to become unslashable** on Polkadot. Once this change takes effect, **only the validator's self-stake will be subject to slashing**." | `docs.polkadot.com`, "Slashing" |
| Nothing-at-stake for delegators | Vitalik's PoS FAQ: with rewards and no penalties, staking on every branch is rational; the tragedy-of-the-commons means "each individual stakeholder might only have a 1% chance of being 'pivotal' ... hence, the bribe needed to convince them personally to join an attack would be only **1% of the size of their deposit**; hence, the required combined bribe would be only **0.5-1% of the total sum of all deposits**". Solved by slashing + fixing validator selection ahead of the fork. | `pos_faq.html` L337-398, retrieved 2026-10-05 |
| LSTs as delegated stake | Liquid staking introduces risks "not captured by standard PoS economic security arguments": pool operational performance is positively associated with subsequent normalized LST returns; a **low-stake adversary** can degrade a target pool's consensus performance and monetise at the application layer via leveraged shorts, "profitable with over one-half probability for LSTs of major staking pools". | arXiv:2605.01025, *Your Loss is My Gain: Low Stake Attacks on Liquid Staking Pools*, 2026-05-01 |
| Leverage on delegated stake | Looping LSD collateral through Aave/Curve amplifies staking exposure; leverage magnifies both yield and loss. | arXiv:2401.08610, *Leverage Staking with Liquid Staking Derivatives (LSDs)*, 2023-11-28 |

**Recommendation (ANALYTICAL).** For a **small** validator set with 2 s slots and a 30-minute proof pipeline,
delegation should be **out of scope for v1**, and the reason is structural, not paternalistic:

1. **Alignment is not achievable by parameter choice within one chain generation.** The delegation contract
   would have to pass slashing through to delegators *and* make unbonding delegations slashable *and* make
   redelegations slashable, or delegators get a free option on operator misbehaviour. Cosmos does all three,
   which is precisely why its staking module is one of the largest and most intricate modules in the SDK.
   Reproducing that is a multi-year surface, and the repo explicitly ranks simplicity first
   (`tokenomics_objective_metrics.md:21`).
2. **Polkadot's 2026 reform is direct evidence that the alignment problem is hard to solve.** A chain with the
   most sophisticated stake-allocation algorithm in production (Phragmen) is moving *away* from slashable
   nominators toward self-stake-only slashing. Copying the earlier, more complex design would be adopting a
   design its inventor is retiring.
3. **A small set changes the risk profile.** With few validators, a delegator's stake is concentrated against
   a small number of operators; there is no diversification benefit to offset the correlation penalty, and
   the `min((3x/n)^2,1)` / `3f` penalty makes an honest key-rotation mistake by one operator a correlated hit
   on that operator's delegators only.
4. **If delegation is nevertheless required** (e.g. because the entry floor would otherwise exclude small
   holders), the minimum viable design is: **operator self-stake >= the operator's own bond floor, slashable
   first**, plus explicit, documented pass-through to delegators, plus a recorded decision that the
   pass-through's simplicity limits are *accepted*. Nothing weaker is honest.

## 2.7 Stake concentration, liquid staking, and why per-address caps do not work

| Claim | Evidence | Source |
|---|---|---|
| Concentrated stake is a live concern at Ethereum scale | EIP-7514 rationale: "Liquid staking tokens (LSTs) also contribute to this, given stakers can use them as they use unstaked ETH"; increasing staked levels strain the consensus layer ("gossip messages ... growing Beacon state size"); "it's unclear how much marginal security benefits come from additional economic weight" | EIP-7514, retrieved 2026-10-05 |
| Churn caps slow but do not prevent concentration | EIP-7514 is explicitly "meant only to slow down growth" and "allows more time for research into more comprehensive solutions" | EIP-7514 |
| Reward composition at high stake rates | "at 100% of ETH supply staked, yearly consensus rewards alone (excluding MEV/transaction fees) for validators still represent ~1.6% of their stake. This small yield does not necessarily dissuade additional capital staking due to the often much higher and unpredictable yields from MEV." | EIP-7514 |
| LSTs are the leading staking method and change the security model | arXiv:2404.00644, *SoK: Liquid Staking Tokens (LSTs) and Emerging Trends in Restaking*, 2024-03-31 |
| Liquid staking is "seen by some as a threat to the Proof-of-Stake" | arXiv:2401.16353, *Empirical and Theoretical Analysis of Liquid Staking Protocols*, 2024-01-29 |
| Measured participation and decentralisation of the Ethereum PoS set | arXiv:2306.10777, *Ethereum Proof-of-Stake Consensus Layer: Participation and Decentralization*, 2023-06-19 |
| Economic-security accounting when staked value is far below secured value | arXiv:2401.05797 (STAKESURE): as of 2023-07-15 Ethereum "has around 410 Billion USD in total assets on chain ... but has only 33 Billion USD worth of ETH staked", an apparent 11x imbalance; the paper formalises **cost-of-corruption** and **profit-from-corruption** as separate objects | arXiv:2401.05797, 2024-01-11 |
| Formal model of the Ethereum staking market under issuance changes | arXiv:2503.14385, *Towards a Formal Framework of the Ethereum Staking Market*, 2025-03-18 |

### Why a per-address (or per-validator) cap does not prevent monopolisation — stated precisely

This argument is **ANALYTICAL**; no primary source located in this pass states it in this form. The repo
already lists "Per-address caps prevent monopolization" among its explicit **non-arguments**
(`01-requirements-and-threat-model.md:214`), so the conclusion is pre-committed by the project.

Let `C` be the cap per address, `S_total` the total stake, `k = S_total / C` the number of addresses needed
to hold everything, and `k_op` the marginal cost of operating one additional address/validator identity
(key generation, custody, monitoring, per-validator overhead, and — if the protocol charges a flat bond —
the amortised bond).

1. **The cap is a quantity constraint on *labels*, not on *capital*.** An adversary who wants to control a
   fraction `b` of stake acquires `b * S_total` tokens and distributes them across `b * k` addresses. The
   *capital* cost of the attack — the dominant term — is **unchanged**. The cap adds only `b * k * k_op`.
2. **Therefore the cap raises attack cost by an additive term that is linear in `k`, while token acquisition
   cost is linear in `b * S_total`.** The ratio (cap overhead)/(attack cost) is `k_op / C`: it shrinks as the
   cap rises and never cancels the dominant term. Making `k_op` large is the only way to make a cap bind, and
   `k_op` is bounded above by the honest-participant cost of entry, which R1 forbids making prohibitive.
3. **A cap on *validators* is worse than a cap on *addresses*, because it is also a cap on the honest
   validator set size.** If the protocol restricts the number of validator slots `n_max`, then the cost of
   *acquiring a slot* becomes the binding constraint, and a wealthy adversary can outbid honest operators for
   existing slots (a secondary market in slots) rather than acquire tokens. Cosmos' `MaxValidators` is a
   consensus-performance parameter, not a decentralisation mechanism; Polkadot's slot allocation is handled by
   Phragmen precisely because slot competition is the real problem, and Polkadot's 2026 self-stake minimum
   is a *floor* on operator commitment, not a cap on stake.
4. **Caps interact badly with delegation**: a delegator facing a cap must spread stake over many operators,
   which *increases* the number of slashable relationships per delegator and therefore the variance of loss
   (see §2.6), without reducing the total stake any single beneficial owner controls.
5. **What actually constrains concentration** is (a) the **total cost of acquiring the float** — which is a
   liquidity and slippage question, not an address question (§2.8), and (b) **rewards that are concave in
   stake** (so the marginal token is worth less to a large holder), and (c) **transparency**, which makes
   concentration observable even when it cannot be prevented. EIP-7514's own text concedes the third is what
   policy has, for now.
6. **The honest statement for the spec (ANALYTICAL).** Any rule that claims a cap "prevents monopolisation"
   must be deleted or restated as "the cap makes `k`-way splitting necessary and therefore adds `b * k * k_op`
   to attack cost, where `k_op` is UNMEASURED". A cap does not change the *shape* of the cost curve; it shifts it.

## 2.8 Attack-cost analysis: methodology, and why the cost is time-varying

### The published frameworks

| Framework | Content | Source |
|---|---|---|
| **Cost-of-corruption / profit-from-corruption** | Formalises the two quantities **separately**; notes the apparent imbalance between value secured and value staked, and derives sharper bounds on profit-from-corruption plus new confirmation rules that reduce the bound; introduces an "insurance" allocation of slashed funds with a notion of *strong cryptoeconomic safety* — "no honest transactor ever loses money" | arXiv:2401.05797 (STAKESURE), 2024-01-11 |
| **Bribe / pivotality argument** | "the bribe needed to convince them personally to join an attack would be only 1% of the size of their deposit; hence, the required combined bribe would be only 0.5-1% of the total sum of all deposits" — the argument for why *rewards alone* are insufficient and slashing is required | Vitalik Buterin, *Proof of Stake FAQ*, section "nothing at stake", 2017-12-31 |
| **Convex correlated penalties** | Ethereum `min(3f, 1)`; Polkadot `min((3x/n)^2, 1)` — the cost of an attack is engineered to be **super-linear in the number of attackers**, so the bribe must not merely compensate each attacker but must compensate them for a penalty that grows with the coalition | §2.3 |
| **Capital-efficiency comparison** | Sufficient condition for a restaking graph to be secure, and a transformation into separate secure PoS protocols; total-capital comparisons between restaking and PoS | arXiv:2505.24440, *The Cost of Secure Restaking vs. Proof-of-Stake*, 2025-05-30 |
| **LST cross-layer attacks** | A low-stake adversary can profit without controlling the stake that the standard accounting assumes is the attack cost — the accounting is *incomplete*, not merely imprecise | arXiv:2605.01025, 2026-05-01 |
| **Slashing as a substitute for hashpower** | "Ability to use economic penalties to make various forms of 51% attacks vastly more expensive to carry out than proof of work ... 'it's as though your ASIC farm burned down if you participated in a 51% attack'" — attributed to Vlad Zamfir | `pos_faq.html` L232-235 |

### The comparison, stated as a FORMULA with no invented numbers

    AttackCost(t)      =  b * S_total * P(t) * (1 + sigma(t))  +  OC(t)  +  E[Slash]
    AttackProfit(t, W) =  EV_extractable(t, W) + OV_option(t, W) - OC_attack(t)
    Requirement (A-ECO-1):   AttackCost(t)  >=  Lambda * AttackProfit(t, W)     Lambda >= 1, Lambda UNMEASURED

| Symbol | Meaning | Status |
|---|---|---|
| `b` | Byzantine stake threshold of the selected protocol (1/3 under `A-CONS-1`) | FORMULA |
| `S_total` | Aggregate slashable stake | PARAM (Phase 4) |
| `P(t)` | TAIKO market price at time `t` | **UNMEASURED / time-varying** |
| `sigma(t)` | Slippage + illiquidity premium for acquiring `b * S_total` of the float within the attack window | **UNMEASURED / time-varying** |
| `OC(t)` | Opportunity cost of capital locked for `D_withdraw` | FORMULA |
| `E[Slash]` | Expected confiscation = `Lambda_slash * stake_at_offence` | FORMULA |
| `EV_extractable(t, W)` | Value extractable during the reversion window `W` (double-spend against L1-final bridge withdrawals, DEX drains, etc.) | **UNMEASURED** |
| `OV_option(t, W)` | Option value of *holding* the ability to attack (e.g. shorting TAIKO/LSTs before the attack) | **UNMEASURED** |
| `W` | Attack window = time from attack to irreversible loss of the attacker's stake = `D_withdraw` (the stake stays slashable for the whole window) | FORMULA |

### Three explicit warnings (ANALYTICAL)

1. **Attack cost is time-varying and can fall for reasons outside the protocol's control.** `P(t)` and
   `sigma(t)` both move. A design that passes `A-ECO-1` at one price can fail at a lower price with **no rule
   change**. `04-architecture-decision.md` must therefore state the *price at which the design stops being
   secure* as a derived quantity, not assert security at an assumed price. This is exactly the mechanism in
   arXiv:2606.03587: "A protocol can have a large nominal reserve and still be close to security failure
   after adverse price or demand shocks."
2. **`sigma(t)` is not a rounding error when `b * S_total` is a large fraction of the float.** If the design
   targets `b * S_total` greater than the order of the daily traded volume, the attacker cannot acquire it at
   the marginal price at all. **`sigma(t)` must therefore be measured from order-book depth / volume, and until
   it is, any statement of the form "an attack costs X million" is UNVERIFIED and must not appear.**
3. **`OV_option` is the term that liquid staking and derivatives make non-negligible.** arXiv:2605.01025
   demonstrates a cross-layer attack that is "profitable with over one-half probability" at **low stake**,
   because the profit is booked at the application layer against an LST repricing rather than against the
   consensus layer. Standard PoS accounting — which assumes the attacker must be a large stakeholder —
   **does not bound this**. If TAIKO acquires an LST or a liquid-derivative market, the `AttackCost` formula
   above is necessary but **not sufficient**.

## 2.9 Rewards funding: sources, the budget identity, and the constraint

### Where the money can come from

| Source | Mechanism | Evidence |
|---|---|---|
| L2 execution fees | Base fee + priority fee charged on L2 | EIP-1559 defines base fee and priority fee |
| Priority fees / tips | On Optimism-style stacks these are routed to the `SequencerFeeVault`, base fees to `BaseFeeVault`, and the L1-data-fee component to `L1FeeVault` | Optimism specs, `exec-engine.md` L104-108, retrieved 2026-10-05 |
| L1 data cost (a **negative** term) | Pre-Ecotone: `(rollupDataGas + l1FeeOverhead) * l1BaseFee * l1FeeScalar / 1e6`; Ecotone and later move to blob-based pricing | Optimism specs `exec-engine.md` L130-143 |
| MEV / ordered priority | EIP-7514 explicitly contrasts consensus rewards (~1.6% at 100% staked) with "the often much higher and unpredictable yields from MEV" | EIP-7514 |
| L1 subsidy / treasury | The DAO controller can hold and forward ETH (`Controller.sol:36`, `Controller.sol:69-75`); the treasury is `0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da` | §1.6 |
| Inflation (new TAIKO) | **Requires a token upgrade**, because the L1 token has no mint path after `init` | `TaikoToken.sol:41`; §1.1 |
| Slashed stake (redistributed) | Currently **burned 50%** and paid 50% to the prover | `LibBonds.sol:161-165` |

### The identity (FORMULA — no number in it is measured)

    SUM_rewards  <=  F_exec_L2 + F_priority_L2 + MEV_captured + S_explicit
                     - C_L1_data - C_L1_verify - C_bridge_ops
    (FORMULA: total reward budget <= net protocol revenue + explicit subsidy)

| Term | Definition | Status |
|---|---|---|
| `SUM_rewards` | Everything paid to validators + provers in a year | FORMULA |
| `F_exec_L2` | L2 execution fees (base + priority) actually collected | **UNMEASURED** |
| `MEV_captured` | The portion of ordering value the protocol actually captures (as opposed to leaking to searchers/builders) | **UNMEASURED** |
| `S_explicit` | Explicit, budgeted, time-limited DAO subsidy. **Must be a line item with an end date, not a standing assumption** | UNMEASURED |
| `C_L1_data` | Blob/calldata cost of posting batch data for every settled batch | **UNMEASURED** |
| `C_L1_verify` | Gas of the proof-verification + state-update L1 transaction | **UNMEASURED** |
| `C_bridge_ops` | Any other protocol L1 operating cost | **UNMEASURED** |

### The constraint, stated as the project requires

> **No token appreciation and no unlimited subsidy may be assumed.** (ANALYTICAL, mandated by the task.)
> Equivalently: `SUM_rewards` must be fundable from `F_exec_L2 + F_priority_L2 + MEV_captured + S_explicit` **over
> a stated horizon**, with `S_explicit` bounded and expiring.

This is exactly the problem formalised by **arXiv:2606.03587, *Reserve Depletion and Security Runway in
Proof-of-Stake Systems* (2026-06-02)**:

- "Many proof-of-stake protocols finance validator rewards from two sources: transaction fees and a finite
  reserve of tokens."
- The paper derives an "exact **state-dependent reserve threshold**" separating three regions:
  **infeasibility / reserve-dependent security / fee-only security**, and shows "a successful hand-off occurs
  exactly if the fee-only region is reached before that failure time".
- Its main implication, quoted: "**reserve policy should not be evaluated by nominal depletion dates or
  steady-state reward ratios alone. A protocol can have a large nominal reserve and still be close to security
  failure after adverse price or demand shocks.** Conversely, once demand crosses the fee-only threshold, the
  reserve becomes redundant for security."
- It provides "stress-test guarantees that convert **lower confidence bands for token price and demand** into
  reserve requirements".

**Therefore: the honest deliverable is a *runway* calculation, not a yield.** And the correct framings are
(a) the *fee-only threshold* — the transaction volume at which fees alone fund the target security level, and
(b) the *runway* — how long an explicitly bounded reserve buys before the design must halt or reduce `n`.

### What measurable data would set the numbers

| Quantity | How to measure | Required by |
|---|---|---|
| `F_exec_L2`, `F_priority_L2` per day | Historical L2 fee revenue at the target 2 s cadence | §2.9 budget |
| `C_L1_data` per batch | Blob fee x blobs per batch, at observed blob-market prices; plus calldata fallback | §2.9 budget |
| `C_L1_verify` per batch | Gas of the D5 atomic (data + proof) transaction x observed L1 base fee | §2.9 budget |
| `MEV_captured` | Fraction of ordering value retained by the protocol vs leaked | §2.9 budget |
| Proof cost per batch | Prover-side USD/batch for RISC Zero and SP1 at the chosen configuration | §3.4 |
| Validator operating cost `C_op` | Hardware + bandwidth + ops + L1 gas per validator-month | §3.1, §3.4 |
| Order-book depth / traded volume | For `sigma(t)` at `b * S_total` | §2.8 |
| L1 inclusion and finality distributions | Empirical quantiles of inclusion delay and L1 finality time | §3.2 |
| Detection latency | Time from an L2 offence to a constructible evidence object, incl. gossip | §3.3 |

---

# 3. Numerical skeleton

**Every entry below is FORMULA, UNMEASURED, or SOURCED. No value is asserted as measured.**

## 3.1 Minimum viable validator stake `S_min`

Three constraints must hold simultaneously. `S_min = max(S_attack, S_capcost, S_entry_min)`, subject to
`S_min <= S_entry_max` or the design fails R1.

**Constraint A — attack cost (per-stake, not per-validator):**

    S_total  >=  Lambda * [EV_extractable + OV_option] / ( b * P(t) * (1 + sigma(t)) )      (FORMULA)

This bounds the **aggregate**, not the individual. It cannot set `S_min` on its own.

**Constraint B — cost recovery for one validator (this is what sets `S_min`):**

    S_min  >=  C_op_annual / ( r_gross - rho_ops )        (FORMULA)
    equivalently, the operator's break-even reward rate is  r_be = C_op_annual / S + rho_ops

where `C_op_annual` = hardware + bandwidth + ops + L1 gas, and `rho_ops` is the operator's required margin.

**Constraint C — participation floor (R1: permissionless entry):**

    S_min  <=  S_affordable(median_participant)          (FORMULA, requires a distribution — UNMEASURED)

**Constraint D — validator-set size window:**

    n = S_total / S_min ,   n in [ n_min_consensus , n_max_consensus ]     (FORMULA)

`n_min_consensus` and `n_max_consensus` are **consensus-rule outputs, not economics inputs** — this document
does not set them. Economics supplies `S_min` and the budget as a function of `n` (§3.4).

| Symbol | Status | Note |
|---|---|---|
| `C_op_annual` | **UNMEASURED** | Must be measured for a reference validator host (CPU, RAM, NVMe, 2 s block cadence, gossip bandwidth, L1 gas for deposits/withdrawals/evidence). Do **not** copy Bitcoin or Ethereum validator costs; the 2 s cadence and L2 state size dominate and are different. |
| `r_gross` | FORMULA | Output of §3.4, not an input. |
| `S_affordable` | **UNMEASURED** | Requires a survey or on-chain distribution of intended participants. |
| `b`, `Lambda`, `P`, `sigma`, `EV`, `OV` | FORMULA / UNMEASURED | See §2.8. |

**Worked *shape* only (no numbers).** If `C_op_annual` is `X` and the required gross rate is `r`, then
`S_min = X / (r - rho_ops)`. The sensitivity that matters: **`S_min` is inversely proportional to the reward
rate.** A design that cannot pay a rate above the operator's margin has **no finite `S_min`** — the validator
set collapses. That is the correct, non-obvious conclusion to record: *the reward rate, not the attack-cost
argument, is the binding constraint on the minimum stake.* **This must be checked before any cap on `n` is chosen.**

## 3.2 Exit / withdrawal delay `D_withdraw`

    D_withdraw  >=  T_proof_bound + T_detect + T_evidence_submit + T_L1_include(p) + T_L1_final + T_process + M
    (FORMULA)

| Term | Definition | Status |
|---|---|---|
| `T_proof_bound` | Upper bound on proving latency (D6: minutes -> 30 min = 900 L2 blocks) | **SOURCED as a design constraint (D6)**, not measured for the target config |
| `T_detect` | Time from the offence occurring on L2 to a *constructible* evidence object reaching someone willing to submit | **UNMEASURED** |
| `T_evidence_submit` | Time for that party to build and submit the L1 transaction (bounded above by the evidence window, §3.3) | FORMULA |
| `T_L1_include(p)` | `p`-quantile L1 inclusion delay for a valid transaction; **must be a quantile, not a mean**, and must not assume a fixed L1 slot duration (R12) | **UNMEASURED** |
| `T_L1_final` | Time for the accepting L1 transaction to reach Ethereum finality (~2 epochs at Ethereum's own finality rules — **use the measured bound, not a nominal constant**) | **SOURCED as an Ethereum property; the value must be measured at design time** |
| `T_process` | Time for the L1 contract (or governance) to process the evidence and apply the slash; Polkadot uses a **27-day reversal grace period** for governance safety, Cosmos applies immediately | **SOURCED that both exist; UNMEASURED as a choice** |
| `M` | Safety margin for reorgs, congestion spikes, and the "evidence arrived at the last moment" case | **UNMEASURED** |

**Non-negotiable structural points.**

1. `D_withdraw` is **not** `T_proof_bound` alone. D5 removes the data-first window, so the delay must extend
   past settlement, not merely past proving.
2. `D_withdraw` must exceed the **correlated-penalty application delay** if a correlated penalty is adopted:
   Ethereum applies it at `withdrawable_epoch - EPOCHS_PER_SLASHINGS_VECTOR/2`, i.e. **up to 8192 epochs
   (~36.4 days) after the slash**. On a small validator set this is a policy choice with a direct UX cost:
   **a long delay is the price of a correlated penalty.** The two must be chosen together or neither works.
3. **Slashing must follow the stake at offence time**, not the balance at evidence time (§2.4). A rule
   "slash the current balance" is defeated by a withdrawal race and must be rejected explicitly.
4. The repo already contains a working precedent for the *shape*: `requestWithdrawal()` stamps a timestamp and
   the `_minBond` floor applies until `withdrawalRequestedAt + _withdrawalDelay` elapses
   (`LibBonds.sol:76-81`, `Inbox.sol:417-420`). **But** the precedent also disables the account on request
   (`LibBonds.sol:139-140`), which for a validator means an exiting validator stops validating. A validator
   design needs "exit requested, still validating and still slashable", which is a **change** to the existing
   semantics.

## 3.3 Evidence-submission window `W_evidence`

    W_evidence  >=  D_withdraw - T_grace - T_L1_include(p) - T_L1_final - T_process   (FORMULA)
    W_evidence  >=  T_replay                                                          (FORMULA, lower bound)

| Symbol | Definition | Status |
|---|---|---|
| `T_grace` | Any deliberate grace period before a slash applies (Polkadot: 27 days) | **SOURCED that it exists; UNMEASURED** |
| `T_replay` | Time for an independent party to reconstruct the witness and re-execute (or re-prove) a batch to detect a *non-equivocation* fault. Bounded by `A-DA-4` | **UNMEASURED** |

**Two distinct classes of evidence, two distinct windows (ANALYTICAL).** Conflating them is a common error:

| Class | Example | Evidence object | Window |
|---|---|---|---|
| **Equivocation / double-sign** | two conflicting PoS certificates or votes at one height/round | two signed messages — self-contained, cheap, immediately verifiable | The full `W_evidence`; the offence is *provable by anyone who saw both messages* |
| **Invalid transition** | a settled batch whose state transition is wrong but which carried a valid proof (i.e. `A-CRYPTO-1` failed) or a withheld certificate revealed late (threat model section 6.2) | requires re-execution; expensive and slow | `W_evidence` must additionally cover `T_replay`; **and per section 6.5 of the threat model this may be outside the fault model entirely** |

**Do not invent a universal window.** The spec must state `W_evidence` as the *pair* of formulas above with
every term UNMEASURED, and must state which term binds.

## 3.4 Reward rate and total cost as a function of `n`

**Per-validator break-even rate:**

    r_req(n)  =  [ C_op(n) / S(n) ]  +  rho_capital                   (FORMULA)

where `rho_capital` = required return on locked capital = risk-free rate + illiquidity premium (for
`D_withdraw`) + slashing-loss premium + **price-risk premium** (the operator is paid in TAIKO but pays costs
in fiat -> the operator bears TAIKO/USD volatility). `rho_capital` is **UNMEASURED**.

**Total annual budget:**

    Budget(n)  =  n * C_op(n)  +  rho_capital * S_total               (FORMULA)
    with  S_total = n * S   =>   Budget(n) = n * ( C_op + rho_capital * S )

**This decomposition is the key structural fact (ANALYTICAL):** the *capital* component scales with
`S_total` (independent of how it is split), while the *operating* component scales with `n`. Therefore:

> **Splitting the same stake across more validators increases the reward budget linearly in `n` without
> increasing `S_total`.** Decentralisation of the validator set is *bought* with operating-cost funding.
> Any rule that forces a small `S_min` (to admit small participants) therefore forces a large `n` and a
> proportionally larger fiat-denominated budget — while the fee revenue that must fund it does **not** scale
> with `n`.

**Fee-only feasibility:**

    n_max_fundable  =  ( F_exec_L2 + F_priority_L2 + MEV_captured + S_explicit - C_L1_data - C_L1_verify - C_bridge_ops )
                       / ( C_op + rho_capital * S )                    (FORMULA)

**Runway (from arXiv:2606.03587):**

    Runway  =  R_reserve / ( Budget(n) - NetFeeRevenue )   while NetFeeRevenue < Budget(n)
    Fee-only region reached  <=>  NetFeeRevenue  >=  Budget(n)         (FORMULA)

**Required table for Phase 4 (UNMEASURED, must be filled with measurements, not estimates):**

| Row | `n` | `S_min` | `r_req` | `Budget(n)`/yr | `NetFeeRevenue`/yr | `S_explicit`/yr | Runway |
|---|---|---|---|---|---|---|---|
| Must be produced | UNMEASURED | UNMEASURED | FORMULA | FORMULA | UNMEASURED | UNMEASURED | FORMULA |

## 3.5 Market data: status

| Datum | Status |
|---|---|
| TAIKO spot price | **UNVERIFIED.** Not obtained from a primary source in this pass. |
| TAIKO market capitalisation | **UNVERIFIED.** |
| TAIKO circulating / free float | **UNVERIFIED.** |
| TAIKO order-book depth or 24 h volume (for `sigma(t)`) | **UNVERIFIED.** |
| Any staking yield | **UNVERIFIED.** |

> **The protocol must not hard-code any of these.** Every one is an input to `sigma(t)`, `S_total`, or
> `AttackProfit`, i.e. every one is a quantity that can invalidate `A-ECO-1` (§2.8). A constant in a
> constructor or an immutable is a claim that the value is stable; none of the above is.

---

# 4. Risks and honest limitations

## 4.1 What cannot be bounded

| # | Limitation | Why it cannot be bounded |
|---|---|---|
| L1 | **No universal bound on user economic loss.** | The threat model already forbids inventing one (`01-requirements-and-threat-model.md:263`, D2 obligation 4: "No universal bound on economic loss may be invented"). Loss depends on `EV_extractable`, which depends on the value bridged, the DEX depth, and how long the breach is undetected — none of which the protocol controls. |
| L2 | **`A-ECO-1` is an assumption, not a guarantee.** | Its failure mode is "attacks become profitable". The protocol can only make the *dollar* cost of an attack observable; it cannot fix it, because `P(t)` and `sigma(t)` are exogenous (§2.8). |
| L3 | **`sigma(t)` (slippage) is unbounded in the direction that matters.** | If `b * S_total` exceeds available liquidity, cost of acquisition is not merely high — it is *undefined* at the marginal price, and the attacker's rational strategy becomes a slow accumulation over months, which no protocol parameter observes. |
| L4 | **The `OV_option` term is not covered by stake-based accounting.** | arXiv:2605.01025 shows a low-stake, application-layer-profitable attack against LSTs. If TAIKO has an LST or a derivatives market, "cost of attack > stake acquired" is an incomplete statement (§2.8). |
| L5 | **zkVM soundness (`A-CRYPTO-1`) is not an economic parameter.** | If it fails, a *valid* proof attests a false transition. No slashing rule repairs this, and no reward budget prices it. It is listed as unrecoverable by protocol design (`01-requirements-and-threat-model.md:97`). |
| L6 | **Governance (`A-GOV-1`) can rewrite every rule.** | A DAO upgrade can change `D_withdraw`, the slash fraction, or the token's mint authority. Staking economics cannot bind the governance that defines them; this is an explicit trust assumption (`01-requirements-and-threat-model.md:131`). |
| L7 | **The detection half of `A-ECO-1` is unbounded unless someone is paid to detect.** | Cosmos relies on a consensus-layer evidence path; Ethereum pays a 7/8 bounty. A design with neither has an unpriced assumption (§2.2). |
| L8 | **Honest-mistake tail scales with operator count, not with stake.** | Polkadot's real incidents (era 774, Kusama 3329/3995) were all cloned keystores. A correlated penalty on a small set makes one operator's operational error a large fraction of the set's loss (§2.3). |

## 4.2 What is conditional

| # | Conditional claim | Condition | If the condition fails |
|---|---|---|---|
| C1 | "Byzantine stake is unprofitable" | `A-CONS-1` (b < 1/3) **and** `A-ECO-1` at the prevailing price, simultaneously | Safety claims do not apply (`01-requirements-and-threat-model.md:107`, F2) |
| C2 | "Slashed stake deters" | The slashed stake is **actually confiscated**, i.e. evidence can be included before the stake is released (§3.2) | The penalty is not credible; slashing is decoration |
| C3 | "Exit delay protects the protocol" | `D_withdraw` is derived from the *settlement pipeline* (§2.5) and slashing follows stake-at-offence-time (§2.4) | A withdrawal race defeats the delay |
| C4 | "Rewards are sustainable" | `SUM_rewards <= F + S_explicit` with `S_explicit` bounded and expiring, **and** the fee-only region is reached before the reserve depletes (arXiv:2606.03587) | Security degrades silently while nominal reserves still look large |
| C5 | "The validator set is decentralised" | `S_min` is low enough to admit small participants **AND** the reward budget funds the resulting `n` (§3.4) | A `S_min` that admits small participants without funding their operating cost produces a set that shrinks to the cheapest operators |
| C6 | "Delegation is safe" | Delegators are slashed, unbonding delegations are slashable, redelegations are slashable — all three (§2.6) | Delegators hold a free option on operator misbehaviour |
| C7 | "The design is simple enough to be implemented correctly" | Rewards and slashing can be explained to a prover-company engineer in one page (`tokenomics_objective_metrics.md:21`) | The stated objective is violated and the failure is F3, not F1 |

## 4.3 Consequences of a TAIKO price collapse (ANALYTICAL, following from §2.8)

Assume `P` falls by a factor `gamma` while the token amount `S_total` is fixed.

| Effect | Mechanism | Consequence |
|---|---|---|
| Attack cost falls by `gamma` | `AttackCost = b * S_total * P * (1 + sigma)` | `A-ECO-1` can fail with **no rule change**. The design's security is a function of a price it does not control. |
| Reward rate in fiat falls by `gamma` | Operators pay fiat costs | `r_req` rises in token terms; the protocol must pay **more tokens** for the same security, which increases sell pressure — the classic reflexive loop. |
| `rho_capital` rises | Price risk + expected slashing loss | Fewer rational operators at any given token reward -> `n` falls -> the security budget rises further per unit of stake |
| Honest operators exit first | They are the ones with alternatives | Adverse selection: the residual set is the one with the lowest outside option, not the most competent |
| `S_total` declines as operators unbond | Unbonding is bounded by `D_withdraw`, so the decline is **slow and visible** | This is the *only* mitigation available, and it is a consequence of §3.2, not of a price rule. **It is the strongest argument for choosing `D_withdraw` generously.** |
| Slashed stake is worth less | If slashes are burned or sent to treasury | Deterrence weakens exactly when it is most needed |
| LST/derivative dynamics worsen `OV_option` | The arXiv:2605.01025 monetisation channel needs a repricing event | A price collapse is precisely the repricing event that makes an application-layer short profitable |

**The honest formulation for the spec.** There is no parameter that makes a PoS chain secured by a volatile
token robust to that token's collapse. The available responses are: (a) **disclose the price at which the
design stops being secure** (a derived number, not an assumption), (b) **shorten the attack window**
(`D_withdraw` is a trade-off: long protects against late evidence, short reduces exposure to a falling price —
this trade-off must be stated, not hidden), (c) **diversify the security budget** so that the fee-only region
is reached earlier, and (d) **monitor and halt** — a safe halt is a first-class outcome
(`01-requirements-and-threat-model.md:150-151`).

## 4.4 Open questions this document does not close

1. Which address owns a new staking contract? (§1.2 — two candidates in-tree.)
2. Is the `No Built-In PoS Reward` line (`tokenomics_objective_metrics.md:19`) still policy? A "yes" forbids
   inflationary staking rewards and forces the design into fees + explicit bounded subsidy.
3. Slashed stake: burn (current code, `LibBonds.sol:161-165`), treasury (whitepaper,
   `tokenomics-whitepaper.tex:39`), redistribution to reporters (§2.2), or to harmed parties (arXiv:2401.05797)?
   These have different deterrence and different securities-law profiles, and the repo currently contradicts itself.
4. Is the existing `LibBonds` ledger (uint64 **gwei**, one slot per bond) extended, or is a separate staking
   contract introduced? (§1.4 point 3.)
5. Is `ProverWhitelist` (currently active, `LibL1Addrs.sol:39`) replaced, retained as a bootstrap, or run in
   parallel? A design that keeps a whitelist while claiming permissionless `R1` is inconsistent.
6. Does the correlated penalty apply on a small `n`? (§2.3, §4.1 L8.) This is a Phase 3/4 decision with a
   direct UX cost (`D_withdraw` must grow to cover the penalty-application delay).
7. Who is paid to watch and report? (§2.2, §4.1 L7.)
8. Is delegation in or out? (§2.6.) A recorded "out" is a legitimate answer and is the simpler one.

---

# 5. Repository fact index (pinned `7718753c1`)

| File | Lines cited |
|---|---|
| `packages/protocol/contracts/layer1/mainnet/TaikoToken.sol` | 9-10, 12-13, 17-21, 35-42, 44-51, 53-74, 83-90, 92-96, 98-114, 118-126, 130-136 |
| `packages/protocol/contracts/layer1/mainnet/TaikoToken_Layout.sol` | 21, 36-38 |
| `packages/protocol/contracts/shared/governance/TaikoTokenBase.sol` | 8-14, 19, 22-24, 27-30, 32-34 |
| `packages/protocol/contracts/layer1/mainnet/MainnetDAOController.sol` | 9-12, 14, 17-19, 24-31 |
| `packages/protocol/contracts/layer1/mainnet/MainnetDAOController_Layout.sol` | 21-23 |
| `packages/protocol/contracts/shared/governance/Controller.sol` | 11, 16-20, 28, 36, 42-44, 46-53, 58-64, 69-75 |
| `packages/protocol/contracts/shared/common/EssentialContract.sol` | 10, 150-165, 193-197, 207, 209 |
| `packages/protocol/contracts/layer1/core/iface/IBondManager.sol` | 13-19, 66-90 |
| `packages/protocol/contracts/layer1/core/libs/LibBonds.sol` | 18, 25-27, 35-54, 76-89, 92-106, 130-141, 148-170, 203-205 |
| `packages/protocol/contracts/layer1/core/impl/Inbox.sol` | 84, 107-108, 160, 402-425, 601-607, 619, 637-638, 701-710, 723-743, 747-756, 768-779 |
| `packages/protocol/contracts/layer1/mainnet/MainnetInbox.sol` | 16-18, 37-52 |
| `packages/protocol/contracts/layer1/core/impl/ProverWhitelist.sol` | 18, 25-30, 45-48, 74-95, 98-107 |
| `packages/protocol/contracts/layer1/core/iface/IProverWhitelist.sol` | 12-15 |
| `packages/protocol/contracts/layer1/mainnet/LibL1Addrs.sol` | 7-77 (addresses in §1.6) |
| `packages/protocol/contracts/layer2/mainnet/BridgedTaikoToken.sol` | 29, 42-49 |
| `packages/protocol/contracts/layer2/core/BondManager_Layout.sol` | 21-22 (orphan) |
| `packages/protocol/contracts/shared/libs/LibNames.sol` | 14 |
| `packages/protocol/docs/tokenomics-whitepaper.tex` | 15, 23, 29, 39, 42, 45 |
| `packages/protocol/docs/tokenomics_objective_metrics.md` | 11, 13, 15, 17, 19, 21-25 |
| `packages/protocol/docs/Etna/pos-zk/01-requirements-and-threat-model.md` | 97, 107, 131, 148, 150-151, 213, 214, 263 |

# 6. External source register (all retrieved 2026-10-05)

| ID | Source | URL | Date of source |
|---|---|---|---|
| S1 | Ethereum consensus specs — phase0 `beacon-chain.md` (master) | https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/beacon-chain.md | retrieved 2026-10-05 |
| S2 | Ethereum consensus specs — bellatrix `beacon-chain.md` | https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/bellatrix/beacon-chain.md | retrieved 2026-10-05 |
| S3 | Ethereum consensus specs — electra `beacon-chain.md` | https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/electra/beacon-chain.md | retrieved 2026-10-05 |
| S4 | Ethereum consensus specs — `weak-subjectivity.md` | https://raw.githubusercontent.com/ethereum/consensus-specs/master/specs/phase0/weak-subjectivity.md | retrieved 2026-10-05 |
| S5 | EIP-7514, *Add Max Epoch Churn Limit* | https://eips.ethereum.org/EIPS/eip-7514 | retrieved 2026-10-05 |
| S6 | EIP-7002, *Execution layer triggerable withdrawals* | https://eips.ethereum.org/EIPS/eip-7002 | retrieved 2026-10-05 |
| S7 | Cosmos SDK `x/slashing/README.md` | https://raw.githubusercontent.com/cosmos/cosmos-sdk/main/x/slashing/README.md | retrieved 2026-10-05 |
| S8 | Cosmos SDK `x/staking/README.md` | https://raw.githubusercontent.com/cosmos/cosmos-sdk/main/x/staking/README.md | retrieved 2026-10-05 |
| S9 | Cosmos SDK `x/evidence/README.md` | https://raw.githubusercontent.com/cosmos/cosmos-sdk/main/x/evidence/README.md | retrieved 2026-10-05 |
| S10 | Polkadot Developer Docs — *Offenses and Slashes* | https://docs.polkadot.com/node-infrastructure/run-a-validator/staking-mechanics/offenses-and-slashes/ | retrieved 2026-10-05 |
| S11 | Vitalik Buterin, *Proof of Stake FAQ* | https://vitalik.eth.limo/general/2017/12/31/pos_faq.html | 2017-12-31 |
| S12 | arXiv:2401.05797 — *STAKESURE: Proof of Stake Mechanisms with Strong Cryptoeconomic Safety* | https://arxiv.org/abs/2401.05797 | 2024-01-11 |
| S13 | arXiv:2606.03587 — *Reserve Depletion and Security Runway in Proof-of-Stake Systems* | https://arxiv.org/abs/2606.03587 | 2026-06-02 |
| S14 | arXiv:2605.01025 — *Your Loss is My Gain: Low Stake Attacks on Liquid Staking Pools* | https://arxiv.org/abs/2605.01025 | 2026-05-01 |
| S15 | arXiv:2505.24440 — *The Cost of Secure Restaking vs. Proof-of-Stake* | https://arxiv.org/abs/2505.24440 | 2025-05-30 |
| S16 | arXiv:2404.00644 — *SoK: Liquid Staking Tokens (LSTs) and Emerging Trends in Restaking* | https://arxiv.org/abs/2404.00644 | 2024-03-31 |
| S17 | arXiv:2401.16353 — *Empirical and Theoretical Analysis of Liquid Staking Protocols* | https://arxiv.org/abs/2401.16353 | 2024-01-29 |
| S18 | arXiv:2401.08610 — *Leverage Staking with Liquid Staking Derivatives (LSDs)* | https://arxiv.org/abs/2401.08610 | 2023-11-28 |
| S19 | arXiv:2306.10777 — *Ethereum Proof-of-Stake Consensus Layer: Participation and Decentralization* | https://arxiv.org/abs/2306.10777 | 2023-06-19 |
| S20 | arXiv:2503.14385 — *Towards a Formal Framework of the Ethereum Staking Market* | https://arxiv.org/abs/2503.14385 | 2025-03-18 |
| S21 | Optimism specs — `exec-engine.md` (fee vaults, L1 data fee) | https://raw.githubusercontent.com/ethereum-optimism/specs/main/specs/protocol/exec-engine.md | retrieved 2026-10-05 |

**Sources consulted but NOT usable, recorded so the gap is visible:**

| Attempt | Outcome |
|---|---|
| Cosmos Hub live `unbonding_time` (21 days) | **UNVERIFIED** — genesis fetch 404'd; not asserted anywhere in this document. |
| Polkadot unbonding period (commonly 28 days) | **UNVERIFIED** — no primary source located in this pass. |
| `blog.ethereum.org/2016/05/09/on-settlement-finality` (Vitalik, cost-of-corruption origin) | Body truncated by the fetch; the JS-rendered page could not be read past the metadata. **Not quoted.** The bribe/pivotality argument is taken from S11 instead, which was read in full. |
| `docs.cosmos.network/main/build/modules/slashing` | 404 — superseded by the GitHub READMEs used as S7/S8. |
| TAIKO price, market cap, float, order-book depth | **UNVERIFIED** — not obtained from a primary source; see §3.5. |

---

# 7. Handoff summary

**Facts a Phase 3/4 author must not have to re-derive.**

1. TAIKO is fixed-supply at 1e9 with **no mint path** after `init`; staking rewards in TAIKO are therefore
   transfers or an explicit token upgrade (`TaikoToken.sol:41`, `tokenomics-whitepaper.tex:45`).
2. The repo already contains a **bond ledger** with deposit / request-withdrawal / delay / best-effort-slash
   semantics, currently configured to **zero bond and zero liveness bond** (`LibBonds.sol`, `MainnetInbox.sol:37-38`).
3. Provers are paid **nothing on L1** today; proving permission comes from a **whitelist**
   (`Inbox.sol:723-743`, `ProverWhitelist.sol:74-95`).
4. Two shapes are proven in production: **objective two-message evidence** (Ethereum, Cosmos) and
   **convex correlated penalties** (Ethereum `min(3f,1)`, Polkadot `min((3x/n)^2,1)`). The withdrawal delay
   must be derived from the settlement pipeline and evidence window, not from proving latency
   (`x/slashing/README.md`, "Staking Tombstone").
5. Both the reward budget and the attack cost are **functions of a price nobody controls**; the correct
   deliverables are a **fee-only threshold** and a **runway**, not a yield (arXiv:2606.03587, arXiv:2401.05797).
