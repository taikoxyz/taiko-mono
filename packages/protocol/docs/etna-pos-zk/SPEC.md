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
- **Upgrades and trust**: `EtnaInbox`, the registry and the L1 `SignalService` are upgradeable proxies whose owner should be the DAO (behind a timelock); an upgrade can bypass any rule in this spec. Verifier soundness, including the management of SGX instances and RISC0/SP1 images, is a separate assumption. **[MODEL-1-1]** Proof completeness is another: every block that is valid under this spec and within the EL limits (gas, zk gas) and the 3.4 block size bound must be provable by at least one valid proof combination, and **[MODEL-1-2]** any grid segment of K such consecutive blocks (6.1) must be provable together within one landing's two proofs, counting in the worst case one 7.2 single-transaction build trial per block (which can use up to another full block's zk budget). A mismatch between the EL and the guests, or a guest resource limit below the EL limits, violates it; such a transaction forced in through forced inclusion is handled by step 3 of governance recovery (section 8). **[MODEL-1-3]** `land`, `saveForcedInclusion` and the registry are not affected by pause; if both proof systems fail at once, losses can only be contained by pausing `SignalService` and the Bridge and by QuotaManager limits, and settlement is rolled back with the Inbox upgrade that replaces the verifier (section 8).
- **Out of scope**: PoS issuance rewards and bootstrapping CometBFT from L1 alone.
- **Slashing scope**: same-round double signing forfeits all remaining principal (4.1). Going offline or withholding signatures is not automatically slashed; the DAO may attribute responsibility and apply a one-time fixed-rate forfeiture with forced exit under 4.4. A recovery exclusion itself only forces exit (section 8 step 2).
- **DAO forfeiture authority**: the DAO may forfeit during normal operation or recovery, including immediate execution through its emergency path. The registry adds no waiting, freeze or appeal period and does not distinguish governance paths. It checks authority, entry identity, amount and authorization expiry, not the correctness of attribution. Section 1's upgrade trust remains.
- **Not yet designed**: the switch from Unzen to Etna, which will be added later (section 12 item 9).

## 2. Components

| Component                                 | Role                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[COMP-2-1]** Validator                  | Stakes TAIKO in the registry and registers a secp256k1eth consensus key (with a key-holder signature); runs stock CometBFT, the ABCI application, alethia-reth and its own L1 node, plus the external FilePV signer behind the checkpoint-trust gate. The registered signing key and anti-double-sign state stay outside the Comet home/mount; signatures require the app's checkpoint-trust authorization. Proposers earn all fees in their blocks (base fees and tips). |
| **[COMP-2-2]** Full node                  | Runs CometBFT, the ABCI application and alethia-reth with its own L1 view, independently validates every block and applies the same checkpoint-trust gate. It has no registered signing key; an unregistered local identity cannot participate in validator voting.                                                                                                                                                                                                       |
| **[COMP-2-3]** Lander                     | Permissionless: reads decided blocks/commits, builds batches, obtains two proofs and calls land in a blob transaction; earns no protocol reward (appendix C)                                                                                                                                                                                                                                                                                                              |
| **[COMP-2-4]** Prover                     | Produces two proofs per batch (6.2)                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **[COMP-2-5]** EtnaInbox (L1)             | Genesis parameters, land, checkpoints, FI queue/protocol fees and atomic governance recovery                                                                                                                                                                                                                                                                                                                                                                              |
| **[COMP-2-6]** `EtnaStakingRegistry` (L1) | Stake and delayed top-ups, exits, withdrawals, double-sign slashing, DAO responsibility forfeiture and exclusion-list forced exits; one checkpoint for every L1 block that changes an entry                                                                                                                                                                                                                                                                               |
| **[COMP-2-7]** `SignalService` (L1)       | Stores the checkpoints the Inbox writes (height, hash, stateRoot) so the bridge can verify L2→L1 messages                                                                                                                                                                                                                                                                                                                                                                 |

## 3. Consensus and blocks

### 3.1 Consensus engine

- **[CONS-3.1-1]** Stock CometBFT v0.40.0 in its own process, driving the application over an ABCI++ socket. **[CONS-3.1-2]** Proposer selection, timeouts, locking and BlockID all use stock behavior; the engine is not forked.

<details>
<summary>Details: secp256k1eth signing format and chain_id construction</summary>

- **[CONS-3.1-3]** Consensus keys use CometBFT v0.40.0's `secp256k1eth`: sign bytes are hashed with keccak256 (no prefix) and signed; the signature is 65 bytes `R‖S‖V` (`V ∈ {0, 1}`, low-s required); the public key is a 33-byte compressed SEC1 key; and the validator address is the Ethereum address `keccak256(uncompressed key without its first byte)[12:]`. L1 can therefore verify any vote directly with `ecrecover` (double-sign slashing in 4.1). CometBFT does not batch-verify these keys. Every ordinary and recovery-initial committee uses voting power = ⌊effStake / `vp_unit`⌋ under 4.3, and the total is at most CometBFT's cap `(2^63 − 1) / 8`.
- **[CONS-3.1-4]** `chain_id = "etna-" + base64url_no_padding(chainDomain)` is exactly 48 ASCII bytes. `chainDomain` is the full 256-bit keccak256 digest binding the version, complete L1/L2 chain ids, Inbox proxy address and generation (appendix A), without truncation. Nodes, signers, guests and the registry recompute the same value. **[CONS-3.1-5]** Old-generation votes cannot authorize a new generation; another deployment's votes cannot authorize a commit or slashing here. Signing the same height in different domains is not a double sign. Stock CometBFT VoteSignBytes and vote encoding remain unchanged.

</details>

- **[CONS-3.1-6]** The mempool is `nop`: user transactions travel over EL devp2p, and the proposer's EL picks them from its own txpool.
- **[CONS-3.1-7]** CometBFT height equals the EL block number; consensus starts at the block after Etna's starting point (written as block 0 for now). Each CometBFT block's `Data.Txs` holds exactly one item: the envelope (5.1).

<details>
<summary>Details: ABCI response constraints</summary>

- **[CONS-3.1-8]** ABCI responses: `app_hash` is the hash of the executed EL block (InitChain returns the genesis hash for the initial deployment and ELHash(c) for governance recovery under 8.4); every transaction result (ExecTxResult) is fixed at code 0, empty data, and gas_wanted and gas_used of 0, all four of which enter LastResultsHash; **[CONS-3.1-9]** at height 0 Info returns the app version in this generation's genesis consensus params; the header's app version is constant within a generation, and the rules version that applies at each height comes from the upgrade schedule, not from Info; consensus params are never updated. This specification uses `APP_VERSION` 1 (encoding versions in appendix A); checkpoint-trust metadata is node-local and does not enter `app_hash` or block bytes.

</details>

- The block interval is set by `timeout_commit`, an operating parameter rather than a validity rule (target about 4 s, assuming n ≲ 128).
- **[CONS-3.1-10]** CometBFT evidence enters blocks as usual, but the application does not punish based on it: double-sign slashing happens only on L1 (`slashDoubleSign` in 4.1), and anyone can submit two conflicting votes seen in gossip to the registry.

<details>
<summary>Details: driving the EL, zk-gas metering and execution fees</summary>

- **[CONS-3.1-11]** The EL is a pinned alethia-reth version with Etna support: no anchor transaction, building from a given transaction list, the base-fee sharing percentage read from `extraData[0]`, and zk gas recorded in `difficulty`. EIP-4396 parameters are published with that pinned EL version. The application drives it with `engine_forkchoiceUpdatedV3`, `engine_getPayloadV5` and `engine_newPayloadV4`.
- **[CONS-3.1-12]** **zk gas**: adopt the [ZK Gas spec](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/docs/zk_gas_spec.md) ([pinned revision](https://github.com/taikoxyz/taiko-mono/blob/ce31a49063b83845691dd22f536f5433b7824b35/packages/protocol/docs/zk_gas_spec.md)) for metering, transaction intrinsic cost, opcode/precompile multipliers, CALL/CREATE spawn estimates, uint64 overflow handling and whole-transaction discard on overflow/limit exceedance. Its rule that the remaining transactions are skipped after a limit exceedance or overflow is not a consensus rule here: how building continues is under “Execution and fees” below, and validation of committed blocks is 3.4 rule 9. Its `BLOCK_ZK_GAS_LIMIT` corresponds to this spec’s `L2_BLOCK_ZK_GAS_LIMIT`, a block budget independent of EVM gas. Publish the enabled revision, parameters and shared vectors with the pinned EL/guest versions; later main-branch changes do not automatically change consensus. The document’s 100M is a placeholder: pin the deployment value under section 11 and pass the acceptance in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md).
- **[CONS-3.1-13]** **Execution and fees**: while building a candidate transaction list, a transaction exceeding the zk budget or overflowing metering arithmetic is fully discarded under the shared rules, restoring the state at that transaction’s start. Rollback includes nonce, authorizations, value transfers, logs, receipts and fees; discarded and unselected transactions are absent from the final block and pay nothing. Whether building then tries further candidates is proposer build policy, not a consensus rule; the recommended policy skips that transaction and its sender’s later nonces, keeps selecting other transactions, and bounds the total work spent on overflowing trials, first-time and repeated. **[CONS-3.1-14]** This policy applies only to pool candidates; an FI transaction the proposer places at position 0 is executed against the actual pre-block state and is never skipped because of remembered overflows. The given-list singleton build (7.2) has only `[tx]` as a candidate, so its result does not depend on this. **[CONS-3.1-15]** Validation or import never discards a transaction listed in a committed block: if any listed transaction exceeds the zk limit or overflows, the whole block is invalid (3.4 rule 9). The 7.2 skip check still runs the singleton build above, which may discard `tx`. **[CONS-3.1-16]** An ordinary EVM revert/OOG remains an included transaction when it fits the zk budget and is charged normally. Use ordinary EVM gas, refunds, base fees and tips without converting zk gas into charged gas. Block gasUsed is the sum of included transactions’ EVM gasUsed, and EIP-4396 uses that value. **[CONS-3.1-17]** `eth_call`/`eth_estimateGas` use the same rules version with the full block zk budget for standalone simulation; report explicit zk-limit errors rather than a successful empty result after discarding the call.

</details>

### 3.2 Block header

**[CONS-3.2-1]** Every field except `beneficiary` is determined by the committed parent (and its parent's timestamp), the block's anchor, BFT time and chain constants. The proposer builds with these values; other nodes recompute them and compare field by field.

| Field                                    | Value                                                                                                                                                                                                                                                               |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[CONS-3.2-2]** `number` / `parentHash` | height / hash of the committed parent                                                                                                                                                                                                                               |
| **[CONS-3.2-3]** `timestamp`             | max(parent.timestamp + 1, ⌊BFT time⌋, anchor.timestamp)                                                                                                                                                                                                             |
| **[CONS-3.2-4]** `beneficiary`           | any fee recipient the proposer chooses, as in Ethereum; not checked. All of the block's base fees and tips are paid to it at L2 execution, independent of L1 settlement, so a proposer's own transactions in its blocks pay no net fee                              |
| **[CONS-3.2-5]** `extraData`             | 13 bytes `[100 \| generation (uint48) \| anchor block number (uint48)]`; the first byte is the base-fee sharing percentage and is always 100, so all base fees go to the beneficiary                                                                                |
| **[CONS-3.2-6]** `parentBeaconBlockRoot` | the anchor's L1 stateRoot. The EL writes it into the EIP-4788 contract (keyed by the L2 block timestamp), and L2 contracts verify L1 storage proofs against it                                                                                                      |
| **[CONS-3.2-7]** `gasLimit`              | chain constant `L2_BLOCK_GAS_LIMIT`                                                                                                                                                                                                                                 |
| **[CONS-3.2-8]** `baseFeePerGas`         | fixed at 0.025 gwei for block 1; afterwards adjusted by EIP-4396 from the parent's gas usage and block interval (parent minus grandparent timestamp), clamped between the chain's minimum base fee (0.01 gwei for chain id 167000, 0.005 gwei otherwise) and 1 gwei |
| **[CONS-3.2-9]** `mixHash`               | computed from parent.difficulty and height with the Unzen formula                                                                                                                                                                                                   |
| **[CONS-3.2-10]** Other                  | empty withdrawals, zero blob gas, empty requests, empty ommers, zero nonce                                                                                                                                                                                          |

stateRoot, receipts, gasUsed (the sum of included transactions’ EVM gasUsed) and the zk gas in `difficulty` are checked by the EL's `newPayload`. **[CONS-3.2-11]** `difficulty` accumulates only included transactions’ zk gas, including ordinary EVM revert/OOG transactions, not discarded over-limit trials or unselected transactions. **[CONS-3.2-12]** Block-start system processing still follows 3.2 and is not rolled back with an aborted transaction.

### 3.3 Anchor

- **[CONS-3.3-1]** Every block has an anchor: the L1 block whose state it reads. A block either carries an anchor witness (the raw L1 header plus the Inbox account and storage proofs) or inherits its parent's anchor. **[CONS-3.3-2]** The first block of each generation and any block that moves the anchor must carry one; a block that keeps the anchor must not. **[CONS-3.3-3]** The witness proves the Inbox's `recoveryGeneration`, `lastCheckpoint` (height, hash) and the forced inclusion queue's head and tail.
- **[CONS-3.3-4]** The proposer picks max(parent's anchor, local L1 `finalized`). A retained proposal keeps its original anchor. **[CONS-3.3-5]** In ProcessProposal, a validator checks with its own L1 node that the anchor header is canonical and finalized, and checks its age against the candidate block's timestamp (3.4); advancing the local finalized head alone cannot make that proposal expire.

<details>
<summary>Details: decoding L1 headers</summary>

- **[CONS-3.3-6]** **Decoding L1 headers**: `rawL1Header` must be an RLP list of at most 4,096 bytes with at least 12 items. Nodes and guests read only four fields, by position: 0 `parentHash` and 3 `stateRoot` (32 bytes each), and 8 `number` and 11 `timestamp` (integers of at most 8 bytes without leading zeros). Every other item need only be a well-formed RLP item and is not interpreted, so fields an L1 fork appends at the end (for example Glamsterdam's EIP-7928 `block_access_list_hash`) are accepted without an upgrade. **[CONS-3.3-7]** A header's identity is always keccak256(rawL1Header) over the raw bytes; it is never decoded and re-encoded. A node fetches the canonical hash for the anchor block number in `extraData` from its own L1 node and compares it with keccak256(rawL1Header): if they differ, the witness is invalid; if they match but the header cannot be parsed under this rule, L1 has changed the header format and the node needs an upgrade, which is a liveness pause (section 8), not a safety halt. When a node reads any other header from its own L1 node (trust checks, cold sync), it likewise relies only on these four fields and ignores unknown ones.

</details>

### 3.4 Block validity

**[CONS-3.4-1]** ProcessProposal and FinalizeBlock apply the same deterministic rules, in order:

1. **[CONS-3.4-2]** height = parent + 1, and `parentHash` links to the parent.
2. **[CONS-3.4-3]** The presence or absence of an anchor witness follows 3.3, and the witness verifies.
3. **[CONS-3.4-4]** The anchor does not regress: it is at least the parent's anchor and the current generation's L1 origin, the l1BlockNumber of its fixed origin record (8.4): `L1_0` for generation 0 and R after a governance recovery.
4. **[CONS-3.4-5]** Generation: recompute `chain_id` per appendix A from `extraData`'s uint48 generation and this deployment's parameters; it must exactly match the current chain and CometBFT header. Do not parse a generation from the digest string. If the Inbox's generation is larger, this chain has been superseded (section 8); if it is smaller, reject the block.
5. **[CONS-3.4-6]** Back-pressure: height − the `lastCheckpoint.height` proven by the anchor ≤ U, so at most U blocks are unsettled. U is the unsettled-block limit committed directly in the config hash; see 6.4 for its constraints.
6. **[CONS-3.4-7]** Committee witness: required at switch block S(t), forbidden elsewhere; its registry proofs are verified under the stateRoot of S(t)'s own anchor (4.3). Recovery establishes its authenticated starting committee under section 8 without re-emitting an old pending update. If the first recovered block is S(t), normal switch derivation still applies.
7. **[CONS-3.4-8]** The header matches 3.2 field by field; anchor freshness: timestamp − anchor.timestamp ≤ `maxAnchorAge`.
8. **[CONS-3.4-9]** The forced inclusion rules (section 7).
9. **[CONS-3.4-10]** The EL's `newPayload` returns VALID. Discarding transactions for zk-limit exceedance/overflow applies to candidate-list construction only (3.1): the final EL body, envelope and blob payload contain exactly the retained transactions, with matching transaction root, receipts, stateRoot, gasUsed and difficulty. **[CONS-3.4-11]** Validation must execute every transaction listed in a committed block; any listed transaction triggering zk-limit exceedance/overflow invalidates the whole block. Never silently drop or truncate transactions of a Comet-signed block and return VALID.

**[CONS-3.4-12]** Freshness is determined only by the candidate and the committed parent: the application does not reject a proposal merely because the node's finalized L1 head advances, since otherwise a locked block re-proposed unchanged in a later round might never gather more than 2/3 of the voting power. PBTS is not enabled. BFT time's relationship to real time requires Byzantine voting power below 1/3, reasonably synchronized honest clocks and continued consensus progress; a coalition above that threshold can manipulate block time.

The following rules describe proposal admission and liveness:

- **[CONS-3.4-13]** **Block size bound**: the envelope's block item (the payload's executionBlock, including its RLP list header, with every transaction, legacy included, counted as an RLP byte string of its EIP-2718 encoding) is at most 124,000 bytes long. The rule looks only at the uncompressed length, so every implementation gets the same answer; ProcessProposal and FinalizeBlock both check it, and the proposer must respect it while building: alethia's build interface takes a byte limit, measured the same way, that it enforces together with gas when selecting transactions, and always keeps the FI transaction at position 0. The bound guarantees that each block fits in one blob on its own, and a six-blob landing holds six maximum-size blocks, so as long as K ≤ 6, any grid segment (6.1) can always be landed in one transaction. **[CONS-3.4-14]** If more than 2/3 of malicious voting power decides a block that violates this rule, honest nodes halt for safety in FinalizeBlock, and only governance recovery can fix that.

<details>
<summary>Details: where the 124,000-byte bound comes from, and single-blob packing</summary>

The bound leaves headroom within the 130,044 bytes one blob carries: compressing one maximum-size block's payload list with standard zlib at default settings yields at most 124,055 bytes including the 0x06 prefix, even for incompressible data (zlib's deflateBound), so every decided block fits in one blob on its own. Six maximum-size blocks compress to at most 744,244 bytes, within six blobs (780,264 bytes), so a grid segment of up to six blocks always fits in one six-blob landing; no special compression mode is needed.

</details>

- **[CONS-3.4-15]** **No usable anchor, no block**: if no available finalized anchor satisfies the deterministic age bound against the candidate block timestamp, L2 pauses until one is usable. This is not an independent wall-clock timer; its timing inherits the BFT-time assumptions above.
- **[CONS-3.4-16]** **Reject a latest checkpoint conflicting with local history**: when the anchor changes, nodes check the anchor's proven `lastCheckpoint`: its height is at most the parent height, and its hash equals the EL block hash at that height on the authenticated local chain. A mismatch rejects the proposal and raises an alert; the proposer may retain a still-valid parent anchor. Guests verify only the witness's storage proofs; nodes do the comparison with the local chain. This check constrains block ancestry only and does not authenticate other landing metadata (FI head, snapshot, stateRoot and so on); off-chain monitors check that metadata without being claimed to prevent bridge or registry payments.

## 4. Staking and committees

### 4.1 Registry

- **[STAKE-4.1-1]** register(bytes publicKey,amount,popSig): amount ≥ minStake. **[STAKE-4.1-2]** Activation occurs after activationDelay L1 blocks; registry records msg.sender as owner. **[STAKE-4.1-3]** exitEffectiveL1 starts at 2\^48 − 1, meaning no exit is set; requestExit reverts unless its computed effective block is below that value.
  - **[STAKE-4.1-4]** Each key can be registered only once, ever, keyed by `ckAddr` and never released after withdrawal. **[STAKE-4.1-5]** The registry stores only `ckPrefix = publicKey[0]` and the following 32-byte `ckX`, not the publicKey itself; `ckY` is derived internally.

<details>
<summary>Details: public-key format, decompression and PoP checks</summary>

- **[STAKE-4.1-6]** `publicKey` is exactly 33 bytes of canonical SEC1 compressed secp256k1 encoding: `ckPrefix ‖ ckX`, with prefix 0x02 or 0x03 and a 32-byte big-endian X retaining leading zeros. Registration tools may accept the user’s existing hex/Base64 public key and convert it to those 33 raw bytes; users do not supply or split X and Y. **[STAKE-4.1-7]** The contract rejects textual encodings, 64/65-byte uncompressed keys, hybrid encodings and trailing bytes.
- **[STAKE-4.1-8]** The registry decompresses and validates the public key internally under appendix A: require X \< p without reducing X modulo p, a finite valid secp256k1 point, Y parity matching the prefix, and byte-for-byte equality when recompressed. **[STAKE-4.1-9]** Any failure rejects the entire registration without creating an entry or consuming the key identity.
- **[STAKE-4.1-10]** The registry computes `ckAddr = keccak256(ckX ‖ ckY)[12:]` from the two decoded 32-byte coordinates, not by hashing the compressed encoding. **[STAKE-4.1-11]** Require `popSig` to be exactly 65 bytes with `V ∈ {0,1}`, `0 < r < n` and `0 < s ≤ n/2`; recovery over appendix A’s registration digest must return a nonzero address equal to ckAddr. **[STAKE-4.1-12]** The digest still binds the L1 chain id, registry and `msg.sender`. The signature must match this supplied public key, not merely recover some valid address. Copying the transaction cannot change the owner.

</details>

- **[STAKE-4.1-13]** There are 4096 slots in total, and the bond id is the slot. **[STAKE-4.1-14]** After a withdrawal the slot goes to a free list, and new registrations reuse freed slots first.
- **[STAKE-4.1-15]** **Top-ups**: `topUp(bondId, amount)` is owner-only. Require an unreleased entry, current L1 block ≥ activeFromL1, effStake > 0, no exit set, no pending top-up, and amount > 0. **[STAKE-4.1-16]** Transfer the TAIKO into the registry and record `pendingTopUp = amount` and `topUpReadyAtL1 = block.number + activationDelay`, rejecting overflow. Only one top-up may be pending per entry. It uses no new slot and changes neither owner, key nor activeFromL1; **[STAKE-4.1-17]** pending funds are not effStake, do not enter regLeaf/entriesRoot, and provide no voting power or contribution to S_MIN_TOTAL.
- **[STAKE-4.1-18]** **Top-up activation**: anyone may call `activateTopUp(bondId)` once the ready block is reached, provided a top-up is pending and no exit is set. Move all pending funds into effStake, clear the pending amount and ready block, and write the normal checkpoint. **[STAKE-4.1-19]** Maturity alone does not activate funds; activation does not rewrite historical snapshots or already-derived committees.
- **[STAKE-4.1-20]** **Top-up liability**: once exit is set, no new top-up or activation is allowed. Pending funds cannot be withdrawn separately; they leave only through the entry's normal confirmed-exit and withdrawal process. **[STAKE-4.1-21]** All principal in an entry backs its key, including still-admissible double-sign evidence from before the top-up and responsibility forfeiture under 4.4. `balance = effStake + pendingTopUp` below. **[STAKE-4.1-22]** Top-up and activation are allowed before Inbox initialization subject to these same checks.
- **[STAKE-4.1-23]** `requestExit(bondId)`: callable only by the entry's owner. The exit takes effect at max(current block + `exitDelay`, activeFromL1 + `exitDelay`). **[STAKE-4.1-24]** It may be called only for an entry with no exit set; once set, `exitEffectiveL1` only moves earlier (slashing, exclusion list), never later.
- **[STAKE-4.1-25]** **Exit confirmation and withdrawal**: `exitEffectiveL1` determines selection eligibility, not the start of the evidence clock. **[STAKE-4.1-26]** Anyone may call `confirmExit(bondId)`: the entry must have an exit set (requestExit, slashing or exclusion list) and must not be withdrawn, and the Inbox must have `activeCommitteeSnapshot ≥ exitEffectiveL1`. The first successful call records the current L1 block as `exitConfirmedAtL1`. Repeated calls are idempotent and must not postpone the clock.
- **[STAKE-4.1-27]** `withdraw(bondId, to)`: requires a confirmed exit and the current block number ≥ `exitConfirmedAtL1 + withdrawalDelay`. When `balance > 0`, only the owner may call it, and all remaining effStake and pendingTopUp are paid to `to`; when `balance = 0`, anyone may call it to release the slot, with no payment. **[STAKE-4.1-28]** Withdrawal zeros the entry, releases the slot and clears its confirmation, pending amount and top-up ready block, but preserves the lifetime entryKey forfeiture flag (4.4). Confirmation requires that a landed committee no longer includes the stake, so a full evidence window starts only after that; a prolonged halt cannot consume it in advance. **[STAKE-4.1-29]** `activeCommitteeSnapshot` never decreases (the only exception, the section 8 verifier-failure rollback, also re-checks every exit confirmation against the restored snapshot), so withdrawal does not re-check it.
- **[STAKE-4.1-30]** The owner cannot be changed after registration; an operator that may need to change custody should register from a contract (such as a multisig), which then becomes the owner. Consensus keys cannot be rotated in place: to change keys, request an exit, withdraw, and register again with the new key. If a key leaks, the owner should request an exit at once; until the exit completes, the leaked key can still be used to double-sign and get the entry slashed.
- **[STAKE-4.1-31]** `slashDoubleSign(bondId, voteA, voteB)`: callable by anyone. Each vote gives its type, height, round, block id (hash and part set header; all zero for nil), timestamp, uint48 generation and 65-byte signature. The caller cannot choose an Inbox, chain id or deployment tag.

<details>
<summary>Details: double-sign evidence checks and slashing</summary>

- **[STAKE-4.1-32]** Both votes have the same type, prevote (1) or precommit (2), and the same height, round and generation, with different block ids. The generation must not exceed the Inbox's current recoveryGeneration. Valid evidence from historical generations remains admissible after recovery; future generations and other deployments are rejected.
- **[STAKE-4.1-33]** The registry derives `ckY` internally from this bond’s stored `ckPrefix ‖ ckX` using the same canonical decompression rules as registration; callers supply neither coordinates nor a substitute public key. Recompute chainDomain, chain_id and both sign-byte strings per appendix A from this deployment’s full L1/L2 chain ids, the Inbox proxy fixed in the registry and the votes’ shared generation. Both `ecrecover(keccak256(signBytes))` results must be nonzero and equal to the stored key’s `keccak256(ckX ‖ ckY)[12:]`. Vote input cannot override these deployment values.
- **[STAKE-4.1-34]** The entry must not be withdrawn and must have `balance > 0`. On success the whole principal is slashed: effStake, pendingTopUp and the top-up ready block become zero and `exitEffectiveL1` becomes min(its old value, the current block); the caller receives `slashBountyBps` of the slashed amount, and the rest goes to `slashSink`.
- **[STAKE-4.1-35]** Membership in the committee of the time need not be proven: only the key holder can produce the signatures, and since `chain_id` carries the deployment tag and the generation, re-signing a lower height after a redeployment or governance recovery is not a double sign.

</details>

- **[STAKE-4.1-36]** Every L1 block that changes an entry ends with one checkpoint (l1Block, count, entriesRoot). Nodes verify snapshots against historical checkpoints, so slot reuse does not affect derivation.
- **[STAKE-4.1-37]** **Inbox address**: the registry fixes the Inbox proxy address at deployment, and it cannot be changed. Inbox initialization checks that the registry's fixed address equals the Inbox's own address and that the registry's `l2ChainId` matches its own. **[STAKE-4.1-38]** Until the Inbox is initialized (the registry checks the Inbox's initialization state), confirmExit, slashDoubleSign and forfeit fail, so no withdrawal is possible; registration, topUp and activateTopUp are unaffected. **[STAKE-4.1-39]** The Inbox can also set the `exitEffectiveL1` of listed entries earlier, to `recoverySnapshot`, during an exclusion-list recovery (section 8 step 2).

### 4.2 Epochs

- **[STAKE-4.2-1]** L = `epochLenL2`, the number of L2 blocks per epoch, and `L1_0` is the L1 block in which the Inbox was initialized; both are fixed at initialization.
- **[STAKE-4.2-2]** Epoch t starts at block `H(t) = 1 + t·L`; block h belongs to epoch ⌊(h − 1) / L⌋.
- **[STAKE-4.2-3]** Epochs are defined by L2 height alone and are not tied to L1 progress; only `maxAnchorAge` (3.4) bounds how old an anchor may be.

### 4.3 Committee derivation

- **[COMM-4.3-1]** **One selection rule**: committee 0, ordinary rotation and governance recovery all apply the following rule to their authenticated registry snapshot, independently of previous voting powers or participation history.
  1. **[COMM-4.3-2]** Verify the complete entries and root of the latest registry checkpoint at that snapshot.
  2. **[COMM-4.3-3]** An eligible entry satisfies activeFromL1 ≤ snapshot \< exitEffectiveL1 and effStake ≥ max(s_min, vp_unit). **[COMM-4.3-4]** Consensus keys are lifetime-unique; a state in which two eligible entries share a key is invalid, not extra voting power. **[COMM-4.3-5]** Released slots are all zero and ineligible, so they take no part in this check.
  3. **[COMM-4.3-6]** Sort by descending effStake, breaking ties by ascending set key, and take the first n_max entries, or all entries if fewer qualify. A key's set key is a fixed sort value: the keccak256 of the L2 chain id and the key's compressed public key (`ckPrefix ‖ ckX`), with the formula in appendix A. It does not change with slot reuse or registration order, and step 2 makes eligible keys distinct, so the order has no ties. **[COMM-4.3-7]** Each assignedPower = floor(effStake / vp_unit).
  4. **[COMM-4.3-8]** Encode selected members in ascending set-key order; totalPower is the sum of assignedPower. The result must be nonempty, each power positive and representable as u64, and the sum at most MAX = floor((2\^63 − 1) / 8). Otherwise reject the derivation; do not truncate integers or apply node-selected scaling.

<details>
<summary>Details: why power cannot overflow</summary>

- **Power cannot overflow**: TAIKO has a fixed total supply of 10\^27 base units, and deployment requires vp_unit ≥ ⌈10\^27 / MAX⌉ = 867,361,738, so the power of all entries together never exceeds MAX and registration cannot trigger an overflow; the check in step 4 is only a backstop. If TAIKO supply ever increases, choose vp_unit for the new supply and deploy a new configuration first.

</details>

- **[COMM-4.3-9]** **Committee 0**: snapshot = genesisCutoff and targetEpoch=0. Inbox stores its record hash, using the same selection and power rule.

<details>
<summary>Ordinary rotation: snapshot, proof root and H+2 activation (details)</summary>

- **[COMM-4.3-10]** **Ordinary rotation**: S(t)=H(t)−2 and D(t)=H(t)−3. **[COMM-4.3-11]** The snapshot is max(the committed anchor number of D(t), l1BlockNumber in the current generation's fixed origin record); the candidate block's new anchor does not select the committee. **[COMM-4.3-12]** Always verify the registry account/storage proofs under the stateRoot of S(t)'s own anchor, newly carried or inherited, i.e. the parentBeaconBlockRoot in S(t)'s header; that root is never earlier than the snapshot. The proof must show the latest registry checkpoint at the selected snapshot. Do not use D(t)'s or any other anchor's root, or the proof bytes would not be unique. Normally the snapshot is D(t)'s anchor; after recovery D(t) may belong to the old generation, so max prevents regression behind the recovery snapshot. **[COMM-4.3-13]** FinalizeBlock at S(t) returns updates effective at H(t), following CometBFT's H+2 rule; S(t) and S(t)+1 remain signed by the original active committee. Record.targetEpoch=t.

</details>

- **[COMM-4.3-14]** **Governance recovery**: apply the same rule at the authenticated execution block R in section 8, including all candidates eligible there. **[COMM-4.3-15]** Set targetEpoch=floor(c/L), effective immediately at c+1. Discard every pending update from the old generation; the initial set depends only on R's snapshot, not on any earlier committee's members or power. The next S(t) actually occurring in the new generation performs ordinary rotation; this also applies if the recovery's first block is S(t).
- **[COMM-4.3-16]** **Guarantees and limits**: authenticated L1 state uniquely determines membership and power. There is no per-rotation power-change limit, automatic offline eviction, or wall-clock takeover warning. **[COMM-4.3-17]** `activationDelay` delays new registrations and top-up increments; already active stake and standby candidates need not wait again. Only activated increments included in the selection snapshot affect power. Each actual committee remains subject to section 1's voting-power assumptions; the DAO monitors availability and concentration.

### 4.4 DAO responsibility forfeiture

- **[FORF-4.4-1]** **Authority and identity**: `forfeit(bondId, entryKey, incidentId, validUntil)` is callable only by the registry owner, the DAO's actual execution address (the Controller where used), and only after Inbox initialization. **[FORF-4.4-2]** entryKey is `keccak256(abi.encode(ckPrefix, ckX))` as in appendix A. **[FORF-4.4-3]** The DAO authorization binds the deployment, full call parameters and published attribution. incidentId identifies that attribution; the same incident may name multiple entries. The registry keeps no incident case or global incident-id deduplication state.
- **[FORF-4.4-4]** **Execution checks**: the bond must be unreleased and still match entryKey, `forfeited[entryKey]` must be false, `block.timestamp <= validUntil`, and `balance = effStake + pendingTopUp` must be positive. **[FORF-4.4-5]** Requested or confirmed exits remain punishable until withdrawal; current committee membership is not required. **[FORF-4.4-6]** validUntil is an absolute L1 Unix timestamp in seconds fixed in the authorization.
- **[FORF-4.4-7]** **Immediate, fixed-rate deduction**: compute `penalty = ceil(balance * forfeitBps / 10000)` from the remaining principal at execution. The deployment fixes `0 < forfeitBps <= 10000`. **[FORF-4.4-8]** Deduct from effStake first and then pendingTopUp; clear the ready block if pending reaches zero. **[FORF-4.4-9]** Send the full penalty to slashSink, with no bounty. **[FORF-4.4-10]** Pending funds and deposits made after authorization but before execution are included: all funds in the entry back its key, without historical-balance accounting.
- **[FORF-4.4-11]** **Once per entry, with exit**: in the same transaction set `forfeited[entryKey] = true` and `exitEffectiveL1 = min(existing, block.number)`, writing the normal checkpoint for changed entry fields. **[FORF-4.4-12]** The flag starts false and is never reset by withdrawal, slot reuse, recovery or verifier-failure rollback. **[FORF-4.4-13]** Changes affect subsequent selection snapshots that include them, not historical snapshots or already-derived committees. **[FORF-4.4-14]** Remaining principal follows normal withdrawal rules; an existing exit confirmation is not reset or delayed. **[FORF-4.4-15]** Valid double-sign evidence may still take all remaining principal; if double signing emptied the entry first, forfeit fails on zero balance without blocking normal slot release.
- **[FORF-4.4-16]** **Authorization expiry and replay**: there is no forfeiture nonce, revocation entry point, queue, hold or extra execution delay. Successful execution immediately completes the forfeiture; the lifetime flag prevents repetition and entryKey prevents targeting a reused slot. **[FORF-4.4-17]** An unexecuted authorization remains executable until validUntil if all checks pass, even if the DAO changes its decision; this interface cannot cancel it. Expired calls revert without cleanup. **[FORF-4.4-18]** Landing, a generation change and recover do not invalidate the authorization.
- **[FORF-4.4-19]** **Atomicity and operations**: update balances, exit and the lifetime flag before transferring funds; reject cross-function reentrancy, and revert all effects on any failure. Emit bondId, entryKey, incidentId, pre-deduction balance and penalty. **[FORF-4.4-20]** Execute before lawful withdrawal; this mechanism cannot recover withdrawn funds. Before execution the DAO assesses replacement availability, online quorum and concentration, since normal-operation forced exits may stall a later rotation. This version has a single-entry API. Execute entries independently when failures must not affect each other; do not couple forfeiture to a potentially stale recover in an all-or-nothing governance batch.

## 5. Data formats and DA

### 5.1 Envelope (private)

**[DATA-5.1-1]** The single tx in each CometBFT block: `0x06 || rlp([block, anchor, committee, forced])` (the last three are each an empty list or exactly one item), **[DATA-5.1-2]** committed to by the CometBFT header's `data_hash` (encoding in appendix A). **[DATA-5.1-3]** It propagates only within the consensus network and never goes to L1.

### 5.2 Blob payload (public)

- **[DATA-5.2-1]** Each batch uses 1–6 blobs (EIP-7594's per-transaction limit) **[DATA-5.2-2]** with Unzen's blob encoding: each blob decodes to at most 130,044 bytes, every non-final blob is full, and all padding bits are 0.
- **[DATA-5.2-3]** Content: `0x06 || zlib(rlp([executionBlock, …]))`, where `executionBlock` is `rlp([EL header, ordered EIP-2718 transactions])`. **[DATA-5.2-4]** Each transaction, legacy included, is an RLP byte string holding its EIP-2718 encoding.

<details>
<summary>Details: blob payload acceptance rules</summary>

- The acceptance rules use fixed limits that operator settings cannot change:
  - **[DATA-5.2-5]** Exactly one complete zlib stream, with no preset dictionary and no trailing bytes; at most 64 MiB decompressed, and each item at most 22,020,096 bytes.
  - **[DATA-5.2-6]** All encodings are canonical and re-encode byte for byte.
  - **[DATA-5.2-7]** Exactly `lastHeight − parentHeight` blocks at heights `parentHeight + 1 … lastHeight`; EL `parentHash` links block by block, the first block's parent equals `parentHash`, and the last block's hash and stateRoot equal `lastBlockHash` and `lastStateRoot`.

</details>

- **[DATA-5.2-8]** Not published: CometBFT headers, original envelopes, anchor/committee/forced witnesses, registry entries, the raw forced transaction of a skip, evidence, commits and signatures. They are private proof inputs: the guest authenticates each original envelope against `data_hash`, then proves that its execution part equals the blob byte for byte.
- **[DATA-5.2-9]** **Recovery from DA**: with a sound proof and a finalized L1 checkpoint, archived blobs plus the starting state suffice to rebuild the landed EL chain and check the last block's hash and stateRoot, without witnesses or signatures. This is not the same as bootstrapping CometBFT from L1 alone; unlanded blocks still need the full consensus history.

### 5.3 Public EL state reconstruction

**[DATA-5.3-1]** Public reconstruction depends only on the starting state, canonical L1 transactions/events/headers and corresponding blobs, not validator-private databases, complete envelopes, witnesses, signatures or a running L2 RPC. **[DATA-5.3-2]** A source-available reconstruction program and these public inputs are required:

- **[DATA-5.3-3]** Starting material includes downloadable complete genesis allocation/state and code, content hashes, EL rule version, L1/L2 chain ids, contract addresses, L1_0, genesis hash and stateRoot. **[DATA-5.3-4]** The program recomputes and matches the L1-authenticated starting point rather than trusting an unchecked snapshot.
- **[DATA-5.3-5]** In canonical L1 landing order, verify versioned hashes and complete (p,h\] blobs. Read p from proof input and actual c from authenticated events/records. **[DATA-5.3-6]** Check reconstructed EL hashes and links for the overlapping prefix; execute only (c,h\] from authenticated c's EL state and check h's hash/stateRoot and FI cursor. **[DATA-5.3-7]** Select history using authenticated generations and fixed recovery origins. **[DATA-5.3-8]** Reject missing original material, unsupported versions or hash mismatches; do not execute the prefix twice, silently skip it or replace authentication with RPC state.
- **[DATA-5.3-9]** Historical blobs must remain retrievable and archive contents must be authenticated against L1 commitments. Private history for complete CometBFT/proving is separate (9.1) and is not an input to EL-only reconstruction.

## 6. Landing and settlement

### 6.1 land

**[LAND-6.1-1]** land is permissionless and nonpayable. **[LAND-6.1-2]** Proofs and blobs cover all of (p,h\], from proof origin p to terminal height h; **[LAND-6.1-3]** c, the latest checkpoint height, is read atomically at execution and only the new suffix (c,h\] is settled, **[LAND-6.1-4]** so another lander advancing c first does not invalidate the same transaction. **[LAND-6.1-5]** Landings end only at grid points: heights, counted from the Etna start (block 0), that are multiples of K, so p, c and h are always grid points (6.3 explains why; section 11 covers the value of K). **[LAND-6.1-6]** The checks are, in order: range, grid and origin record; **[LAND-6.1-7]** the leaves are exactly those of the grid points in (p,h) and **[LAND-6.1-8]** the leaf at c matches the current checkpoint record; FI head advance; reference block and blobs; computing cutHash and verifying both proofs. **[LAND-6.1-9]** Once all pass, land atomically updates the checkpoint, snapshot, FI head, slot 285 record and SignalService.

**[LAND-6.1-10]** The reference Solidity in the toggle below lists every check land performs; the checks are normative. **[LAND-6.1-11]** All checks precede any state change and **[LAND-6.1-12]** the leaf checks precede proof verification; the remaining order is illustrative. **[LAND-6.1-13]** The land signature, LandInput's eight fields, K and the cutLeaf and cutHash encodings (appendix A) are the interface. Local names and helper bodies are illustrative: helper results are defined in appendix A and the comments, and storage variables map to the normative layout in appendix B.

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

- **[PROOF-6.2-1]** The verifier is an Inbox immutable. **[PROOF-6.2-2]** The contract only calls its `verifyProof` interface and does not check the implementation; **[PROOF-6.2-3]** production deployments must use the same `ZkRequiredVerifier` as mainnet (Unzen): **[PROOF-6.2-4]** exactly two sub-proofs, at least one of them ZK (SGX + RISC0/SP1, or RISC0 + SP1), which needs two guests. **[PROOF-6.2-5]** The verifier address, code hash and accepted image set are pinned in the deployment manifest and checked as a launch gate in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md). **[PROOF-6.2-6]** If one backend fails, another combination can be used; if no valid combination can be assembled, settlement stops.
- **[PROOF-6.2-7]** Withdrawals use the checkpoint that `land` writes into SignalService directly, with no extra withdrawal root, delay or veto.
- **[PROOF-6.2-8]** Here parentHeight/parentHash and headBefore are taken at proof origin p. **[PROOF-6.2-9]** Each subproof authenticates the same statement, including cutHash; execution and cut authentication cannot be split between backends. **[PROOF-6.2-10]** The proof stays valid even if p is not the latest checkpoint at execution; 6.1 atomically selects actual c.

<details>
<summary>What the guest must prove (10 items)</summary>

- The guest must prove:
  1. **[PROOF-6.2-11]** Inbox and registry storage holds under authenticated L1 roots; `committeeConfigHash` opens per appendix A; the genesis schedule is authenticated.
  2. **[PROOF-6.2-12]** Derive signing and pending committees using 4.3's unified rule, authenticating snapshot, entries, power, record and H+2 activation. **[PROOF-6.2-13]** The ordinary path follows authenticated EL parentHash to the required D(t), requiring at most L+2 historical headers. **[PROOF-6.2-14]** Every proof authenticates the current generation's fixed origin record (3.4 rule 3 uses its l1BlockNumber); recovery also authenticates retained checkpoint c and the R registry snapshot and directly selects the initial set. **[PROOF-6.2-15]** Current-generation Comet headers link by last_block_id: the first non-genesis header binds parentCometHash and the terminal one binds lastCometHash. A generation's first header has empty last_block_id; parentCometHash then authenticates only the old origin c header (0 when c=0). **[PROOF-6.2-16]** Every block's commit signatures and schedule are verified. L+2 excludes the separate L1-ancestry and recovery-material budget.
  3. **[PROOF-6.2-17]** Each block's commit carries more than 2/3 of the voting power from distinct signers of its actual active committee, secp256k1eth (keccak256 then `ecrecover`, low-s), under this generation's `chain_id`; **[PROOF-6.2-18]** each block's `validators_hash` and `next_validators_hash` match the authenticated activation schedule, including the ordinary S(t), S(t)+1 and H(t) handover and recovery and subsequent normal handovers under section 8. **[PROOF-6.2-19]** A numeric epoch alone cannot authorize a committee.
  4. **[PROOF-6.2-20]** Original envelopes match `data_hash` and their witnesses satisfy the rules of sections 3 and 7; **[PROOF-6.2-21]** execution runs from `parentHash` to the last block's hash and stateRoot; the execution part equals the blob payload byte for byte. **[PROOF-6.2-22]** Nodes, the EL and both guests use the same pinned zk-gas rules/parameters and validate the entire committed transaction list under 3.4; **[PROOF-6.2-23]** do not normalize an over-limit payload into a shorter prefix and prove that instead.
  5. **[PROOF-6.2-24]** Forced inclusion entries `[headBefore, headAfter)` are consumed exactly and in order (section 7); **[PROOF-6.2-25]** eligibility of the raw bytes follows 7.2 and the same vectors; **[PROOF-6.2-26]** skipping an eligible transaction reproduces, on the parent, the same singleton build result as alethia, namely an empty block. **[PROOF-6.2-27]** This includes an empty singleton result caused by the zk limit under 7.2’s full block budgets; **[PROOF-6.2-28]** its discarded trial work is still part of the proof computation even though it contributes no final difficulty or fees.
  6. **[PROOF-6.2-29]** Each block has extraData\[0\]=100.
  7. **[PROOF-6.2-30]** activeCommitteeSnapshot is the authenticated selection snapshot of the committee actually governing lastHeight: genesisCutoff for committee 0, that generation's R for its recovery initial committee, and 4.3's snapshot for ordinary rotations. **[PROOF-6.2-31]** Pending committees, the terminal anchor and reference block are not substitutes. **[PROOF-6.2-32]** Old pending updates never activate after recovery; report R until an ordinary update in the new generation actually takes effect.
  8. **[PROOF-6.2-33]** The anchor of every block in (p,h\] and every other L1 root used in the proof lie on the L1 header chain ending at the reference block. **[PROOF-6.2-34]** Each header is decoded per 3.3, and links compare keccak256 of the raw bytes with the next header's `parentHash`.
  9. The blob payload is bound to `blobHashes`:
     - **[PROOF-6.2-35]** For each i, all 4096 field elements of blob i are canonical (less than the BLS12-381 scalar field modulus), and there is a KZG commitment C with `blobHashes[i] = 0x01 ‖ sha256(C)[1:]` that commits to exactly that blob. **[PROOF-6.2-36]** The guest may recompute C from the blob, or use a proof of equivalence: derive the challenge point by hashing the blob together with C, evaluate the blob at that point itself, and verify the KZG opening of C at that point.
     - **[PROOF-6.2-37]** The blob payload is the bytes decoded from these blobs in index order with the encoding in 5.2, and it satisfies every acceptance rule in 5.2; "the blob payload" in item 4 means this payload.
     - **[PROOF-6.2-38]** The statement's `keccak256(abi.encodePacked(blobHashes))` is computed from the same list.
  10. **[PROOF-6.2-39]** The cuts cover p through h continuously without duplicates or omissions. **[PROOF-6.2-40]** The first EL/Comet hashes and FI cursor match the authenticated origin; **[PROOF-6.2-41]** every later cut comes from the corresponding real header and execution/consumption results, with the FI cursor advancing by 0 or 1 per block under section 7. **[PROOF-6.2-42]** The last cut's two hashes and FI cursor equal lastBlockHash, lastCometHash and forcedInclusionHeadAfter. **[PROOF-6.2-43]** p and h are grid points; compute cutHash over the cuts at every grid point in (p,h) using appendix A's unique encoding; **[PROOF-6.2-44]** cuts not authenticated by execution must not be accepted. **[PROOF-6.2-45]** Every block in (p,h\] satisfies anchor, commit, committee, FI and EL rules, including time and ancestry verification of the anchor it uses (newly carried or inherited); **[PROOF-6.2-46]** origin p is authenticated by its slot 285 record and is not verified on its own. **[PROOF-6.2-47]** Only when p+1 inherits p's anchor does the guest take that anchor's raw header and Inbox proofs as input and verify them against p+1's extraData and parentBeaconBlockRoot.

</details>

### 6.3 Batches

- **[BATCH-6.3-1]** A batch is cut only at grid points (6.1) and may cross epochs. **[BATCH-6.3-2]** Handover heights, cancelled old activation heights and the next normal handover are unrelated to the grid and may fall inside a batch or exactly on a grid point; a recovery start is a checkpoint and so always a grid point. **[BATCH-6.3-3]** All of these use the actual schedule rather than avoiding a problematic cut. **[BATCH-6.3-4]** `l1ReferenceBlockNumber` can be any recent L1 block, avoiding expiry of the reference hash alone. When the old unsettled suffix above c is proven after a long outage without governance recovery, **[BATCH-6.3-5]** the old anchors those blocks used must still be authenticated within the supported ancestry/proving budget, and choosing a recent reference does not remove that requirement. **[BATCH-6.3-6]** Landers and provers need a resource bound on the reference-header chain (reference value 131,072 headers, about 18 days of L1 blocks at 12 s); **[BATCH-6.3-7]** a suffix beyond it cannot be landed the ordinary way and can only be discarded by governance recovery under section 8 (at most U blocks), restarting from R; the outage before R does not count toward this bound (8.4).
- **[BATCH-6.3-8]** Prove from an authenticated, retained historical checkpoint p, normally the latest when work begins. **[BATCH-6.3-9]** It cannot precede this generation's starting point, and the proof cannot span generations. **[BATCH-6.3-10]** If another lander advances to c, the original transaction (two proofs, blobs and leaves) stays valid unchanged whenever p ≤ c \< h: execution settles (c, h\] with no reproving, reaggregation or parameter change. **[BATCH-6.3-11]** If c ≥ h, the target is already settled and work can be cancelled. **[BATCH-6.3-12]** Reference expiry, rule/image changes or a generation transition can still invalidate a job; **[BATCH-6.3-13]** signed jobs must not be rewritten to bypass those boundaries. **[BATCH-6.3-14]** Copying a transaction cannot change any proven content; landing carries no reward, so who submits it does not affect settlement.

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

**[BACKP-6.4-1]** L2 height cannot exceed the anchor-proven lastCheckpoint.height + U, **[BACKP-6.4-2]** where U is an integer parameter committed directly in the config hash, with `K ≤ U ≤ 65,536` and U a multiple of K, so the pause point is a grid point. **[BACKP-6.4-3]** U is a circuit breaker for settlement failure, not the pace of normal settlement: it should pause L2 only when proving or landing stalls for a long time or a decided block cannot be proven, capping the blocks governance recovery may discard. **[BACKP-6.4-4]** The target deployment uses **U = 3,600** (about 4 h at 4 s blocks); **[BACKP-6.4-5]** approximately 4 s blocks and no more than 20 min between L1 inclusions of successive successful landings are operating targets, not block-validity rules. **[BACKP-6.4-6]** U and the epoch length L do not constrain each other: the unsettled suffix may span several epochs, and L is chosen separately for committee rotation (section 11). **[BACKP-6.4-7]** A landing stall permits at most U further blocks. **[BACKP-6.4-8]** L1 inclusion alone does not release the pause: the landing state must finalize and be adopted by a new anchor.

<details>
<summary>Details: latency budget and unsettled-block arithmetic</summary>

An approximately 4 s block interval is an operating target, not a minimum interval or uninterrupted-production guarantee. L counts blocks; nominal epoch duration is L × target block interval, while actual duration can be shorter or longer. End-to-end settlement includes batching, queues/proving, retries, L1 inclusion/finality and anchor adoption. Assess back-pressure from actual `height − anchor.lastCheckpoint.height`, not average-interval conversion alone. U=3,600 corresponds to 4 h at a sustained 4 s block interval, not a wall-clock outage guarantee. In normal operation the unsettled count is about “the interval between landing inclusions + the previous batch's terminal-block-to-inclusion latency + the next landing's finality and anchor-adoption latency”, counting the actual critical path of the two proofs; at 20 + 20 + 20 min that is about 900 blocks, leaving about 3 h for a proving or landing outage. This latency budget is an operating target: missing it shrinks the margin but does not pause L2. Sustained 4 s production is about 15 blocks/min; settlement throughput must keep pace without a growing unsettled backlog. At one batch every 20 min, each must cover about 300 blocks on average. If maxBatchBlocks, six-blob capacity or proving capacity cannot support that batch, settle more frequently or provide the missing capacity rather than merely delaying a halt with a larger U; after an outage, proving capacity must exceed the block rate to clear the backlog. The 20 min finality/adoption component neither bounds L1 finality nor relaxes maxAnchorAge. Exceeding the allowance causes a normal pause, never a bypass of U; this arithmetic establishes neither a measured pause fraction nor a no-pause SLA.

</details>

For uninterrupted operation, U should exceed the number of blocks produced during one landing round trip. Landers should continuously prepare and submit batches from the latest checkpoint, submitting early based on actual unsettled blocks and remaining proving/finality time. The 20 min target is not a mandatory batching wait and grants no exclusive landing right. “One producible height left” is an emergency signal, not the point to start proving. The target remains 4 s; a result obtained by temporarily slowing production does not establish that target.

**[BACKP-6.4-9]** U is fixed at deployment and cannot be overridden by local node configuration. **[BACKP-6.4-10]** An anchor is a finalized L1 block, and checkpoints only advance, so anchor-based accounting never undercounts unsettled blocks; **[BACKP-6.4-11]** the sole exception is the section 8 verifier-failure rollback, whose accounting rules ship with that upgrade. **[BACKP-6.4-12]** L1 finality lag only brings the pause forward and cannot authorize exceeding U. **[BACKP-6.4-13]** Raising U raises the maximum number of blocks governance recovery under section 8 may discard; before recovery, blocks are settled up to the last provable grid point (8.1), so only blocks that truly cannot be settled are discarded, plus at most K − 1 provable blocks short of a full grid segment. **[BACKP-6.4-14]** Publish the selected L and its nominal epoch duration L × 4 s (60 min at the suggested L = 900), without treating it as a wall-clock guarantee.

**[BACKP-6.4-15]** **Acceptance**: before using the target configuration, pass the resource and latency acceptance in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md); until then, do not claim deployment readiness or target attainment. **[BACKP-6.4-16]** Do not omit latest-checkpoint checks, use non-finalized anchors, remove a proof, locally loosen U or silently expand resource limits.

## 7. Forced inclusion

### 7.1 Submission

**[FI-7.1-1]** `saveForcedInclusion(bytes tx)`: at most 8,192 bytes, with a fee of `fee × (threshold + pending) / threshold` gwei, where pending is the number of entries on L1 not yet consumed by a landing (`tail − head`; while settlement lags this includes entries already consumed on L2 but not yet landed); overpayment is refunded. **[FI-7.1-2]** Each entry stores only `keccak256(tx)`, the L1 timestamp and the L1 block number. **[FI-7.1-3]** The enqueue event records the entry index, raw transaction bytes and actual fee charged in wei, excluding refunded overpayment; encoding is not checked at submission. **[FI-7.1-4]** On successful enqueue, the fee calculated and collected using the formula becomes protocol revenue and stays in the Inbox. **[FI-7.1-5]** The fee buys queue admission, not successful execution: inclusion, valid skipping, governance blanking and replay after a settlement rollback neither refund it, charge it again nor pay it to a lander. **[FI-7.1-6]** Historical per-entry charges are recorded only in enqueue events, not used as consumption or recovery inputs. **[FI-7.1-7]** If the submission transaction reverts, neither enqueueing nor charging takes effect.

<details>
<summary>Details: sweeping protocol fees</summary>

**[FI-7.1-8]** **Sweeping protocol fees**: deployment fixes a nonzero DAO treasury address, `protocolFeeRecipient` (an Inbox immutable), and publishes it in the deployment manifest. **[FI-7.1-9]** Only `saveForcedInclusion` accepts ETH (overpayment is refunded in the same transaction) and every other Inbox entry point rejects ETH, so, apart from force-sent ETH, the Inbox balance is the FI fees not yet swept. **[FI-7.1-10]** Anyone may call `sweepProtocolFees()` to transfer the Inbox's entire ETH balance to that address; a failed transfer reverts. **[FI-7.1-11]** Force-sent ETH is swept with it. **[FI-7.1-12]** Neither `saveForcedInclusion` nor `land` transfers funds to the treasury, so a treasury receipt failure affects only the sweep. **[FI-7.1-13]** Sweeping does not depend on the queue head or landing and does not modify FI entries or queue progress.

</details>

### 7.2 Consumption rules

- **[FI-7.2-1]** L2 state keeps a cursor c (the number of entries consumed, initially 0). Each block consumes at most one entry, and only entry c. After a landing, the Inbox's head equals c at the checkpoint.
- **[FI-7.2-2]** Each block uses its own anchor A: if `c ≥ tail(A)`, it carries no forced witness; otherwise it must carry entry c's witness, a storage proof under A's stateRoot.
- **[FI-7.2-3]** **Due**: `A.timestamp ≥ entry.timestamp + forcedInclusionDelay`, evaluated without overflow. Entries never expire.

<details>
<summary>Eligible transaction: exactly one canonical EIP-2718 transaction (detailed rules)</summary>

- **[FI-7.2-4]** **Eligible transaction**: the raw bytes are exactly one canonical EIP-2718 transaction. Canonicity depends only on the raw bytes, never on state, and nodes and guests implement it against the same shared accept/reject vectors rather than any library's decoder: decoding consumes all input and re-encoding reproduces the bytes; the type is a non-blob type accepted by the pinned EL version (type 3 and unknown types are ineligible); a typed transaction's chain_id equals the L2 chain id and its y_parity is 0 or 1, and a legacy transaction's v is 27, 28, 2·l2ChainId + 35 or 2·l2ChainId + 36; nonce and gas are below 2\^64, each fee field is below 2\^128, and value is below 2\^256; the signature's r and s lie in \[1, n − 1\] (n is the secp256k1 order) with s ≤ n/2 and recover a sender; and gas is at most `L2_BLOCK_GAS_LIMIT`. These checks cover only the transaction's own fields and signature: type-4 authorization tuples need only the field widths EIP-7702 requires, and an invalid tuple signature or chain id makes the EL skip that tuple without affecting eligibility. Eligibility ignores fees: a transaction whose `maxFeePerGas` (`gasPrice` for type 0/1) is below the block's base fee has an empty singleton build, so it may be legitimately skipped. A proposer can push the base fee to the 1 gwei cap at no cost (3.2), so an FI transaction should set `maxFeePerGas` to at least 1 gwei to be sure it is not skipped for its fee.

</details>

| Case                                                                                                         | Handling                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[FI-7.2-5]** Transaction 0 of the execution block is the entry (canonical, at most 8,192 bytes, same hash) | Included, c + 1, before or after due. Ordinary transactions may follow, and ordinary EVM revert/OOG counts as inclusion; a zk-aborted transaction absent from the final body does not                                |
| **[FI-7.2-6]** Not included, not due                                                                         | c unchanged                                                                                                                                                                                                          |
| **[FI-7.2-7]** Not included, due, raw bytes ineligible                                                       | Skipped, c + 1, no EL needed                                                                                                                                                                                         |
| **[FI-7.2-8]** Not included, due, raw bytes eligible                                                         | Skippable, with c + 1, only if a complete build of `[tx]` on the committed parent with the same attributes, in alethia's given-list mode, yields an empty block; the result is judged under "Given-list build" below |

<details>
<summary>Details: given-list build (deciding whether a skip is legal)</summary>

- **[FI-7.2-9]** **Given-list build**: the build returns only after completing the deterministic build decision for `[tx]`, and has exactly two possible results: a block containing the transaction, or an empty block. It must not return a placeholder from before the build completes. If an eligible transaction cannot execute for any transaction-level reason (nonce, balance, intrinsic gas and so on), the result is an empty block, never an error. Transient infrastructure failures such as timeouts, a dropped connection or a SYNCING response from newPayload are not results: ProcessProposal and FinalizeBlock both wait and retry until a result exists, and never reject a proposal, judge a block invalid or skip because of them; while waiting, that node processes no new consensus messages. If the EL definitively cannot build on that parent (for example because the historical state was pruned), the node halts for safety under section 8 and restarts after the state is restored. An eligible transaction's gas is at most one block's limit, so each build does bounded work. This singleton build starts from that parent with the same attributes and candidate list `[tx]` only, with full EVM-gas and zk-gas block budgets; ordinary transactions may not consume them first. A completed empty result after fully discarding `tx` for zk-limit exceedance/metering overflow under the shared rules is deterministic and reproducible. An included ordinary EVM revert/OOG is not empty. Nodes and guests make the same complete determination; a host timeout, exhausted prover resources or a smaller local budget cannot justify skipping.

</details>

- **[FI-7.2-10]** A block at or after due that neither includes nor legally skips the entry is invalid. Only position 0 counts as inclusion: a replacement transaction with the same sender and nonce, or the transaction placed later in the block, does not count.

<details>
<summary>Details: raw bytes in the witness and fetching them</summary>

- **[FI-7.2-11]** The raw bytes in the witness may be empty; if nonempty, their hash must match the entry. A skip must carry the raw bytes, and empty bytes can only prove that the submission itself was empty. For an inclusion the guest authenticates transaction 0 of the execution block directly, so proposers leave the bytes empty to save data.
- **[FI-7.2-12]** The proposer fetches the raw bytes with `eth_getLogs` at the entry's L1 block and checks the hash. Before due, if they cannot be fetched it may propose an ordinary block; after due, it cannot propose without them.

</details>

- **[FI-7.2-13]** **Blanked entries**: after submission, an entry's `txHash` changes only when step 3 of governance recovery (section 8) overwrites it with the hash of the empty byte string, `keccak256("")`. Under an anchor that shows this value, the raw bytes are the empty string and need no `eth_getLogs`; such an entry can never be included, and once due it is skipped as ineligible, without the EL.

### 7.3 Guarantees and bounds

- **[FI-7.3-1]** A due queue-head entry must be included or legally skipped under 7.2; there is no age-only deletion. **[FI-7.3-2]** For the current queue-head entry, any valid block with `block.timestamp ≥ entry.timestamp + forcedInclusionDelay + maxAnchorAge` necessarily sees it as due, using overflow-safe arithmetic. This is a block-time implication, not a wall-clock inclusion deadline. Wall-clock progress also depends on the BFT-time assumptions in 3.4, L1 finality, queue backlog and settlement.
- **[FI-7.3-3]** Senders must hold a balance of gasLimit × `maxFeePerGas`; **[FI-7.3-4]** the queue consumes at most one entry per block, and the fee rises linearly with the queue length.
- **Backlog cost accounting**: let F be the fees actually paid for an attacker's enqueues. **[FI-7.3-5]** With fees belonging to the protocol, no share of successful landings lets the attacker recover F by consuming those entries. Add L1 submission gas, proving/landing/blob costs the attacker chooses to incur, and the L2 gas actually executed separately; account for other rewards or proceeds separately as well. Production fees, threshold, service rate under sustained attack and honest-user costs require evaluation; [Etna Acceptance and Launch Checklist](ACCEPTANCE.md) gives an illustrative calculation.

## 8. Halts and recovery

**[RECOV-8-1]** **Scope**: an automatically retrying liveness pause loses no blocks; **[RECOV-8-2]** executing governance recovery discards the suffix above c.

- **[RECOV-8-3]** **Liveness pauses**: the process keeps running and CometBFT keeps rounding; production resumes automatically once the cause clears, and no blocks are lost. **[RECOV-8-4]** Causes: the anchor not yet finalized or older than `maxAnchorAge`, back-pressure, an unavailable committee witness, or unavailable raw bytes for a due forced transaction. **[RECOV-8-5]** A local L1 node that lags, is unreachable or times out falls in this class too (section 9). **[RECOV-8-6]** So does an anchor header whose hash matches the canonical hash but that cannot be parsed under 3.3 (L1 changed the header format): ProcessProposal rejects, FinalizeBlock waits and retries, and production resumes once the node is upgraded.

<details>
<summary>Details: ABCI constraints that keep a pause lossless under stock CometBFT</summary>

**[RECOV-8-7]** For a liveness pause to lose no blocks with stock CometBFT v0.40.0, the app must never return an error or exception from any ABCI method on any connection (CometBFT exits or panics); Query and the snapshot methods return only error codes or empty results. **[RECOV-8-8]** ProcessProposal returns only ACCEPT or REJECT. **[RECOV-8-9]** PrepareProposal stays within the request's `max_tx_bytes`; **[RECOV-8-10]** during a pause, or when the required envelope does not fit, it returns a placeholder proposal with no transactions, which ProcessProposal rejects, and CometBFT moves to the next round as usual. **[RECOV-8-11]** InitChain returns only `app_hash`, with no validators or consensus params, and Commit always returns a `retain_height` of 0. Automatic recovery after refused signatures is in section 9.

</details>

- **[RECOV-8-12]** **Safety halts**: the process exits and needs manual investigation. **[RECOV-8-13]** Causes: a decided block that violates the validity rules or contradicts local state or the EL (including an EL `-38002` rejection); fork evidence found during sync or trust checks, or malformed or unverifiable data from the node's own L1 node or EL (section 9; an L1 header whose hash matches but that cannot be parsed under 3.3 is excluded); or, while replaying a canonical skip during cold sync, an EL that refuses to build on the parent with a non-retryable error, usually because it lacks the parent's historical state, which must be restored before restarting.
- **[RECOV-8-14]** **Superseded generation**: once an anchor shows a `recoveryGeneration` larger than this chain's generation, this chain cannot advance and the node can only restart under the new generation. **[RECOV-8-15]** ProcessProposal rejects a proposal carrying such an anchor and revokes checkpoint trust while the process keeps running; **[RECOV-8-16]** a decided block carrying such an anchor, or a startup or signer-session trust check that finds an Inbox generation different from this chain's, is a safety halt.
- **[RECOV-8-17]** **Committee derivation failure**: an empty candidate set or failed authentication/numeric constraint under 4.3 rejects S(t) proposals and may persistently halt production. **[RECOV-8-18]** Do not locally scale, add members or skip rotation. **[RECOV-8-19]** Governance recovery below may reselect from a new R snapshot, but eligible candidates are still required.
- **[RECOV-8-20]** **At least 1/3 voting power offline**: consensus halts without automatic replacement or power reduction. **[RECOV-8-21]** Returning members may restore it; otherwise governance recovery below reselects. **[RECOV-8-22]** Withdrawals still follow 4.1: confirmed exits can withdraw once the waiting period ends, while unconfirmed exits await settlement coverage.
- **[RECOV-8-23]** **Settlement stall**: L2 produces at most U more blocks and then stops on back-pressure.
- **Verifier failure**: both proofs accepting a wrong result is outside the threat model (section 1). **[RECOV-8-24]** A bad landing may corrupt the checkpoint, FI head or snapshot, and ordinary governance recovery cannot repair it. **[RECOV-8-25]** Contain losses first by pausing `SignalService` and the Bridge and by QuotaManager limits. **[RECOV-8-26]** Replacing the verifier already requires an Inbox upgrade, and the settlement rollback is executed in the same DAO upgrade of the Inbox and the registry. **[RECOV-8-27]** The Inbox restores lastCheckpoint (slots 270/271), the FI head (281) and activeCommitteeSnapshot (284) to the values written by the last trusted landing and voids later landing records and SignalService checkpoints. **[RECOV-8-28]** The last trusted landing is the last landing before the first bad one; if there is none, restore the initialization values. **[RECOV-8-29]** The registry re-checks every exit confirmation against the restored snapshot, keeping it only if that snapshot ≥ the entry's exitEffectiveL1 and clearing it otherwise. **[RECOV-8-30]** The check does not compare the L1 block numbers of confirmations, because block numbers cannot order transactions within one block. Node rules for handling the rollback ship with it. **[RECOV-8-31]** The rollback returns c to an earlier value, so the same upgrade must preserve and increment the current recoveryNonce (8.3), invalidating every prior recovery authorization without restoring a historical nonce; **[RECOV-8-32]** the rollback itself does not change the generation. **[RECOV-8-33]** If a governance recovery executed at a c above the restored one, that generation starts above the restored c and no landing can succeed in it; **[RECOV-8-34]** the DAO must follow the rollback with a new governance recovery from the restored c. **[RECOV-8-35]** Bridge payments or stake already withdrawn using bad checkpoints cannot be recovered; **[RECOV-8-36]** L2 fees were paid to proposers at execution and are unaffected.
- **Governance recovery**: for a long landing stall that normal settlement cannot clear. **[RECOV-8-37]** The call is recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil, exclusions, fiToClear). **[RECOV-8-38]** Exclusions is a list of (bondId, entryKey) sorted strictly by bondId; fiToClear contains strictly increasing entry indices. Call conditions, replay protection and atomicity are in 8.3; timing is in 8.1.
  1. **[RECOV-8-39]** Validate all lists and state before applying the following transition in one transaction.
  2. **[RECOV-8-40]** Each excluded entry must still match the entryKey given in the call and must not have been released or reused; otherwise reject the whole operation. **[RECOV-8-41]** Inbox calls the registry to set exitEffectiveL1=min(existing,R), with no forfeiture by recover itself; **[RECOV-8-42]** independent responsibility forfeiture (4.4) and double-sign evidence remain available.
  3. **[RECOV-8-43]** Each fiToClear index must still be in \[head,tail). **[RECOV-8-44]** Replace txHash with keccak256(""), retaining timestamp and enqueue block. **[RECOV-8-45]** This is for handling unprovable content only; unlisted entries survive and are consumed by the new chain under the normal rules. **[RECOV-8-46]** Admission fees are neither refunded nor recharged, and no lander is paid.
  4. **[RECOV-8-47]** Increment generation (generation+1 must fit uint48), write the fixed origin in 8.4, and emit execution details and complete lists. **[RECOV-8-48]** Preserve checkpoint c's landing record and FI head. **[RECOV-8-49]** Recovery must not advance activeCommitteeSnapshot early; only a real landing signed by the new committee advances it. **[RECOV-8-50]** Confirmed exits are unaffected (4.1).
  5. **[RECOV-8-51]** Nodes rebuild EL from authenticated c and select the committee directly from the registry snapshot at execution block R under 4.3, without carrying over the old generation's powers. **[RECOV-8-52]** Excluded entries are ineligible; other already active candidates may enter. **[RECOV-8-53]** Discard every pending update from the old generation and resume ordinary switches/H+2 on global heights. **[RECOV-8-54]** No signing for the new generation before the 8.2 authentication completes. **[RECOV-8-55]** Nodes/guests independently authenticate R's final snapshot rather than trust governance-supplied weights.
  6. **[RECOV-8-56]** Discard only the unsettled suffix above c; **[RECOV-8-57]** users resubmit those transactions, and fees in those blocks are void with them. **[RECOV-8-58]** Do not rewind the settled prefix.

### 8.1 Recovery authority and user-visible boundaries

- **[RECOV-8.1-1]** Only the DAO authorizes recovery, exclusion and FI blanking; ordinary on-call or pause authority has no such powers. **[RECOV-8.1-2]** Bridge/SignalService pauses limit future exposure but cannot recover paid bridge funds or withdrawn stake.
- **[RECOV-8.1-3]** **Timing**: recover has no separate time threshold; the shortest stall before recovery depends on the delay of the DAO's authorization path. **[RECOV-8.1-4]** expectedC is set to the current c and fixed at authorization, so any landing after that makes the call unexecutable; a recovery executed through the standard path (veto period plus timelock) therefore implies no landing during that whole period. The emergency path that skips the veto period should be used only for a long landing stall that normal settlement cannot clear, and on that path the lists may become public only at execution, with no advance notice. **[RECOV-8.1-5]** Slow progress, low TPS, a wall-clock FI delay or missing the 20 min landing target is never a reason to recover.
- **[RECOV-8.1-6]** **Before authorizing**: the DAO has landers settle up to the last provable grid point and sets expectedC to the resulting c, so only blocks that truly cannot be settled are discarded, plus at most K − 1 provable blocks short of a full grid segment. **[RECOV-8.1-7]** Before scheduling and executing, it checks a nonempty intended set, more than 2/3 online power, no party at or above 1/3, and available history and signers, and confirms that c's landing matches honest nodes' local chain: the EL hash, Comet hash and FI head in its slot 285 record, the SignalService checkpoint at c, and slot 284 (the selection snapshot of the committee that signed c). **[RECOV-8.1-8]** A mismatch means the verifier has failed: perform the section 8 verifier-failure rollback first, then authorize recovery.
- **[RECOV-8.1-9]** **Economic review and independent forfeiture**: estimate the intended committee against the launch checklist's capital target, then reassess the actual snapshot after R is finalized, including newly activated registrations and top-ups. **[RECOV-8.1-10]** A capital shortfall or expired valuation triggers an alert, public disclosure and replenishment, not a new recovery or signer veto; existing quorum, concentration and authentication checks remain. **[RECOV-8.1-11]** Recover neither executes nor cancels responsibility forfeiture and does not wait for it; **[RECOV-8.1-12]** resumed production does not erase responsibility under 4.4.

### 8.2 Recovery signer

- **[RECOV-8.2-1]** The signer keeps separate stock HRS state for each full `chain_id` (which includes the generation), persists each signature before returning it, and never resets or rolls that state back; **[RECOV-8.2-2]** no copy of the key may sign outside that state. **[RECOV-8.2-3]** If the state is lost or its latest value is uncertain, stop signing; deleting state cannot restore service.
- **[RECOV-8.2-4]** Sign for a new generation only after the node's own finalized L1 view authenticates the recovery execution (new generation, origin c, R's registry snapshot and the committee reselected under 4.3) and both the 8.4 origin-record and genesis checks and section 9 checkpoint trust pass. **[RECOV-8.2-5]** The new generation starts its own HRS state at c + 1, and once the recovery is authenticated, signing requests for the old generation are refused. **[RECOV-8.2-6]** Votes in different generations use different signing domains and are not double signs. Failover, fencing and similar protections against same-domain double signing are operational practice.

### 8.3 Execution-time checks in recover

- **[RECOV-8.3-1]** **Caller and conditions**: only the Inbox owner (the DAO) may call recover. **[RECOV-8.3-2]** Both recover and invalidateRecoveryNonce require Inbox initialization. **[RECOV-8.3-3]** At execution expectedGeneration, expectedC and expectedRecoveryNonce must equal current state, and `block.timestamp <= validUntil`; **[RECOV-8.3-4]** validUntil is an absolute L1 Unix timestamp in seconds fixed at authorization. **[RECOV-8.3-5]** For recovery authorization, Inbox stores only a monotonically increasing uint256 recoveryNonce, initially zero, with no recovery queue or scheduling records. **[RECOV-8.3-6]** It does not distinguish DAO authorization paths; **[RECOV-8.3-7]** authorization or queueing does not freeze landing.
- **[RECOV-8.3-8]** **Replay and invalidation**: increment recoveryNonce on successful recover. **[RECOV-8.3-9]** Only the Inbox owner may call `invalidateRecoveryNonce(expectedRecoveryNonce)`; require a match and increment to invalidate all unexecuted authorizations with that nonce. **[RECOV-8.3-10]** Verifier-failure rollback also preserves and increments the current nonce; **[RECOV-8.3-11]** no path may restore an older value or wrap it. **[RECOV-8.3-12]** Landing changes c, recovery changes generation, and generation never decreases. **[RECOV-8.3-13]** A rollback returning c to an old value cannot revive old authorizations. **[RECOV-8.3-14]** Every retry must pass all checks; changed parameters require fresh DAO authorization. **[RECOV-8.3-15]** This recovery nonce is independent of the entryKey lifetime forfeiture flag in 4.4.
- **[RECOV-8.3-16]** **Atomicity**: list validation, registry forceExit, FI blanking, counter updates and origin recording all happen inside one recover call, and any failure reverts everything, leaving no partial exit, FI edit or generation change. **[RECOV-8.3-17]** Recovery-list exclusion and FI blanking exist only inside recover and cannot be applied in an earlier transaction. **[RECOV-8.3-18]** This does not restrict owner exits, double-sign slashing (4.1) or the independent responsibility forfeiture and forced exit in 4.4. **[RECOV-8.3-19]** During recovery, reject cross-function reentrancy that could change the checkpoint, generation, recovery lists or withdrawal eligibility, including land, recover, recovery-nonce invalidation and registry mutations or withdrawals.

### 8.4 Fixed origin and genesis of a new generation

**[RECOV-8.4-1]** Recovery uses stock CometBFT v0.40.0 without adding an authorizer or trusted snapshot service. **[RECOV-8.4-2]** c is the fixed recovery origin and R the canonical L1 block that executed recover; nodes authenticate both from their own finalized L1 view.

- **[RECOV-8.4-3]** **Fixed origin record**: slot 290 stores (startHeight, l1BlockNumber, l1Timestamp) = (c, R.number, R.timestamp) per generation; generation 0 is (0, L1_0, the initialization transaction's L1 timestamp) and only describes genesis. **[RECOV-8.4-4]** Each record is written once and never overwritten or deleted. **[RECOV-8.4-5]** A missing record is rejected; mapping defaults or the latest checkpoint are not substitutes. **[RECOV-8.4-6]** generationStartHeight and recoverySnapshot read it directly, without caches.
- **[RECOV-8.4-7]** **Unique genesis**: chain_id uses the new generation, initial_height=c+1, genesis_time=R.timestamp, and InitChain returns app_hash=ELHash(c); **[RECOV-8.4-8]** EL state must match c's authenticated EL hash and stateRoot. **[RECOV-8.4-9]** Genesis validators are selected by 4.3 on the R snapshot (record.targetEpoch=floor(c/L), cutoffL1Block=R).
- **[RECOV-8.4-10]** **First block**: uses stock genesis's empty LastBlockID/LastCommit; c's Comet hash serves only as the proving boundary (6.2 item 2). **[RECOV-8.4-11]** The FI cursor starts at the authenticated origin head. **[RECOV-8.4-12]** The first block must carry a finalized anchor witness no earlier than R and does not use c's anchor. **[RECOV-8.4-13]** Every anchor and L1 root used by the new generation's proofs is no earlier than R (3.4 rule 3).
- **[RECOV-8.4-14]** **Joining nodes**: replay from the fixed genesis to the latest checkpoint on their own finalized L1 and match both EL and Comet hashes before becoming trusted; **[RECOV-8.4-15]** the latest checkpoint is never a new genesis for the same domain.

## 9. Sync and weak subjectivity

- **[SYNC-9-1]** **Replay uses the live rules**: during cold sync (replay or blocksync), for a block it did not judge live that carries an anchor witness, FinalizeBlock likewise first checks with its own L1 node that the anchor header is canonical and finalized, and checks the witness's lastCheckpoint per 3.4. **[SYNC-9-2]** An own L1 node that lags, is unreachable or times out only makes it wait and retry. The node halts for safety only on contradictory evidence from its own L1 node.
- **[SYNC-9-3]** **Checkpoint fence**: FinalizeBlock passes the `lastCheckpoint.hash` proven by the anchor to the EL's forkchoice as `finalized`; a history that does not descend from that checkpoint is rejected by the EL (`-38002`), and the node halts for safety. A history forged with old keys can therefore extend at most U blocks beyond its fork point, but that point can be old; forging blocks above the checkpoint needs more than 2/3 of the keys of the committee governing those heights, and that stake cannot be withdrawn until a checkpoint covers its exit.
- **[SYNC-9-4]** **Weak subjectivity is solved by L1**: every app startup and signer session starts untrusted, authenticates the Inbox's latest checkpoint in its own L1 finalized view, and **[SYNC-9-5]** becomes trusted only after reaching that height with an exact match of both the EL hash and the CometBFT hash in the slot 285 record (block 0's record has Comet hash 0; recovery origin c's record keeps the Comet hash from its original generation); **[SYNC-9-6]** after that, every anchor change checks the new lastCheckpoint per 3.4. A forged history either stays below the target and is never trusted, or is rejected at the target, so no weak-subjectivity checkpoint and no age limit on the starting point is needed. **[SYNC-9-7]** Missing data keeps the node untrusted and retrying; an authenticated contradiction, or malformed or unverifiable data from its own L1 node or EL, halts it for safety, because the node cannot tell that apart from forgery. **[SYNC-9-8]** An L1 header whose hash matches the canonical hash is not in this category: its source is authenticated, and a parse failure only means the node needs an upgrade (3.3). **[SYNC-9-9]** A recovery generation's fixed genesis origin may differ from this latest trust target; distinguish them and replay under 8.4 rather than rebuilding same-domain genesis at each newer checkpoint.

<details>
<summary>Sign and serve only when trusted (signing gate and automatic restart details)</summary>

- **[SYNC-9-10]** **Sign and serve only when trusted**: every validator signature (including nil votes and retained blocks) needs the app to confirm that the node is trusted; **[SYNC-9-11]** untrusted state, a timeout or a superseded generation means no signature, with no fallback to local signing. CometBFT v0.40.0 never retries a refused or timed-out signing request, so refusals by at least 1/3 of the voting power at the same step stall that height indefinitely. **[SYNC-9-12]** After a signing request is refused for lack of trust or a timeout, the supervisor must therefore restart CometBFT automatically once trust returns: the signer first completes the new session's trust check and only then connects to CometBFT's `priv_validator_laddr`, and WAL replay then requests a signature for the refused step again. **[SYNC-9-13]** The signer follows the stock rules (refuse a lower height/round/step, return the original signature for the same one) and persists each signature before it is broadcast, so this cannot double-sign. **[SYNC-9-14]** The restart needs no operator and resets no signing state; safety halts (section 8), requests for an old generation and refusals at a 10.1 upgrade boundary do not trigger it. **[SYNC-9-15]** Exchanges, bridges and public RPC must read the app's trust status, not raw CometBFT/EL sync progress or `catching_up`.

</details>

<details>
<summary>Details: node requirements</summary>

- **[SYNC-9-16]** **Node requirements**: the own L1 node must return headers by number back to `L1_0` and serve the `eth_getProof` the trust check needs; a validator also needs historical `eth_getProof` and `debug_getRawHeader`, and a proposer must be able to query historical logs of unconsumed forced-inclusion entries.

</details>

### 9.1 Consensus history and double-sign evidence

- **[SYNC-9.1-1]** Complete CometBFT recovery and proving require original blocks/envelopes, headers, commits/LastCommit, registry snapshots/entries/witnesses, FI data/logs, relevant L1 headers/proofs, genesis parameters and recovery records. **[SYNC-9.1-2]** Archives must retain these dependencies; public blobs or an EL snapshot alone are insufficient. **[SYNC-9.1-3]** Private keys are not historical archive data; signing state follows 8.2.
- File hashes detect corruption but do not authenticate committees. **[SYNC-9.1-4]** Recovery uses the node's own finalized L1 view to authenticate the current generation's fixed origin, c's EL/Comet hashes and R's registry snapshot, then reselects under 4.3. **[SYNC-9.1-5]** Subsequent current/pending committees follow authenticated switches. An EL snapshot's app_hash does not authenticate extra committee metadata. **[SYNC-9.1-6]** Missing material leaves the node untrusted; contradictions halt under section 9.
- **[SYNC-9.1-7]** Anyone may collect verifiable same-round conflicting votes from different peers and submit directly to L1; Comet evidence inclusion is not required. **[SYNC-9.1-8]** Evidence retention/submission is independent of the local pool's 100,000-block/48-hour limits and should track confirmExit and withdrawal boundaries. Historical evidence may remain necessary until collateral withdrawal is finalized. **[SYNC-9.1-9]** Retention does not guarantee observation of every conflicting vote, and **[SYNC-9.1-10]** different BlockIDs across rounds are not automatically double signing.

## 10. Startup and deployment

The flow below assumes startup from block 0 as the starting point; it will be adjusted once the switch from Unzen to Etna is added.

1. **[START-10-1]** Deploy the Inbox proxy (not yet initialized; only its owner can initialize it), then deploy the registry with that proxy address fixed; validators sign the registration digest (appendix A) with their consensus keys, register and wait for activation and finality.
2. **[START-10-2]** Pick a past `genesisCutoff` and compute committee 0's record hash and the config hash.
3. **[START-10-3]** Install EIP-4788 and EIP-2935 in the L2 genesis; set the base-fee sharing percentage to 100.
4. **[START-10-4]** Compute block 0's hash and stateRoot with the EL.
5. **[START-10-5]** Deploy SignalService and initialize the Inbox (checking the registry under 4.1) with genesis hash/stateRoot, L, genesisCutoff, committee-0/config hashes, forcedInclusionDelay and maxAnchorAge, and save the block-0 checkpoint. Fix a nonzero DAO treasury as protocolFeeRecipient. Initialize recoveryGeneration and recoveryNonce to 0, activeCommitteeSnapshot to genesisCutoff and generation 0's origin under 8.4, with recover callable only by the owner.
6. **[START-10-6]** After L1 finality, read the genesis record and generate CometBFT genesis. Start the EL and ABCI app, then the guarded signer and stock CometBFT with `priv_validator_laddr`; PubKey/Ping allow handshake while trust is closed. The signer owns the existing registered key and anti-double-sign state outside the Comet home/mount. Use the supported supervisor/startup configuration; never reset signing state or enable a local FilePV fallback to bypass readiness. Full nodes use an unregistered identity.

<details>
<summary>Details: deployment constraints</summary>

**[START-10-7]** **Deployment constraints**: L≥3, L+1\<2\^48; **[START-10-8]** cutoff is in the past and no earlier than the first registry checkpoint; **[START-10-9]** forcedInclusionDelay>0 and maxAnchorAge≥1152 s; **[START-10-10]** K≤U≤65,536 with U a multiple of K (target deployment U=3,600, which works for any 1 ≤ K ≤ 6), **[START-10-11]** L1_0\<2\^48, 1≤n_max≤4096, **[START-10-12]** vp_unit≥867,361,738 (4.3) and s_min≥vp_unit; **[START-10-13]** use positive activation/exit delays; **[START-10-14]** deployment, nodes and guests check the same configuration. **[START-10-15]** Appendix A's chain_id is exactly 48 ASCII bytes. **[START-10-16]** Incorrect immutable parameters still require a new Inbox/genesis; because the registry fixes the old Inbox address, the DAO must upgrade it to point at the new Inbox or deploy a new registry. **[START-10-17]** Old signing state is not reset.

</details>

Use U=3,600 and choose L independently (suggested 900), with approximately 4 s blocks and 20 min landing as operating targets. **[START-10-18]** Pin maxBatchBlocks≥K (at least one grid segment). The launch gate (including committee 0's minimum total stake and concentration limits) and all acceptance criteria are in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md); **[START-10-19]** do not claim readiness before they pass, or advertise unmeasured recovery duration as a service commitment.

<details>
<summary>Details: initial CometBFT genesis parameters</summary>

**[START-10-20]** **Initial-deployment CometBFT genesis** (recovery origin, time, validators and app_hash follow 8.4; InitChain checks representable ABCI fields): `chain_id` is built per appendix A from the full L1/L2 chain ids, Inbox proxy address and the Inbox's `recoveryGeneration`; `initial_height` = 1; `genesis_time` = the timestamp of block `L1_0`; the validators are exactly committee 0 (keys and power); `app_state` carries the header of `L1_0`, the Inbox proof and committee 0's witness. **[START-10-21]** Consensus params are fixed: `block.max_bytes` 22,020,096 and `max_gas` −1; evidence limits of 100,000 blocks, 48 h and 1 MiB; secp256k1eth keys only; `APP_VERSION = 1`; vote extensions off; no parameter update authority. **[START-10-22]** Initial state: anchor `L1_0`, forced cursor 0, checkpoint (0, genesis hash). **[START-10-23]** The generator writes an empty parameter-update authority; the typed InitChain request does not expose that field, so InitChain cannot independently compare it. **[START-10-24]** In-place migration from other app/config versions (including a populated registry) is unsupported, and deleting retained state must not be used to bypass version checks.

</details>

### 10.1 Protocol upgrade boundaries

- **[START-10.1-1]** Protocol upgrades stop production and settle before switching rules, without a zero-downtime promise. **[START-10.1-2]** Operational restarts that preserve validity rules retain all same-domain signer state. **[START-10.1-3]** Changes to section 10's deployment-immutable parameters remain a separate new-Inbox/new-genesis migration; this section cannot bypass immutability.
- **[START-10.1-4]** An upgrade plan must bind the deployment, generation, boundary height H (a grid point, since landings end only at grid points, 6.1; an upgrade that changes K needs H to be a multiple of both the old and the new K, or no origin on the new grid remains), old/new client and EL rules, guest images and verifier acceptance ranges. **[START-10.1-5]** Authenticate it through the actual DAO/timelock authority and enforce it in both nodes and L1 verification; an off-chain manifest or operator agreement alone is insufficient. This activation mechanism is not fully designed yet and will be added later; **[START-10.1-6]** registering a new image alone is not a protocol upgrade.
- **[START-10.1-7]** Before the boundary, coordinate signers to stop above H while retaining all HRS state. **[START-10.1-8]** Settle through H under the old rules and authenticate its EL/CometBFT checkpoint before activating the new rules at H + 1. **[START-10.1-9]** The plan must take effect before signing crosses the boundary. **[START-10.1-10]** If signatures or unsettled blocks already exist above H, do not erase state or move the boundary backward; replan, or use section 8's separate procedures if settlement cannot complete.
- **[START-10.1-11]** Isolate in-flight jobs by deployment, generation, statement/config/image version and height range; batches do not cross H. **[START-10.1-12]** Old jobs must validly settle before the switch or be explicitly invalidated, never rewritten into a new version. **[START-10.1-13]** Retain old rule/image material for historical replay, but L1 settlement above H must no longer accept an image that only checks the old rules. **[START-10.1-14]** New images must not implicitly change history through H. **[START-10.1-15]** Define and test the exact on-chain acceptance ranges, switching transaction and failure rollback plan.
- The upgrade activation mechanism will be added later; this section does not establish an available recovery fallback. L1 hard-fork deadlines are separate (section 12, item 10).

## 11. Parameters

**[PARAM-11-1]** Principle: any parameter that could split nodes comes only from L1 (Inbox initialization or the config hash) or is built into the client per chain id; local configuration cannot change consensus.

**[PARAM-11-2]** Values in the table are references only; actual deployment follows L1 initialization/config hash and section 10. **[PARAM-11-3]** assignedPower is computed directly under 4.3, not from node-local configuration.

| Parameter                                                                                                                        | Layer                                                           | Constraint                                                                                                                                                                                                                                                                                                                | Reference value                                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **[PARAM-11-4]** L, genesisCutoff                                                                                                | Inbox initialization                                            | Choose L for rotation and ordinary L+2 history, independently of U; no wall-clock takeover warning                                                                                                                                                                                                                        | Suggested L=900, nominally 60 min at 4 s; deployment-specific genesisCutoff                         |
| **[PARAM-11-5]** `forcedInclusionDelay`, `maxAnchorAge`                                                                          | Inbox initialization                                            | The former above 0; the latter ≥ 1152 s and above the L1 finality delay                                                                                                                                                                                                                                                   | Per deployment                                                                                      |
| **[PARAM-11-6]** `maxBatchBlocks`, forced inclusion fee and doubling threshold, verifier, `protocolFeeRecipient`                 | Inbox immutable                                                 | maxBatchBlocks ≥ K, and small enough that its leaf calldata ((maxBatchBlocks/K − 1) × 32 bytes) fits within the per-transaction gas limit; fee and threshold above 0; protocol recipient nonzero and set to the DAO treasury                                                                                              | Per deployment                                                                                      |
| **[PARAM-11-7]** vp_unit, s_min, n_max                                                                                           | config hash                                                     | Direct power under 4.3/10; vp_unit ≥ 867,361,738                                                                                                                                                                                                                                                                          | References: 1e9 base units, 1 TAIKO, 128; pin and validate for deployment                           |
| **[PARAM-11-8]** U                                                                                                               | Config hash                                                     | K ≤ U ≤ 65,536 and a multiple of K, independent of L; circuit breaker for settlement failure, the target deployment selects U=3,600 (about 4 h), subject to validation in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md)                                                                                           | 3,600                                                                                               |
| **[PARAM-11-9]** K (grid interval)                                                                                               | Protocol constant built into the Inbox and both guests          | 1 ≤ K ≤ 6 (six maximum-size blocks fill the six blobs of one transaction, 3.4); any K consecutive worst-case blocks, each including one 7.2 single-transaction build trial, must be provable within one landing's two proofs; constrains U and maxBatchBlocks (6.4, section 10)                                           | Not fixed yet; set from proving capacity measured during acceptance                                 |
| **[PARAM-11-10]** `L2_BLOCK_GAS_LIMIT`, `L2_BLOCK_ZK_GAS_LIMIT`, zk gas metering parameters and multiplier table                 | Built into the client per chain id (with the pinned EL version) | A change needs a coordinated client upgrade; zk gas has an independent limit under 3.1’s shared rules; transaction fees use ordinary EVM gas                                                                                                                                                                              | 45,000,000; `L2_BLOCK_ZK_GAS_LIMIT` and metering parameters/multipliers per pinned EL version (3.1) |
| **[PARAM-11-11]** `minStake`, activation/exit/withdrawal delays, `slashBountyBps`, `slashSink`, `l2ChainId`, Inbox proxy address | Registry immutable                                              | `withdrawalDelay` runs from exitConfirmedAtL1 and is no shorter than the double-sign evidence window (suggested ≥ 7 days, about 50,400 L1 blocks); `slashBountyBps` ≤ 10000 (suggested 1000); `slashSink` nonzero; `l2ChainId` matches the Inbox; Inbox initialization checks that the Inbox proxy address equals its own | Per deployment                                                                                      |
| **[PARAM-11-12]** `forfeitBps`                                                                                                   | Registry immutable                                              | Fixed responsibility-forfeiture rate, 0 < forfeitBps ≤ 10000; all proceeds to slashSink, no extra delay                                                                                                                                                                                                                   | Pin before launch                                                                                   |
| `C_CAP_MIN`, `P_REF`, `S_MIN_TOTAL`                                                                                              | Launch manifest, not consensus                                  | Capital target, conservative price with validity/review policy, and derived stake floor under checklist section 4; concrete values required before launch                                                                                                                                                                 | Per deployment                                                                                      |
| `timeout_commit`                                                                                                                 | CometBFT configuration                                          | Block cadence only                                                                                                                                                                                                                                                                                                        | Set for the \~4 s block-time target                                                                 |

**[PARAM-11-13]** Activation, exit, withdrawal and top-up readiness use L1 block numbers. **[PARAM-11-14]** Authorization deadlines use L1 block.timestamp in Unix seconds. **[PARAM-11-15]** In addition to the double-sign evidence window, evaluate withdrawalDelay against detection, DAO decision/authorization and L1 inclusion time on the fastest lawful withdrawal path; do not assume exitDelay remains available. The suggested seven days is not automatically sufficient. If the standard governance path cannot finish before withdrawal, forfeiture needs timely emergency execution or may be lost. **[PARAM-11-16]** Publish and exercise this response budget; no guaranteed reaction time is implied.

## 12. Known limitations and open items

1. **[LIMIT-12-1]** **No wall-clock FI deadline.** `maxAnchorAge` bounds only anchor age relative to block time; wall-clock progress also depends on 3.4's BFT-time assumptions, queue backlog, L1 finality and settlement (7.3).
2. **[LIMIT-12-2]** **Offline quorum relies on DAO recovery.** A halted chain does not replace members automatically. Returning members may restore it; otherwise the DAO reselects at R with authorized exclusions (section 8). Newly eligible standby candidates may enter directly, but the DAO still judges online availability and operator concentration; success is not guaranteed, and L1 finality failure, incomplete proofs or missing history can still prevent recovery. Ordinary recovery discards the suffix above c, and its duration includes the DAO authorization delay, finality, reconstruction, signer migration and first settlement. There is no non-governance escape hatch.
3. **[LIMIT-12-3]** **Double-sign slashing is same-round only.** Cross-round amnesia is not covered, and gossip can miss evidence; offline responsibility is discretionary DAO forfeiture, not automatic evidence-based slashing (4.4).
4. **[LIMIT-12-4]** **Operations depend on DAO funding.** Landing has no protocol revenue; settlement liveness relies on DAO-funded landers and on validators landing to avoid a back-pressure halt. Budgets and real proving/landing costs still need measurement (appendix C).
5. **[LIMIT-12-5]** **Dependence on L1 finality.** Production pauses when no finalized anchor satisfies `maxAnchorAge` (3.4).
6. **[LIMIT-12-6]** **Empty committee.** With no eligible candidate, an ordinary switch stops; recovery cannot create quorum from nothing, so eligible stake must be replenished first (4.3, section 8).
7. **[LIMIT-12-7]** **No rotation power-change limit.** Each term directly selects the top n_max by stake, with no takeover bound or guaranteed DAO reaction window; continuously assess the actual committee's less-than-1/3 Byzantine-power assumption (4.3).
8. **[LIMIT-12-8]** **Refunds depend on settlement and the post-confirmation evidence window.** An exit must first be covered by a landed committee, then confirmed, then wait the full withdrawalDelay. If the Inbox cannot recover or must be replaced, unblocking exits still needs a governance upgrade (4.1).
9. **[LIMIT-12-9]** **The switch from Unzen is not included yet.** To keep the spec small and easy to discuss, it deliberately leaves out the switch from Unzen to Etna for now; that will be added later, and section 10's startup flow and the starting point used in the text (block 0, committee 0 and the grid origin of 6.1) will be adjusted then. Bridge wiring comes with the switch: L2→L1 messages already work through SignalService checkpoints, but how the existing Bridge, vaults and L2 SignalService connect (including the L2 SignalService reading L1 state from EIP-4788) is not yet specified.
10. **[LIMIT-12-10]** **The upgrade activation mechanism is not fully designed yet.** Section 10.1 specifies stopping and settling through H, new rules from H + 1, in-flight job isolation and historical-replay boundaries. Authentication of the plan, exact height-scoped on-chain image acceptance and switch/failure paths are still to be designed and will be added later; this is not an available fallback. L1 hard forks are a separate, external deadline: forks that only append header fields are absorbed by the decoding rule in 3.3, while forks that change existing fields or the state commitment (for example EIP-7864's binary trie, which invalidates every MPT witness) need the client and guest upgrades and the new image registrations done before the fork activates on L1, on L1's schedule rather than at an L2 height.
11. **[LIMIT-12-11]** **Registry capacity.** There are 4096 slots in total; filling them locks 4096 × `minStake`, plus L1 transaction costs, and new registrations are blocked while they are full. Registration occupies a slot before activation, and entries that are not selected also retain their slots until exit and withdrawal. Higher-stake newcomers can therefore be excluded without the occupier controlling committee voting power. Competitive or expiring admission remains an open design choice; any reclamation must preserve historical snapshot proofs and the settlement condition on collateral withdrawal.
12. **[LIMIT-12-12]** **No automatic gradual-offline handling.** The protocol does not reduce power for low participation, so offline members can keep their stake ranking; removal depends on owner exit, replacement by other eligible stake, DAO responsibility forfeiture with forced exit (4.4), or post-stall governance recovery.
13. **[LIMIT-12-13]** **secp256k1eth is new.** The key type was added only in CometBFT v0.40.0, with one later fix to its signature format, so it is less battle-tested than Ed25519; support in external signers and HSM/KMS must be confirmed separately. CometBFT does not batch-verify it. [Etna Acceptance and Launch Checklist](ACCEPTANCE.md) requires pinned versions, cross-implementation vectors, signer/HSM/KMS compatibility and n = 128 measurements; a negligible cost impact must not be assumed before testing.
14. **[LIMIT-12-14]** **Registration admission bounds.** The vp_unit lower bound only prevents power overflow (4.3); selection is still limited by the 4096 registry slots, stake ranking and eligibility, so registration does not guarantee selection.
15. **[LIMIT-12-15]** **Private consensus-history availability.** Public blobs only reconstruct the settled EL; ordinary proving, Comet replay, signing evidence and L1 ancestry depend on the 9.1 archives, and unauthenticated snapshots are not substitutes.
16. **[LIMIT-12-16]** **Overlapping proofs provide short-landing protection, pending acceptance.** Grid rules are in 6.1 and 6.3. A competitor landing first at any grid point in (p,h) cannot make an honest submission fail. Only a competitor settling h or beyond makes it revert as already settled, and then the competitor has advanced settlement on its behalf, which cannot trigger back-pressure; at worst the honest lander pays blob gas and calldata for that transaction. No throughput or recovery guarantee is claimed under more-than-1/3 collusion, unavailable proofs/data or failed L1 finality.
17. **[LIMIT-12-17]** **Resource and latency figures await validation.** U=3,600, approximately 4 s blocks, 20 min landings, about 900 unsettled blocks in normal operation and about 3 h of outage margin are illustrative, not measured, and must pass [Etna Acceptance and Launch Checklist](ACCEPTANCE.md). Checking only the latest checkpoint does not remove history retention or fix indefinite L1 finality failure; the unsettled suffix remains governance rollback exposure.
18. **[LIMIT-12-18]** **Economic security and discretionary forfeiture.** At least 1/3 of voting power can halt consensus by withholding signatures. Checklist section 4 defines S_MIN_TOTAL from an independent capital target and conservative reference price; concrete deployment values and launch checks remain required. Operation and recovery may continue with publicly disclosed economic-security shortfalls. Forfeiture depends on correct DAO attribution and execution before lawful withdrawal; it does not guarantee loss for every halt, and has no extra waiting or appeal period. Its unexecuted authorizations cannot be revoked through the registry before expiry. Normal-operation forfeiture grants the DAO forced-exit authority and may disrupt later rotations. Top-ups replenish existing entries even when all slots are occupied, but do not admit new operators into a full registry.

## Appendix A: Encodings

**[ENC-A-1]** **Versions**: APP_VERSION=1, and every versioned domain tag is V1; the outer envelope/payload prefix is 0x06. **[ENC-A-2]** Config has seven words/224 bytes; CommitteeRecord has five fields. **[ENC-A-3]** Slot 285 has three words (appendix B). **[ENC-A-4]** Bind real guest-image/verifier acceptance to the config; until the upgrade mechanism is complete, changing clients or registering an image does not activate new rules.

**Shared vectors**: every encoding, interface, storage layout and boundary condition needs accept/reject vectors shared by nodes, contracts and both guests; the list is in [Etna Acceptance and Launch Checklist](ACCEPTANCE.md).

**[ENC-A-5]** Protocol hashes are keccak256 over `abi.encode`, with domain tags as right-zero-padded `bytes32` ASCII; the exceptions are the inner nodes of `entriesRoot` (plain concatenation) and the blob hash list and the cut leaf list (`abi.encodePacked`).

```txt
// [ENC-A-6]
chainDomain = keccak256(abi.encode(bytes32("ETNA_COMET_DOMAIN_V1"),
                uint256(l1ChainId), uint256(l2ChainId), address(inbox), uint48(generation)))
// [ENC-A-7]
chain_id    = "etna-" + base64url_no_padding(chainDomain)  // raw 32-byte digest -> 43 chars; total 48 ASCII bytes
  // [ENC-A-8]
  // RFC 4648 section 5 alphabet, canonical zero pad bits, no "=" or whitespace; case-sensitive
  // [ENC-A-9]
  // inbox is the EtnaInbox proxy address; generation starts at 0 and never wraps or decreases
// [ENC-A-10]
extraData  = 0x64 || uint48_be(generation) || uint48_be(anchorNumber)   // 13 bytes

// [ENC-A-11]
envelope   = 0x06 || rlp([block, anchor, committee, forced])
  // [ENC-A-12]
  block     = [elHeader, [tx, ...]]                    // tx: RLP byte string of its EIP-2718 encoding, legacy included
  // [ENC-A-13]
  anchor    = [] or [[rawL1Header, inboxWitness]]       // rawL1Header: byte string holding the L1 header's raw RLP, decoded per 3.3
  // [ENC-A-14]
  committee = [] or [[record, registryWitness, [entry, ...]]]
  // [ENC-A-15]
  forced    = [] or [[index, entryWitness, tx]]         // tx may be empty; if nonempty its hash must match; required for skips
  // [ENC-A-16]
  // Strict decoding (identical for nodes and guests; any violation makes the proposal invalid): the envelope is exactly 0x06 plus one RLP list, with no trailing bytes;
  // [ENC-A-17]
  // every list has exactly the items above, and anchor/committee/forced are empty or hold exactly one item; integers use minimal big-endian encoding, 0 is the empty string, no leading zeros;
  // [ENC-A-18]
  // fixed-length byte strings (hashes, stateRoots, slots) have exactly their length (slots 32 bytes, addresses 20 bytes); no extra items or unknown fields
  // [ENC-A-19]
  // Field types: hashes, stateRoots and slots are 32-byte strings and addresses 20-byte strings; RegistryEntry.ckX is a 32-byte string (leading zeros kept), ckPrefix and the other numbers are integers;
  // [ENC-A-20]
  // storage values always use minimal integer encoding, including slots that hold hashes; RLP length prefixes must also be minimal; a released slot's entry has all-zero fields;
  // [ENC-A-21]
  // AccountWitness.address must be the expected contract: the Inbox for anchor and forced witnesses, the registry for the committee witness
  // [ENC-A-22]
  // committee-witness account/storage proofs are always verified under this block's anchor stateRoot (new or inherited), i.e. parentBeaconBlockRoot (4.3)

// [ENC-A-23]
payload    = 0x06 || zlib(rlp([rlp([elHeader, [tx, ...]]), ...]))

// [ENC-A-24]
AccountWitness  = [address, nonce, balance, storageRoot, codeHash, accountProof, [[slot, value, proof], ...]]
  // [ENC-A-25]
  Prove exactly in order: anchor [268, 270, 271, 281]; forced entry [base,base+1], base=keccak256(abi.encode(i,280));
  // [ENC-A-26]
  registry snapshot [R, cp(i), cp(i) + 1], plus cp(i + 1) if i + 1 < length, where cp(i) = keccak256(R) + 2i
  // accountProof and each storage proof are exactly the ordered MPT path from the root to the leaf (or to the node proving absence), with no extra nodes;
  // value uses minimal big-endian encoding (0 is the empty string) and equals the proven value; the account fields match the account RLP in the proof
// [ENC-A-27]
CommitteeRecord = [targetEpoch, cutoffL1Block, checkpointIndex, setRoot, totalPower]
// [ENC-A-28]
RegistryEntry   = [ckPrefix, ckX, effStake, activeFromL1, exitEffectiveL1]
```

```txt
// [ENC-A-29]
cutLeaf(x)  = keccak256(abi.encode(uint256(x), blockHash(x), cometHash(x), forcedHead(x)))   // 4 words
  // blockHash(x) and cometHash(x) are the bytes32 EL and CometBFT block hashes at L2 height x,
  //   forcedHead(x) is the uint256 FI cursor at x
K           // grid interval: a protocol constant with 1 <= K <= 6 whose value is not fixed yet (section 11);
            //   heights count from the Etna start (block 0); landings end only at multiples of K, so every
            //   checkpoint height, including generation starts, is one
// [ENC-A-30]
cutHash     = keccak256(abi.encode(bytes32("ETNA_LAND_CUTS_V1"),
                uint256(generation), uint256(p), uint256(h),
                keccak256(abi.encodePacked(cutLeaf(p+K), cutLeaf(p+2K), .., cutLeaf(h-K)))))
  // [ENC-A-31]
  // the inner list has the (h-p)/K - 1 grid-point leaves strictly between p and h, in height order;
  // [ENC-A-32]
  //   it is empty, hashed as keccak256(""), when h = p+K
  // land(input, leaves, proof): leaves = that list; calldata = 32 bytes per leaf
  // [ENC-A-33]
  // execution: require p % K == 0, h % K == 0 and leaves.length == (h-p)/K - 1 (c >= h is rejected as
  // [ENC-A-34]
  //   already settled); if c > p, leaves[(c-p)/K - 1] must equal cutLeaf(c) computed from c's slot 285
  //   record; the FI cursor in that record must equal the current FI head; all of these run before
  //   proof verification

// [ENC-A-35]
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
// [ENC-A-36]
committeeConfigHash = keccak256(abi.encode(bytes32("ETNA_PARENT_ANCHOR_V1"), l2ChainId, registry,
  vp_unit, s_min, n_max, U))  // 7 words, 224 bytes

// [ENC-A-37]
regLeaf(j)  = keccak256(abi.encode("ETNA_REG_ENTRY_V1", j, ckPrefix, ckX, effStake, activeFromL1,
                exitEffectiveL1))
// [ENC-A-38]
entriesRoot = leaves zero-padded to a power of two, inner nodes keccak256(left || right); one entry gives its leaf, none gives 0

// [ENC-A-39]
setKey(ck)  = keccak256(abi.encode("ETNA_SET_KEY_V1", l2ChainId, ckPrefix, ckX))
// [ENC-A-40]
setLeaf(i)  = keccak256(abi.encode("ETNA_SET_LEAF_V1", l2ChainId, k, i, ckPrefix, ckX, effStake, assignedPower))
// [ENC-A-41]
setNode     = keccak256(abi.encode("ETNA_SET_NODE", l2ChainId, k, left, right))  // an odd last node is promoted unchanged
// [ENC-A-42]
record      = keccak256(abi.encode("ETNA_COMMITTEE_V1", l2ChainId, targetEpoch, cutoffL1Block,
                checkpointIndex, setRoot, totalPower))
k           = targetEpoch + 1
```

```txt
// [ENC-A-43]
voteSignBytes = uvarint(len(cv)) || cv                  // same as CometBFT VoteSignBytes
// [ENC-A-44]
cv = [0x08 varint type]                                 // 1 = prevote, 2 = precommit
  || [0x11 int64_le(height)]                            // 8 bytes little-endian
  || [0x19 int64_le(round)]
  || [0x22 len blockId]                                 // omitted for a nil vote (hash, total, partsHash all zero)
  || 0x2a len timestamp                                 // always written
  || 0x32 len chainId                                   // exact 48-byte chain_id computed above
  blockId   = [0x0a len hash] || 0x12 len psh
  psh       = [0x08 varint total] || [0x12 len partsHash]
  timestamp = [0x08 varint seconds] || [0x10 varint nanos]
  // [ENC-A-45]
  // fields in [ ] are omitted when zero or empty; len is a uvarint length prefix
// [ENC-A-46]
signer   = ecrecover(keccak256(voteSignBytes), V + 27, R, S)   // 65-byte R‖S‖V, V ∈ {0,1}, S ≤ n/2
// register(bytes publicKey, uint256 amount, bytes popSig)
// [ENC-A-47]
// publicKey is exactly 33 raw bytes: ckPrefix (0x02/0x03) || uint256_be(ckX).
// [ENC-A-48]
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
// [ENC-A-49]
ckAddr   = keccak256(uint256_be(ckX) || uint256_be(ckY))[12:]
// The 0x04 uncompressed prefix is not hashed. Require nonzero matching PoP recovery.
// Store ckPrefix/ckX only. slashDoubleSign(bondId,voteA,voteB) derives Y from that stored key.

registerDigest  = keccak256(0x1901 || domainSeparator ||
                    keccak256(abi.encode(keccak256("Register(address owner)"), owner)))
domainSeparator = EIP-712 domain: name "EtnaStakingRegistry", version "1", chainId = L1 chain id, verifyingContract = registry
// [ENC-A-50]
// popSig: exactly 65 bytes R || S || V; V in {0,1}, 0 < R < n, 0 < S <= n/2.
popSigner = ecrecover(registerDigest, V + 27, R, S)
require popSigner != address(0) and popSigner == ckAddr

// Recovery call: recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil,
//                        Exclusion[] exclusions, uint256[] fiToClear)
// [ENC-A-51]
// Exclusion = (uint256 bondId, bytes32 entryKey), sorted strictly by bondId.
// [ENC-A-52]
// invalidateRecoveryNonce(uint256 expectedRecoveryNonce): Inbox owner only.
// [ENC-A-53]
// recoveryNonce is uint256; validUntil is uint256 L1 Unix seconds.
// Registry: topUp(uint256 bondId, uint256 amount); activateTopUp(uint256 bondId).
// [ENC-A-54]
// Registry: forfeit(uint256 bondId, bytes32 entryKey, bytes32 incidentId, uint256 validUntil).
// [ENC-A-55]
// forfeit is registry-owner-only, once per lifetime entryKey; no forfeiture nonce or revocation.
// Events: TopUpDeposited(bondId, amount, readyAtL1), TopUpActivated(bondId, amount),
//         Forfeited(bondId, entryKey, incidentId, balanceBefore, penalty),
//         RecoveryNonceInvalidated(oldNonce, newNonce).
// Event identifiers/amounts/nonces are uint256; readyAtL1 is uint48; keys/incidentId are bytes32.
// entryKey = keccak256(abi.encode(ckPrefix, ckX)) identifies the slot's current occupant.
// Only the Inbox owner may call recover; require all three expected values and validUntil (8.3).
```

## Appendix B: L1 storage layout

| `EtnaInbox` slot               | Content                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[STOR-B-1]** 258             | Initialization status (3 after initialization); not in the anchor witness                                                                                                                                                                                                                                                                                                                                                             |
| **[STOR-B-2]** 268 / 269       | `recoveryGeneration` / `committeeConfigHash`                                                                                                                                                                                                                                                                                                                                                                                          |
| **[STOR-B-3]** 270 / 271       | `lastCheckpoint` height / hash                                                                                                                                                                                                                                                                                                                                                                                                        |
| **[STOR-B-4]** 272 / 273 / 274 | `[genesisHeight, L1_0, L]` / genesis hash / genesis stateRoot                                                                                                                                                                                                                                                                                                                                                                         |
| **[STOR-B-5]** 278 / 279       | Committee 0 record hash / `genesisCutoff`                                                                                                                                                                                                                                                                                                                                                                                             |
| **[STOR-B-6]** 280 / 281       | Forced inclusion queue (two words per entry: `txHash`; packed timestamp and L1 block number, with the remaining bits zero and unused. No charge is stored. `txHash` changes only when governance recovery in section 8 overwrites it with `keccak256("")`) / `head`, `tail`                                                                                                                                                           |
| **[STOR-B-7]** 282             | `forcedInclusionDelay`, `maxAnchorAge` (seconds)                                                                                                                                                                                                                                                                                                                                                                                      |
| **[STOR-B-8]** 283 / 284       | Reserved: no reads, writes or reuse / activeCommitteeSnapshot (set to genesisCutoff at Inbox initialization)                                                                                                                                                                                                                                                                                                                          |
| **[STOR-B-9]** 285             | landing mapping, lastHeight → three words: word 1 packs actual parentHeight=c, generation and head; words 2/3 are EL/Comet hashes. Initialize block 0 with parent/generation/head=0, EL hash = genesis hash and Comet hash=0. Retain original recovery-origin records; proof origin p never replaces actual parent. Historical parent links and old-p records serve overlapping proofs and public reconstruction and are never pruned |
| **[STOR-B-10]** 286 / 287      | Reserved: no reads, writes or reuse                                                                                                                                                                                                                                                                                                                                                                                                   |
| **[STOR-B-11]** 288            | Reserved: no reads, writes or reuse                                                                                                                                                                                                                                                                                                                                                                                                   |
| **[STOR-B-12]** 289            | Reserved: no reads, writes or reuse                                                                                                                                                                                                                                                                                                                                                                                                   |
| **[STOR-B-13]** 290            | Fixed per-generation origin mapping: (startHeight,l1BlockNumber,l1Timestamp), each a uint256 word with height/block/timestamp range checks; store three consecutive words from the mapping base keyed by generation. Includes generation 0 under 8.4, with no latest cache and no ordinary anchor-witness addition                                                                                                                    |
| **[STOR-B-14]** 291            | Reserved: no reads, writes or reuse                                                                                                                                                                                                                                                                                                                                                                                                   |
| **[STOR-B-15]** 292            | uint256 recoveryNonce, initially 0; monotonically increased under 8.3, including verifier-failure rollback; not part of ordinary anchor witnesses                                                                                                                                                                                                                                                                                     |

**[STOR-B-16]** Nodes verify the latest checkpoint under 3.3/3.4, its slot 285 record under section 9, and slot 290 for startup, recovery and proving under 8.4. **[STOR-B-17]** Reserved slots 283, 286–289 and 291 are neither read nor written. Slot 284 serves exit confirmation; 285 retains the history needed for overlapping proofs and reconstruction.

**[STOR-B-18]** Inbox stores only the recovery authorization nonce for invalidation, with no recovery queue or scheduling records (8.3). **[STOR-B-19]** Provide shared vectors for the layout and interfaces; other layouts are neither decoded nor migrated in place.

**[STOR-B-20]** The registry uses the ERC-7201 namespace `taiko.etna.registry` with base slot R. **[STOR-B-21]** Nodes read only two things: `checkpoints` at `R` (two words each: packed `l1Block` and `count`, then `entriesRoot`) and `entries` at `R + 1` (three words each: `ckX`, `effStake`, packed `ckPrefix`/`activeFromL1`/`exitEffectiveL1`). **[STOR-B-22]** exitEffectiveL1 = 2\^48 − 1 means no exit is set.

**[STOR-B-23]** **Packed words**: where this appendix packs several fields into one word (Inbox slots 272, 281 and 282, the second word of each 280 entry and the first word of 285; the registry's first checkpoint word and third entry word), the fields are laid out in the listed order from the least-significant bit. **[STOR-B-24]** ckPrefix takes 8 bits and every other field 48 bits; unused high bits are zero. **[STOR-B-25]** Writing a value wider than its field reverts.

**[STOR-B-26]** Exit confirmations use a separate ERC-7201 namespace, `taiko.etna.registry.exit-confirmations`, mapping bond id to `exitConfirmedAtL1` (0 means not confirmed). **[STOR-B-27]** This does not use the entry layout, enter regLeaf/entriesRoot or create a committee checkpoint; clear it on slot release. **[STOR-B-28]** The owner lives in a separate namespace, `taiko.etna.registry.owners`, indexed by bond id: written at registration and cleared on slot release. **[STOR-B-29]** It also stays out of entriesRoot, and nodes do not read it. Validate the concrete layout, including slot 290, through layout checks and shared vectors.

**[STOR-B-30]** Top-ups use ERC-7201 namespace `taiko.etna.registry.top-ups`: a mapping at its base keyed by uint256 bondId, with uint256 pendingTopUp at the mapping element and uint48 topUpReadyAtL1 in the next word (unused bits zero). **[STOR-B-31]** Clear both on slot release. **[STOR-B-32]** Lifetime forfeiture flags use namespace `taiko.etna.registry.forfeitures`, a mapping at its base from bytes32 entryKey to bool forfeited (initially false; stored as 0 or 1 and never cleared). **[STOR-B-33]** Neither namespace enters regLeaf/entriesRoot or is read by nodes/guests; only changes to existing entry fields affect committee checkpoints. **[STOR-B-34]** Preserve flags through verifier-failure rollback. Validate these namespaces and Inbox slot 292 with shared layout vectors.

## Appendix C: Operating funding and cost assumptions

This appendix states operating requirements, not validity rules.

- **[COST-C-1]** **The DAO funds operations**: validators, proving, landing, historical data and on-call service, including low/zero transaction load, FI consumption, repeated DA, discarded competitive work and retries. **[COST-C-2]** Landing has no protocol revenue (base fees and tips go to proposers, FI fees to the protocol); this operating budget covers all landing and proving costs.
- **[COST-C-3]** **How funding is paid**: funding grants no exclusive landing permission. **[COST-C-4]** Landers do not receive FI fees, and funding is not paid per FI entry consumed or by FI fee value, so an attacker cannot recover its FI fees through funding (7.3). **[COST-C-5]** land binds no recipient and a public blob transaction can be copied, so DAO compensation must not be a per-landing bounty paid to the submitting address; fund named operators or attribute work off chain.
- **[COST-C-6]** **Fund the sustained worst case**: measure and fund the budget for the operating targets of approximately 4 s blocks and at most 20 min between L1 inclusions of successive successful landings (6.4); cost estimates alone are not evidence that funding is in place. **[COST-C-7]** A proposer pays no net fee for any load in its own blocks (3.2), whether zk-heavy or data-heavy; such load is bounded only by the per-block gas, zk-gas and 124,000-byte (3.4) limits. **[COST-C-8]** Without zk-to-charged-gas conversion, a zk-heavy workload with low EVM gas may use almost the whole per-block zk-gas limit. **[COST-C-9]** The data worst case is every block filled with incompressible data. **[COST-C-10]** A landing carries at most six blobs, hence six blocks, and must end at a grid point, so each covers m blocks, where m is the largest multiple of K not above 6: about 900/m landings an hour, which is about 150 when K divides 6, about 225 at K = 4 and about 180 at K = 5. **[COST-C-11]** Whatever K is, that is 3 blobs per L1 slot. **[COST-C-12]** Fund that sustained worst case explicitly in the proving, blob and landing budgets.

[Etna Acceptance and Launch Checklist](ACCEPTANCE.md)
