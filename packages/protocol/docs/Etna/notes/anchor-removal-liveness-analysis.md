# Anchor removal: checkpoint reveal and bridge liveness

Analysis date: 2026-10-01. Source baseline: `7217121d516ce37e8c1684d168d6e5b525f8765c`; all seven Etna design pages and the supplied issue #22147 discussion were reviewed. This is a design analysis, not implemented or benchmarked contract behavior. **Proposed** denotes the recommended rule; **proven** denotes a deduction under the stated assumptions; **open** denotes a launch validation obligation.

## Recommendation

Keep the selected issue direction: every Etna L2 header has `parentBeaconBlockRoot = segment.origin.hash`, the authenticated L1 **execution** header hash; upstream EIP-4788 records it, and upstream EIP-2935 records L2 parent hashes. Remove the anchor transaction without adding a Taiko pre-execution hook or requiring any ordinary transaction at index zero. Use ordinary permissionless header-preimage reveals on the retained L2 SignalService. [Issue direction](https://github.com/taikoxyz/taiko-mono/issues/22147#issuecomment-5756531478), [origin authentication](../design/index.html#origin), [EIP-4788](https://eips.ethereum.org/EIPS/eip-4788#block-processing), [EIP-2935](https://eips.ethereum.org/EIPS/eip-2935#block-processing).

Add the small ordinary-call fallback `pinCurrentOrigin()`: read EIP-4788 at the executing block's timestamp and persist membership of that authenticated hash. A forced pin selects the origin **when it eventually executes**, so its calldata never names an expiring timestamp. A later reveal can authenticate against that permanent pin. This adds one explicitly allocated mapping, paid for by callers, and closes the FIFO/expiry gap without a historical light client, a periodic keeper, a mandatory reveal, or an enlarged ring.

Use a common **1,536-byte maximum L1 header** in the Etna HeaderStore and L2 reveal parser. This tightens the previous 4,096-byte Etna-origin parser bound so every admissible origin can be revealed through the existing 2,048-byte forced-transaction envelope. Preserve the separately specified legacy-drain header bound; it authenticates another historical format and is not this new-origin bound. Conformance of the launch L1 header schema with 1,536 bytes remains a launch condition. [Existing parser](../design/codec.html#l1-header), [forced limits](../design/index.html#forced), [legacy drain](../design/migration.html#drain-adapter).

The direct reveal remains the normal inexpensive path. Fresh-root reproof remains the recovery for persistent source signals when their originally selected checkpoint was never revealed or pinned. The pin path removes reliance on timely discretionary inclusion for **checkpoint acquisition**. It does not make every possible Bridge message fit the separately bounded force path.

## Why the ring alone does not establish liveness

EIP-4788 stores a timestamp tag at `i = timestamp % 8191` and the associated root at `i + 8191`. A getter takes exactly the raw 32-byte encoded timestamp, with no Solidity selector; it checks the tag. Under Etna's strictly increasing L2 timestamps, a later block cannot collide with timestamp `t` while `0 < laterTimestamp - t < 8191`. At `t + 8191`, a block can overwrite the slot. It is therefore a guaranteed **strictly less than 8,191 seconds of L2 timestamp advancement**, not the last 8,191 arbitrary timestamps and not an unconditional 4.5-hour window. At exactly two seconds per block, matching residues recur after 16,382 seconds; arbitrary gaps invalidate that cadence calculation. A tag can remain readable much longer if no colliding block is produced. Do not add a hard TTL that rejects an otherwise matching tag. [EIP-4788 contract](https://eips.ethereum.org/EIPS/eip-4788#beacon-roots-contract), [accepted issue correction](https://github.com/taikoxyz/taiko-mono/issues/22147#issuecomment-5756503026).

This is not an off-chain wall-clock timer: while L2 is halted its storage is unchanged, but it cannot execute a reveal either. The first recovery block can jump to a colliding timestamp and overwrite an old entry before any ordinary transaction runs. Conversely, that same block records its **new current origin** before ordinary execution, making a current-origin pin possible immediately.

Etna force requests never expire. They mature after 120 seconds; parent-frozen snapshots and the 900-second origin-age ceiling guarantee eventual processing on a progressing chain; each accepted successor consumes at most four eligible requests. There is no queue-length cap or uniform short service deadline. The existing conditional bound is:

```text
processedAt <= enqueuedAt + 1020 + (1 + ceil((p + 1) / 4)) * delta
```

Here `p` is the finite earlier backlog and `delta` bounds accepted-segment spacing under A-LIVE. At the illustrative `delta = 660 seconds`, `p = 39` already gives 8,280 seconds, exceeding the 8,191-second no-collision interval even before accounting for the age of the selected ring entry at enqueue. This is a conservative service bound, not a proof that every such request waits that long. An arbitrarily large paid backlog or outage plainly permits such a delay; increasing a finite ring cannot cover every backlog. [FIFO theorem and limits](../design/arguments.html#l2), [core rule](../design/index.html#forced), [role economics](../design/roles.html#competition).

A concrete failure trace is: a user queues `revealCheckpoint(t, header)`; earlier requests delay execution; canonical blocks advance until one uses timestamp `t + k*8191`; that slot now has a different tag; the reveal executes and reverts. Repeating with a fresh timestamp can fail indefinitely if each new attempt joins a sufficiently long backlog. A-INCLUDE(120) concerns funded valid **L1** transactions; it does not mean an arbitrary discretionary L2 transaction is included within 120 seconds. Even a capable self-prover may repeatedly lose to valid competing children. The current design explicitly declines ordinary mempool fairness. [Assumption ledger](../design/arguments.html#assumptions), [accepted limits](../design/arguments.html#limits).

## Exact ordinary-call fallback

The following is an extension interface sketch on the existing L2 SignalService, not an implementation or new custody address:

```solidity
interface IEtnaCheckpointReveal {
    /// @notice Permanently records the executing block's authenticated L1 origin hash.
    /// @dev Reads the standard EIP-4788 contract at block.timestamp; ordinary gas applies.
    /// @return originHash_ The origin hash recorded or already present.
    function pinCurrentOrigin() external returns (bytes32 originHash_);

    /// @notice Persists an authenticated L1 checkpoint from its complete header.
    /// @dev Timestamp zero selects a permanently pinned hash; a nonzero timestamp selects EIP-4788.
    /// @param _l2Timestamp Zero for pin mode, otherwise the exact recorded L2 timestamp.
    /// @param _headerRlp The complete canonical L1 execution header, at most 1536 bytes.
    /// @return checkpoint_ The identical existing or newly persisted checkpoint.
    function revealCheckpoint(uint64 _l2Timestamp, bytes calldata _headerRlp)
        external returns (ICheckpointStore.Checkpoint memory checkpoint_);

    /// @notice Reports whether an authenticated origin hash was permanently pinned.
    /// @param _originHash The L1 execution header hash.
    /// @return pinned_ Whether pinCurrentOrigin has recorded the hash in this history.
    function isOriginPinned(bytes32 _originHash) external view returns (bool pinned_);

    event OriginPinned(bytes32 indexed originHash, uint64 indexed l2Timestamp);
}
```

**Proposed pin semantics:**

1. Require the explicit L2/post-cutover reveal mode. L1 disables the entire extension; legacy L2 execution does not acquire new checkpoint authority. The migration must bind this gate to its exact authenticated boundary.
2. `staticcall` canonical EIP-4788 address `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` with `abi.encode(uint256(block.timestamp))`. Require success, exactly 32 return bytes, and a nonzero hash. No caller chooses a timestamp or root.
3. If absent, set `pinnedOrigins[hash] = true` and emit `OriginPinned(hash, checkedUint64(block.timestamp))`. If already present, return the hash without changing state or emitting another first-pin event. An event is informational; the persistent mapping is the authorization evidence.
4. There is no pin owner, fee claim, expiry, replacement, deletion, enumerable array or governance pruning function. Anyone pays ordinary transaction gas. Lifetime state grows with distinct paid pins; work per call is bounded. A hash does not become a usable state-root checkpoint until its full header is revealed.

**Proposed exact storage allocation:** keep SignalService VERSION 1, existing linear fields, gaps, received caches, checkpoint mapping and hashed sent-signal slots unchanged. Allocate a new ERC-7201-style namespace:

```text
P = keccak256(abi.encode(
      uint256(keccak256("taiko.etna.origin-pins.v1")) - 1
    )) & ~bytes32(uint256(255))

word P: mapping(bytes32 originHash => bool pinned)
entry slot: keccak256(abi.encode(originHash, P))
default: false; sole ordinary transition: false -> true
```

Preflight must compare this exact namespace against the deployed linear, EIP-1967, custom, transient and hashed-signal domains. The previous migration statement “zero new shared persistent slots” must be revised to disclose this one mapping root and its entries; an unspecified storage gap is not the allocation. Pin membership survives honest upgrades. [Preserved layouts and allocation obligation](../design/migration.html#slots), [source SignalService layout](../../../contracts/shared/signal/SignalService_Layout.sol).

**Proposed reveal semantics:**

1. Check the explicit L2/post-cutover mode and bound bytes before allocation. Parse a single complete canonical RLP list with 12–32 top-level fields, no trailing bytes and no nonminimal lengths or integers. Use the same bounded stable-prefix parser as HeaderStore, with the common 1,536-byte maximum. Extract parentHash item 0 and stateRoot item 3 as exactly 32 bytes; require stateRoot nonzero; number item 8 and timestamp item 11 must fit uint48 before narrowing. Hash the entire header, including every appended field.
2. If the existing VERSION-1 checkpoint at that number is present, require identical hash and state root, and return it. Conflicts revert. This idempotent path works after ring expiry and handles front-running without changing an existing record.
3. Otherwise, with `_l2Timestamp == 0`, require `pinnedOrigins[headerHash]`. Zero is solely a **SignalService mode selector**; it is never queried in EIP-4788 and is not an execution timestamp.
4. Otherwise require an eligible post-cutover L2 timestamp, query EIP-4788 with its raw 32-byte word, and require successful exact 32-byte nonzero return equal to the complete header hash. A missing/overwritten tag reverts. Do not accept a caller-supplied block number, root, event or RPC-finality assertion as authentication.
5. Write the existing checkpoint tuple and emit existing `CheckpointSaved`. Require nonzero stored hash/root, make repeats idempotent, prohibit conflicting overwrite and permit out-of-order reveals. No latest-height pointer is necessary; any separately added pointer must be a maximum, not the most recently revealed height.

The current source already rejects a missing checkpoint through `_getCheckpoint`; maintain that behavior and its root check. `HopProof`, the remote SignalService address, signal slots and `LibTrieProof` remain unchanged for the separate reveal flow. On L1, Inbox continues to publish accepted L2 checkpoints. On post-cutover L2, the old Anchor-authorized `saveCheckpoint` route must be disabled; the public old anchor signer cannot remain a second root authority. [SignalService](../../../contracts/shared/signal/SignalService.sol), [checkpoint ABI](../../../contracts/shared/signal/ICheckpointStore.sol), [issue contract review](https://github.com/taikoxyz/taiko-mono/issues/22147#issuecomment-5756081071).

## Why the pin is insensitive to FIFO delay

Assume a source signal was included in canonical L1 block `S`, and a user subsequently enqueues a valid signed `pinCurrentOrigin()` transaction in block `Q`. Let the request eventually execute in an Etna segment with origin `O`.

The parent's due snapshot includes the enqueue block and has timestamp at least enqueue time plus 120 seconds. The child origin is nondecreasing in number and timestamp from that parent origin. Consequently `O.number >= Q.number >= S.number`. Its authenticated full L1 state therefore includes the previously sent **persistent** signal. The current block's upstream EIP-4788 write has already run, so the pin records exactly `O.hash`, independently of queue delay and independently of any earlier ring collision. [Snapshot and consumption rules](../design/index.html#forced), [origin monotonicity](../design/index.html#origin).

After observing canonical processing, the user obtains `O`'s complete header, calls or forces `revealCheckpoint(0, headerOfO)`, and prepares the normal source-signal witness against `O.stateRoot`. Since the pin does not expire, this second call survives another arbitrarily long **finite** FIFO backlog. Another caller revealing first is harmless. The resulting checkpoint likewise remains usable indefinitely within that canonical history and the honest-upgrade assumption.

The user must keep each raw transaction state-valid: use a funded ordinary account with its intended nonce still available, sufficient gas, an empty access list for the byte bound below, and a fee cap covering the supported basefee. The stated Etna maximum basefee is 1 gwei; a cap at least that high covers basefee validity, and any selected priority fee must also fit the cap. Avoid spending the account's nonce/balance through another transaction while waiting. These are normal transaction conditions, not an authorization role. Gas repricing or a future execution revision may require fresh transactions; no immutable signed transaction is promised compatibility with every future fork. [Ordinary fees and clamp](../design/codec.html#fees), [force outcomes](../design/index.html#verifier-interface).

This proof establishes eventual checkpoint acquisition under canonical progress, affordable funding, ordinary transaction validity, authentic source-header/witness availability and honest upgrades. It does not set a uniform completion deadline or require any incumbent relayer to remain online. During pre-ACTIVE draining, queued new Etna requests remain behind the finite legacy work and the first ordinary snapshot; the same pin remains meaningful after activation. [Migration FIFO initialization](../design/migration.html#bootstrap), [all-incumbent recovery](../design/staging.html#recovery).

## Exact forced-reveal byte budget

For `revealCheckpoint(uint64,bytes)` and a maximum-length 1,536-byte header, canonical ABI calldata is:

```text
selector + timestamp + bytes offset + bytes length + padded header
   4     +    32     +     32       +      32      +     1536
= 1636 bytes
```

Use a normal signed type-2 transaction, destination SignalService, zero value, empty access list, uint64 nonce, gas limit at most 1,000,000, and uint256 chain ID and fee fields. A conservative canonical signed-RLP upper bound is:

| Field | Maximum encoded bytes |
| --- | ---: |
| Chain ID | 33 |
| Nonce | 9 |
| Priority fee | 33 |
| Maximum fee | 33 |
| Gas limit | 4 |
| Destination | 21 |
| Zero value | 1 |
| Calldata including its RLP prefix | 1,639 |
| Empty access list | 1 |
| Signature parity | 1 |
| Signature r | 33 |
| Signature s, conservatively | 33 |
| RLP list prefix plus transaction type | 4 |
| **Total** | **1,845** |

Thus it has **203 bytes of margin** under 2,048, including the signature and envelope. Shorter canonical integers only reduce this bound. `pinCurrentOrigin()` has only four bytes of call data and trivially fits the same form. This arithmetic was independently evaluated with a small scratch calculation; no contract gas benchmark was run.

The proposed common 1,536-byte parser cap is necessary for the simple “every admissible origin has a forceable reveal” statement. Keeping a 4,096-byte admissible header but merely recommending a 1,536-byte client limit would not prove it. A future L1 fork exceeding the cap requires a reviewed parser/force-envelope revision before Etna can use those headers; silent truncation or prefix-only hashing is forbidden. The stricter bound applies to Etna origin import and reveal, not historical legacy end headers. The implementation must also establish worst-case execution within the existing one-million-gas force limit; byte fit alone is not a gas result. [Codec bounds](../design/codec.html#l1-header), [launch measurements](../design/arguments.html#launch).

## Persistent signals are narrower than historical state

Current `sendSignal(s)` writes `s` to the separately hashed storage slot for `(sourceChainId, msg.sender, s)`. The current implementation has no ordinary clear operation; sending the same signal writes the same nonzero value. For this specific fact, a newer canonical state at or after the send contains the same signal, provided the source SignalService/address/storage semantics survive upgrades. A user can obtain a **new** Merkle witness under a newer revealed root. An old witness does not verify against the new root merely because the signal survived. [SignalService send/slot/proof implementation](../../../contracts/shared/signal/SignalService.sol), [historical-message rule](../design/migration.html#history).

Do not generalize this to “a newer root proves everything an older root did.” Balances, approvals, contract code, arbitrary storage, receipt roots, transaction roots and overwritten caches can change. A state root does not contain historical receipts or every previous storage value. A timestamp tag overwritten in EIP-4788 is itself a direct counterexample. Historical proof consumers require a retained authenticated old checkpoint or an explicitly designed historical proof path.

The local `_receivedSignals[VERSION]` boolean cache is a different fact: a successful verification was previously performed on the destination. Preserve its existing namespace so an empty proof can still use that authenticated result. It is not a source sent-signal slot, and an arbitrary cache value cannot be re-derived from a later remote root without its own proven semantics. Preserve old valid checkpoints and caches rather than treating reproof as a license to delete them. [Current proof interface](../../../contracts/shared/signal/ISignalService.sol), [migration history](../design/migration.html#history).

An old checkpoint that was neither revealed nor pinned and whose ring entry was overwritten is **not reconstructible on chain through this API**. A user wanting a persistent source signal instead pins the current origin, reveals it and obtains a witness there. Exact old roots for transient state are outside this recovery guarantee. Already stored legacy checkpoints remain supported; no VERSION bump or migration reset is justified.

Witness availability is an explicit premise. A retained hash proves authenticity but cannot reconstruct its header bytes or a state-trie witness. Extend the existing A-ARCHIVE/A-RETRIEVE description to include a reachable L1 header and proof source for the selected checkpoint, or a user-retained valid witness. Fresh source-state access can recover a persistent signal even when a particular historical proof provider is missing; if all usable state/archives are lost, a proof or hash alone cannot repair that loss. Optional custodians have finite publication duties and are not perpetual archive guarantors. [Assumptions](../design/arguments.html#assumptions), [DA lifetime](../design/staging.html#lifecycle), [custody-duty limits](../design/accountability.html#limits).

## Failure and recovery behavior

| Condition | Required behavior |
| --- | --- |
| Direct timestamp reveal reaches an overwritten entry | Ordinary application revert; no checkpoint write. A state-valid forced transaction receives outcome 4, its exact failed receipt is committed and the FIFO cursor advances. It cannot block the queue, invalidate the whole segment or be replaced by a silently refreshed call. |
| Reveal transaction is nonce/balance/basefee invalid | Existing outcome 2 under the selected Ethereum validity rules; consume that forced record with no receipt. The caller must submit a fresh valid transaction if still needed. |
| Pin or reveal lacks enough execution gas | Ordinary failed transaction/outcome 4 if transaction-valid; state effects revert. Launch gas bounds must make a correctly funded supported call feasible. |
| Exact checkpoint was already saved | Idempotent success even after oracle expiry; preserve its hash/root and avoid duplicate new-checkpoint state. |
| Same L1 height is supplied with a different hash or root | Reject. A pinned or live oracle value cannot overwrite conflicting stored checkpoint state. Investigate implementation or history mismatch. |
| All incumbent relayers leave | Users or replacement relayers can make direct calls or force the compact pin and reveal. No relayer key, assignment, stake or registry membership is needed. Users fund fees; voluntary silence is not automatically slashable. |
| All capable provers leave | L2 stops accepting successors, so no new L2 claim can execute. Existing finalized L2 roots on L1 can still support otherwise-valid L2-to-L1 claims. Recovery requires a capable funded entrant and retained data, not a DAO timeout that creates a root. |
| L2 resumes after a long timestamp gap | Old ring reads may succeed or fail according to their tag. A forced current-origin pin reads the new block's already written origin and remains usable; it need not revive the old timestamp. |
| L1 reorg or competing soft L2 branch | Follow canonical derivation. Rolled-back pins, reveals, cache writes and claims have no force in the replacement history. A soft pin event is not finality. Re-fetch canonical roots and witnesses; finality follows the containing L1 acceptance under A-L1. |
| Missing header or proof witness | Remain unavailable/UNKNOWN; fetch from another authenticated source or pin a fresh origin for a persistent signal. Never substitute an RPC assertion or arbitrary root. |
| Bridge message/proof exceeds force caps | Do not claim FIFO coverage. Ordinary paid L2 inclusion or a successful public self-built segment remains permissionless, but eventual inclusion of that discretionary operation requires its own inclusion/competition conditions. A new generic staged-proof adapter is outside this change. |

The outcome distinction follows the existing tags: 0 malformed, 1 unsupported/protocol restriction, 2 state-invalid, 3 executed successfully, 4 executed and reverted. Ring expiry is a contract-execution condition, not an ordinary Ethereum transaction-validity condition. Forced fees settle and the cursor advances according to existing proved processing; an application revert does not refund or retain that request by special rule. [Outcome ABI](../design/index.html#verifier-interface), [forced codec](../design/codec.html#forced), [escrow treatment](../design/roles.html).

General bridge-proof size is a preexisting limitation: the source Bridge permits relayer proofs up to 200,000 bytes, whereas Etna's whole forced transaction is capped at 2,048 bytes and one million gas. An optional combined reveal-and-claim envelope does not cure that mismatch. Preserve separate reveal plus existing proof semantics; a successfully cached signal can reduce later proof bytes to empty, but its first proof and the message itself must still be included. Do not promise arbitrary Bridge application success, arbitrary recipient gas, or universal censorship resistance for oversized operations. [Bridge proof limit and processing](../../../contracts/shared/bridge/Bridge.sol), [accepted force scope](../design/arguments.html#limits).

## Alternatives and why the pin is smaller

| Alternative | Benefit | Remaining limitation or additional machinery |
| --- | --- | --- |
| Fresh direct reveal and source-signal reproof only | No new persistent mapping; suitable normal operation. | Requires a reveal to execute while its fixed timestamp remains readable. Long FIFO delays and discretionary censorship leave a liveness gap unless an additional timely-L2-inclusion assumption is stated. |
| Authenticate a historical L2 header against EIP-2935, then read its parentBeaconBlockRoot | Extends access to the last 8,191 retained L2 block hashes; useful for some timestamp gaps. | Still finite, in **block numbers**, with no permanent backfill. Once the chosen L2 hash ages out, a fixed forced request can still fail. Requires another complete L2-header parser/witness path. BLOCKHASH's ordinary 256-block semantics are unchanged. |
| Chain arbitrary historical L2 headers to a recent authenticated hash | Can authenticate older ancestors while a recent anchor remains accessible. | Witness length grows with age; a bounded chain proof still needs multiple persistent steps, and a recursive succinct proof adds verifier/program/gas obligations. Fixed queued witnesses can become stale. |
| Prove an old L2 header from a finalized/accepted L1 receipt and block-hash membership | Can recover an old recorded origin using permanent L1 acceptance history. | L2 must first authenticate the L1 state/finality containing that receipt, retain its schema/domain, verify storage proofs and six-level block membership, and parse the old header. A self-asserted “finalized L2 header” is not an authentication source. Usually needs a fresh revealed L1 root, a light client or an additional immutable verifier. |
| Mandatory periodic reveals or a designated keeper | Makes common checkpoints persistent. | Either introduces required transaction behavior contrary to the selected scope or makes liveness depend on the keeper. Paid permissionless optional keepers are useful, but not the fallback proof. |
| Ordinary `pinCurrentOrigin()` plus later header reveal | Its fixed compact call survives FIFO delay and obtains a permanent authenticated future proof target. | Adds one paid persistent mapping, requires header/witness availability and preserves the existing force-size limits for subsequent application claims. |

[EIP-2935 bounded lookup](https://eips.ethereum.org/EIPS/eip-2935#specification), [accepted block-hash tree](../design/staging.html#block-tree), [permanent accepted receipts](../design/index.html#state), [issue storage comparison](https://github.com/taikoxyz/taiko-mono/issues/22147#issuecomment-5756310019).

## Required launch validation

This analysis adds no production code and reports no executed contract tests. The specification and future implementation should exercise: timestamp differences 8,190/8,191/8,192; irregular cadence and long gaps; repeated origins; direct reveal before/after collision; permanently pinned reveal after both rings have rotated many times; pin and reveal with long FIFO backlogs; idempotent front-running; conflicting checkpoints; parser canonicality and maximum lengths; exact 1,845-byte signed envelope; worst-case one-million-gas feasibility; source signals re-proved under a later root; preserved legacy roots and empty cache proofs; L1 and soft-L2 reorg rollback; all relayers absent; and delayed activation with queued pins.

Build, import and both proving backends must execute the **unmodified** upstream 4788/2935 state changes identically. Current-origin pinning assumes that parity and canonical deployed contract code. The migration disables old L2 checkpoint writers at the authenticated boundary, preserves existing custody/cache layouts, and enables reveals/pins only in the correct execution regime. Neither a failed deployment nor absent EIP-4788 code may turn a zero return into an accepted checkpoint. [Issue deployment ordering and corrections](https://github.com/taikoxyz/taiko-mono/issues/22147#issuecomment-5756503026), [migration preflight](../design/migration.html#preflight).
