// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaInbox
/// @notice The L1 Inbox of an Etna PoS chain: it records the Etna start S, lands proven batches
/// that end at any height above the checkpoint, keeps the forced inclusion queue, the rules
/// schedule, the DAO fallback key set and `minTotalStake`, and runs governance recovery.
/// @dev Section numbers refer to the Etna specification. S is block 0 on a new network and the last
/// Unzen block on a network that switches from Unzen. Nodes, guests and landers read the storage
/// layout of spec appendix B (slots 258-293) with EIP-1186 proofs; each struct names the slots it
/// occupies. Every packed word lays its fields out in declaration order from the
/// least-significant bit. This file has no imports so clients can copy it as is.
/// @custom:security-contact security@taiko.xyz
interface IEtnaInbox {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice The immutable parameters of an Inbox implementation (spec 11).
    struct Config {
        /// @notice The verifier of `land` proofs (spec 6.2).
        address proofVerifier;
        /// @notice The L1 SignalService that stores the landed L2 checkpoints.
        address signalService;
        /// @notice The `EtnaStaking` proxy on L2 whose snapshots select the committees (spec 4.1);
        /// non-zero. The third word of the config hash.
        address etnaStaking;
        /// @notice The chain id of the Etna L2; non-zero.
        uint64 l2ChainId;
        /// @notice The maximum `h - p` of one landing; at least 1 and at most 12,952 (spec 11).
        uint64 maxBatchBlocks;
        /// @notice The forced inclusion fee in Gwei with an empty queue (spec 7.1); non-zero.
        uint64 forcedInclusionFeeInGwei;
        /// @notice The number of pending forced inclusions at which the fee doubles; non-zero.
        uint64 forcedInclusionFeeDoubleThreshold;
        /// @notice The DAO treasury that receives the swept forced inclusion fees (spec 7.1);
        /// non-zero.
        address protocolFeeRecipient;
        /// @notice The live Unzen Inbox proxy on a switching network, which must have code; zero
        /// on a new network (PARAM-11-12a).
        address unzenInbox;
        /// @notice `ETNA_FORK_TIME` in L1 Unix seconds on a switching network; zero on a new
        /// network (PARAM-11-12a).
        uint48 etnaForkTime;
        /// @notice `U`, the maximum number of unsettled L2 blocks (spec 6.4), in [1, 262,144]; the
        /// fourth word of the config hash.
        uint64 unsettledLimit;
    }

    /// @notice A DAO fallback key (spec 4.3, appendix A): a secp256k1 consensus key in SEC1
    /// compressed form, `ckPrefix ‖ ckX`, which signs with voting power 1 whenever the staking
    /// candidate is not usable.
    struct FallbackKey {
        /// @notice The SEC1 prefix: 0x02 for an even Y, 0x03 for an odd Y.
        uint8 ckPrefix;
        /// @notice The X coordinate, big-endian and below the field prime.
        bytes32 ckX;
    }

    /// @notice The inputs of `init` (spec 10 step 5).
    struct InitParams {
        /// @notice The hash of L2 block 0 on a new network, non-zero; zero on a switching network,
        /// whose start `setOrigin` writes.
        bytes32 genesisBlockHash;
        /// @notice The state root of L2 block 0 on a new network, non-zero; zero on a switching
        /// network.
        bytes32 genesisStateRoot;
        /// @notice The initial fallback key list, checked as `setFallbackKeys` checks it.
        FallbackKey[] fallbackKeys;
        /// @notice The initial `minTotalStake`; any value.
        uint256 minTotalStake;
        /// @notice The forced inclusion delay in seconds, in [1, 2^48) (spec 7.2).
        uint256 forcedInclusionDelay;
        /// @notice The maximum anchor age in seconds, in [1152, 2^48) (spec 3.4).
        uint256 maxAnchorAge;
    }

    /// @notice The public inputs of `land` (spec 6.1): seven fields.
    struct LandInput {
        /// @notice `p`: the proof origin, a retained checkpoint at or below `c`.
        uint256 parentHeight;
        /// @notice `h`: the terminal height, any height above `c`.
        uint256 lastHeight;
        /// @notice The EL block hash at `h`.
        bytes32 lastBlockHash;
        /// @notice The CometBFT block hash at `h`.
        bytes32 lastCometHash;
        /// @notice The EL state root at `h`.
        bytes32 lastStateRoot;
        /// @notice The L1 block whose header chain holds every anchor and proving root used.
        uint256 l1ReferenceBlockNumber;
        /// @notice The forced-inclusion cursor at `h` (the spec's "FI cursor"): the number of queue
        /// entries L2 has consumed through `h`. The Inbox queue head (slot 281) equals it once `h`
        /// is the checkpoint.
        uint256 forcedInclusionHead;
    }

    /// @notice The landed checkpoint (`lastCheckpoint`, slots 270/271): the latest landed L2 block
    /// `c` as (height, EL block hash).
    /// @dev Distinct from the SignalService checkpoint (height, block hash, state root).
    struct LandedCheckpoint {
        /// @notice The L2 height.
        uint48 height;
        /// @notice The EL block hash.
        bytes32 blockHash;
    }

    /// @notice The start record (slots 272-274); slot 272 packs the two 48-bit fields, and its
    /// bits from 96 up are zero.
    /// @dev The struct and `genesisHeight` keep appendix B's names, but `genesisHeight` holds the
    /// Etna start S, and slots 273 and 274 hold the start block's hash and state root: those of
    /// L2 block 0 only on a new network. The start write writes every field, and the start is
    /// written exactly when `startBlockHash` is non-zero.
    struct GenesisRecord {
        /// @notice The Etna start S: block 0 on a new network, the last Unzen block on a switching
        /// network.
        uint48 genesisHeight;
        /// @notice `L1_0`: the L1 block of the start write.
        uint48 l1Block;
        /// @notice The EL block hash of the start block S (slot 273).
        bytes32 startBlockHash;
        /// @notice The state root of the start block S (slot 274).
        bytes32 startStateRoot;
    }

    /// @notice The rules schedule (slot 293, spec 10.1), packed from the least-significant bit.
    /// @dev Zero at initialization: ruleset 0, nothing scheduled and no stop.
    struct RulesSchedule {
        /// @notice The ruleset of blocks before `rulesTime`.
        uint48 activeRules;
        /// @notice The ruleset of blocks at or after `rulesTime`.
        uint48 nextRules;
        /// @notice The L2 timestamp from which `nextRules` applies; 2^48 - 1 cancels it.
        uint48 rulesTime;
        /// @notice The planned stop time; zero means no stop.
        uint48 stopTime;
    }

    /// @notice The landing record of a checkpoint height (slot 285 mapping, three words); the
    /// first word packs `parentHeight`, `generation` and `head`.
    /// @dev The start write records S as (S, 0, 0, start hash, 0). Records are never pruned
    /// (spec 8.4).
    struct Landing {
        /// @notice The actual checkpoint `c` the landing settled on, never the proof origin.
        uint48 parentHeight;
        /// @notice The recovery generation of the landing.
        uint48 generation;
        /// @notice The forced-inclusion cursor at this height (the spec's "FI cursor"): the number
        /// of queue entries L2 has consumed through it. The Inbox queue head (slot 281) equals it
        /// once this height is the checkpoint.
        uint48 head;
        /// @notice The EL block hash at this height; never zero once written.
        bytes32 elHash;
        /// @notice The CometBFT block hash at this height; zero for the start S.
        bytes32 cometHash;
    }

    /// @notice The fixed per-generation origin record (slot 290 mapping, four words: startHeight,
    /// l1BlockNumber, l1Timestamp, fallbackKeysHash; spec 8.4).
    /// @dev "Origin" has two other uses in this interface: the proof origin `p` of `land`
    /// (`LandInput.parentHeight`) and `setOrigin`, which performs the start write.
    /// Generation 0 is (S, L1_0, L1_0's timestamp, slot 278 at the start write), written by the
    /// start write; a recovery generation is (c, R.number, R.timestamp, slot 278 at R). Written
    /// once; the first three fields are below 2^48.
    struct Origin {
        /// @notice The checkpoint height `c` the generation starts from.
        uint256 startHeight;
        /// @notice The origin L1 block: `R` for a recovery generation, `L1_0` for generation 0.
        uint256 l1BlockNumber;
        /// @notice The timestamp of that L1 block.
        uint256 l1Timestamp;
        /// @notice The fallback key hash (slot 278) when the record was written: the keys that
        /// sign the generation's first two blocks, whatever the list is later.
        bytes32 fallbackKeysHash;
    }

    /// @notice A forced inclusion queue entry (slot 280 mapping, two words; spec 7.1); the second
    /// word packs `timestamp` and `l1Block`.
    struct ForcedInclusion {
        /// @notice keccak256 of the submitted bytes; recovery may replace it with keccak256("").
        bytes32 txHash;
        /// @notice The L1 timestamp of the submission.
        uint48 timestamp;
        /// @notice The L1 block of the submission.
        uint48 l1Block;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted once, when `init` runs (spec 10 step 5).
    /// @param configHash The stored config hash (slot 269).
    /// @param etnaStaking The `EtnaStaking` proxy on L2, the config hash's third word.
    /// @param unsettledLimit `U`, the config hash's fourth word.
    event EtnaInitialized(bytes32 configHash, address etnaStaking, uint256 unsettledLimit);

    /// @notice Emitted once, by the start write: `init` on a new network, `setOrigin` on a
    /// switching network (START-10-5b).
    /// @param height The Etna start S.
    /// @param blockHash The EL block hash of S.
    /// @param stateRoot The state root of S.
    event StartWritten(uint256 height, bytes32 blockHash, bytes32 stateRoot);

    /// @notice Emitted by `setFallbackKeys` and by `init` (appendix A).
    /// @param fallbackKeysHash The new fallback key hash (slot 278).
    /// @param keys The stored list.
    event FallbackKeysUpdated(bytes32 indexed fallbackKeysHash, FallbackKey[] keys);

    /// @notice Emitted by `setMinTotalStake` and by `init` (appendix A).
    /// @param value The new `minTotalStake` (slot 279).
    event MinTotalStakeUpdated(uint256 value);

    /// @notice Emitted by every successful `scheduleRules`, `scheduleStop` and `recover`.
    /// @param value The new slot 293 word, packed as in `RulesSchedule`.
    event RulesScheduleUpdated(uint256 value);

    /// @notice Emitted when `land` settles `(c, h]` with a proof covering `(p, h]` (spec 6.1).
    /// @param parentHeight `p`, the proof origin.
    /// @param checkpointHeight `c`, the checkpoint the landing settled on.
    /// @param lastHeight `h`, the new checkpoint.
    /// @param cutHash The hash over the cut leaves of the heights strictly inside `(p, h)`
    /// (appendix A).
    /// @param version The landing statement version, 1.
    event Landed(
        uint256 indexed parentHeight,
        uint256 indexed checkpointHeight,
        uint256 indexed lastHeight,
        bytes32 cutHash,
        uint8 version
    );

    /// @notice Emitted when a transaction enters the forced inclusion queue (spec 7.1).
    /// @param index The assigned queue index.
    /// @param tx The submitted bytes; the entry stores only their hash.
    /// @param feeWei The fee charged in wei, excluding the refunded overpayment.
    event ForcedInclusionSaved(uint48 indexed index, bytes tx, uint256 feeWei);

    /// @notice Emitted when the Inbox's whole ETH balance is swept to `protocolFeeRecipient`.
    /// @param amount The amount swept in wei.
    event ProtocolFeesSwept(uint256 amount);

    /// @notice Emitted when the owner invalidates unexecuted recovery authorizations.
    /// @param oldNonce The previously current authorization nonce.
    /// @param newNonce The new nonce, exactly oldNonce + 1.
    event RecoveryNonceInvalidated(uint256 oldNonce, uint256 newNonce);

    /// @notice Emitted when governance recovery starts a new generation (spec 8).
    /// @param newGeneration The new recovery generation.
    /// @param checkpointHeight `c`, the checkpoint the generation starts from.
    /// @param l1BlockNumber The number of the execution block `R`.
    /// @param l1Timestamp The timestamp of `R`.
    /// @param fallbackKeysHash The fallback key hash the new origin record holds.
    /// @param fiToClear The blanked forced inclusion indices, strictly increasing.
    event Recovered(
        uint48 indexed newGeneration,
        uint256 checkpointHeight,
        uint256 l1BlockNumber,
        uint256 l1Timestamp,
        bytes32 fallbackKeysHash,
        uint256[] fiToClear
    );

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox (spec 10 step 5).
    /// @dev Only the owner, by upgrading the proxy from its bootstrap implementation. Validates the
    /// spec 10 deployment constraints it can check: forcedInclusionDelay in [1, 2^48),
    /// maxAnchorAge in [1152, 2^48) and block.number and block.timestamp below 2^48, and checks
    /// the fallback key list as `setFallbackKeys` does. Stores the list and its hash and emits
    /// `FallbackKeysUpdated`, then stores `minTotalStake` and emits `MinTotalStakeUpdated`, as
    /// the two setters do. Stores the config hash (slot 269), keccak256 of the four words
    /// bytes32("ETNA_CONFIG_V1"), l2ChainId, etnaStaking and unsettledLimit (appendix A), and
    /// emits `EtnaInitialized`; generation, nonce and rules schedule stay 0.
    /// On a new network (`unzenInbox() == address(0)`) the genesis hash and state root must be
    /// non-zero, and the same call performs the start write with S = 0 (see `setOrigin`) and
    /// saves the block-0 SignalService checkpoint. On a switching network both must be zero and
    /// nothing of the start is written. Any failure reverts everything.
    /// @param _params The initialization inputs.
    function init(InitParams calldata _params) external;

    /// @notice Writes the Etna start S on a switching network (START-10-5a, LAND-6.1-8a,
    /// START-10-5b, START-10-5c).
    /// @dev The one-time start write that records the Etna start S (the spec's "start write").
    /// "Origin" in the name is that start, not the slot 290 `Origin` record and not the proof
    /// origin `p` of `land`. Permissionless. Before writing anything it requires, in order: an
    /// initialized Inbox whose start is unwritten (`NotInitialized`, `StartAlreadyWritten`); a
    /// switching network, `unzenInbox()` and `etnaForkTime()` non-zero (`NotSwitching`); S != 0
    /// (`InvalidStart`); block.timestamp >= etnaForkTime() (`BeforeEtnaForkTime`); the live Unzen
    /// Inbox's `proposeCutoff()` non-zero and reached, block.timestamp >= cutoff
    /// (`ProposalsNotClosed`); its `getCoreState()` with nextProposalId ==
    /// lastFinalizedProposalId + 1 (`UnzenNotFinalized`); the L1 SignalService's
    /// `getCheckpoint(S)` with a non-zero block hash equal to the Unzen Inbox's
    /// lastFinalizedBlockHash (`UnzenStartMismatch`) and a non-zero state root (`InvalidStart`);
    /// and block.number and block.timestamp below 2^48 (`ValueOverflow`). A failing read reverts
    /// the call. The start write takes the hash and state root from that checkpoint and sets slot
    /// 272 to (S, L1_0 = block.number), slots 273/274 to them, origins[0] = (S, L1_0,
    /// block.timestamp, fallbackKeysHash()), the checkpoint to (S, hash) and landings[S] =
    /// (S, 0, 0, hash, 0), closes the checkpoint forwarder, opens the forced inclusion queue and
    /// emits `StartWritten`. It leaves the SignalService checkpoint at S untouched. A new-network
    /// Inbox reverts every call.
    /// @param _s The Etna start S, the last Unzen block.
    function setOrigin(uint48 _s) external;

    /// @notice Lands a proven batch: settles `(c, h]` with a proof covering `(p, h]` (spec 6.1).
    /// @dev Permissionless and nonpayable; shares `recover`'s reentrancy lock. Before the start
    /// write no landing passes check 2, because landings[0] is unwritten. With `c` the latest
    /// checkpoint height read at execution, it requires, before any state change:
    /// 1. generationStartHeight() <= p <= c < h < 2^48 (c >= h means already settled) and
    ///    h - p <= maxBatchBlocks;
    /// 2. landings[p].elHash != 0, and landings[p].generation == recoveryGeneration unless p is
    ///    the current generation's start height. The spec's `isValidLanding(p)` is this written-
    ///    record check: these contracts have no rollback that voids records;
    /// 3. _leaves.length == h - p - 1 and landings[c].head equal to the queue head; if c > p,
    ///    _leaves[c - p - 1] == keccak256(abi.encode(c, elHash, cometHash, uint256(head))) over
    ///    landings[c];
    /// 4. head <= forcedInclusionHead <= tail and forcedInclusionHead - head <= h - c;
    /// 5. l1ReferenceBlockNumber < block.number with a non-zero hash from `blockhash` (256 blocks)
    ///    or the EIP-2935 history contract (8191 blocks), and 1 to 6 blobs;
    /// 6. proofVerifier.verifyProof(0, statement, _proof) succeeds.
    /// cutHash = keccak256(abi.encode(bytes32("ETNA_LAND_CUTS_V1"), uint256(generation), p, h,
    /// keccak256(abi.encodePacked(_leaves)))), where an empty list (h = p + 1) hashes as
    /// keccak256(""). The statement is the keccak256 of 19 static ABI words (608 bytes):
    /// bytes32("TAIKO_ETNA_LAND_V1"), block.chainid, l2ChainId, this proxy, generation, p,
    /// parentHash, parentCometHash, configHash, h, lastBlockHash, lastCometHash, lastStateRoot,
    /// l1ReferenceBlockNumber, its block hash, keccak256(abi.encodePacked(blobHashes)),
    /// headBefore, forcedInclusionHead and cutHash, where parentHash, parentCometHash and
    /// headBefore are the elHash, cometHash and head of landings[p] (appendix A). It then sets
    /// the checkpoint to (h, lastBlockHash), the queue head and landings[h] = (c, generation,
    /// forcedInclusionHead, lastBlockHash, lastCometHash), saves the SignalService checkpoint
    /// (h, lastBlockHash, lastStateRoot) and emits `Landed`. It pays no fee.
    /// @param _input The batch's public inputs.
    /// @param _leaves The cut leaves of the heights p + 1, ..., h - 1, in height order.
    /// @param _proof The two sub-proofs (spec 6.2).
    function land(
        LandInput calldata _input,
        bytes32[] calldata _leaves,
        bytes calldata _proof
    )
        external;

    /// @notice Appends a forced transaction to the queue and charges the current fee (spec 7.1).
    /// @dev Requires the start write and at most 8,192 bytes; the encoding is not checked. Charges
    /// getCurrentForcedInclusionFee() Gwei, which stays in the Inbox until swept, and refunds any
    /// overpayment to the caller. Stores keccak256(_tx), block.timestamp and block.number, each
    /// below 2^48.
    /// @param _tx The raw transaction bytes, published in `ForcedInclusionSaved`.
    function saveForcedInclusion(bytes calldata _tx) external payable;

    /// @notice Sends the Inbox's whole ETH balance to `protocolFeeRecipient` (spec 7.1).
    /// @dev Permissionless and unaffected by pause; reverts if the transfer fails. Leaves the
    /// queue untouched.
    function sweepProtocolFees() external;

    /// @notice Starts a new recovery generation at the current checkpoint `c` (spec 8, 8.3, 8.4).
    /// @dev Only the owner; shares `land`'s reentrancy lock and is atomic: any failure reverts
    /// every effect. Reverts `NotInitialized` before `init` and `StartNotWritten` before the
    /// start write. Requires _expectedGeneration == recoveryGeneration() (`GenerationMismatch`),
    /// _expectedC == lastCheckpoint().height (`CheckpointMismatch`), an exact recovery nonce
    /// (`RecoveryNonceMismatch`) and block.timestamp <= _validUntil (`AuthorizationExpired`).
    /// A non-zero _rules must equal the schedule's nextRules + 1 (`InvalidRules`). Increments the
    /// authorization nonce without wrapping on success. The new generation, block.number and
    /// block.timestamp each below 2^48 (`ValueOverflow`); fiToClear strictly increasing within
    /// [head, tail). All of these are checked before any write, and the call makes no external
    /// call. Each listed queue entry's txHash becomes keccak256(""). With R = block.number, it
    /// increments the generation, writes origins[generation] = (c, R, block.timestamp,
    /// fallbackKeysHash()) once (`OriginAlreadyWritten` if that record already exists) and emits
    /// `Recovered`. It then clears the planned stop and, for a non-zero _rules, sets activeRules =
    /// nextRules = _rules and rulesTime = 0, and emits `RulesScheduleUpdated`.
    /// The checkpoint, its landing record and the queue head are kept.
    /// @param _expectedGeneration The recovery generation the call was authorized for.
    /// @param _expectedC The checkpoint height the call was authorized for.
    /// @param _expectedRecoveryNonce The exact current authorization nonce (slot 292).
    /// @param _validUntil The inclusive L1 Unix timestamp deadline in seconds.
    /// @param _fiToClear The queue indices to blank, strictly increasing.
    /// @param _rules Zero, or the ruleset the new generation runs from its first block.
    function recover(
        uint48 _expectedGeneration,
        uint256 _expectedC,
        uint256 _expectedRecoveryNonce,
        uint256 _validUntil,
        uint256[] calldata _fiToClear,
        uint48 _rules
    )
        external;

    /// @notice Schedules the next ruleset (spec 10.1, START-10.1-5a).
    /// @dev Owner only after initialization, under the Inbox lock. First requires
    /// _expectedGeneration == recoveryGeneration() (`GenerationMismatch`, START-10.1-5c), so an
    /// authorization for an earlier generation cannot change or cancel a schedule. With M =
    /// maxAnchorAge(): if block.timestamp >= rulesTime it first sets activeRules = nextRules,
    /// otherwise it requires block.timestamp + M < rulesTime (`RulesLocked`). It then requires
    /// _rules to be nextRules or nextRules + 1 (`InvalidRules`) and _time >= block.timestamp + M
    /// (`InvalidScheduleTime`), sets nextRules = _rules and rulesTime = _time and emits
    /// `RulesScheduleUpdated`. An equal _rules reschedules the pending ruleset and
    /// _time = 2^48 - 1 cancels it.
    /// @param _expectedGeneration The recovery generation the call was authorized for.
    /// @param _rules The ruleset number.
    /// @param _time The L2 timestamp from which it applies.
    function scheduleRules(
        uint48 _expectedGeneration,
        uint48 _rules,
        uint48 _time
    )
        external;

    /// @notice Schedules, moves or cancels the planned stop (spec 10.1, START-10.1-5b).
    /// @dev Owner only after initialization, under the Inbox lock. First requires
    /// _expectedGeneration == recoveryGeneration() (`GenerationMismatch`, START-10.1-5c). With
    /// M = maxAnchorAge(): if a stop is set it requires block.timestamp + M < stopTime
    /// (`StopLocked`). It then requires _time to be 0, which cancels the stop, or at least
    /// block.timestamp + M (`InvalidStop`), sets stopTime = _time and emits
    /// `RulesScheduleUpdated`.
    /// @param _expectedGeneration The recovery generation the call was authorized for.
    /// @param _time The stop time, or 0 for no stop.
    function scheduleStop(uint48 _expectedGeneration, uint48 _time) external;

    /// @notice Replaces the DAO fallback key set (spec 4.3).
    /// @dev Owner only after initialization, under the Inbox lock and unaffected by pause; it takes
    /// no generation and applies at once. Requires 1 to 128 keys (`InvalidFallbackKeys`), each a
    /// valid compressed public key (the key library's `InvalidPublicKey`), in strictly ascending
    /// order of the 33-byte big-endian value `ckPrefix ‖ ckX`, prefix first, so no key repeats
    /// (`InvalidFallbackKeys`). Stores the list and its hash (slot 278), keccak256 of the ABI
    /// encoding of bytes32("ETNA_FALLBACK_KEYS_V1") and the list (appendix A), and emits
    /// `FallbackKeysUpdated`. Origin records already written keep the hash they hold.
    /// @param _keys The new list.
    function setFallbackKeys(FallbackKey[] calldata _keys) external;

    /// @notice Sets `minTotalStake`, the total stake a staking candidate needs to sign instead of
    /// the fallback key set (spec 4.3).
    /// @dev Owner only after initialization, under the Inbox lock and unaffected by pause; it takes
    /// no generation and applies at once. Stores any value in slot 279 and emits
    /// `MinTotalStakeUpdated`; 2^256 - 1 makes no staking candidate usable.
    /// @param _value The new threshold in token base units.
    function setMinTotalStake(uint256 _value) external;

    /// @notice Invalidates all unexecuted recovery authorizations carrying the current nonce.
    /// @dev Owner only after initialization, under the Inbox lock. Requires an exact nonce and
    /// increments it without wrapping. Landing does not change it.
    /// Verifier-failure rollback upgrades must preserve and increment the current nonce rather
    /// than restore a historical value (spec 8.3).
    /// @param _expectedRecoveryNonce The nonce to invalidate.
    function invalidateRecoveryNonce(uint256 _expectedRecoveryNonce) external;

    /// @notice Returns the monotonically increasing uint256 recovery authorization nonce.
    /// @return nonce_ Slot 292, initially zero; incremented by recovery or explicit invalidation.
    function recoveryNonce() external view returns (uint256 nonce_);

    /// @notice Returns whether `init` has run.
    /// @dev Slot 258 holds 3 once initialized.
    /// @return Whether the Inbox is initialized.
    function isInitialized() external view returns (bool);

    /// @notice Returns the recovery generation (slot 268), bound into every landing statement and
    /// CometBFT chain id.
    /// @return The recovery generation.
    function recoveryGeneration() external view returns (uint48);

    /// @notice Returns the config hash (slot 269), keccak256 of the four words
    /// bytes32("ETNA_CONFIG_V1"), l2ChainId, etnaStaking and unsettledLimit (appendix A).
    /// @return The config hash; zero before initialization.
    function configHash() external view returns (bytes32);

    /// @notice Returns the latest landed checkpoint `c` (slots 270/271).
    /// @return The checkpoint; (S, start hash) right after the start write.
    function lastCheckpoint() external view returns (LandedCheckpoint memory);

    /// @notice Returns the start record (slots 272-274).
    /// @return The start record; zero before the start write.
    function genesis() external view returns (GenesisRecord memory);

    /// @notice Returns the Etna start: S and the start hash, whose non-zero value closes the Unzen
    /// checkpoint forwarder `saveCheckpoint` (START-10-5).
    /// @return height_ S (slot 272).
    /// @return blockHash_ The EL block hash of S (slot 273); zero exactly before the start write.
    function etnaStart() external view returns (uint48 height_, bytes32 blockHash_);

    /// @notice Returns the rules schedule (slot 293, spec 10.1).
    /// @return The rules schedule; zero at initialization.
    function rulesSchedule() external view returns (RulesSchedule memory);

    /// @notice Returns the stored fallback key list (slot 275), which no anchor witness proves;
    /// nodes and guests check a list against `fallbackKeysHash()`.
    /// @return The list; empty before initialization.
    function getFallbackKeys() external view returns (FallbackKey[] memory);

    /// @notice Returns the fallback key hash (slot 278, appendix A).
    /// @return The hash of `getFallbackKeys()`; zero before initialization.
    function fallbackKeysHash() external view returns (bytes32);

    /// @notice Returns `minTotalStake` (slot 279).
    /// @return The threshold in token base units; zero before initialization.
    function minTotalStake() external view returns (uint256);

    /// @notice Returns the forced inclusion delay in seconds (slot 282, bits 0-47).
    /// @return The forced inclusion delay; zero before initialization.
    function forcedInclusionDelay() external view returns (uint48);

    /// @notice Returns the maximum anchor age in seconds (slot 282, bits 48-95).
    /// @return The maximum anchor age; zero before initialization.
    function maxAnchorAge() external view returns (uint48);

    /// @notice Returns the landing record of an L2 height (slot 285).
    /// @param _height The L2 height.
    /// @return The record; all zero if no landing ended at `_height`.
    function landings(uint256 _height) external view returns (Landing memory);

    /// @notice Returns the fixed per-generation origin record (slot 290): startHeight,
    /// l1BlockNumber, l1Timestamp and fallbackKeysHash.
    /// @param _generation The recovery generation.
    /// @return The origin; all zero if the generation has not started.
    function origins(uint256 _generation) external view returns (Origin memory);

    /// @notice Returns the current generation's start height,
    /// `origins(recoveryGeneration()).startHeight`.
    /// @dev Reverts with `StartNotWritten` before the start write, which writes generation 0's
    /// record: a missing record has no default (spec 8.4). `recover`, which starts every later
    /// generation, writes its record in the same transaction.
    /// @return The start height.
    function generationStartHeight() external view returns (uint256);

    /// @notice Returns the forced inclusion queue pointers (slot 281).
    /// @return head_ The index of the next entry to consume.
    /// @return tail_ The index of the next submission.
    function getForcedInclusionState() external view returns (uint48 head_, uint48 tail_);

    /// @notice Returns a stored queue entry, consumed or not.
    /// @param _index The queue index.
    /// @return The entry; all zero at or beyond the tail.
    function getForcedInclusion(uint48 _index) external view returns (ForcedInclusion memory);

    /// @notice Returns pending queue entries starting at `_start`.
    /// @dev Empty if `_start` is outside [head, tail) or `_maxCount` is zero.
    /// @param _start The first queue index.
    /// @param _maxCount The maximum number of entries.
    /// @return At most min(_maxCount, tail - _start) entries.
    function getForcedInclusions(
        uint48 _start,
        uint48 _maxCount
    )
        external
        view
        returns (ForcedInclusion[] memory);

    /// @notice Returns the fee in Gwei of the next forced inclusion (spec 7.1).
    /// @dev forcedInclusionFeeInGwei * (threshold + tail - head) / threshold, capped at
    /// type(uint64).max.
    /// @return feeInGwei_ The fee in Gwei.
    function getCurrentForcedInclusionFee() external view returns (uint64 feeInGwei_);

    /// @notice Returns the `EtnaStaking` proxy on L2, the config hash's third word.
    /// @return The EtnaStaking proxy address.
    function etnaStaking() external view returns (address);

    /// @notice Returns the SignalService that stores the landed checkpoints.
    /// @return The SignalService address.
    function signalService() external view returns (address);

    /// @notice Returns the verifier of `land` proofs.
    /// @return The verifier address.
    function proofVerifier() external view returns (address);

    /// @notice Returns the chain id of the Etna L2.
    /// @return The L2 chain id.
    function l2ChainId() external view returns (uint64);

    /// @notice Returns the maximum `h - p` of one landing.
    /// @return The maximum batch size in L2 blocks.
    function maxBatchBlocks() external view returns (uint64);

    /// @notice Returns the forced inclusion fee in Gwei with an empty queue.
    /// @return The base fee in Gwei.
    function forcedInclusionFeeInGwei() external view returns (uint64);

    /// @notice Returns the number of pending forced inclusions at which the fee doubles.
    /// @return The doubling threshold.
    function forcedInclusionFeeDoubleThreshold() external view returns (uint64);

    /// @notice Returns the DAO treasury that receives the swept forced inclusion fees.
    /// @return The protocol fee recipient.
    function protocolFeeRecipient() external view returns (address);

    /// @notice Returns the live Unzen Inbox whose checkpoints `saveCheckpoint` forwards and whose
    /// closed, fully proven tip `setOrigin` records; zero on a new network.
    /// @return The Unzen Inbox proxy.
    function unzenInbox() external view returns (address);

    /// @notice Returns `ETNA_FORK_TIME`, the earliest time of `setOrigin`; zero on a new network.
    /// @return The fork time in L1 Unix seconds.
    function etnaForkTime() external view returns (uint48);

    /// @notice Returns `U`, the maximum number of unsettled L2 blocks, the config hash's fourth
    /// word.
    /// @return The limit, in [1, 262,144].
    function unsettledLimit() external view returns (uint64);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    /// @notice The Inbox is not initialized.
    error NotInitialized();
    /// @notice The Etna start is not written yet.
    error StartNotWritten();
    /// @notice The Etna start is already written: a second `setOrigin`.
    error StartAlreadyWritten();
    /// @notice `recover` finds the new generation's origin record (slot 290) already written.
    error OriginAlreadyWritten();
    /// @notice `setOrigin` is called before `etnaForkTime()`.
    error BeforeEtnaForkTime();
    /// @notice `setOrigin` names S = 0, or the SignalService checkpoint at S has a zero state
    /// root.
    error InvalidStart();
    /// @notice `setOrigin` is called on a new network, which has no Unzen Inbox or fork time.
    error NotSwitching();
    /// @notice The switching-network immutables are neither both zero nor both non-zero, or the
    /// Unzen Inbox has no code.
    error InvalidSwitchConfig();
    /// @notice `U` is zero or above 262,144.
    error InvalidUnsettledLimit();
    /// @notice The Unzen Inbox's `proposeCutoff()` is zero or not yet reached.
    error ProposalsNotClosed();
    /// @notice The Unzen Inbox has an unfinalized proposal.
    error UnzenNotFinalized();
    /// @notice The SignalService checkpoint at S has a zero block hash or one that differs from
    /// the Unzen Inbox's last finalized block hash.
    error UnzenStartMismatch();
    /// @notice The Unzen Inbox forwarded a checkpoint after the start write, which closes the
    /// forwarder at every height.
    error ForwardingClosed();
    /// @notice The ruleset is neither `nextRules` nor `nextRules + 1`, or not `nextRules + 1` in
    /// `recover`.
    error InvalidRules();
    /// @notice The rules time is earlier than `block.timestamp + maxAnchorAge`.
    error InvalidScheduleTime();
    /// @notice The pending ruleset can no longer be changed.
    error RulesLocked();
    /// @notice The planned stop can no longer be changed.
    error StopLocked();
    /// @notice The stop time is neither 0 nor at least `maxAnchorAge` ahead.
    error InvalidStop();
    /// @notice The expected recovery nonce differs from the current one.
    error RecoveryNonceMismatch();
    /// @notice The authorization's `validUntil` deadline has passed.
    error AuthorizationExpired();
    /// @notice `maxBatchBlocks` is zero or above 12,952.
    error InvalidMaxBatchBlocks();
    /// @notice The forced inclusion fee is zero.
    error ForcedInclusionFeeZero();
    /// @notice The forced inclusion fee doubling threshold is zero.
    error ForcedInclusionFeeDoubleThresholdZero();
    /// @notice The genesis block hash or state root is zero on a new network, or non-zero on a
    /// switching network.
    error InvalidGenesis();
    /// @notice The forced inclusion delay is zero or does not fit 48 bits.
    error InvalidForcedInclusionDelay();
    /// @notice The maximum anchor age is below 1152 seconds or does not fit 48 bits.
    error InvalidMaxAnchorAge();
    /// @notice A value does not fit its 48-bit storage field.
    error ValueOverflow();
    /// @notice The terminal height is already settled (`c >= h`).
    error AlreadySettled();
    /// @notice The proof origin is outside [generationStartHeight(), c] or `h` reaches 2^48.
    error InvalidRange();
    /// @notice `h - p` exceeds `maxBatchBlocks`.
    error BatchTooLarge();
    /// @notice The proof origin `p` (`LandInput.parentHeight`) has no landing record (slot 285);
    /// unrelated to the slot 290 origin record.
    error MissingOrigin();
    /// @notice The proof origin's record belongs to another generation.
    error ForeignGeneration();
    /// @notice The number of cut leaves is not `h - p - 1`.
    error LeafCountMismatch();
    /// @notice The forced-inclusion cursor in the checkpoint's landing record (`Landing.head`, the
    /// spec's "FI cursor") differs from the Inbox queue head (slot 281), which must equal it once
    /// that height is the checkpoint.
    error ForcedInclusionHeadMismatch();
    /// @notice The cut leaf at `c`, the latest checkpoint height (the "frontier"), differs from the
    /// one computed from `c`'s landing record.
    error FrontierLeafMismatch();
    /// @notice The new queue head goes back, passes the tail or advances more than `h - c`.
    error InvalidForcedInclusionHead();
    /// @notice The reference block is not in the past or its hash is unavailable.
    error ReferenceBlockUnavailable();
    /// @notice The transaction carries no blob or more than 6.
    error InvalidBlobCount();
    /// @notice The forced transaction exceeds 8,192 bytes.
    error ForcedTransactionTooLarge();
    /// @notice The forced inclusion fee is not covered.
    error InsufficientFee();
    /// @notice The expected generation is not the current one.
    error GenerationMismatch();
    /// @notice The expected checkpoint height is not the landed checkpoint's
    /// (`lastCheckpoint().height`).
    error CheckpointMismatch();
    /// @notice The forced inclusion indices to clear are not strictly increasing.
    error FiToClearNotSorted();
    /// @notice A forced inclusion index to clear is outside [head, tail).
    error FiIndexOutOfRange();
    /// @notice The entry point does not accept ETH.
    error EtherNotAccepted();
    /// @notice The fallback key list has no key or more than 128, or its keys are not in strictly
    /// ascending order of `ckPrefix ‖ ckX`.
    error InvalidFallbackKeys();
}
