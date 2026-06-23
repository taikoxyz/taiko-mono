# Security Audit — Taiko Alethia Protocol v3.0.0 (`packages/protocol/contracts`)

| | |
|---|---|
| **Auditor** | Claude (solidity-security-audit skill) |
| **Date** | 2026-06-23 |
| **Commit / version** | `6f05f9405` (`taiko-alethia-protocol-v3.0.0-7-g6f05f9405`) |
| **Framework** | Foundry |
| **Files in scope** | 143 `.sol` files, ~12,692 LoC |
| **Tools used** | Manual review (8 focused passes + synthesis); Solidity reasoning. Slither/Aderyn not installed in env. |

## 1. Executive summary

The in-scope code is the Taiko Alethia protocol — a Type-1 ZK-EVM **based rollup** plus a cross-domain **bridge / signal-service / token-vault** stack, deployed across L1, L2, and shared layers. The architecture is mature and defensively strong: every value-custody path I traced (bridge ETH accounting, vault mint/burn gated by an authenticated peer-vault context, cross-chain signal verification against proven checkpoints, the bond ledger, and the SGX proof-signature binding) holds its safety invariants, and every state-changing entry point carries the correct authorization on every path I checked. I found **no** way to double-release bridged value, replay a message across chains, forge a delivery/checkpoint, spoof a bridged-token mint, drain the bond ledger, or seize ownership via an initializer.

The issues that survived validation are concentrated in **liveness / censorship-resistance fallbacks that are configured and documented but never wired into the executing logic**, plus two defensive gaps in the preconfirmation subsystem.

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Low | 3 |
| **Total** | **5** |

The headline issues (M-01, M-02) share a root cause: the Inbox's automatic, trust-minimizing safety valves — permissionless proving after a delay, forced-inclusion consumption, and permissionless proposing when inclusions age out — are present as configured parameters (with on-chain validation and NatSpec promising the behavior) but are **not implemented in `prove`/`propose`**. The consequence is that the rollup's liveness and exit guarantees depend entirely on the whitelisted proposer/prover set plus manual owner intervention, and users can pay a non-refundable forced-inclusion fee into a feature that can never execute.

## 2. Scope

**In scope** — all first-party Solidity under `packages/protocol/contracts/`:
- `shared/` — `bridge/` (Bridge 645, QuotaManager 85, IBridge), `signal/` (SignalService 261, ICheckpointStore), `vault/` (ERC20Vault 426, ERC721Vault 233, ERC1155Vault 280, BaseVault, Bridged* tokens), `common/` (EssentialContract, EssentialResolverContract, DefaultResolver), `governance/`, `fork-router/`, `libs/` (LibTrieProof, LibAddress, LibBytes, LibMath…).
- `layer1/` — `core/` (Inbox 701, LibBonds, LibForcedInclusion, LibCodec/LibPackUnpack, ProverWhitelist), `verifiers/` (SgxVerifier, compose/*, Risc0/SP1, LibPublicInput), `automata-attestation/` (DCAP V3 quote parsing), `preconf/` (LookaheadStore 569, LookaheadSlasher, PreconfWhitelist, LibBLS12381, LibEIP4788, LibBeaconMerkleUtils), `mainnet/`/`hoodi`/`devnet` config wrappers.
- `layer2/` — `core/` (Anchor 196, AnchorForkRouter), `governance/` (DelegateController), `mainnet/`/`hoodi`.

**Out of scope**
- Dependencies under `node_modules/`/`lib/` (OpenZeppelin, Optimism `SecureMerkleTrie`/RLP, eth-fabric URC registry) — read for context only.
- **ZK circuit soundness** and the underlying proof-system precompiles (RISC0/SP1 verifier internals, the SGX **ES256** signature precompile, EIP-2537 BLS pairing internals, EIP-4788 oracle). The contract-layer wiring of these is in scope; their cryptographic correctness is specialist scope (noted where relevant).
- Off-chain components (node/derivation, relayer, prover infrastructure) and deployment/governance configuration beyond the values hardcoded in the in-scope `mainnet/` contracts.

**Commit:** `6f05f9405` · **Solidity:** `^0.8.24`/`^0.8.26` · **Target chains:** Ethereum L1 + Taiko L2.

## 3. Methodology

The codebase was modeled once (entry points, roles, asset flow, external surface, upgradeability) into a shared system model and a 27-item invariant list, then hunted in eight focused passes over a shared candidate ledger, followed by a synthesis pass for cross-cutting/chained issues. Validation and triage were global: each candidate was driven to a concrete {attacker, precondition, action, impact} exploit path or dropped, and the strongest leads were re-validated against the actual `MainnetInbox` configuration and the library internals. This report contains exploitable security / correctness findings only — style, gas, NatSpec, events, and test-coverage observations are intentionally excluded.

| Pass | Candidates | Promoted |
|---|---|---|
| 1 · Access control & entry points | 4 | 0 |
| 2 · Reentrancy & token integration | 6 | 0 |
| 3 · Accounting, value & invariants | 2 | 1 (→ M-02) |
| 4 · MEV / DoS / griefing / liveness | 5 | 2 (M-01, M-02) |
| 5 · Signatures / init / upgrade / storage | 8 (4 cleared) | 1 (L-01) |
| 6 · Cross-domain / L2 / Taiko | 5 | 0 net-new (overlap M-01/M-02) |
| 7 · Logic vs. specification | 4 | 2 (M-01, M-02) + 1 (L-03) |
| 8 · Low-level / assembly / attestation | 6 | 1 (L-02) |
| 9 · Synthesis & interactions | — | unified M-01/M-02 root cause |

**Coverage & honesty notes.** All 143 files were inventoried; the high-value contracts (Bridge, SignalService, all three vaults, Inbox, Anchor, LibBonds, LibForcedInclusion, QuotaManager, EssentialContract, SgxVerifier, LookaheadStore) were read in full. The following were reviewed at the contract-wiring level but their underlying cryptography requires a specialist and was **not** independently verified: the SGX DCAP quote parser → ES256 verification (the parse-then-verify binding was traced and is sound; forgery reduces to ES256 precompile correctness), BLS12-381 subgroup handling, and the beacon SSZ generalized-index proofs (see L-02). The Pacaya legacy implementations behind the fork routers were not audited (only the routing/selector/storage compatibility was checked, and it is correct).

## 4. Findings

### [M-01] Documented permissionless-proving fallback is never implemented; a whitelisted-prover outage halts finalization and freezes L2→L1 exits

| | |
|---|---|
| **Severity** | Medium |
| **Impact** | High (finalization + all L2→L1 bridge withdrawals frozen) |
| **Likelihood** | Low (requires the whitelisted prover set to stall/censor; owner can recover manually) |
| **Location** | `contracts/layer1/core/impl/Inbox.sol:99,165,535,756-764` (`_permissionlessProvingDelay`, `_checkProver`, `prove`); `contracts/layer1/core/libs/LibInboxSetup.sol` (`validateConfig`); `contracts/layer1/mainnet/MainnetInbox.sol:44` |
| **Status** | Open |

**Description**

`Inbox.prove` gates who may submit a proof solely through `_checkProver`:

```solidity
function _checkProver(address _addr) private view returns (bool whitelistEnabled_) {
    if (address(_proverWhitelist) == address(0)) return false;
    (bool isWhitelisted, uint256 proverCount) = _proverWhitelist.isProverWhitelisted(_addr);
    if (proverCount == 0) return false;
    require(isWhitelisted, ProverNotWhitelisted());   // <-- strict, with no time-based escape
    return true;
}
```

When a prover whitelist is configured and non-empty (`proverCount > 0` — the intended operating mode during the "whitelist phase"), only whitelisted addresses can ever call `prove`. The immutable `_permissionlessProvingDelay` is declared (`:99`), assigned (`:165`), surfaced by `getConfig` (`:535`), and `LibInboxSetup.validateConfig` even requires it to be `> provingWindow` — but it is **never read in any control-flow decision**. The `IInbox.Config` NatSpec describes it as *"The delay after which proving becomes permissionless when whitelist is enabled,"* and `MainnetInbox` sets it to `5 days` with the comment *"Allows the security council time to intervene if a bug is found."* That automatic transition does not exist in code.

Because finalization (`prove`) is the only writer of `lastFinalizedBlockHash` and the only caller of `SignalService.saveCheckpoint`, and the L1 bridge accepts L2→L1 withdrawals only against a checkpoint stateRoot, a prover stall **freezes all L2→L1 exits**, not just proving. Compounding the exposure, during the whitelist phase `_processLivenessBond` is skipped entirely (`Inbox.sol:353`, `if (!isWhitelistEnabled)`) and `MainnetInbox` sets `livenessBond = minBond = 0`, so there is no economic liveness incentive on the whitelisted provers either.

**Exploit scenario**

1. Owner whitelists ≥1 prover (`proverCount > 0`) — the documented whitelist-phase configuration.
2. The whitelisted prover(s) go offline, lose keys, or censor a specific proposal (no bond is at stake).
3. More than `permissionlessProvingDelay` (5 days) elapses. A non-whitelisted honest prover with a valid proof calls `prove` → `_checkProver` reverts `ProverNotWhitelisted()`. The documented "permissionless after the delay" path does not engage.
4. Finalization stays stuck; no new checkpoint is saved; every user's L2→L1 bridge withdrawal that depends on a post-stall state root cannot be proven on L1. Funds are inaccessible until the owner manually removes provers (driving `proverCount → 0`, which makes `_checkProver` return `false`).

**Proof of concept** *(sketch — statically verifiable against the cited code)*

```solidity
function test_permissionlessProvingDelay_isInert() public {
    // proverWhitelist has 1 prover; prover never proves.
    vm.warp(block.timestamp + inbox.getConfig().permissionlessProvingDelay + 1);
    // An honest, non-whitelisted prover with a valid proof still cannot prove:
    vm.prank(nonWhitelistedProver);
    vm.expectRevert(Inbox.ProverNotWhitelisted.selector);
    inbox.prove(validData, validProof);          // delay elapsed, yet still gated
}
```

**Recommendation**

Wire `_permissionlessProvingDelay` into the prover gate so the documented fallback actually engages, e.g. bypass the whitelist once the oldest unfinalized proposal has aged past the delay:

```solidity
// in prove(), after computing proposalAge / the first unfinalized timestamp:
bool pastPermissionlessDelay =
    block.timestamp > _coreState.lastFinalizedTimestamp + _permissionlessProvingDelay;

bool isWhitelistEnabled = pastPermissionlessDelay ? false : _checkProver(msg.sender);
```

Alternatively, if keeping proving permanently whitelist-gated is the intended design, remove `_permissionlessProvingDelay` (and its `validateConfig` check and NatSpec) so the contract does not advertise a liveness guarantee it does not provide, and document the manual owner-recovery path as the sole fallback in the trust model.

---

### [M-02] `saveForcedInclusion` charges a non-refundable fee for a forced-inclusion path that can never execute; the censorship/exit escape hatch is inert

| | |
|---|---|
| **Severity** | Medium |
| **Impact** | Medium (user fees locked with no recovery; documented censorship-resistance feature non-functional) |
| **Likelihood** | Medium (function is live, payable, permissionless, and documented as working) |
| **Location** | `contracts/layer1/core/impl/Inbox.sol:427-439` (`saveForcedInclusion`), `:749` (`require(_input.numForcedInclusions == 0)`), `:633-705` (consume path), `:53` (`permissionlessInclusionMultiplier`); `contracts/layer1/core/libs/LibForcedInclusion.sol:42-72`; `contracts/layer1/mainnet/MainnetInbox.sol:50` |
| **Status** | Open |

**Description**

Forced inclusions are the based-rollup's censorship-resistance / exit guarantee: a user pays a fee so their transaction is guaranteed to be included even if every proposer censors them. The on-chain entry point is live and charges a real fee:

```solidity
// LibForcedInclusion.saveForcedInclusion
uint256 requiredFee = requiredFeeInGwei * 1 gwei;        // MainnetInbox base = 0.001 ETH, scaling up with queue depth
require(msg.value >= requiredFee, InsufficientFee());
$.queue[$.tail++] = inclusion;                            // fee retained in the Inbox
refund_ = msg.value - requiredFee;                        // only the *excess* is refunded
```

`Inbox.saveForcedInclusion` is `external payable` with no access control and no `whenNotPaused`; it is reachable by anyone once the first post-genesis proposal exists. However, the **consumption** side is hard-disabled: `_validateProposeInput` requires `numForcedInclusions == 0` (`:749`), so `_consumeForcedInclusions` always computes `toProcess == 0`, the queue `head` never advances, and the only fee-payout path (`_dequeueAndProcessForcedInclusions`, `:694`) is unreachable. There is **no cancel, no refund, and no owner sweep** for a queued inclusion, and the Inbox has no `receive()`/recovery for these funds.

The documented secondary backstop — *"the multiplier to determine when a forced inclusion is too old so that proposing becomes permissionless"* (`permissionlessInclusionMultiplier`, set to `160` ≈ 25.6h on mainnet) — is, like M-01's delay, declared, validated (`> 1`), and surfaced by `getConfig`, but **never consulted**: `propose` always enforces `_proposerChecker.checkProposer` (`Inbox.sol:599`, comment: *"Permissionless proposing is temporarily disabled"*).

Net effect today: a user who calls `saveForcedInclusion` (e.g. precisely because they are being censored — the scenario the feature exists for) pays ≥0.001 ETH, receives neither inclusion nor refund, and the funds are recoverable only via a UUPS upgrade. Even a future upgrade that re-enables consumption would pay the accrued fee to whatever *proposer* eventually drains the queue, never back to the original payer.

**Exploit scenario**

1. The chain is live (proposal #1 exists), so `Inbox.saveForcedInclusion` is callable.
2. A user (or an integrator/UI that surfaces the documented forced-inclusion feature) calls `saveForcedInclusion{value: 0.001 ether}(blobRef)` expecting a guaranteed inclusion.
3. The fee is stored in the queue; only excess over the required fee is refunded.
4. No proposer can ever consume it (`numForcedInclusions == 0` enforced), no refund/cancel exists, and `permissionlessInclusionMultiplier` never opens proposing. The user's funds are stuck and their transaction is never force-included.

**Proof of concept** *(sketch)*

```solidity
function test_forcedInclusionFee_isLockedAndInert() public {
    uint256 fee = inbox.getCurrentForcedInclusionFee();      // 0.001 ETH on mainnet config
    uint256 balBefore = address(user).balance;
    vm.prank(user);
    inbox.saveForcedInclusion{value: fee}(blobRef);          // fee accepted, queued
    assertEq(address(inbox).balance, fee);                   // ETH now sits in the Inbox

    // Consumption is impossible: propose rejects any forced inclusions.
    ProposeInput memory in_ = _input(); in_.numForcedInclusions = 1;
    vm.expectRevert();                                       // require(numForcedInclusions == 0)
    inbox.propose(lookahead, abi.encode(in_));

    // No refund/cancel/sweep function exists -> user cannot recover `fee`.
    assertEq(address(user).balance, balBefore - fee);
}
```

**Recommendation**

Pick one of two coherent states rather than the current "charge-but-don't-serve":

- **If forced inclusions are intentionally off:** make `saveForcedInclusion` revert (or be non-payable / paused) while disabled, so users cannot pay into a dead queue; and clearly mark the censorship-resistance escape hatch as inactive in the published trust model.
- **If they are meant to be available:** re-enable consumption (`propose` accepting `numForcedInclusions > 0`) and implement the `permissionlessInclusionMultiplier` permissionless-proposing fallback so the guarantee actually holds; until then, add a user-callable refund/cancel for un-consumed queue entries.

In all cases, add `nonReentrant` and `whenNotPaused` to `saveForcedInclusion` (it is currently the only Inbox mutator lacking both; it refunds excess ETH via a full-gas `sendEtherAndVerify` after a state write).

---

### [L-01] Lookahead poster's commitment signature omits chain ID, contract address, and a nonce/epoch — conditional cross-deployment replay

| | |
|---|---|
| **Severity** | Low |
| **Impact** | Low (unauthorized lookahead posting → preconfer mis-scheduling; bonded/slashable) |
| **Likelihood** | Low (requires identical `lookaheadSlasher` address and an opted-in committer across the two contexts) |
| **Location** | `contracts/layer1/preconf/impl/LookaheadStore.sol:553,637-645` |
| **Status** | Open |

**Description**

A lookahead poster authorizes a schedule by signing a commitment whose digest binds only the commitment type, the lookahead payload, and the slasher address:

```solidity
// _buildLookaheadCommitment
ISlasher.Commitment({ commitmentType: 0, payload: abi.encode(_lookahead), slasher: lookaheadSlasher });
// _validateLookaheadPoster
address committer = ECDSA.recover(keccak256(abi.encode(_commitment)), _commitmentSignature);
require(committer == slasherCommitment.committer, CommitmentSignerMismatch());
```

The signed preimage does **not** include `block.chainid`, `address(this)` (the LookaheadStore), the target epoch, or a nonce. Same-chain cross-epoch replay is prevented because the `LookaheadSlot` timestamps are absolute and must fall in the target next epoch, but the only domain separation against another chain or another LookaheadStore deployment is the `lookaheadSlasher` address. If two deployments share a `lookaheadSlasher` address (e.g. deterministic/CREATE2 deployment across chains or a testnet/mainnet pair) and the same committer is opted into that slasher in both, a signature captured in one context can be replayed to post an unauthorized lookahead in the other.

**Exploit scenario**

1. A committer signs a lookahead commitment for deployment A (whose `lookaheadSlasher` address equals deployment B's).
2. The committer is also a registered, opted-in operator on deployment B.
3. An observer replays `(commitment, signature)` to `LookaheadStore.updateLookahead` on B for an epoch whose slot timestamps are valid, posting a schedule the operator never authorized for B — biasing preconfer assignment (liveness/MEV griefing), correctable only after the fact via the slasher.

**Recommendation**

Bind the signed payload to its domain. Use EIP-712 with a domain separator over `{name, version, chainId, verifyingContract}` and include the target epoch timestamp (and ideally a nonce) in the struct:

```solidity
bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
    LOOKAHEAD_COMMIT_TYPEHASH, block.chainid, address(this), _nextEpochTimestamp,
    keccak256(abi.encode(_lookahead)), lookaheadSlasher
)));
```

---

### [L-02] Beacon-state Merkle proof verification does not bound `leafIndex` against proof depth (generalized-index confusion)

| | |
|---|---|
| **Severity** | Low |
| **Impact** | Low–Medium if exploitable (forge/evade slashing evidence); requires SSZ-specialist confirmation |
| **Likelihood** | Low |
| **Location** | `contracts/layer1/preconf/libs/LibBeaconMerkleUtils.sol:44-70` (consumed by `LibEIP4788`/`LookaheadSlasher`) |
| **Status** | Open |

**Description**

The beacon Merkle verifier walks the proof using the low bits of `leafIndex` but never checks that the proof length matches the expected tree depth, nor that `leafIndex < 2**proof.length`:

```solidity
function verifyProof(bytes32[] memory proof, bytes32 root, bytes32 leaf, uint256 leafIndex) ... {
    bytes32 h = leaf;
    uint256 index = leafIndex;
    for (uint256 i = 0; i < proof.length; i++) {
        h = index % 2 == 0 ? sha256(bytes.concat(h, proof[i])) : sha256(bytes.concat(proof[i], h));
        index = index / 2;          // high bits of leafIndex beyond proof.length are silently ignored
    }
    return h == root;
}
```

Because the caller supplies both `proof` (attacker-influenced length) and, for validator/lookahead leaves, an index derived from caller-controlled values (`validatorIndex` / `proposerLookaheadIndex`), the absence of a depth/range bound is the classic generalized-index-confusion pattern: distinct `leafIndex` values that agree in their low `proof.length` bits verify identically, so a leaf can be "proven" at a position it does not occupy. Whether a *useful* forgery results depends on the exact SSZ container depths and the fixed generalized indices used in `LibEIP4788.verifyValidator` — which require a beacon-SSZ specialist to settle. The final `h == root` check against the real EIP-4788 beacon root constrains arbitrary forgery, so I rate this Low and flag it as a defensive gap rather than a proven exploit. The impact surface is the preconfirmation **slashing** path (forging evidence to slash an honest operator, or shaping an index to evade a valid slash), not user fund custody.

**Recommendation**

Constrain proof length and index to the fixed depth for each proven field:

```solidity
require(leafIndex < (1 << proof.length), InvalidGeneralizedIndex());
// and assert proof.length == EXPECTED_DEPTH for each fixed gindex (e.g. validatorsRoot, beaconState).
```

Commission a beacon-SSZ specialist review of `LibBeaconMerkleUtils` + `LibEIP4788` generalized-index handling for the slashing evidence flow.

---

### [L-03] `validateConfig` does not enforce `withdrawalDelay ≥ provingWindow + maxProofSubmissionDelay`, allowing a future bond config that lets a proposer escape a liveness slash

| | |
|---|---|
| **Severity** | Low |
| **Impact** | Medium if bonds are enabled with a bad config (owed liveness slash evaded) |
| **Likelihood** | Low (latent: `minBond = livenessBond = 0` on current mainnet, so the bond system is dormant) |
| **Location** | `contracts/layer1/core/libs/LibBonds.sol:58-89` (`withdraw`), `:148-170` (`settleLivenessBond`); `contracts/layer1/core/libs/LibInboxSetup.sol` (`validateConfig`) |
| **Status** | Open |

**Description**

`LibBonds.withdraw` waives the `minBond` floor once a withdrawal request has matured (`block.timestamp ≥ withdrawalRequestedAt + withdrawalDelay`), letting an account drain its full balance to zero. `settleLivenessBond` is explicitly best-effort: against a zero balance, `_debitBond` returns `0` and the slash is a silent no-op. `validateConfig` enforces `permissionlessProvingDelay > provingWindow` but imposes **no** relationship between `withdrawalDelay` and the liveness-slash deadline (`provingWindow + maxProofSubmissionDelay`). If bonds are ever enabled (the system is clearly built for it) with `withdrawalDelay` shorter than that deadline, a proposer can: propose (passing `hasSufficientBond`), `requestWithdrawal`, wait `withdrawalDelay`, `withdraw` the entire bond, and then — when their proposal is proven late — face a `settleLivenessBond` that debits an empty balance and slashes nothing.

This is **not exploitable on the current mainnet configuration** (bonds are dormant, and `withdrawalDelay = 1 week` ≫ `provingWindow 4h + maxProofSubmissionDelay 3m`). It is reported as a latent invariant/config-validation gap to fix before the bond mechanism is activated.

**Recommendation**

Add the ordering invariant to `validateConfig` so a future bond activation cannot silently break liveness slashing:

```solidity
require(config.withdrawalDelay >= config.provingWindow + config.maxProofSubmissionDelay, InvalidConfig());
```

## 5. Trust model & assumptions

These are by-design powers and operating assumptions, documented for the reader. They are **not** findings (except where they intersect M-01/M-02 above).

- **Per-contract `owner`** (Ownable2Step behind a UUPS proxy): can upgrade implementations (`_authorizeUpgrade = onlyOwner`, **no in-contract timelock** — any upgrade delay/exit-window is enforced by the external governance layer, `MainnetDAOController`), register resolver addresses, set quotas, manage the prover whitelist, run `changeBridgedToken` (90-day migration delay), and perform Inbox `activate`/`init2`/`init3` and Anchor `withdraw`. Upgrade authority can swap in arbitrary logic; users rely on governance to time-lock it. This is the dominant trust assumption.
- **"Training wheels" liveness posture (current mainnet):** the prover whitelist is active, `minBond = livenessBond = 0` (bonds dormant, no liveness slashing while whitelisted), forced-inclusion consumption is disabled, and permissionless proposing is disabled. Consequently the rollup's liveness, censorship-resistance, and exit guarantees currently depend on the honesty and uptime of the whitelisted proposer/prover set plus manual owner recovery. The protocol's own configured *automatic* fallbacks for this (`permissionlessProvingDelay`, `permissionlessInclusionMultiplier`, forced inclusion) are inert — see **M-01/M-02**.
- **`pauser`** (immutable on Bridge & SignalService): may pause/unpause alongside the owner; the Bridge `pauser` may also fund the bridge via plain Ether `receive()`.
- **`GOLDEN_TOUCH_ADDRESS`** (L2): the sole caller of `Anchor.anchorV4`; its checkpoint/ancestor inputs are validated by L2 consensus/derivation off-chain.
- **`_authorizedSyncer`** (Inbox on L1 / Anchor on L2): the sole writer of `SignalService.saveCheckpoint`. A checkpoint for a given block number can be overwritten by the syncer; this is safe under the trust model because the syncer is trusted and the proof system makes two distinct state roots for one finalized block number unreachable.
- **`QuotaManager` circuit breaker** (intentional): rate-limits ETH/token outflow from the Bridge/ERC20Vault per period. When the per-period quota is exhausted, **all** ETH-releasing operations revert until it regenerates — including `recallMessage` (reclaiming ETH from a message that failed on the destination). This temporarily blocks fund-recovery, by design; it is period-bounded and self-resolving, and consuming quota requires moving real ETH, so it is not a cheap griefing vector. Operators should size `quota`/`quotaPeriod` with this in mind.
- **SGX instance registration is permissionless** on mainnet (`registrar = address(0)`). Security therefore rests on the DCAP quote verification: the parse-then-verify binding (PCK → QE report → attestation key → local enclave report, anchored to the Intel root via `ROOTCA_PUBKEY_HASH`, with DEBUG/PROVISION attributes rejected) was traced and is **sound at the contract layer**; forgery reduces to the correctness of the `ES256` signature-verification precompile, which is specialist scope.
- **Resolver:** mainnet wires security-critical names (`bridge`, `signal_service`, vaults) through a hardcoded/pure `SharedResolver`, not the owner-writable `DefaultResolver`, so cross-domain delivery authentication is effectively pinned. Deployments using a writable resolver for these names would widen the cross-domain trust surface.
- **ZK circuit soundness is out of scope** and assumed correct; a forged validity proof would bypass the contract-layer finalization checks entirely.

## 6. Appendix

**Invariants identified and stress-tested (held under the stated trust model):**

- Bridge: a message is consumed at most once (`messageStatus` lifecycle, all mutators `nonReentrant`); ETH out = value + fee with no double-pay or over-refund; release requires a verified cross-chain signal proof; `Context` is set/reset around every invocation and `context()` rejects the PLACEHOLDER; cross-chain replay blocked (msgHash binds src/dest chain IDs; signal slot binds chainId + remote bridge); `signalForFailedMessage = msgHash ^ 3` has no realistic collision; ETH quota debit matches ETH leaving.
- Vaults: mint/release gated by `checkProcessMessageContext` (caller = Bridge **and** `ctx.from` = this vault's address on the source chain); bridged mint/burn restricted to the owning vault; canonical balance-delta accounting; no mint-without-lock.
- SignalService: storage proof verified against the immutable `_remoteSignalService` at the proven checkpoint's `stateRoot`; `saveCheckpoint` restricted to the authorized syncer.
- Inbox: finalization is sequential and parent-block-hash-linked; `prove` finalizes state + saves the checkpoint **before** `verifyProof`, but a failed proof reverts the whole transaction (no partial finalization); ring-buffer capacity check prevents overwriting unfinalized proposals; bond ledger conserves (gwei↔token scaling, best-effort debit, 50/50 liveness split with the odd wei burned, `uint64` overflow reverts).
- Anchor: `anchorV4` restricted to `GOLDEN_TOUCH_ADDRESS`; ancestorsHash continuity enforced; checkpoint block number monotonic.
- Init/upgrade: all initializers single-shot; implementations constructor-disabled (`_disableInitializers`); every `_authorizeUpgrade` is `onlyOwner`; fork-router ↔ implementation storage layouts and selectors are non-colliding.

*No informational, gas-optimization, or code-style section is included; this report covers exploitable security issues only.*
