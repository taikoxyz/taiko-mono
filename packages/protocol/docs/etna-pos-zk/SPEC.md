# Etna PoS + ZK Design Spec

> **In one sentence**: In Etna, a committee of TAIKO stakers produces blocks with stock CometBFT and finalizes them instantly; anyone can land a proven batch on L1, and funds on L1 recognize only landed checkpoints.
>
> **Scope**: To keep the spec small and easy to discuss, it deliberately leaves out the switch from Unzen to Etna for now; that will be added later (section 12, item 9).
>
> **Target**: Stage 0; Stage 1 is not a goal for now.

## 1. Positioning and security model

- **Positioning**: a PoS-sequenced validity rollup, not a based rollup. L2 PoS decides transaction order; Ethereum does not sequence, it only provides DA (blobs), proof verification, settlement and the bridge's anchor.
- **Funds**: L1 recognizes only landed checkpoints, and every landing needs two proofs, at least one of them ZK (6.2). Even the whole committee acting maliciously cannot take funds on L1.
- **Finality**: while Byzantine voting power stays below 1/3, a CometBFT commit is final and consensus never rolls back a committed block; the only exception is governance recovery, which discards blocks above the latest checkpoint (section 8). Nothing at or below a checkpoint can be rolled back except by a DAO upgrade after verifier failure (section 8), so exchanges and bridges should rely on checkpoints.
- **Liveness**: needs more than 2/3 of the voting power online, L1 finalizing, and landings continuing (6.4).
- **Censorship resistance**: forced inclusion is enforced by the proof: a due queue-head entry can only be included or legally skipped, otherwise the block is invalid. Entries cannot be deleted merely because they are old; the only exception is that governance recovery (section 8) can explicitly blank specified entries. Progress depends on consensus, L1 finality, queue service and settlement; this does not provide a wall-clock inclusion deadline (sections 7 and 3.4).
- **Upgrades and trust**: `EtnaInbox`, the registry and the L1 `SignalService` are upgradeable proxies whose owner should be the DAO (behind a timelock); an upgrade can bypass any rule in this spec. Verifier soundness, including the management of SGX instances and RISC0/SP1 images, is a separate assumption. Proof completeness is another: every block that is valid under this spec and within the EL limits (gas, zk gas) and the 3.4 block size bound must be provable by at least one valid proof combination, and any grid segment of K such consecutive blocks (6.1) must be provable together within one landing's two proofs, counting in the worst case one 7.2 single-transaction build trial per block (which can use up to another full block's zk budget). A mismatch between the EL and the guests, or a guest resource limit below the EL limits, violates it; such a transaction forced in through forced inclusion is handled by step 3 of governance recovery (section 8). `land`, `saveForcedInclusion` and the registry are not affected by pause; if both proof systems fail at once, losses can only be contained by pausing `SignalService` and the Bridge and by QuotaManager limits, and settlement is rolled back with the Inbox upgrade that replaces the verifier (section 8).
- **Out of scope**: PoS issuance rewards and bootstrapping CometBFT from L1 alone.
- **Slashing scope**: same-round double signing forfeits all remaining principal (4.1). Going offline or withholding signatures is not automatically slashed; the DAO may attribute responsibility and apply a one-time fixed-rate forfeiture with forced exit under 4.4. A recovery exclusion itself only forces exit (section 8 step 2).
- **DAO forfeiture authority**: the DAO may forfeit during normal operation or recovery, including immediate execution through its emergency path. The registry adds no waiting, freeze or appeal period and does not distinguish governance paths. It checks authority, entry identity, amount and authorization expiry, not the correctness of attribution. Section 1's upgrade trust remains.
- **Not yet designed**: the switch from Unzen to Etna, which will be added later (section 12 item 9).

## 2. Components

| Component                  | Role                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Validator                  | Stakes TAIKO in the registry and registers a secp256k1eth consensus key (with a key-holder signature); runs stock CometBFT, the ABCI application, alethia-reth and its own L1 node, plus the external FilePV signer behind the checkpoint-trust gate. The registered signing key and anti-double-sign state stay outside the Comet home/mount; signatures require the app's checkpoint-trust authorization. Proposers earn all fees in their blocks (base fees and tips). |
| Full node                  | Runs CometBFT, the ABCI application and alethia-reth with its own L1 view, independently validates every block and applies the same checkpoint-trust gate. It has no registered signing key; an unregistered local identity cannot participate in validator voting.                                                                                                                                                                                                       |
| Lander                     | Permissionless: reads decided blocks/commits, builds batches, obtains two proofs and calls land in a blob transaction; earns no protocol reward (appendix C)                                                                                                                                                                                                                                                                                                              |
| Prover                     | Produces two proofs per batch (6.2)                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| EtnaInbox (L1)             | Genesis parameters, land, checkpoints, FI queue/protocol fees and atomic governance recovery                                                                                                                                                                                                                                                                                                                                                                              |
| `EtnaStakingRegistry` (L1) | Stake and delayed top-ups, exits, withdrawals, double-sign slashing, DAO responsibility forfeiture and exclusion-list forced exits; one checkpoint for every L1 block that changes an entry                                                                                                                                                                                                                                                                               |
| `SignalService` (L1)       | Stores the checkpoints the Inbox writes (height, hash, stateRoot) so the bridge can verify L2→L1 messages                                                                                                                                                                                                                                                                                                                                                                 |

## 3. Consensus and blocks

### 3.1 Consensus engine

- Stock CometBFT v0.40.0 in its own process, driving the application over an ABCI++ socket. Proposer selection, timeouts, locking and BlockID all use stock behavior; the engine is not forked.

<details>
<summary>Details: secp256k1eth signing format and chain_id construction</summary>

- Consensus keys use CometBFT v0.40.0's `secp256k1eth`: sign bytes are hashed with keccak256 (no prefix) and signed; the signature is 65 bytes `R‖S‖V` (`V ∈ {0, 1}`, low-s required); the public key is a 33-byte compressed SEC1 key; and the validator address is the Ethereum address `keccak256(uncompressed key without its first byte)[12:]`. L1 can therefore verify any vote directly with `ecrecover` (double-sign slashing in 4.1). CometBFT does not batch-verify these keys. Every ordinary and recovery-initial committee uses voting power = ⌊effStake / `vp_unit`⌋ under 4.3, and the total is at most CometBFT's cap `(2^63 − 1) / 8`.
- `chain_id = "etna-" + base64url_no_padding(chainDomain)` is exactly 48 ASCII bytes. `chainDomain` is the full 256-bit keccak256 digest binding the version, complete L1/L2 chain ids, Inbox proxy address and generation (appendix A), without truncation. Nodes, signers, guests and the registry recompute the same value. Old-generation votes cannot authorize a new generation; another deployment's votes cannot authorize a commit or slashing here. Signing the same height in different domains is not a double sign. Stock CometBFT VoteSignBytes and vote encoding remain unchanged.

</details>

- The mempool is `nop`: user transactions travel over EL devp2p, and the proposer's EL picks them from its own txpool.
- CometBFT height equals the EL block number; consensus starts at the block after Etna's starting point (written as block 0 for now). Each CometBFT block's `Data.Txs` holds exactly one item: the envelope (5.1).

<details>
<summary>Details: ABCI response constraints</summary>

- ABCI responses: `app_hash` is the hash of the executed EL block (InitChain returns the genesis hash for the initial deployment and ELHash(c) for governance recovery under 8.4); every transaction result (ExecTxResult) is fixed at code 0, empty data, and gas_wanted and gas_used of 0, all four of which enter LastResultsHash; at height 0 Info returns the app version in this generation's genesis consensus params; the header's app version is constant within a generation, and the rules version that applies at each height comes from the upgrade schedule, not from Info; consensus params are never updated. This specification uses `APP_VERSION` 1 (encoding versions in appendix A); checkpoint-trust metadata is node-local and does not enter `app_hash` or block bytes.

</details>

- The block interval is set by `timeout_commit`, an operating parameter rather than a validity rule (target about 4 s, assuming n ≲ 128).
- CometBFT evidence enters blocks as usual, but the application does not punish based on it: double-sign slashing happens only on L1 (`slashDoubleSign` in 4.1), and anyone can submit two conflicting votes seen in gossip to the registry.

<details>
<summary>Details: driving the EL, zk-gas metering and execution fees</summary>

- The EL is a pinned alethia-reth version with Etna support: no anchor transaction, building from a given transaction list, the base-fee sharing percentage read from `extraData[0]`, and zk gas recorded in `difficulty`. EIP-4396 parameters are published with that pinned EL version. The application drives it with `engine_forkchoiceUpdatedV3`, `engine_getPayloadV5` and `engine_newPayloadV4`.
- **zk gas**: adopt the [ZK Gas spec](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/docs/zk_gas_spec.md) ([pinned revision](https://github.com/taikoxyz/taiko-mono/blob/ce31a49063b83845691dd22f536f5433b7824b35/packages/protocol/docs/zk_gas_spec.md)) for metering, transaction intrinsic cost, opcode/precompile multipliers, CALL/CREATE spawn estimates, uint64 overflow handling and whole-transaction discard on overflow/limit exceedance. Its rule that the remaining transactions are skipped after a limit exceedance or overflow is not a consensus rule here: how building continues is under “Execution and fees” below, and validation of committed blocks is 3.4 rule 9. Its `BLOCK_ZK_GAS_LIMIT` corresponds to this spec’s `L2_BLOCK_ZK_GAS_LIMIT`, a block budget independent of EVM gas. Publish the enabled revision, parameters and shared vectors with the pinned EL/guest versions; later main-branch changes do not automatically change consensus. The document’s 100M is a placeholder: pin the deployment value under section 11 and pass the acceptance in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md).
- **Execution and fees**: while building a candidate transaction list, a transaction exceeding the zk budget or overflowing metering arithmetic is fully discarded under the shared rules, restoring the state at that transaction’s start. Rollback includes nonce, authorizations, value transfers, logs, receipts and fees; discarded and unselected transactions are absent from the final block and pay nothing. Whether building then tries further candidates is proposer build policy, not a consensus rule; the recommended policy skips that transaction and its sender’s later nonces, keeps selecting other transactions, and bounds the total work spent on overflowing trials, first-time and repeated. This policy applies only to pool candidates; an FI transaction the proposer places at position 0 is executed against the actual pre-block state and is never skipped because of remembered overflows. The given-list singleton build (7.2) has only `[tx]` as a candidate, so its result does not depend on this. Validation or import never discards a transaction listed in a committed block: if any listed transaction exceeds the zk limit or overflows, the whole block is invalid (3.4 rule 9). The 7.2 skip check still runs the singleton build above, which may discard `tx`. An ordinary EVM revert/OOG remains an included transaction when it fits the zk budget and is charged normally. Use ordinary EVM gas, refunds, base fees and tips without converting zk gas into charged gas. Block gasUsed is the sum of included transactions’ EVM gasUsed, and EIP-4396 uses that value. `eth_call`/`eth_estimateGas` use the same rules version with the full block zk budget for standalone simulation; report explicit zk-limit errors rather than a successful empty result after discarding the call.

</details>

### 3.2 Block header

Every field except `beneficiary` is determined by the committed parent (and its parent's timestamp), the block's anchor, BFT time and chain constants. The proposer builds with these values; other nodes recompute them and compare field by field.

| Field                   | Value                                                                                                                                                                                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `number` / `parentHash` | height / hash of the committed parent                                                                                                                                                                                                                               |
| `timestamp`             | max(parent.timestamp + 1, ⌊BFT time⌋, anchor.timestamp)                                                                                                                                                                                                             |
| `beneficiary`           | any fee recipient the proposer chooses, as in Ethereum; not checked. All of the block's base fees and tips are paid to it at L2 execution, independent of L1 settlement, so a proposer's own transactions in its blocks pay no net fee                              |
| `extraData`             | 13 bytes `[100 \| generation (uint48) \| anchor block number (uint48)]`; the first byte is the base-fee sharing percentage and is always 100, so all base fees go to the beneficiary                                                                                |
| `parentBeaconBlockRoot` | the anchor's L1 stateRoot. The EL writes it into the EIP-4788 contract (keyed by the L2 block timestamp), and L2 contracts verify L1 storage proofs against it                                                                                                      |
| `gasLimit`              | chain constant `L2_BLOCK_GAS_LIMIT`                                                                                                                                                                                                                                 |
| `baseFeePerGas`         | fixed at 0.025 gwei for block 1; afterwards adjusted by EIP-4396 from the parent's gas usage and block interval (parent minus grandparent timestamp), clamped between the chain's minimum base fee (0.01 gwei for chain id 167000, 0.005 gwei otherwise) and 1 gwei |
| `mixHash`               | computed from parent.difficulty and height with the Unzen formula                                                                                                                                                                                                   |
| Other                   | empty withdrawals, zero blob gas, empty requests, empty ommers, zero nonce                                                                                                                                                                                          |

stateRoot, receipts, gasUsed (the sum of included transactions’ EVM gasUsed) and the zk gas in `difficulty` are checked by the EL's `newPayload`. `difficulty` accumulates only included transactions’ zk gas, including ordinary EVM revert/OOG transactions, not discarded over-limit trials or unselected transactions. Block-start system processing still follows 3.2 and is not rolled back with an aborted transaction.

### 3.3 Anchor

- Every block has an anchor: the L1 block whose state it reads. A block either carries an anchor witness (the raw L1 header plus the Inbox account and storage proofs) or inherits its parent's anchor. The first block of each generation and any block that moves the anchor must carry one; a block that keeps the anchor must not. The witness proves the Inbox's `recoveryGeneration`, `lastCheckpoint` (height, hash) and the forced inclusion queue's head and tail.
- The proposer picks max(parent's anchor, local L1 `finalized`). A retained proposal keeps its original anchor. In ProcessProposal, a validator checks with its own L1 node that the anchor header is canonical and finalized, and checks its age against the candidate block's timestamp (3.4); advancing the local finalized head alone cannot make that proposal expire.

<details>
<summary>Details: decoding L1 headers</summary>

- **Decoding L1 headers**: `rawL1Header` must be an RLP list of at most 4,096 bytes with at least 12 items. Nodes and guests read only four fields, by position: 0 `parentHash` and 3 `stateRoot` (32 bytes each), and 8 `number` and 11 `timestamp` (integers of at most 8 bytes without leading zeros). Every other item need only be a well-formed RLP item and is not interpreted, so fields an L1 fork appends at the end (for example Glamsterdam's EIP-7928 `block_access_list_hash`) are accepted without an upgrade. A header's identity is always keccak256(rawL1Header) over the raw bytes; it is never decoded and re-encoded. A node fetches the canonical hash for the anchor block number in `extraData` from its own L1 node and compares it with keccak256(rawL1Header): if they differ, the witness is invalid; if they match but the header cannot be parsed under this rule, L1 has changed the header format and the node needs an upgrade, which is a liveness pause (section 8), not a safety halt. When a node reads any other header from its own L1 node (trust checks, cold sync), it likewise relies only on these four fields and ignores unknown ones.

</details>

### 3.4 Block validity

ProcessProposal and FinalizeBlock apply the same deterministic rules, in order:

1. height = parent + 1, and `parentHash` links to the parent.
2. The presence or absence of an anchor witness follows 3.3, and the witness verifies.
3. The anchor does not regress: it is at least the parent's anchor and the current generation's L1 origin, the l1BlockNumber of its fixed origin record (8.4): `L1_0` for generation 0 and R after a governance recovery.
4. Generation: recompute `chain_id` per appendix A from `extraData`'s uint48 generation and this deployment's parameters; it must exactly match the current chain and CometBFT header. Do not parse a generation from the digest string. If the Inbox's generation is larger, this chain has been superseded (section 8); if it is smaller, reject the block.
5. Back-pressure: height − the `lastCheckpoint.height` proven by the anchor ≤ U, so at most U blocks are unsettled. U is the unsettled-block limit committed directly in the config hash; see 6.4 for its constraints.
6. Committee witness: required at switch block S(t), forbidden elsewhere; its registry proofs are verified under the stateRoot of S(t)'s own anchor (4.3). Recovery establishes its authenticated starting committee under section 8 without re-emitting an old pending update. If the first recovered block is S(t), normal switch derivation still applies.
7. The header matches 3.2 field by field; anchor freshness: timestamp − anchor.timestamp ≤ `maxAnchorAge`.
8. The forced inclusion rules (section 7).
9. The EL's `newPayload` returns VALID. Discarding transactions for zk-limit exceedance/overflow applies to candidate-list construction only (3.1): the final EL body, envelope and blob payload contain exactly the retained transactions, with matching transaction root, receipts, stateRoot, gasUsed and difficulty. Validation must execute every transaction listed in a committed block; any listed transaction triggering zk-limit exceedance/overflow invalidates the whole block. Never silently drop or truncate transactions of a Comet-signed block and return VALID.

Freshness is determined only by the candidate and the committed parent: the application does not reject a proposal merely because the node's finalized L1 head advances, since otherwise a locked block re-proposed unchanged in a later round might never gather more than 2/3 of the voting power. PBTS is not enabled. BFT time's relationship to real time requires Byzantine voting power below 1/3, reasonably synchronized honest clocks and continued consensus progress; a coalition above that threshold can manipulate block time.

The following rules describe proposal admission and liveness:

- **Block size bound**: the envelope's block item (the payload's executionBlock, including its RLP list header, with every transaction, legacy included, counted as an RLP byte string of its EIP-2718 encoding) is at most 124,000 bytes long. The rule looks only at the uncompressed length, so every implementation gets the same answer; ProcessProposal and FinalizeBlock both check it, and the proposer must respect it while building: alethia's build interface takes a byte limit, measured the same way, that it enforces together with gas when selecting transactions, and always keeps the FI transaction at position 0. The bound guarantees that each block fits in one blob on its own, and a six-blob landing holds six maximum-size blocks, so as long as K ≤ 6, any grid segment (6.1) can always be landed in one transaction. If more than 2/3 of malicious voting power decides a block that violates this rule, honest nodes halt for safety in FinalizeBlock, and only governance recovery can fix that.

<details>
<summary>Details: where the 124,000-byte bound comes from, and single-blob packing</summary>

The bound leaves headroom within the 130,044 bytes one blob carries: compressing one maximum-size block's payload list with standard zlib at default settings yields at most 124,055 bytes including the 0x06 prefix, even for incompressible data (zlib's deflateBound), so every decided block fits in one blob on its own. Six maximum-size blocks compress to at most 744,244 bytes, within six blobs (780,264 bytes), so a grid segment of up to six blocks always fits in one six-blob landing; no special compression mode is needed.

</details>

- **No usable anchor, no block**: if no available finalized anchor satisfies the deterministic age bound against the candidate block timestamp, L2 pauses until one is usable. This is not an independent wall-clock timer; its timing inherits the BFT-time assumptions above.
- **Reject a latest checkpoint conflicting with local history**: when the anchor changes, nodes check the anchor's proven `lastCheckpoint`: its height is at most the parent height, and its hash equals the EL block hash at that height on the authenticated local chain. A mismatch rejects the proposal and raises an alert; the proposer may retain a still-valid parent anchor. Guests verify only the witness's storage proofs; nodes do the comparison with the local chain. This check constrains block ancestry only and does not authenticate other landing metadata (FI head, snapshot, stateRoot and so on); off-chain monitors check that metadata without being claimed to prevent bridge or registry payments.

## 4. Staking and committees

### 4.1 Registry

- register(bytes publicKey,amount,popSig): amount ≥ minStake. Activation occurs after activationDelay L1 blocks; registry records msg.sender as owner. exitEffectiveL1 starts at 2\^48 − 1, meaning no exit is set; requestExit reverts unless its computed effective block is below that value.
  - Each key can be registered only once, ever, keyed by `ckAddr` and never released after withdrawal. The registry stores only `ckPrefix = publicKey[0]` and the following 32-byte `ckX`, not the publicKey itself; `ckY` is derived internally.

<details>
<summary>Details: public-key format, decompression and PoP checks</summary>

- `publicKey` is exactly 33 bytes of canonical SEC1 compressed secp256k1 encoding: `ckPrefix ‖ ckX`, with prefix 0x02 or 0x03 and a 32-byte big-endian X retaining leading zeros. Registration tools may accept the user’s existing hex/Base64 public key and convert it to those 33 raw bytes; users do not supply or split X and Y. The contract rejects textual encodings, 64/65-byte uncompressed keys, hybrid encodings and trailing bytes.
- The registry decompresses and validates the public key internally under appendix A: require X \< p without reducing X modulo p, a finite valid secp256k1 point, Y parity matching the prefix, and byte-for-byte equality when recompressed. Any failure rejects the entire registration without creating an entry or consuming the key identity.
- The registry computes `ckAddr = keccak256(ckX ‖ ckY)[12:]` from the two decoded 32-byte coordinates, not by hashing the compressed encoding. Require `popSig` to be exactly 65 bytes with `V ∈ {0,1}`, `0 < r < n` and `0 < s ≤ n/2`; recovery over appendix A’s registration digest must return a nonzero address equal to ckAddr. The digest still binds the L1 chain id, registry and `msg.sender`. The signature must match this supplied public key, not merely recover some valid address. Copying the transaction cannot change the owner.

</details>

- There are 4096 slots in total, and the bond id is the slot. After a withdrawal the slot goes to a free list, and new registrations reuse freed slots first.
- **Top-ups**: `topUp(bondId, amount)` is owner-only. Require an unreleased entry, current L1 block ≥ activeFromL1, effStake > 0, no exit set, no pending top-up, and amount > 0. Transfer the TAIKO into the registry and record `pendingTopUp = amount` and `topUpReadyAtL1 = block.number + activationDelay`, rejecting overflow. Only one top-up may be pending per entry. It uses no new slot and changes neither owner, key nor activeFromL1; pending funds are not effStake, do not enter regLeaf/entriesRoot, and provide no voting power or contribution to S_MIN_TOTAL.
- **Top-up activation**: anyone may call `activateTopUp(bondId)` once the ready block is reached, provided a top-up is pending and no exit is set. Move all pending funds into effStake, clear the pending amount and ready block, and write the normal checkpoint. Maturity alone does not activate funds; activation does not rewrite historical snapshots or already-derived committees.
- **Top-up liability**: once exit is set, no new top-up or activation is allowed. Pending funds cannot be withdrawn separately; they leave only through the entry's normal confirmed-exit and withdrawal process. All principal in an entry backs its key, including still-admissible double-sign evidence from before the top-up and responsibility forfeiture under 4.4. `balance = effStake + pendingTopUp` below. Top-up and activation are allowed before Inbox initialization subject to these same checks.
- `requestExit(bondId)`: callable only by the entry's owner. The exit takes effect at max(current block + `exitDelay`, activeFromL1 + `exitDelay`). It may be called only for an entry with no exit set; once set, `exitEffectiveL1` only moves earlier (slashing, exclusion list), never later.
- **Exit confirmation and withdrawal**: `exitEffectiveL1` determines selection eligibility, not the start of the evidence clock. Anyone may call `confirmExit(bondId)`: the entry must have an exit set (requestExit, slashing or exclusion list) and must not be withdrawn, and the Inbox must have `activeCommitteeSnapshot ≥ exitEffectiveL1`. The first successful call records the current L1 block as `exitConfirmedAtL1`. Repeated calls are idempotent and must not postpone the clock.
- `withdraw(bondId, to)`: requires a confirmed exit and the current block number ≥ `exitConfirmedAtL1 + withdrawalDelay`. When `balance > 0`, only the owner may call it, and all remaining effStake and pendingTopUp are paid to `to`; when `balance = 0`, anyone may call it to release the slot, with no payment. Withdrawal zeros the entry, releases the slot and clears its confirmation, pending amount and top-up ready block, but preserves the lifetime entryKey forfeiture flag (4.4). Confirmation requires that a landed committee no longer includes the stake, so a full evidence window starts only after that; a prolonged halt cannot consume it in advance. `activeCommitteeSnapshot` never decreases (the only exception, the section 8 verifier-failure rollback, also re-checks every exit confirmation against the restored snapshot), so withdrawal does not re-check it.
- The owner cannot be changed after registration; an operator that may need to change custody should register from a contract (such as a multisig), which then becomes the owner. Consensus keys cannot be rotated in place: to change keys, request an exit, withdraw, and register again with the new key. If a key leaks, the owner should request an exit at once; until the exit completes, the leaked key can still be used to double-sign and get the entry slashed.
- `slashDoubleSign(bondId, voteA, voteB)`: callable by anyone. Each vote gives its type, height, round, block id (hash and part set header; all zero for nil), timestamp, uint48 generation and 65-byte signature. The caller cannot choose an Inbox, chain id or deployment tag.

<details>
<summary>Details: double-sign evidence checks and slashing</summary>

- Both votes have the same type, prevote (1) or precommit (2), and the same height, round and generation, with different block ids. The generation must not exceed the Inbox's current recoveryGeneration. Valid evidence from historical generations remains admissible after recovery; future generations and other deployments are rejected.
- The registry derives `ckY` internally from this bond’s stored `ckPrefix ‖ ckX` using the same canonical decompression rules as registration; callers supply neither coordinates nor a substitute public key. Recompute chainDomain, chain_id and both sign-byte strings per appendix A from this deployment’s full L1/L2 chain ids, the Inbox proxy fixed in the registry and the votes’ shared generation. Both `ecrecover(keccak256(signBytes))` results must be nonzero and equal to the stored key’s `keccak256(ckX ‖ ckY)[12:]`. Vote input cannot override these deployment values.
- The entry must not be withdrawn and must have `balance > 0`. On success the whole principal is slashed: effStake, pendingTopUp and the top-up ready block become zero and `exitEffectiveL1` becomes min(its old value, the current block); the caller receives `slashBountyBps` of the slashed amount, and the rest goes to `slashSink`.
- Membership in the committee of the time need not be proven: only the key holder can produce the signatures, and since `chain_id` carries the deployment tag and the generation, re-signing a lower height after a redeployment or governance recovery is not a double sign.

</details>

- Every L1 block that changes an entry ends with one checkpoint (l1Block, count, entriesRoot). Nodes verify snapshots against historical checkpoints, so slot reuse does not affect derivation.
- **Inbox address**: the registry fixes the Inbox proxy address at deployment, and it cannot be changed. Inbox initialization checks that the registry's fixed address equals the Inbox's own address and that the registry's `l2ChainId` matches its own. Until the Inbox is initialized (the registry checks the Inbox's initialization state), confirmExit, slashDoubleSign and forfeit fail, so no withdrawal is possible; registration, topUp and activateTopUp are unaffected. The Inbox can also set the `exitEffectiveL1` of listed entries earlier, to `recoverySnapshot`, during an exclusion-list recovery (section 8 step 2).

### 4.2 Epochs

- L = `epochLenL2`, the number of L2 blocks per epoch, and `L1_0` is the L1 block in which the Inbox was initialized; both are fixed at initialization.
- Epoch t starts at block `H(t) = 1 + t·L`; block h belongs to epoch ⌊(h − 1) / L⌋.
- Epochs are defined by L2 height alone and are not tied to L1 progress; only `maxAnchorAge` (3.4) bounds how old an anchor may be.

### 4.3 Committee derivation

- **One selection rule**: committee 0, ordinary rotation and governance recovery all apply the following rule to their authenticated registry snapshot, independently of previous voting powers or participation history.
  1. Verify the complete entries and root of the latest registry checkpoint at that snapshot.
  2. An eligible entry satisfies activeFromL1 ≤ snapshot \< exitEffectiveL1 and effStake ≥ max(s_min, vp_unit). Consensus keys are lifetime-unique; a state in which two eligible entries share a key is invalid, not extra voting power. Released slots are all zero and ineligible, so they take no part in this check.
  3. Sort by descending effStake, breaking ties by ascending set key, and take the first n_max entries, or all entries if fewer qualify. A key's set key is a fixed sort value: the keccak256 of the L2 chain id and the key's compressed public key (`ckPrefix ‖ ckX`), with the formula in appendix A. It does not change with slot reuse or registration order, and step 2 makes eligible keys distinct, so the order has no ties. Each assignedPower = floor(effStake / vp_unit).
  4. Encode selected members in ascending set-key order; totalPower is the sum of assignedPower. The result must be nonempty, each power positive and representable as u64, and the sum at most MAX = floor((2\^63 − 1) / 8). Otherwise reject the derivation; do not truncate integers or apply node-selected scaling.

<details>
<summary>Details: why power cannot overflow</summary>

- **Power cannot overflow**: TAIKO has a fixed total supply of 10\^27 base units, and deployment requires vp_unit ≥ ⌈10\^27 / MAX⌉ = 867,361,738, so the power of all entries together never exceeds MAX and registration cannot trigger an overflow; the check in step 4 is only a backstop. If TAIKO supply ever increases, choose vp_unit for the new supply and deploy a new configuration first.

</details>

- **Committee 0**: snapshot = genesisCutoff and targetEpoch=0. Inbox stores its record hash, using the same selection and power rule.

<details>
<summary>Ordinary rotation: snapshot, proof root and H+2 activation (details)</summary>

- **Ordinary rotation**: S(t)=H(t)−2 and D(t)=H(t)−3. The snapshot is max(the committed anchor number of D(t), l1BlockNumber in the current generation's fixed origin record); the candidate block's new anchor does not select the committee. Always verify the registry account/storage proofs under the stateRoot of S(t)'s own anchor, newly carried or inherited, i.e. the parentBeaconBlockRoot in S(t)'s header; that root is never earlier than the snapshot. The proof must show the latest registry checkpoint at the selected snapshot. Do not use D(t)'s or any other anchor's root, or the proof bytes would not be unique. Normally the snapshot is D(t)'s anchor; after recovery D(t) may belong to the old generation, so max prevents regression behind the recovery snapshot. FinalizeBlock at S(t) returns updates effective at H(t), following CometBFT's H+2 rule; S(t) and S(t)+1 remain signed by the original active committee. Record.targetEpoch=t.

</details>

- **Governance recovery**: apply the same rule at the authenticated execution block R in section 8, including all candidates eligible there. Set targetEpoch=floor(c/L), effective immediately at c+1. Discard every pending update from the old generation; the initial set depends only on R's snapshot, not on any earlier committee's members or power. The next S(t) actually occurring in the new generation performs ordinary rotation; this also applies if the recovery's first block is S(t).
- **Guarantees and limits**: authenticated L1 state uniquely determines membership and power. There is no per-rotation power-change limit, automatic offline eviction, or wall-clock takeover warning. `activationDelay` delays new registrations and top-up increments; already active stake and standby candidates need not wait again. Only activated increments included in the selection snapshot affect power. Each actual committee remains subject to section 1's voting-power assumptions; the DAO monitors availability and concentration.

### 4.4 DAO responsibility forfeiture

- **Authority and identity**: `forfeit(bondId, entryKey, incidentId, validUntil)` is callable only by the registry owner, the DAO's actual execution address (the Controller where used), and only after Inbox initialization. entryKey is `keccak256(abi.encode(ckPrefix, ckX))` as in appendix A. The DAO authorization binds the deployment, full call parameters and published attribution. incidentId identifies that attribution; the same incident may name multiple entries. The registry keeps no incident case or global incident-id deduplication state.
- **Execution checks**: the bond must be unreleased and still match entryKey, `forfeited[entryKey]` must be false, `block.timestamp <= validUntil`, and `balance = effStake + pendingTopUp` must be positive. Requested or confirmed exits remain punishable until withdrawal; current committee membership is not required. validUntil is an absolute L1 Unix timestamp in seconds fixed in the authorization.
- **Immediate, fixed-rate deduction**: compute `penalty = ceil(balance * forfeitBps / 10000)` from the remaining principal at execution. The deployment fixes `0 < forfeitBps <= 10000`. Deduct from effStake first and then pendingTopUp; clear the ready block if pending reaches zero. Send the full penalty to slashSink, with no bounty. Pending funds and deposits made after authorization but before execution are included: all funds in the entry back its key, without historical-balance accounting.
- **Once per entry, with exit**: in the same transaction set `forfeited[entryKey] = true` and `exitEffectiveL1 = min(existing, block.number)`, writing the normal checkpoint for changed entry fields. The flag starts false and is never reset by withdrawal, slot reuse, recovery or verifier-failure rollback. Changes affect subsequent selection snapshots that include them, not historical snapshots or already-derived committees. Remaining principal follows normal withdrawal rules; an existing exit confirmation is not reset or delayed. Valid double-sign evidence may still take all remaining principal; if double signing emptied the entry first, forfeit fails on zero balance without blocking normal slot release.
- **Authorization expiry and replay**: there is no forfeiture nonce, revocation entry point, queue, hold or extra execution delay. Successful execution immediately completes the forfeiture; the lifetime flag prevents repetition and entryKey prevents targeting a reused slot. An unexecuted authorization remains executable until validUntil if all checks pass, even if the DAO changes its decision; this interface cannot cancel it. Expired calls revert without cleanup. Landing, a generation change and recover do not invalidate the authorization.
- **Atomicity and operations**: update balances, exit and the lifetime flag before transferring funds; reject cross-function reentrancy, and revert all effects on any failure. Emit bondId, entryKey, incidentId, pre-deduction balance and penalty. Execute before lawful withdrawal; this mechanism cannot recover withdrawn funds. Before execution the DAO assesses replacement availability, online quorum and concentration, since normal-operation forced exits may stall a later rotation. This version has a single-entry API. Execute entries independently when failures must not affect each other; do not couple forfeiture to a potentially stale recover in an all-or-nothing governance batch.

## 5. Data formats and DA

### 5.1 Envelope (private)

The single tx in each CometBFT block: `0x06 || rlp([block, anchor, committee, forced])` (the last three are each an empty list or exactly one item), committed to by the CometBFT header's `data_hash` (encoding in appendix A). It propagates only within the consensus network and never goes to L1.

### 5.2 Blob payload (public)

- Each batch uses 1–6 blobs (EIP-7594's per-transaction limit) with Unzen's blob encoding: each blob decodes to at most 130,044 bytes, every non-final blob is full, and all padding bits are 0.
- Content: `0x06 || zlib(rlp([executionBlock, …]))`, where `executionBlock` is `rlp([EL header, ordered EIP-2718 transactions])`. Each transaction, legacy included, is an RLP byte string holding its EIP-2718 encoding.

<details>
<summary>Details: blob payload acceptance rules</summary>

- The acceptance rules use fixed limits that operator settings cannot change:
  - Exactly one complete zlib stream, with no preset dictionary and no trailing bytes; at most 64 MiB decompressed, and each item at most 22,020,096 bytes.
  - All encodings are canonical and re-encode byte for byte.
  - Exactly `lastHeight − parentHeight` blocks at heights `parentHeight + 1 … lastHeight`; EL `parentHash` links block by block, the first block's parent equals `parentHash`, and the last block's hash and stateRoot equal `lastBlockHash` and `lastStateRoot`.

</details>

- Not published: CometBFT headers, original envelopes, anchor/committee/forced witnesses, registry entries, the raw forced transaction of a skip, evidence, commits and signatures. They are private proof inputs: the guest authenticates each original envelope against `data_hash`, then proves that its execution part equals the blob byte for byte.
- **Recovery from DA**: with a sound proof and a finalized L1 checkpoint, archived blobs plus the starting state suffice to rebuild the landed EL chain and check the last block's hash and stateRoot, without witnesses or signatures. This is not the same as bootstrapping CometBFT from L1 alone; unlanded blocks still need the full consensus history.

### 5.3 Public EL state reconstruction

Public reconstruction depends only on the starting state, canonical L1 transactions/events/headers and corresponding blobs, not validator-private databases, complete envelopes, witnesses, signatures or a running L2 RPC. A source-available reconstruction program and these public inputs are required:

- Starting material includes downloadable complete genesis allocation/state and code, content hashes, EL rule version, L1/L2 chain ids, contract addresses, L1_0, genesis hash and stateRoot. The program recomputes and matches the L1-authenticated starting point rather than trusting an unchecked snapshot.
- In canonical L1 landing order, verify versioned hashes and complete (p,h\] blobs. Read p from proof input and actual c from authenticated events/records. Check reconstructed EL hashes and links for the overlapping prefix; execute only (c,h\] from authenticated c's EL state and check h's hash/stateRoot and FI cursor. Select history using authenticated generations and fixed recovery origins. Reject missing original material, unsupported versions or hash mismatches; do not execute the prefix twice, silently skip it or replace authentication with RPC state.
- Historical blobs must remain retrievable and archive contents must be authenticated against L1 commitments. Private history for complete CometBFT/proving is separate (9.1) and is not an input to EL-only reconstruction.

## 6. Landing and settlement

### 6.1 land

land is permissionless and nonpayable. Proofs and blobs cover all of (p,h\], from proof origin p to terminal height h; c, the latest checkpoint height, is read atomically at execution and only the new suffix (c,h\] is settled, so another lander advancing c first does not invalidate the same transaction. Landings end only at grid points: heights, counted from the Etna start (block 0), that are multiples of K, so p, c and h are always grid points (6.3 explains why; section 11 covers the value of K). The checks are, in order: range, grid and origin record; the leaves are exactly those of the grid points in (p,h) and the leaf at c matches the current checkpoint record; FI head advance; reference block and blobs; computing cutHash and verifying both proofs. Once all pass, land atomically updates the checkpoint, snapshot, FI head, slot 285 record and SignalService.

The reference Solidity in the toggle below lists every check land performs; the checks are normative. All checks precede any state change and the leaf checks precede proof verification; the remaining order is illustrative. The land signature, LandInput's eight fields, K and the cutLeaf and cutHash encodings (appendix A) are the interface. Local names and helper bodies are illustrative: helper results are defined in appendix A and the comments, and storage variables map to the normative layout in appendix B.

<details>
<summary>Reference Solidity: land's checks and state updates</summary>

```solidity
// Storage (appendix B): recoveryGeneration 268, lastCheckpoint 270/271, fiHead/fiTail 281,
// activeCommitteeSnapshot 284, landings 285; generationStartHeight() reads 290

struct LandInput {
    uint256 parentHeight;            // proof origin p
    uint256 lastHeight;              // terminal height h
    bytes32 lastBlockHash;           // h's EL block hash
    bytes32 lastCometHash;           // h's CometBFT block hash
    bytes32 lastStateRoot;           // h's EL stateRoot
    uint256 l1ReferenceBlockNumber;  // reference block
    uint256 forcedInclusionHead;     // FI head after settlement
    uint256 activeCommitteeSnapshot; // selection snapshot of the committee actually signing h
}

// Cuts: the EL block hash, CometBFT block hash and FI cursor at each height, with leaf
// cutLeaf(x) = keccak256(abi.encode(x, blockHash, cometHash, forcedHead)) (appendix A).
// Landings end only at grid points: heights, counted from the Etna start (block 0), that are
// multiples of K, so every checkpoint height is a grid point. Both proofs authenticate cutHash, a
// hash over the leaves at every grid point in (p, h) (appendix A), and land carries all of them
// (6.3 explains why).
// K: grid interval, a protocol constant with 1 <= K <= 6; its value is not fixed yet (section 11)

function land(
    LandInput calldata input,
    bytes32[] calldata leaves,    // leaves at grid points p+K, p+2K, ..., h-K inside (p, h), in height order
    bytes calldata proof          // the two proofs (6.2)
) external nonReentrant {          // permissionless, nonpayable; shares recover's reentrancy lock (8.3)
    uint256 p = input.parentHeight;
    uint256 h = input.lastHeight;
    uint256 c = lastCheckpoint.height;          // read atomically at execution; always a grid point

    // 1. Range and grid. c >= h means the target is already settled: reject without mutation.
    require(generationStartHeight() <= p && p <= c && c < h && h < 2**48);
    require(p % K == 0 && h % K == 0 && h - p <= maxBatchBlocks);

    // 2. Origin p needs a retained slot 285 record in the current generation; a missing p is rejected.
    //    The only exception is the current generation's origin, which may reuse an older
    //    generation's record. Proofs cannot cross generations.
    Landing memory origin = landings[p];
    require(origin.elHash != 0);   // a written record never has EL hash 0 (block 0 stores the genesis hash; its Comet hash is 0)
    require(origin.generation == recoveryGeneration || p == generationStartHeight());

    // 3. leaves must be exactly the grid-point leaves in (p, h). If c > p, the leaf at c must equal the
    //    leaf the contract computes from c's slot 285 record: height, EL hash, Comet hash and FI cursor
    //    all match (comparing only height or stateRoot is insufficient); if c = p, step 2 and the
    //    statement already bind the origin record. The FI cursor in c's record must also equal the
    //    current FI head. All of this is checked before proof verification. The other leaves only
    //    feed cutHash; a wrong one fails proof verification in step 6.
    require(leaves.length == (h - p) / K - 1);
    Landing memory cur = landings[c];
    require(cur.head == fiHead);
    if (c > p) {
        require(leaves[(c - p) / K - 1] == keccak256(abi.encode(c, cur.elHash, cur.cometHash, uint256(cur.head))));
    }

    // 4. FI head only advances from its pre-execution value to forcedInclusionHead, never beyond
    //    tail and by at most h - c. The proof authenticates all consumption from p; L1 applies
    //    only the suffix and never consumes the prefix again.
    uint256 headAfter = input.forcedInclusionHead;
    require(fiHead <= headAfter && headAfter <= fiTail && headAfter - fiHead <= h - c);

    // 5. The reference block is in the past with a readable hash (blockhash's 256-block or
    //    EIP-2935's 8191-block window). The transaction carries 1-6 blobs binding all of (p, h];
    //    they cannot be replaced by suffix-only blobs.
    require(input.l1ReferenceBlockNumber < block.number);
    bytes32 refHash = l1BlockHash(input.l1ReferenceBlockNumber);
    require(refHash != 0);
    bytes32[] memory blobs = txBlobHashes();   // in index order
    require(blobs.length >= 1 && blobs.length <= 6);

    // 6. Compute cutHash from leaves, build the statement and verify both proofs (encodings in
    //    appendix A); wrong leaves fail proof verification. parentHash, parentCometHash and
    //    headBefore come from origin p; the statement's other words are deployment constants and
    //    committeeConfigHash (slot 269). The proof authenticates activeCommitteeSnapshot as the
    //    selection snapshot of the committee actually signing h, no later than the reference block.
    bytes32 cutHash = keccak256(abi.encode(bytes32("ETNA_LAND_CUTS_V1"), recoveryGeneration, p, h,
                                           keccak256(abi.encodePacked(leaves))));
    bytes32 st = statement(recoveryGeneration, input, origin, refHash, keccak256(abi.encodePacked(blobs)), cutHash);
    verifier.verifyProof(0, st, proof);   // age 0 = not applicable; reverts unless both proofs verify

    // 7. Update atomically; any failure reverts everything. FI fees are not paid out. The landing
    //    record's parent is always actual c, never proof origin p. Once the frontier advances,
    //    recovery authorizations bound to the old c can no longer execute (8.3).
    lastCheckpoint = Checkpoint(h, input.lastBlockHash);
    activeCommitteeSnapshot = input.activeCommitteeSnapshot;
    fiHead = headAfter;
    landings[h] = Landing({parentHeight: c, generation: recoveryGeneration, head: headAfter,
                           elHash: input.lastBlockHash, cometHash: input.lastCometHash}); // slot 285
    signalService.saveCheckpoint(h, input.lastBlockHash, input.lastStateRoot);
    emit Landed(p, c, h, cutHash, input.activeCommitteeSnapshot, VERSION);
}
```

</details>

### 6.2 Proofs

- The verifier is an Inbox immutable. The contract only calls its `verifyProof` interface and does not check the implementation; production deployments must use the same `ZkRequiredVerifier` as mainnet (Unzen): exactly two sub-proofs, at least one of them ZK (SGX + RISC0/SP1, or RISC0 + SP1), which needs two guests. The verifier address, code hash and accepted image set are pinned in the deployment manifest and checked as a launch gate in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md). If one backend fails, another combination can be used; if no valid combination can be assembled, settlement stops.
- Withdrawals use the checkpoint that `land` writes into SignalService directly, with no extra withdrawal root, delay or veto.
- Here parentHeight/parentHash and headBefore are taken at proof origin p. Each subproof authenticates the same statement, including cutHash; execution and cut authentication cannot be split between backends. The proof stays valid even if p is not the latest checkpoint at execution; 6.1 atomically selects actual c.

<details>
<summary>What the guest must prove (10 items)</summary>

- The guest must prove:
  1. Inbox and registry storage holds under authenticated L1 roots; `committeeConfigHash` opens per appendix A; the genesis schedule is authenticated.
  2. Derive signing and pending committees using 4.3's unified rule, authenticating snapshot, entries, power, record and H+2 activation. The ordinary path follows authenticated EL parentHash to the required D(t), requiring at most L+2 historical headers. Every proof authenticates the current generation's fixed origin record (3.4 rule 3 uses its l1BlockNumber); recovery also authenticates retained checkpoint c and the R registry snapshot and directly selects the initial set. Current-generation Comet headers link by last_block_id: the first non-genesis header binds parentCometHash and the terminal one binds lastCometHash. A generation's first header has empty last_block_id; parentCometHash then authenticates only the old origin c header (0 when c=0). Every block's commit signatures and schedule are verified. L+2 excludes the separate L1-ancestry and recovery-material budget.
  3. Each block's commit carries more than 2/3 of the voting power from distinct signers of its actual active committee, secp256k1eth (keccak256 then `ecrecover`, low-s), under this generation's `chain_id`; each block's `validators_hash` and `next_validators_hash` match the authenticated activation schedule, including the ordinary S(t), S(t)+1 and H(t) handover and recovery and subsequent normal handovers under section 8. A numeric epoch alone cannot authorize a committee.
  4. Original envelopes match `data_hash` and their witnesses satisfy the rules of sections 3 and 7; execution runs from `parentHash` to the last block's hash and stateRoot; the execution part equals the blob payload byte for byte. Nodes, the EL and both guests use the same pinned zk-gas rules/parameters and validate the entire committed transaction list under 3.4; do not normalize an over-limit payload into a shorter prefix and prove that instead.
  5. Forced inclusion entries `[headBefore, headAfter)` are consumed exactly and in order (section 7); eligibility of the raw bytes follows 7.2 and the same vectors; skipping an eligible transaction reproduces, on the parent, the same singleton build result as alethia, namely an empty block. This includes an empty singleton result caused by the zk limit under 7.2’s full block budgets; its discarded trial work is still part of the proof computation even though it contributes no final difficulty or fees.
  6. Each block has extraData\[0\]=100.
  7. activeCommitteeSnapshot is the authenticated selection snapshot of the committee actually governing lastHeight: genesisCutoff for committee 0, that generation's R for its recovery initial committee, and 4.3's snapshot for ordinary rotations. Pending committees, the terminal anchor and reference block are not substitutes. Old pending updates never activate after recovery; report R until an ordinary update in the new generation actually takes effect.
  8. The anchor of every block in (p,h\] and every other L1 root used in the proof lie on the L1 header chain ending at the reference block. Each header is decoded per 3.3, and links compare keccak256 of the raw bytes with the next header's `parentHash`.
  9. The blob payload is bound to `blobHashes`:
     - For each i, all 4096 field elements of blob i are canonical (less than the BLS12-381 scalar field modulus), and there is a KZG commitment C with `blobHashes[i] = 0x01 ‖ sha256(C)[1:]` that commits to exactly that blob. The guest may recompute C from the blob, or use a proof of equivalence: derive the challenge point by hashing the blob together with C, evaluate the blob at that point itself, and verify the KZG opening of C at that point.
     - The blob payload is the bytes decoded from these blobs in index order with the encoding in 5.2, and it satisfies every acceptance rule in 5.2; "the blob payload" in item 4 means this payload.
     - The statement's `keccak256(abi.encodePacked(blobHashes))` is computed from the same list.
  10. The cuts cover p through h continuously without duplicates or omissions. The first EL/Comet hashes and FI cursor match the authenticated origin; every later cut comes from the corresponding real header and execution/consumption results, with the FI cursor advancing by 0 or 1 per block under section 7. The last cut's two hashes and FI cursor equal lastBlockHash, lastCometHash and forcedInclusionHeadAfter. p and h are grid points; compute cutHash over the cuts at every grid point in (p,h) using appendix A's unique encoding; cuts not authenticated by execution must not be accepted. Every block in (p,h\] satisfies anchor, commit, committee, FI and EL rules, including time and ancestry verification of the anchor it uses (newly carried or inherited); origin p is authenticated by its slot 285 record and is not verified on its own. Only when p+1 inherits p's anchor does the guest take that anchor's raw header and Inbox proofs as input and verify them against p+1's extraData and parentBeaconBlockRoot.

</details>

### 6.3 Batches

- A batch is cut only at grid points (6.1) and may cross epochs. Handover heights, cancelled old activation heights and the next normal handover are unrelated to the grid and may fall inside a batch or exactly on a grid point; a recovery start is a checkpoint and so always a grid point. All of these use the actual schedule rather than avoiding a problematic cut. `l1ReferenceBlockNumber` can be any recent L1 block, avoiding expiry of the reference hash alone. When the old unsettled suffix above c is proven after a long outage without governance recovery, the old anchors those blocks used must still be authenticated within the supported ancestry/proving budget, and choosing a recent reference does not remove that requirement. Landers and provers need a resource bound on the reference-header chain (reference value 131,072 headers, about 18 days of L1 blocks at 12 s); a suffix beyond it cannot be landed the ordinary way and can only be discarded by governance recovery under section 8 (at most U blocks), restarting from R; the outage before R does not count toward this bound (8.4).
- Prove from an authenticated, retained historical checkpoint p, normally the latest when work begins. It cannot precede this generation's starting point, and the proof cannot span generations. If another lander advances to c, the original transaction (two proofs, blobs and leaves) stays valid unchanged whenever p ≤ c \< h: execution settles (c, h\] with no reproving, reaggregation or parameter change. If c ≥ h, the target is already settled and work can be cancelled. Reference expiry, rule/image changes or a generation transition can still invalidate a job; signed jobs must not be rewritten to bypass those boundaries. Copying a transaction cannot change any proven content; landing carries no reward, so who submits it does not affect settlement.

<details>
<summary>Details: why landings end only at grid points</summary>

- **Why check c at all**: a proof may start at a p older than c, while c advances through other landings. If more than 1/3 of the voting power double-signs, one height can have two valid blocks; without checking that the proof's chain at c is the block L1 recorded, L1 could settle one fork and then attach the other, and the bridge could be double-spent. Requiring p = c avoids the check, but then every competing landing forces reproving.
- **Why a grid**: a proof is generated without knowing c at execution, so it must commit to every possible c. If any height could be c, that takes a Merkle tree plus a window and sibling nodes, with the lander guessing at signing time where c will be and reverting on a wrong guess. With landings ending only at grid points, c is always a grid point and the candidate list is short enough to carry in full: the same transaction works for c at any grid point in (p,h), the lander guesses nothing, and a competitor cannot make an honest submission fail by landing first (section 12, item 16). The contract does one hash and one indexed comparison, and the guest builds no Merkle tree.
- **Choosing K**: a grid segment has at most K blocks and must always be landable in one transaction. The 3.4 block size bound lets each block fit in one blob on its own, and a transaction carries at most 6 blobs, so K ≤ 6. A larger K means fewer leaves, but longer waits, more blocks discarded on a halt and more proving per landing (next item). The value is not fixed yet; it is set from measured worst-case proving capacity during acceptance (section 11).
- **Costs**: a lander waits at most K − 1 blocks to reach a grid point. Leaves grow linearly with the batch: a batch of B blocks carries B/K − 1 leaves of 32 bytes each (for 300 blocks, 99 leaves and 3,168 bytes at K = 3, or 49 leaves and 1,568 bytes at K = 6). Every grid segment must be provable within one landing's two proofs (section 1). If the chain halts between two grid points, governance recovery discards at most K − 1 more provable decided blocks (8.1).

</details>

- Landers may coordinate active jobs off chain, monitor checkpoints and cancel stale work, reusing only inputs or subproofs that can be reauthenticated and are compatible with the target version. Coordination grants no exclusive rights and cannot bypass 6.4's U bound. Wasted proving and retry costs are covered by DAO operating funds (appendix C).
- Follow 6.4's proactive batching and submission policy. One remaining producible height is an alarm requiring immediate submission of an available batch, not the point to start proving.

### 6.4 Back-pressure

L2 height cannot exceed the anchor-proven lastCheckpoint.height + U, where U is an integer parameter committed directly in the config hash, with `K ≤ U ≤ 65,536` and U a multiple of K, so the pause point is a grid point. U is a circuit breaker for settlement failure, not the pace of normal settlement: it should pause L2 only when proving or landing stalls for a long time or a decided block cannot be proven, capping the blocks governance recovery may discard. The target deployment uses **U = 3,600** (about 4 h at 4 s blocks); approximately 4 s blocks and no more than 20 min between L1 inclusions of successive successful landings are operating targets, not block-validity rules. U and the epoch length L do not constrain each other: the unsettled suffix may span several epochs, and L is chosen separately for committee rotation (section 11). A landing stall permits at most U further blocks. L1 inclusion alone does not release the pause: the landing state must finalize and be adopted by a new anchor.

<details>
<summary>Details: latency budget and unsettled-block arithmetic</summary>

An approximately 4 s block interval is an operating target, not a minimum interval or uninterrupted-production guarantee. L counts blocks; nominal epoch duration is L × target block interval, while actual duration can be shorter or longer. End-to-end settlement includes batching, queues/proving, retries, L1 inclusion/finality and anchor adoption. Assess back-pressure from actual `height − anchor.lastCheckpoint.height`, not average-interval conversion alone. U=3,600 corresponds to 4 h at a sustained 4 s block interval, not a wall-clock outage guarantee. In normal operation the unsettled count is about “the interval between landing inclusions + the previous batch's terminal-block-to-inclusion latency + the next landing's finality and anchor-adoption latency”, counting the actual critical path of the two proofs; at 20 + 20 + 20 min that is about 900 blocks, leaving about 3 h for a proving or landing outage. This latency budget is an operating target: missing it shrinks the margin but does not pause L2. Sustained 4 s production is about 15 blocks/min; settlement throughput must keep pace without a growing unsettled backlog. At one batch every 20 min, each must cover about 300 blocks on average. If maxBatchBlocks, six-blob capacity or proving capacity cannot support that batch, settle more frequently or provide the missing capacity rather than merely delaying a halt with a larger U; after an outage, proving capacity must exceed the block rate to clear the backlog. The 20 min finality/adoption component neither bounds L1 finality nor relaxes maxAnchorAge. Exceeding the allowance causes a normal pause, never a bypass of U; this arithmetic establishes neither a measured pause fraction nor a no-pause SLA.

</details>

For uninterrupted operation, U should exceed the number of blocks produced during one landing round trip. Landers should continuously prepare and submit batches from the latest checkpoint, submitting early based on actual unsettled blocks and remaining proving/finality time. The 20 min target is not a mandatory batching wait and grants no exclusive landing right. “One producible height left” is an emergency signal, not the point to start proving. The target remains 4 s; a result obtained by temporarily slowing production does not establish that target.

U is fixed at deployment and cannot be overridden by local node configuration. An anchor is a finalized L1 block, and checkpoints only advance, so anchor-based accounting never undercounts unsettled blocks; the sole exception is the section 8 verifier-failure rollback, whose accounting rules ship with that upgrade. L1 finality lag only brings the pause forward and cannot authorize exceeding U. Raising U raises the maximum number of blocks governance recovery under section 8 may discard; before recovery, blocks are settled up to the last provable grid point (8.1), so only blocks that truly cannot be settled are discarded, plus at most K − 1 provable blocks short of a full grid segment. Publish the selected L and its nominal epoch duration L × 4 s (60 min at the suggested L = 900), without treating it as a wall-clock guarantee.

**Acceptance**: before using the target configuration, pass the resource and latency acceptance in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md); until then, do not claim deployment readiness or target attainment. Do not omit latest-checkpoint checks, use non-finalized anchors, remove a proof, locally loosen U or silently expand resource limits.

## 7. Forced inclusion

### 7.1 Submission

`saveForcedInclusion(bytes tx)`: at most 8,192 bytes, with a fee of `fee × (threshold + pending) / threshold` gwei, where pending is the number of entries on L1 not yet consumed by a landing (`tail − head`; while settlement lags this includes entries already consumed on L2 but not yet landed); overpayment is refunded. Each entry stores only `keccak256(tx)`, the L1 timestamp and the L1 block number. The enqueue event records the entry index, raw transaction bytes and actual fee charged in wei, excluding refunded overpayment; encoding is not checked at submission. On successful enqueue, the fee calculated and collected using the formula becomes protocol revenue and stays in the Inbox. The fee buys queue admission, not successful execution: inclusion, valid skipping, governance blanking and replay after a settlement rollback neither refund it, charge it again nor pay it to a lander. Historical per-entry charges are recorded only in enqueue events, not used as consumption or recovery inputs. If the submission transaction reverts, neither enqueueing nor charging takes effect.

<details>
<summary>Details: sweeping protocol fees</summary>

**Sweeping protocol fees**: deployment fixes a nonzero DAO treasury address, `protocolFeeRecipient` (an Inbox immutable), and publishes it in the deployment manifest. Only `saveForcedInclusion` accepts ETH (overpayment is refunded in the same transaction) and every other Inbox entry point rejects ETH, so, apart from force-sent ETH, the Inbox balance is the FI fees not yet swept. Anyone may call `sweepProtocolFees()` to transfer the Inbox's entire ETH balance to that address; a failed transfer reverts. Force-sent ETH is swept with it. Neither `saveForcedInclusion` nor `land` transfers funds to the treasury, so a treasury receipt failure affects only the sweep. Sweeping does not depend on the queue head or landing and does not modify FI entries or queue progress.

</details>

### 7.2 Consumption rules

- L2 state keeps a cursor c (the number of entries consumed, initially 0). Each block consumes at most one entry, and only entry c. After a landing, the Inbox's head equals c at the checkpoint.
- Each block uses its own anchor A: if `c ≥ tail(A)`, it carries no forced witness; otherwise it must carry entry c's witness, a storage proof under A's stateRoot.
- **Due**: `A.timestamp ≥ entry.timestamp + forcedInclusionDelay`, evaluated without overflow. Entries never expire.

<details>
<summary>Eligible transaction: exactly one canonical EIP-2718 transaction (detailed rules)</summary>

- **Eligible transaction**: the raw bytes are exactly one canonical EIP-2718 transaction. Canonicity depends only on the raw bytes, never on state, and nodes and guests implement it against the same shared accept/reject vectors rather than any library's decoder: decoding consumes all input and re-encoding reproduces the bytes; the type is a non-blob type accepted by the pinned EL version (type 3 and unknown types are ineligible); a typed transaction's chain_id equals the L2 chain id and its y_parity is 0 or 1, and a legacy transaction's v is 27, 28, 2·l2ChainId + 35 or 2·l2ChainId + 36; nonce and gas are below 2\^64, each fee field is below 2\^128, and value is below 2\^256; the signature's r and s lie in \[1, n − 1\] (n is the secp256k1 order) with s ≤ n/2 and recover a sender; and gas is at most `L2_BLOCK_GAS_LIMIT`. These checks cover only the transaction's own fields and signature: type-4 authorization tuples need only the field widths EIP-7702 requires, and an invalid tuple signature or chain id makes the EL skip that tuple without affecting eligibility. Eligibility ignores fees: a transaction whose `maxFeePerGas` (`gasPrice` for type 0/1) is below the block's base fee has an empty singleton build, so it may be legitimately skipped. A proposer can push the base fee to the 1 gwei cap at no cost (3.2), so an FI transaction should set `maxFeePerGas` to at least 1 gwei to be sure it is not skipped for its fee.

</details>

| Case                                                                                          | Handling                                                                                                                                                                                                             |
| --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Transaction 0 of the execution block is the entry (canonical, at most 8,192 bytes, same hash) | Included, c + 1, before or after due. Ordinary transactions may follow, and ordinary EVM revert/OOG counts as inclusion; a zk-aborted transaction absent from the final body does not                                |
| Not included, not due                                                                         | c unchanged                                                                                                                                                                                                          |
| Not included, due, raw bytes ineligible                                                       | Skipped, c + 1, no EL needed                                                                                                                                                                                         |
| Not included, due, raw bytes eligible                                                         | Skippable, with c + 1, only if a complete build of `[tx]` on the committed parent with the same attributes, in alethia's given-list mode, yields an empty block; the result is judged under "Given-list build" below |

<details>
<summary>Details: given-list build (deciding whether a skip is legal)</summary>

- **Given-list build**: the build returns only after completing the deterministic build decision for `[tx]`, and has exactly two possible results: a block containing the transaction, or an empty block. It must not return a placeholder from before the build completes. If an eligible transaction cannot execute for any transaction-level reason (nonce, balance, intrinsic gas and so on), the result is an empty block, never an error. Transient infrastructure failures such as timeouts, a dropped connection or a SYNCING response from newPayload are not results: ProcessProposal and FinalizeBlock both wait and retry until a result exists, and never reject a proposal, judge a block invalid or skip because of them; while waiting, that node processes no new consensus messages. If the EL definitively cannot build on that parent (for example because the historical state was pruned), the node halts for safety under section 8 and restarts after the state is restored. An eligible transaction's gas is at most one block's limit, so each build does bounded work. This singleton build starts from that parent with the same attributes and candidate list `[tx]` only, with full EVM-gas and zk-gas block budgets; ordinary transactions may not consume them first. A completed empty result after fully discarding `tx` for zk-limit exceedance/metering overflow under the shared rules is deterministic and reproducible. An included ordinary EVM revert/OOG is not empty. Nodes and guests make the same complete determination; a host timeout, exhausted prover resources or a smaller local budget cannot justify skipping.

</details>

- A block at or after due that neither includes nor legally skips the entry is invalid. Only position 0 counts as inclusion: a replacement transaction with the same sender and nonce, or the transaction placed later in the block, does not count.

<details>
<summary>Details: raw bytes in the witness and fetching them</summary>

- The raw bytes in the witness may be empty; if nonempty, their hash must match the entry. A skip must carry the raw bytes, and empty bytes can only prove that the submission itself was empty. For an inclusion the guest authenticates transaction 0 of the execution block directly, so proposers leave the bytes empty to save data.
- The proposer fetches the raw bytes with `eth_getLogs` at the entry's L1 block and checks the hash. Before due, if they cannot be fetched it may propose an ordinary block; after due, it cannot propose without them.

</details>

- **Blanked entries**: after submission, an entry's `txHash` changes only when step 3 of governance recovery (section 8) overwrites it with the hash of the empty byte string, `keccak256("")`. Under an anchor that shows this value, the raw bytes are the empty string and need no `eth_getLogs`; such an entry can never be included, and once due it is skipped as ineligible, without the EL.

### 7.3 Guarantees and bounds

- A due queue-head entry must be included or legally skipped under 7.2; there is no age-only deletion. For the current queue-head entry, any valid block with `block.timestamp ≥ entry.timestamp + forcedInclusionDelay + maxAnchorAge` necessarily sees it as due, using overflow-safe arithmetic. This is a block-time implication, not a wall-clock inclusion deadline. Wall-clock progress also depends on the BFT-time assumptions in 3.4, L1 finality, queue backlog and settlement.
- Senders must hold a balance of gasLimit × `maxFeePerGas`; the queue consumes at most one entry per block, and the fee rises linearly with the queue length.
- **Backlog cost accounting**: let F be the fees actually paid for an attacker's enqueues. With fees belonging to the protocol, no share of successful landings lets the attacker recover F by consuming those entries. Add L1 submission gas, proving/landing/blob costs the attacker chooses to incur, and the L2 gas actually executed separately; account for other rewards or proceeds separately as well. Production fees, threshold, service rate under sustained attack and honest-user costs require evaluation; [Etna Acceptance and Launch Checklist](ACCEPTANCE.md) gives an illustrative calculation.

## 8. Halts and recovery

**Scope**: an automatically retrying liveness pause loses no blocks; executing governance recovery discards the suffix above c.

- **Liveness pauses**: the process keeps running and CometBFT keeps rounding; production resumes automatically once the cause clears, and no blocks are lost. Causes: the anchor not yet finalized or older than `maxAnchorAge`, back-pressure, an unavailable committee witness, or unavailable raw bytes for a due forced transaction. A local L1 node that lags, is unreachable or times out falls in this class too (section 9). So does an anchor header whose hash matches the canonical hash but that cannot be parsed under 3.3 (L1 changed the header format): ProcessProposal rejects, FinalizeBlock waits and retries, and production resumes once the node is upgraded.

<details>
<summary>Details: ABCI constraints that keep a pause lossless under stock CometBFT</summary>

For a liveness pause to lose no blocks with stock CometBFT v0.40.0, the app must never return an error or exception from any ABCI method on any connection (CometBFT exits or panics); Query and the snapshot methods return only error codes or empty results. ProcessProposal returns only ACCEPT or REJECT. PrepareProposal stays within the request's `max_tx_bytes`; during a pause, or when the required envelope does not fit, it returns a placeholder proposal with no transactions, which ProcessProposal rejects, and CometBFT moves to the next round as usual. InitChain returns only `app_hash`, with no validators or consensus params, and Commit always returns a `retain_height` of 0. Automatic recovery after refused signatures is in section 9.

</details>

- **Safety halts**: the process exits and needs manual investigation. Causes: a decided block that violates the validity rules or contradicts local state or the EL (including an EL `-38002` rejection); fork evidence found during sync or trust checks, or malformed or unverifiable data from the node's own L1 node or EL (section 9; an L1 header whose hash matches but that cannot be parsed under 3.3 is excluded); or, while replaying a canonical skip during cold sync, an EL that refuses to build on the parent with a non-retryable error, usually because it lacks the parent's historical state, which must be restored before restarting.
- **Superseded generation**: once an anchor shows a `recoveryGeneration` larger than this chain's generation, this chain cannot advance and the node can only restart under the new generation. ProcessProposal rejects a proposal carrying such an anchor and revokes checkpoint trust while the process keeps running; a decided block carrying such an anchor, or a startup or signer-session trust check that finds an Inbox generation different from this chain's, is a safety halt.
- **Committee derivation failure**: an empty candidate set or failed authentication/numeric constraint under 4.3 rejects S(t) proposals and may persistently halt production. Do not locally scale, add members or skip rotation. Governance recovery below may reselect from a new R snapshot, but eligible candidates are still required.
- **At least 1/3 voting power offline**: consensus halts without automatic replacement or power reduction. Returning members may restore it; otherwise governance recovery below reselects. Withdrawals still follow 4.1: confirmed exits can withdraw once the waiting period ends, while unconfirmed exits await settlement coverage.
- **Settlement stall**: L2 produces at most U more blocks and then stops on back-pressure.
- **Verifier failure**: both proofs accepting a wrong result is outside the threat model (section 1). A bad landing may corrupt the checkpoint, FI head or snapshot, and ordinary governance recovery cannot repair it. Contain losses first by pausing `SignalService` and the Bridge and by QuotaManager limits. Replacing the verifier already requires an Inbox upgrade, and the settlement rollback is executed in the same DAO upgrade of the Inbox and the registry. The Inbox restores lastCheckpoint (slots 270/271), the FI head (281) and activeCommitteeSnapshot (284) to the values written by the last trusted landing and voids later landing records and SignalService checkpoints. The last trusted landing is the last landing before the first bad one; if there is none, restore the initialization values. The registry re-checks every exit confirmation against the restored snapshot, keeping it only if that snapshot ≥ the entry's exitEffectiveL1 and clearing it otherwise. The check does not compare the L1 block numbers of confirmations, because block numbers cannot order transactions within one block. Node rules for handling the rollback ship with it. The rollback returns c to an earlier value, so the same upgrade must preserve and increment the current recoveryNonce (8.3), invalidating every prior recovery authorization without restoring a historical nonce; the rollback itself does not change the generation. If a governance recovery executed at a c above the restored one, that generation starts above the restored c and no landing can succeed in it; the DAO must follow the rollback with a new governance recovery from the restored c. Bridge payments or stake already withdrawn using bad checkpoints cannot be recovered; L2 fees were paid to proposers at execution and are unaffected.
- **Governance recovery**: for a long landing stall that normal settlement cannot clear. The call is recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil, exclusions, fiToClear). Exclusions is a list of (bondId, entryKey) sorted strictly by bondId; fiToClear contains strictly increasing entry indices. Call conditions, replay protection and atomicity are in 8.3; timing is in 8.1.
  1. Validate all lists and state before applying the following transition in one transaction.
  2. Each excluded entry must still match the entryKey given in the call and must not have been released or reused; otherwise reject the whole operation. Inbox calls the registry to set exitEffectiveL1=min(existing,R), with no forfeiture by recover itself; independent responsibility forfeiture (4.4) and double-sign evidence remain available.
  3. Each fiToClear index must still be in \[head,tail). Replace txHash with keccak256(""), retaining timestamp and enqueue block. This is for handling unprovable content only; unlisted entries survive and are consumed by the new chain under the normal rules. Admission fees are neither refunded nor recharged, and no lander is paid.
  4. Increment generation (generation+1 must fit uint48), write the fixed origin in 8.4, and emit execution details and complete lists. Preserve checkpoint c's landing record and FI head. Recovery must not advance activeCommitteeSnapshot early; only a real landing signed by the new committee advances it. Confirmed exits are unaffected (4.1).
  5. Nodes rebuild EL from authenticated c and select the committee directly from the registry snapshot at execution block R under 4.3, without carrying over the old generation's powers. Excluded entries are ineligible; other already active candidates may enter. Discard every pending update from the old generation and resume ordinary switches/H+2 on global heights. No signing for the new generation before the 8.2 authentication completes. Nodes/guests independently authenticate R's final snapshot rather than trust governance-supplied weights.
  6. Discard only the unsettled suffix above c; users resubmit those transactions, and fees in those blocks are void with them. Do not rewind the settled prefix.

### 8.1 Recovery authority and user-visible boundaries

- Only the DAO authorizes recovery, exclusion and FI blanking; ordinary on-call or pause authority has no such powers. Bridge/SignalService pauses limit future exposure but cannot recover paid bridge funds or withdrawn stake.
- **Timing**: recover has no separate time threshold; the shortest stall before recovery depends on the delay of the DAO's authorization path. expectedC is set to the current c and fixed at authorization, so any landing after that makes the call unexecutable; a recovery executed through the standard path (veto period plus timelock) therefore implies no landing during that whole period. The emergency path that skips the veto period should be used only for a long landing stall that normal settlement cannot clear, and on that path the lists may become public only at execution, with no advance notice. Slow progress, low TPS, a wall-clock FI delay or missing the 20 min landing target is never a reason to recover.
- **Before authorizing**: the DAO has landers settle up to the last provable grid point and sets expectedC to the resulting c, so only blocks that truly cannot be settled are discarded, plus at most K − 1 provable blocks short of a full grid segment. Before scheduling and executing, it checks a nonempty intended set, more than 2/3 online power, no party at or above 1/3, and available history and signers, and confirms that c's landing matches honest nodes' local chain: the EL hash, Comet hash and FI head in its slot 285 record, the SignalService checkpoint at c, and slot 284 (the selection snapshot of the committee that signed c). A mismatch means the verifier has failed: perform the section 8 verifier-failure rollback first, then authorize recovery.
- **Economic review and independent forfeiture**: estimate the intended committee against the launch checklist's capital target, then reassess the actual snapshot after R is finalized, including newly activated registrations and top-ups. A capital shortfall or expired valuation triggers an alert, public disclosure and replenishment, not a new recovery or signer veto; existing quorum, concentration and authentication checks remain. Recover neither executes nor cancels responsibility forfeiture and does not wait for it; resumed production does not erase responsibility under 4.4.

### 8.2 Recovery signer

- The signer keeps separate stock HRS state for each full `chain_id` (which includes the generation), persists each signature before returning it, and never resets or rolls that state back; no copy of the key may sign outside that state. If the state is lost or its latest value is uncertain, stop signing; deleting state cannot restore service.
- Sign for a new generation only after the node's own finalized L1 view authenticates the recovery execution (new generation, origin c, R's registry snapshot and the committee reselected under 4.3) and both the 8.4 origin-record and genesis checks and section 9 checkpoint trust pass. The new generation starts its own HRS state at c + 1, and once the recovery is authenticated, signing requests for the old generation are refused. Votes in different generations use different signing domains and are not double signs. Failover, fencing and similar protections against same-domain double signing are operational practice.

### 8.3 Execution-time checks in recover

- **Caller and conditions**: only the Inbox owner (the DAO) may call recover. Both recover and invalidateRecoveryNonce require Inbox initialization. At execution expectedGeneration, expectedC and expectedRecoveryNonce must equal current state, and `block.timestamp <= validUntil`; validUntil is an absolute L1 Unix timestamp in seconds fixed at authorization. For recovery authorization, Inbox stores only a monotonically increasing uint256 recoveryNonce, initially zero, with no recovery queue or scheduling records. It does not distinguish DAO authorization paths; authorization or queueing does not freeze landing.
- **Replay and invalidation**: increment recoveryNonce on successful recover. Only the Inbox owner may call `invalidateRecoveryNonce(expectedRecoveryNonce)`; require a match and increment to invalidate all unexecuted authorizations with that nonce. Verifier-failure rollback also preserves and increments the current nonce; no path may restore an older value or wrap it. Landing changes c, recovery changes generation, and generation never decreases. A rollback returning c to an old value cannot revive old authorizations. Every retry must pass all checks; changed parameters require fresh DAO authorization. This recovery nonce is independent of the entryKey lifetime forfeiture flag in 4.4.
- **Atomicity**: list validation, registry forceExit, FI blanking, counter updates and origin recording all happen inside one recover call, and any failure reverts everything, leaving no partial exit, FI edit or generation change. Recovery-list exclusion and FI blanking exist only inside recover and cannot be applied in an earlier transaction. This does not restrict owner exits, double-sign slashing (4.1) or the independent responsibility forfeiture and forced exit in 4.4. During recovery, reject cross-function reentrancy that could change the checkpoint, generation, recovery lists or withdrawal eligibility, including land, recover, recovery-nonce invalidation and registry mutations or withdrawals.

### 8.4 Fixed origin and genesis of a new generation

Recovery uses stock CometBFT v0.40.0 without adding an authorizer or trusted snapshot service. c is the fixed recovery origin and R the canonical L1 block that executed recover; nodes authenticate both from their own finalized L1 view.

- **Fixed origin record**: slot 290 stores (startHeight, l1BlockNumber, l1Timestamp) = (c, R.number, R.timestamp) per generation; generation 0 is (0, L1_0, the initialization transaction's L1 timestamp) and only describes genesis. Each record is written once and never overwritten or deleted. A missing record is rejected; mapping defaults or the latest checkpoint are not substitutes. generationStartHeight and recoverySnapshot read it directly, without caches.
- **Unique genesis**: chain_id uses the new generation, initial_height=c+1, genesis_time=R.timestamp, and InitChain returns app_hash=ELHash(c); EL state must match c's authenticated EL hash and stateRoot. Genesis validators are selected by 4.3 on the R snapshot (record.targetEpoch=floor(c/L), cutoffL1Block=R).
- **First block**: uses stock genesis's empty LastBlockID/LastCommit; c's Comet hash serves only as the proving boundary (6.2 item 2). The FI cursor starts at the authenticated origin head. The first block must carry a finalized anchor witness no earlier than R and does not use c's anchor. Every anchor and L1 root used by the new generation's proofs is no earlier than R (3.4 rule 3).
- **Joining nodes**: replay from the fixed genesis to the latest checkpoint on their own finalized L1 and match both EL and Comet hashes before becoming trusted; the latest checkpoint is never a new genesis for the same domain.

## 9. Sync and weak subjectivity

- **Replay uses the live rules**: during cold sync (replay or blocksync), for a block it did not judge live that carries an anchor witness, FinalizeBlock likewise first checks with its own L1 node that the anchor header is canonical and finalized, and checks the witness's lastCheckpoint per 3.4. An own L1 node that lags, is unreachable or times out only makes it wait and retry. The node halts for safety only on contradictory evidence from its own L1 node.
- **Checkpoint fence**: FinalizeBlock passes the `lastCheckpoint.hash` proven by the anchor to the EL's forkchoice as `finalized`; a history that does not descend from that checkpoint is rejected by the EL (`-38002`), and the node halts for safety. A history forged with old keys can therefore extend at most U blocks beyond its fork point, but that point can be old; forging blocks above the checkpoint needs more than 2/3 of the keys of the committee governing those heights, and that stake cannot be withdrawn until a checkpoint covers its exit.
- **Weak subjectivity is solved by L1**: every app startup and signer session starts untrusted, authenticates the Inbox's latest checkpoint in its own L1 finalized view, and becomes trusted only after reaching that height with an exact match of both the EL hash and the CometBFT hash in the slot 285 record (block 0's record has Comet hash 0; recovery origin c's record keeps the Comet hash from its original generation); after that, every anchor change checks the new lastCheckpoint per 3.4. A forged history either stays below the target and is never trusted, or is rejected at the target, so no weak-subjectivity checkpoint and no age limit on the starting point is needed. Missing data keeps the node untrusted and retrying; an authenticated contradiction, or malformed or unverifiable data from its own L1 node or EL, halts it for safety, because the node cannot tell that apart from forgery. An L1 header whose hash matches the canonical hash is not in this category: its source is authenticated, and a parse failure only means the node needs an upgrade (3.3). A recovery generation's fixed genesis origin may differ from this latest trust target; distinguish them and replay under 8.4 rather than rebuilding same-domain genesis at each newer checkpoint.

<details>
<summary>Sign and serve only when trusted (signing gate and automatic restart details)</summary>

- **Sign and serve only when trusted**: every validator signature (including nil votes and retained blocks) needs the app to confirm that the node is trusted; untrusted state, a timeout or a superseded generation means no signature, with no fallback to local signing. CometBFT v0.40.0 never retries a refused or timed-out signing request, so refusals by at least 1/3 of the voting power at the same step stall that height indefinitely. After a signing request is refused for lack of trust or a timeout, the supervisor must therefore restart CometBFT automatically once trust returns: the signer first completes the new session's trust check and only then connects to CometBFT's `priv_validator_laddr`, and WAL replay then requests a signature for the refused step again. The signer follows the stock rules (refuse a lower height/round/step, return the original signature for the same one) and persists each signature before it is broadcast, so this cannot double-sign. The restart needs no operator and resets no signing state; safety halts (section 8), requests for an old generation and refusals at a 10.1 upgrade boundary do not trigger it. Exchanges, bridges and public RPC must read the app's trust status, not raw CometBFT/EL sync progress or `catching_up`.

</details>

<details>
<summary>Details: node requirements</summary>

- **Node requirements**: the own L1 node must return headers by number back to `L1_0` and serve the `eth_getProof` the trust check needs; a validator also needs historical `eth_getProof` and `debug_getRawHeader`, and a proposer must be able to query historical logs of unconsumed forced-inclusion entries.

</details>

### 9.1 Consensus history and double-sign evidence

- Complete CometBFT recovery and proving require original blocks/envelopes, headers, commits/LastCommit, registry snapshots/entries/witnesses, FI data/logs, relevant L1 headers/proofs, genesis parameters and recovery records. Archives must retain these dependencies; public blobs or an EL snapshot alone are insufficient. Private keys are not historical archive data; signing state follows 8.2.
- File hashes detect corruption but do not authenticate committees. Recovery uses the node's own finalized L1 view to authenticate the current generation's fixed origin, c's EL/Comet hashes and R's registry snapshot, then reselects under 4.3. Subsequent current/pending committees follow authenticated switches. An EL snapshot's app_hash does not authenticate extra committee metadata. Missing material leaves the node untrusted; contradictions halt under section 9.
- Anyone may collect verifiable same-round conflicting votes from different peers and submit directly to L1; Comet evidence inclusion is not required. Evidence retention/submission is independent of the local pool's 100,000-block/48-hour limits and should track confirmExit and withdrawal boundaries. Historical evidence may remain necessary until collateral withdrawal is finalized. Retention does not guarantee observation of every conflicting vote, and different BlockIDs across rounds are not automatically double signing.

## 10. Startup and deployment

The flow below assumes startup from block 0 as the starting point; it will be adjusted once the switch from Unzen to Etna is added.

1. Deploy the Inbox proxy (not yet initialized; only its owner can initialize it), then deploy the registry with that proxy address fixed; validators sign the registration digest (appendix A) with their consensus keys, register and wait for activation and finality.
2. Pick a past `genesisCutoff` and compute committee 0's record hash and the config hash.
3. Install EIP-4788 and EIP-2935 in the L2 genesis; set the base-fee sharing percentage to 100.
4. Compute block 0's hash and stateRoot with the EL.
5. Deploy SignalService and initialize the Inbox (checking the registry under 4.1) with genesis hash/stateRoot, L, genesisCutoff, committee-0/config hashes, forcedInclusionDelay and maxAnchorAge, and save the block-0 checkpoint. Fix a nonzero DAO treasury as protocolFeeRecipient. Initialize recoveryGeneration and recoveryNonce to 0, activeCommitteeSnapshot to genesisCutoff and generation 0's origin under 8.4, with recover callable only by the owner.
6. After L1 finality, read the genesis record and generate CometBFT genesis. Start the EL and ABCI app, then the guarded signer and stock CometBFT with `priv_validator_laddr`; PubKey/Ping allow handshake while trust is closed. The signer owns the existing registered key and anti-double-sign state outside the Comet home/mount. Use the supported supervisor/startup configuration; never reset signing state or enable a local FilePV fallback to bypass readiness. Full nodes use an unregistered identity.

<details>
<summary>Details: deployment constraints</summary>

**Deployment constraints**: L≥3, L+1\<2\^48; cutoff is in the past and no earlier than the first registry checkpoint; forcedInclusionDelay>0 and maxAnchorAge≥1152 s; K≤U≤65,536 with U a multiple of K (target deployment U=3,600, which works for any 1 ≤ K ≤ 6), L1_0\<2\^48, 1≤n_max≤4096, vp_unit≥867,361,738 (4.3) and s_min≥vp_unit; use positive activation/exit delays; deployment, nodes and guests check the same configuration. Appendix A's chain_id is exactly 48 ASCII bytes. Incorrect immutable parameters still require a new Inbox/genesis; because the registry fixes the old Inbox address, the DAO must upgrade it to point at the new Inbox or deploy a new registry. Old signing state is not reset.

</details>

Use U=3,600 and choose L independently (suggested 900), with approximately 4 s blocks and 20 min landing as operating targets. Pin maxBatchBlocks≥K (at least one grid segment). The launch gate (including committee 0's minimum total stake and concentration limits) and all acceptance criteria are in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md); do not claim readiness before they pass, or advertise unmeasured recovery duration as a service commitment.

<details>
<summary>Details: initial CometBFT genesis parameters</summary>

**Initial-deployment CometBFT genesis** (recovery origin, time, validators and app_hash follow 8.4; InitChain checks representable ABCI fields): `chain_id` is built per appendix A from the full L1/L2 chain ids, Inbox proxy address and the Inbox's `recoveryGeneration`; `initial_height` = 1; `genesis_time` = the timestamp of block `L1_0`; the validators are exactly committee 0 (keys and power); `app_state` carries the header of `L1_0`, the Inbox proof and committee 0's witness. Consensus params are fixed: `block.max_bytes` 22,020,096 and `max_gas` −1; evidence limits of 100,000 blocks, 48 h and 1 MiB; secp256k1eth keys only; `APP_VERSION = 1`; vote extensions off; no parameter update authority. Initial state: anchor `L1_0`, forced cursor 0, checkpoint (0, genesis hash). The generator writes an empty parameter-update authority; the typed InitChain request does not expose that field, so InitChain cannot independently compare it. In-place migration from other app/config versions (including a populated registry) is unsupported, and deleting retained state must not be used to bypass version checks.

</details>

### 10.1 Protocol upgrade boundaries

- Protocol upgrades stop production and settle before switching rules, without a zero-downtime promise. Operational restarts that preserve validity rules retain all same-domain signer state. Changes to section 10's deployment-immutable parameters remain a separate new-Inbox/new-genesis migration; this section cannot bypass immutability.
- An upgrade plan must bind the deployment, generation, boundary height H (a grid point, since landings end only at grid points, 6.1; an upgrade that changes K needs H to be a multiple of both the old and the new K, or no origin on the new grid remains), old/new client and EL rules, guest images and verifier acceptance ranges. Authenticate it through the actual DAO/timelock authority and enforce it in both nodes and L1 verification; an off-chain manifest or operator agreement alone is insufficient. This activation mechanism is not fully designed yet and will be added later; registering a new image alone is not a protocol upgrade.
- Before the boundary, coordinate signers to stop above H while retaining all HRS state. Settle through H under the old rules and authenticate its EL/CometBFT checkpoint before activating the new rules at H + 1. The plan must take effect before signing crosses the boundary. If signatures or unsettled blocks already exist above H, do not erase state or move the boundary backward; replan, or use section 8's separate procedures if settlement cannot complete.
- Isolate in-flight jobs by deployment, generation, statement/config/image version and height range; batches do not cross H. Old jobs must validly settle before the switch or be explicitly invalidated, never rewritten into a new version. Retain old rule/image material for historical replay, but L1 settlement above H must no longer accept an image that only checks the old rules. New images must not implicitly change history through H. Define and test the exact on-chain acceptance ranges, switching transaction and failure rollback plan.
- The upgrade activation mechanism will be added later; this section does not establish an available recovery fallback. L1 hard-fork deadlines are separate (section 12, item 10).

## 11. Parameters

Principle: any parameter that could split nodes comes only from L1 (Inbox initialization or the config hash) or is built into the client per chain id; local configuration cannot change consensus.

Values in the table are references only; actual deployment follows L1 initialization/config hash and section 10. assignedPower is computed directly under 4.3, not from node-local configuration.

| Parameter                                                                                                      | Layer                                                           | Constraint                                                                                                                                                                                                                                                                                                                | Reference value                                                                                     |
| -------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| L, genesisCutoff                                                                                               | Inbox initialization                                            | Choose L for rotation and ordinary L+2 history, independently of U; no wall-clock takeover warning                                                                                                                                                                                                                        | Suggested L=900, nominally 60 min at 4 s; deployment-specific genesisCutoff                         |
| `forcedInclusionDelay`, `maxAnchorAge`                                                                         | Inbox initialization                                            | The former above 0; the latter ≥ 1152 s and above the L1 finality delay                                                                                                                                                                                                                                                   | Per deployment                                                                                      |
| `maxBatchBlocks`, forced inclusion fee and doubling threshold, verifier, `protocolFeeRecipient`                | Inbox immutable                                                 | maxBatchBlocks ≥ K, and small enough that its leaf calldata ((maxBatchBlocks/K − 1) × 32 bytes) fits within the per-transaction gas limit; fee and threshold above 0; protocol recipient nonzero and set to the DAO treasury                                                                                              | Per deployment                                                                                      |
| vp_unit, s_min, n_max                                                                                          | config hash                                                     | Direct power under 4.3/10; vp_unit ≥ 867,361,738                                                                                                                                                                                                                                                                          | References: 1e9 base units, 1 TAIKO, 128; pin and validate for deployment                           |
| U                                                                                                              | Config hash                                                     | K ≤ U ≤ 65,536 and a multiple of K, independent of L; circuit breaker for settlement failure, the target deployment selects U=3,600 (about 4 h), subject to validation in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md)                                                                                           | 3,600                                                                                               |
| K (grid interval)                                                                                              | Protocol constant built into the Inbox and both guests          | 1 ≤ K ≤ 6 (six maximum-size blocks fill the six blobs of one transaction, 3.4); any K consecutive worst-case blocks, each including one 7.2 single-transaction build trial, must be provable within one landing's two proofs; constrains U and maxBatchBlocks (6.4, section 10)                                           | Not fixed yet; set from proving capacity measured during acceptance                                 |
| `L2_BLOCK_GAS_LIMIT`, `L2_BLOCK_ZK_GAS_LIMIT`, zk gas metering parameters and multiplier table                 | Built into the client per chain id (with the pinned EL version) | A change needs a coordinated client upgrade; zk gas has an independent limit under 3.1’s shared rules; transaction fees use ordinary EVM gas                                                                                                                                                                              | 45,000,000; `L2_BLOCK_ZK_GAS_LIMIT` and metering parameters/multipliers per pinned EL version (3.1) |
| `minStake`, activation/exit/withdrawal delays, `slashBountyBps`, `slashSink`, `l2ChainId`, Inbox proxy address | Registry immutable                                              | `withdrawalDelay` runs from exitConfirmedAtL1 and is no shorter than the double-sign evidence window (suggested ≥ 7 days, about 50,400 L1 blocks); `slashBountyBps` ≤ 10000 (suggested 1000); `slashSink` nonzero; `l2ChainId` matches the Inbox; Inbox initialization checks that the Inbox proxy address equals its own | Per deployment                                                                                      |
| `forfeitBps`                                                                                                   | Registry immutable                                              | Fixed responsibility-forfeiture rate, 0 < forfeitBps ≤ 10000; all proceeds to slashSink, no extra delay                                                                                                                                                                                                                   | Pin before launch                                                                                   |
| `C_CAP_MIN`, `P_REF`, `S_MIN_TOTAL`                                                                            | Launch manifest, not consensus                                  | Capital target, conservative price with validity/review policy, and derived stake floor under checklist section 4; concrete values required before launch                                                                                                                                                                 | Per deployment                                                                                      |
| `timeout_commit`                                                                                               | CometBFT configuration                                          | Block cadence only                                                                                                                                                                                                                                                                                                        | Set for the \~4 s block-time target                                                                 |

Activation, exit, withdrawal and top-up readiness use L1 block numbers. Authorization deadlines use L1 block.timestamp in Unix seconds. In addition to the double-sign evidence window, evaluate withdrawalDelay against detection, DAO decision/authorization and L1 inclusion time on the fastest lawful withdrawal path; do not assume exitDelay remains available. The suggested seven days is not automatically sufficient. If the standard governance path cannot finish before withdrawal, forfeiture needs timely emergency execution or may be lost. Publish and exercise this response budget; no guaranteed reaction time is implied.

## 12. Known limitations and open items

1. **No wall-clock FI deadline.** `maxAnchorAge` bounds only anchor age relative to block time; wall-clock progress also depends on 3.4's BFT-time assumptions, queue backlog, L1 finality and settlement (7.3).
2. **Offline quorum relies on DAO recovery.** A halted chain does not replace members automatically. Returning members may restore it; otherwise the DAO reselects at R with authorized exclusions (section 8). Newly eligible standby candidates may enter directly, but the DAO still judges online availability and operator concentration; success is not guaranteed, and L1 finality failure, incomplete proofs or missing history can still prevent recovery. Ordinary recovery discards the suffix above c, and its duration includes the DAO authorization delay, finality, reconstruction, signer migration and first settlement. There is no non-governance escape hatch.
3. **Double-sign slashing is same-round only.** Cross-round amnesia is not covered, and gossip can miss evidence; offline responsibility is discretionary DAO forfeiture, not automatic evidence-based slashing (4.4).
4. **Operations depend on DAO funding.** Landing has no protocol revenue; settlement liveness relies on DAO-funded landers and on validators landing to avoid a back-pressure halt. Budgets and real proving/landing costs still need measurement (appendix C).
5. **Dependence on L1 finality.** Production pauses when no finalized anchor satisfies `maxAnchorAge` (3.4).
6. **Empty committee.** With no eligible candidate, an ordinary switch stops; recovery cannot create quorum from nothing, so eligible stake must be replenished first (4.3, section 8).
7. **No rotation power-change limit.** Each term directly selects the top n_max by stake, with no takeover bound or guaranteed DAO reaction window; continuously assess the actual committee's less-than-1/3 Byzantine-power assumption (4.3).
8. **Refunds depend on settlement and the post-confirmation evidence window.** An exit must first be covered by a landed committee, then confirmed, then wait the full withdrawalDelay. If the Inbox cannot recover or must be replaced, unblocking exits still needs a governance upgrade (4.1).
9. **The switch from Unzen is not included yet.** To keep the spec small and easy to discuss, it deliberately leaves out the switch from Unzen to Etna for now; that will be added later, and section 10's startup flow and the starting point used in the text (block 0, committee 0 and the grid origin of 6.1) will be adjusted then. Bridge wiring comes with the switch: L2→L1 messages already work through SignalService checkpoints, but how the existing Bridge, vaults and L2 SignalService connect (including the L2 SignalService reading L1 state from EIP-4788) is not yet specified.
10. **The upgrade activation mechanism is not fully designed yet.** Section 10.1 specifies stopping and settling through H, new rules from H + 1, in-flight job isolation and historical-replay boundaries. Authentication of the plan, exact height-scoped on-chain image acceptance and switch/failure paths are still to be designed and will be added later; this is not an available fallback. L1 hard forks are a separate, external deadline: forks that only append header fields are absorbed by the decoding rule in 3.3, while forks that change existing fields or the state commitment (for example EIP-7864's binary trie, which invalidates every MPT witness) need the client and guest upgrades and the new image registrations done before the fork activates on L1, on L1's schedule rather than at an L2 height.
11. **Registry capacity.** There are 4096 slots in total; filling them locks 4096 × `minStake`, plus L1 transaction costs, and new registrations are blocked while they are full. Registration occupies a slot before activation, and entries that are not selected also retain their slots until exit and withdrawal. Higher-stake newcomers can therefore be excluded without the occupier controlling committee voting power. Competitive or expiring admission remains an open design choice; any reclamation must preserve historical snapshot proofs and the settlement condition on collateral withdrawal.
12. **No automatic gradual-offline handling.** The protocol does not reduce power for low participation, so offline members can keep their stake ranking; removal depends on owner exit, replacement by other eligible stake, DAO responsibility forfeiture with forced exit (4.4), or post-stall governance recovery.
13. **secp256k1eth is new.** The key type was added only in CometBFT v0.40.0, with one later fix to its signature format, so it is less battle-tested than Ed25519; support in external signers and HSM/KMS must be confirmed separately. CometBFT does not batch-verify it. [Etna Acceptance and Launch Checklist](ACCEPTANCE.md) requires pinned versions, cross-implementation vectors, signer/HSM/KMS compatibility and n = 128 measurements; a negligible cost impact must not be assumed before testing.
14. **Registration admission bounds.** The vp_unit lower bound only prevents power overflow (4.3); selection is still limited by the 4096 registry slots, stake ranking and eligibility, so registration does not guarantee selection.
15. **Private consensus-history availability.** Public blobs only reconstruct the settled EL; ordinary proving, Comet replay, signing evidence and L1 ancestry depend on the 9.1 archives, and unauthenticated snapshots are not substitutes.
16. **Overlapping proofs provide short-landing protection, pending acceptance.** Grid rules are in 6.1 and 6.3. A competitor landing first at any grid point in (p,h) cannot make an honest submission fail. Only a competitor settling h or beyond makes it revert as already settled, and then the competitor has advanced settlement on its behalf, which cannot trigger back-pressure; at worst the honest lander pays blob gas and calldata for that transaction. No throughput or recovery guarantee is claimed under more-than-1/3 collusion, unavailable proofs/data or failed L1 finality.
17. **Resource and latency figures await validation.** U=3,600, approximately 4 s blocks, 20 min landings, about 900 unsettled blocks in normal operation and about 3 h of outage margin are illustrative, not measured, and must pass [Etna Acceptance and Launch Checklist](ACCEPTANCE.md). Checking only the latest checkpoint does not remove history retention or fix indefinite L1 finality failure; the unsettled suffix remains governance rollback exposure.
18. **Economic security and discretionary forfeiture.** At least 1/3 of voting power can halt consensus by withholding signatures. Checklist section 4 defines S_MIN_TOTAL from an independent capital target and conservative reference price; concrete deployment values and launch checks remain required. Operation and recovery may continue with publicly disclosed economic-security shortfalls. Forfeiture depends on correct DAO attribution and execution before lawful withdrawal; it does not guarantee loss for every halt, and has no extra waiting or appeal period. Its unexecuted authorizations cannot be revoked through the registry before expiry. Normal-operation forfeiture grants the DAO forced-exit authority and may disrupt later rotations. Top-ups replenish existing entries even when all slots are occupied, but do not admit new operators into a full registry.

## Appendix A: Encodings

**Versions**: APP_VERSION=1, and every versioned domain tag is V1; the outer envelope/payload prefix is 0x06. Config has seven words/224 bytes; CommitteeRecord has five fields. Slot 285 has three words (appendix B). Bind real guest-image/verifier acceptance to the config; until the upgrade mechanism is complete, changing clients or registering an image does not activate new rules.

**Shared vectors**: every encoding, interface, storage layout and boundary condition needs accept/reject vectors shared by nodes, contracts and both guests; the list is in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md).

Protocol hashes are keccak256 over `abi.encode`, with domain tags as right-zero-padded `bytes32` ASCII; the exceptions are the inner nodes of `entriesRoot` (plain concatenation) and the blob hash list and the cut leaf list (`abi.encodePacked`).

```txt
chainDomain = keccak256(abi.encode(bytes32("ETNA_COMET_DOMAIN_V1"),
                uint256(l1ChainId), uint256(l2ChainId), address(inbox), uint48(generation)))
chain_id    = "etna-" + base64url_no_padding(chainDomain)  // raw 32-byte digest -> 43 chars; total 48 ASCII bytes
  // RFC 4648 section 5 alphabet, canonical zero pad bits, no "=" or whitespace; case-sensitive
  // inbox is the EtnaInbox proxy address; generation starts at 0 and never wraps or decreases
extraData  = 0x64 || uint48_be(generation) || uint48_be(anchorNumber)   // 13 bytes

envelope   = 0x06 || rlp([block, anchor, committee, forced])
  block     = [elHeader, [tx, ...]]                    // tx: RLP byte string of its EIP-2718 encoding, legacy included
  anchor    = [] or [[rawL1Header, inboxWitness]]       // rawL1Header: byte string holding the L1 header's raw RLP, decoded per 3.3
  committee = [] or [[record, registryWitness, [entry, ...]]]
  forced    = [] or [[index, entryWitness, tx]]         // tx may be empty; if nonempty its hash must match; required for skips
  // Strict decoding (identical for nodes and guests; any violation makes the proposal invalid): the envelope is exactly 0x06 plus one RLP list, with no trailing bytes;
  // every list has exactly the items above, and anchor/committee/forced are empty or hold exactly one item; integers use minimal big-endian encoding, 0 is the empty string, no leading zeros;
  // fixed-length byte strings (hashes, stateRoots, slots) have exactly their length (slots 32 bytes, addresses 20 bytes); no extra items or unknown fields
  // Field types: hashes, stateRoots and slots are 32-byte strings and addresses 20-byte strings; RegistryEntry.ckX is a 32-byte string (leading zeros kept), ckPrefix and the other numbers are integers;
  // storage values always use minimal integer encoding, including slots that hold hashes; RLP length prefixes must also be minimal; a released slot's entry has all-zero fields;
  // AccountWitness.address must be the expected contract: the Inbox for anchor and forced witnesses, the registry for the committee witness
  // committee-witness account/storage proofs are always verified under this block's anchor stateRoot (new or inherited), i.e. parentBeaconBlockRoot (4.3)

payload    = 0x06 || zlib(rlp([rlp([elHeader, [tx, ...]]), ...]))

AccountWitness  = [address, nonce, balance, storageRoot, codeHash, accountProof, [[slot, value, proof], ...]]
  Prove exactly in order: anchor [268, 270, 271, 281]; forced entry [base,base+1], base=keccak256(abi.encode(i,280));
  registry snapshot [R, cp(i), cp(i) + 1], plus cp(i + 1) if i + 1 < length, where cp(i) = keccak256(R) + 2i
  // accountProof and each storage proof are exactly the ordered MPT path from the root to the leaf (or to the node proving absence), with no extra nodes;
  // value uses minimal big-endian encoding (0 is the empty string) and equals the proven value; the account fields match the account RLP in the proof
CommitteeRecord = [targetEpoch, cutoffL1Block, checkpointIndex, setRoot, totalPower]
RegistryEntry   = [ckPrefix, ckX, effStake, activeFromL1, exitEffectiveL1]
```

```txt
cutLeaf(x)  = keccak256(abi.encode(uint256(x), blockHash(x), cometHash(x), forcedHead(x)))   // 4 words
  // blockHash(x) and cometHash(x) are the bytes32 EL and CometBFT block hashes at L2 height x,
  //   forcedHead(x) is the uint256 FI cursor at x
K           // grid interval: a protocol constant with 1 <= K <= 6 whose value is not fixed yet (section 11);
            //   heights count from the Etna start (block 0); landings end only at multiples of K, so every
            //   checkpoint height, including generation starts, is one
cutHash     = keccak256(abi.encode(bytes32("ETNA_LAND_CUTS_V1"),
                uint256(generation), uint256(p), uint256(h),
                keccak256(abi.encodePacked(cutLeaf(p+K), cutLeaf(p+2K), .., cutLeaf(h-K)))))
  // the inner list has the (h-p)/K - 1 grid-point leaves strictly between p and h, in height order;
  //   it is empty, hashed as keccak256(""), when h = p+K
  // land(input, leaves, proof): leaves = that list; calldata = 32 bytes per leaf
  // execution: require p % K == 0, h % K == 0 and leaves.length == (h-p)/K - 1 (c >= h is rejected as
  //   already settled); if c > p, leaves[(c-p)/K - 1] must equal cutLeaf(c) computed from c's slot 285
  //   record; the FI cursor in that record must equal the current FI head; all of these run before
  //   proof verification

statement = keccak256(abi.encode(
  bytes32("TAIKO_ETNA_LAND_V1"), l1ChainId, l2ChainId, inbox, registry,
  generation, parentHeight, parentHash, parentCometHash, committeeConfigHash,
  lastHeight, lastBlockHash, lastCometHash, lastStateRoot,
  l1ReferenceBlockNumber, l1ReferenceBlockHash, keccak256(abi.encodePacked(blobHashes)),
  forcedInclusionHeadBefore, forcedInclusionHeadAfter, activeCommitteeSnapshot,
  cutHash))  // 21 static ABI words, 672 bytes
  // parentHeight/hash/CometHash and headBefore are taken at proof origin p
```

```txt
committeeConfigHash = keccak256(abi.encode(bytes32("ETNA_PARENT_ANCHOR_V1"), l2ChainId, registry,
  vp_unit, s_min, n_max, U))  // 7 words, 224 bytes

regLeaf(j)  = keccak256(abi.encode("ETNA_REG_ENTRY_V1", j, ckPrefix, ckX, effStake, activeFromL1,
                exitEffectiveL1))
entriesRoot = leaves zero-padded to a power of two, inner nodes keccak256(left || right); one entry gives its leaf, none gives 0

setKey(ck)  = keccak256(abi.encode("ETNA_SET_KEY_V1", l2ChainId, ckPrefix, ckX))
setLeaf(i)  = keccak256(abi.encode("ETNA_SET_LEAF_V1", l2ChainId, k, i, ckPrefix, ckX, effStake, assignedPower))
setNode     = keccak256(abi.encode("ETNA_SET_NODE", l2ChainId, k, left, right))  // an odd last node is promoted unchanged
record      = keccak256(abi.encode("ETNA_COMMITTEE_V1", l2ChainId, targetEpoch, cutoffL1Block,
                checkpointIndex, setRoot, totalPower))
k           = targetEpoch + 1
```

```txt
voteSignBytes = uvarint(len(cv)) || cv                  // same as CometBFT VoteSignBytes
cv = [0x08 varint type]                                 // 1 = prevote, 2 = precommit
  || [0x11 int64_le(height)]                            // 8 bytes little-endian
  || [0x19 int64_le(round)]
  || [0x22 len blockId]                                 // omitted for a nil vote (hash, total, partsHash all zero)
  || 0x2a len timestamp                                 // always written
  || 0x32 len chainId                                   // exact 48-byte chain_id computed above
  blockId   = [0x0a len hash] || 0x12 len psh
  psh       = [0x08 varint total] || [0x12 len partsHash]
  timestamp = [0x08 varint seconds] || [0x10 varint nanos]
  // fields in [ ] are omitted when zero or empty; len is a uvarint length prefix
signer   = ecrecover(keccak256(voteSignBytes), V + 27, R, S)   // 65-byte R‖S‖V, V ∈ {0,1}, S ≤ n/2
// register(bytes publicKey, uint256 amount, bytes popSig)
// publicKey is exactly 33 raw bytes: ckPrefix (0x02/0x03) || uint256_be(ckX).
// Decode internally; reject noncanonical input rather than reducing coordinates.
require len(publicKey) == 33 and publicKey[0] in {0x02,0x03}
ckPrefix = publicKey[0]
p        = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
ckX      = parse_uint256_be(publicKey[1:33]); require ckX < p
a        = (ckX^3 + 7) mod p       // all field operations are exact modular arithmetic
y0       = powmod(a, (p + 1) / 4, p); require 0 <= y0 < p and (y0^2 mod p) == a
ckY      = y0 if (y0 mod 2) == (ckPrefix - 2) else p - y0
// Require ckY < p, the requested parity, a finite curve point, and exact recompression.
// Any modular-exponentiation failure or malformed result rejects; never truncate or wrap.
ckAddr   = keccak256(uint256_be(ckX) || uint256_be(ckY))[12:]
// The 0x04 uncompressed prefix is not hashed. Require nonzero matching PoP recovery.
// Store ckPrefix/ckX only. slashDoubleSign(bondId,voteA,voteB) derives Y from that stored key.

registerDigest  = keccak256(0x1901 || domainSeparator ||
                    keccak256(abi.encode(keccak256("Register(address owner)"), owner)))
domainSeparator = EIP-712 domain: name "EtnaStakingRegistry", version "1", chainId = L1 chain id, verifyingContract = registry
// popSig: exactly 65 bytes R || S || V; V in {0,1}, 0 < R < n, 0 < S <= n/2.
popSigner = ecrecover(registerDigest, V + 27, R, S)
require popSigner != address(0) and popSigner == ckAddr

// Recovery call: recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil,
//                        Exclusion[] exclusions, uint256[] fiToClear)
// Exclusion = (uint256 bondId, bytes32 entryKey), sorted strictly by bondId.
// invalidateRecoveryNonce(uint256 expectedRecoveryNonce): Inbox owner only.
// recoveryNonce is uint256; validUntil is uint256 L1 Unix seconds.
// Registry: topUp(uint256 bondId, uint256 amount); activateTopUp(uint256 bondId).
// Registry: forfeit(uint256 bondId, bytes32 entryKey, bytes32 incidentId, uint256 validUntil).
// forfeit is registry-owner-only, once per lifetime entryKey; no forfeiture nonce or revocation.
// Events: TopUpDeposited(bondId, amount, readyAtL1), TopUpActivated(bondId, amount),
//         Forfeited(bondId, entryKey, incidentId, balanceBefore, penalty),
//         RecoveryNonceInvalidated(oldNonce, newNonce).
// Event identifiers/amounts/nonces are uint256; readyAtL1 is uint48; keys/incidentId are bytes32.
// entryKey = keccak256(abi.encode(ckPrefix, ckX)) identifies the slot's current occupant.
// Only the Inbox owner may call recover; require all three expected values and validUntil (8.3).
```

## Appendix B: L1 storage layout

| `EtnaInbox` slot | Content                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 258              | Initialization status (3 after initialization); not in the anchor witness                                                                                                                                                                                                                                                                                                                                                             |
| 268 / 269        | `recoveryGeneration` / `committeeConfigHash`                                                                                                                                                                                                                                                                                                                                                                                          |
| 270 / 271        | `lastCheckpoint` height / hash                                                                                                                                                                                                                                                                                                                                                                                                        |
| 272 / 273 / 274  | `[genesisHeight, L1_0, L]` / genesis hash / genesis stateRoot                                                                                                                                                                                                                                                                                                                                                                         |
| 278 / 279        | Committee 0 record hash / `genesisCutoff`                                                                                                                                                                                                                                                                                                                                                                                             |
| 280 / 281        | Forced inclusion queue (two words per entry: `txHash`; packed timestamp and L1 block number, with the remaining bits zero and unused. No charge is stored. `txHash` changes only when governance recovery in section 8 overwrites it with `keccak256("")`) / `head`, `tail`                                                                                                                                                           |
| 282              | `forcedInclusionDelay`, `maxAnchorAge` (seconds)                                                                                                                                                                                                                                                                                                                                                                                      |
| 283 / 284        | Reserved: no reads, writes or reuse / activeCommitteeSnapshot (set to genesisCutoff at Inbox initialization)                                                                                                                                                                                                                                                                                                                          |
| 285              | landing mapping, lastHeight → three words: word 1 packs actual parentHeight=c, generation and head; words 2/3 are EL/Comet hashes. Initialize block 0 with parent/generation/head=0, EL hash = genesis hash and Comet hash=0. Retain original recovery-origin records; proof origin p never replaces actual parent. Historical parent links and old-p records serve overlapping proofs and public reconstruction and are never pruned |
| 286 / 287        | Reserved: no reads, writes or reuse                                                                                                                                                                                                                                                                                                                                                                                                   |
| 288              | Reserved: no reads, writes or reuse                                                                                                                                                                                                                                                                                                                                                                                                   |
| 289              | Reserved: no reads, writes or reuse                                                                                                                                                                                                                                                                                                                                                                                                   |
| 290              | Fixed per-generation origin mapping: (startHeight,l1BlockNumber,l1Timestamp), each a uint256 word with height/block/timestamp range checks; store three consecutive words from the mapping base keyed by generation. Includes generation 0 under 8.4, with no latest cache and no ordinary anchor-witness addition                                                                                                                    |
| 291              | Reserved: no reads, writes or reuse                                                                                                                                                                                                                                                                                                                                                                                                   |
| 292              | uint256 recoveryNonce, initially 0; monotonically increased under 8.3, including verifier-failure rollback; not part of ordinary anchor witnesses                                                                                                                                                                                                                                                                                     |

Nodes verify the latest checkpoint under 3.3/3.4, its slot 285 record under section 9, and slot 290 for startup, recovery and proving under 8.4. Reserved slots 283, 286–289 and 291 are neither read nor written. Slot 284 serves exit confirmation; 285 retains the history needed for overlapping proofs and reconstruction.

Inbox stores only the recovery authorization nonce for invalidation, with no recovery queue or scheduling records (8.3). Provide shared vectors for the layout and interfaces; other layouts are neither decoded nor migrated in place.

The registry uses the ERC-7201 namespace `taiko.etna.registry` with base slot R. Nodes read only two things: `checkpoints` at `R` (two words each: packed `l1Block` and `count`, then `entriesRoot`) and `entries` at `R + 1` (three words each: `ckX`, `effStake`, packed `ckPrefix`/`activeFromL1`/`exitEffectiveL1`). exitEffectiveL1 = 2\^48 − 1 means no exit is set.

**Packed words**: where this appendix packs several fields into one word (Inbox slots 272, 281 and 282, the second word of each 280 entry and the first word of 285; the registry's first checkpoint word and third entry word), the fields are laid out in the listed order from the least-significant bit. ckPrefix takes 8 bits and every other field 48 bits; unused high bits are zero. Writing a value wider than its field reverts.

Exit confirmations use a separate ERC-7201 namespace, `taiko.etna.registry.exit-confirmations`, mapping bond id to `exitConfirmedAtL1` (0 means not confirmed). This does not use the entry layout, enter regLeaf/entriesRoot or create a committee checkpoint; clear it on slot release. The owner lives in a separate namespace, `taiko.etna.registry.owners`, indexed by bond id: written at registration and cleared on slot release. It also stays out of entriesRoot, and nodes do not read it. Validate the concrete layout, including slot 290, through layout checks and shared vectors.

Top-ups use ERC-7201 namespace `taiko.etna.registry.top-ups`: a mapping at its base keyed by uint256 bondId, with uint256 pendingTopUp at the mapping element and uint48 topUpReadyAtL1 in the next word (unused bits zero). Clear both on slot release. Lifetime forfeiture flags use namespace `taiko.etna.registry.forfeitures`, a mapping at its base from bytes32 entryKey to bool forfeited (initially false; stored as 0 or 1 and never cleared). Neither namespace enters regLeaf/entriesRoot or is read by nodes/guests; only changes to existing entry fields affect committee checkpoints. Preserve flags through verifier-failure rollback. Validate these namespaces and Inbox slot 292 with shared layout vectors.

## Appendix C: Operating funding and cost assumptions

This appendix states operating requirements, not validity rules.

- **The DAO funds operations**: validators, proving, landing, historical data and on-call service, including low/zero transaction load, FI consumption, repeated DA, discarded competitive work and retries. Landing has no protocol revenue (base fees and tips go to proposers, FI fees to the protocol); this operating budget covers all landing and proving costs.
- **How funding is paid**: funding grants no exclusive landing permission. Landers do not receive FI fees, and funding is not paid per FI entry consumed or by FI fee value, so an attacker cannot recover its FI fees through funding (7.3). land binds no recipient and a public blob transaction can be copied, so DAO compensation must not be a per-landing bounty paid to the submitting address; fund named operators or attribute work off chain.
- **Fund the sustained worst case**: measure and fund the budget for the operating targets of approximately 4 s blocks and at most 20 min between L1 inclusions of successive successful landings (6.4); cost estimates alone are not evidence that funding is in place. A proposer pays no net fee for any load in its own blocks (3.2), whether zk-heavy or data-heavy; such load is bounded only by the per-block gas, zk-gas and 124,000-byte (3.4) limits. Without zk-to-charged-gas conversion, a zk-heavy workload with low EVM gas may use almost the whole per-block zk-gas limit. The data worst case is every block filled with incompressible data. A landing carries at most six blobs, hence six blocks, and must end at a grid point, so each covers m blocks, where m is the largest multiple of K not above 6: about 900/m landings an hour, which is about 150 when K divides 6, about 225 at K = 4 and about 180 at K = 5. Whatever K is, that is 3 blobs per L1 slot. Fund that sustained worst case explicitly in the proving, blob and landing budgets.

[Etna Acceptance and Launch Checklist](ACCEPTANCE.md)
