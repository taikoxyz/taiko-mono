// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaInbox
/// @notice The L1 Inbox of an Etna PoS chain: it records L2 genesis, lands proven batches that end
/// at grid points, keeps the forced inclusion queue and runs governance recovery.
/// @dev Section numbers refer to the Etna specification. Nodes, guests and landers read the
/// storage layout of spec appendix B (slots 258-291) with EIP-1186 proofs; each struct names the
/// slots it occupies. Every packed word lays its fields out in declaration order from the
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
        /// @notice The staking registry whose snapshots select the committees (spec 4.1).
        address stakingRegistry;
        /// @notice The chain id of the Etna L2; non-zero.
        uint64 l2ChainId;
        /// @notice The maximum `h - p` of one landing; at least 6, one grid segment (spec 10).
        uint64 maxBatchBlocks;
        /// @notice The forced inclusion fee in Gwei with an empty queue (spec 7.1); non-zero.
        uint64 forcedInclusionFeeInGwei;
        /// @notice The number of pending forced inclusions at which the fee doubles; non-zero.
        uint64 forcedInclusionFeeDoubleThreshold;
        /// @notice The DAO treasury that receives the swept forced inclusion fees (spec 7.1);
        /// non-zero.
        address protocolFeeRecipient;
    }

    /// @notice The committee derivation parameters opened by `committeeConfigHash` (spec 4.3, 6.4).
    /// @dev committeeConfigHash = keccak256(abi.encode(bytes32("ETNA_PARENT_ANCHOR_V1"),
    /// uint256(l2ChainId), stakingRegistry, vpUnit, sMin, nMax, unsettledLimit)): seven words,
    /// 224 bytes (appendix A).
    struct CommitteeConfig {
        /// @notice `vp_unit`: the stake per unit of voting power; at least 867,361,738.
        uint256 vpUnit;
        /// @notice `s_min`: the minimum effective stake of an eligible entry; at least `vpUnit`.
        uint256 sMin;
        /// @notice `n_max`: the maximum committee size, in [1, 4096].
        uint256 nMax;
        /// @notice `U`: the maximum number of unsettled L2 blocks, a multiple of 6 in [6, 65,532].
        uint256 unsettledLimit;
    }

    /// @notice The genesis inputs of `init` (spec 10 step 5).
    struct InitParams {
        /// @notice The hash of L2 block 0; non-zero.
        bytes32 genesisBlockHash;
        /// @notice The state root of L2 block 0; non-zero.
        bytes32 genesisStateRoot;
        /// @notice `L`: the epoch length in L2 blocks, with L >= 3 and L + 1 < 2^48 (spec 4.2).
        uint256 epochLenL2;
        /// @notice The registry snapshot block of committee 0: a past L1 block at or after the
        /// registry's first checkpoint (spec 4.3).
        uint256 genesisCutoff;
        /// @notice The committee 0 record hash (appendix A `record`); non-zero.
        bytes32 committeeRecordHash;
        /// @notice The committee derivation parameters; `init` validates them and stores their
        /// hash.
        CommitteeConfig committeeConfig;
        /// @notice The forced inclusion delay in seconds, in [1, 2^48) (spec 7.2).
        uint256 forcedInclusionDelay;
        /// @notice The maximum anchor age in seconds, in [1152, 2^48) (spec 3.4).
        uint256 maxAnchorAge;
    }

    /// @notice The public inputs of `land` (spec 6.1).
    struct LandInput {
        /// @notice `p`: the proof origin, a retained checkpoint and grid point at or below `c`.
        uint256 parentHeight;
        /// @notice `h`: the terminal height, a grid point above `c`.
        uint256 lastHeight;
        /// @notice The EL block hash at `h`.
        bytes32 lastBlockHash;
        /// @notice The CometBFT block hash at `h`.
        bytes32 lastCometHash;
        /// @notice The EL state root at `h`.
        bytes32 lastStateRoot;
        /// @notice The L1 block whose header chain holds every anchor and proving root used.
        uint256 l1ReferenceBlockNumber;
        /// @notice The forced inclusion queue head after `h`.
        uint256 forcedInclusionHead;
        /// @notice The selection snapshot of the committee actually signing `h`.
        uint256 activeCommitteeSnapshot;
    }

    /// @notice The latest landed L2 block `c` (slots 270/271).
    struct LandedCheckpoint {
        /// @notice The L2 height.
        uint48 height;
        /// @notice The EL block hash.
        bytes32 blockHash;
    }

    /// @notice The genesis record (slots 272-274); slot 272 packs the three 48-bit fields.
    struct GenesisRecord {
        /// @notice The Etna genesis height, always 0.
        uint48 genesisHeight;
        /// @notice `L1_0`: the L1 block of `init`.
        uint48 l1Block;
        /// @notice `L`: the epoch length in L2 blocks.
        uint48 epochLenL2;
        /// @notice The hash of L2 block 0.
        bytes32 genesisBlockHash;
        /// @notice The state root of L2 block 0.
        bytes32 genesisStateRoot;
    }

    /// @notice The landing record of a checkpoint height (slot 285 mapping, three words); the
    /// first word packs `parentHeight`, `generation` and `head`.
    /// @dev Height 0 holds (0, 0, 0, genesis hash, 0). Records are never pruned (spec 8.4).
    struct Landing {
        /// @notice The actual checkpoint `c` the landing settled on, never the proof origin.
        uint48 parentHeight;
        /// @notice The recovery generation of the landing.
        uint48 generation;
        /// @notice The forced inclusion queue head at this height.
        uint48 head;
        /// @notice The EL block hash at this height; never zero once written.
        bytes32 elHash;
        /// @notice The CometBFT block hash at this height; zero for block 0.
        bytes32 cometHash;
    }

    /// @notice The fixed origin of a recovery generation (slot 290 mapping, three words; spec 8.4).
    /// @dev Generation 0 is (0, L1_0, initialization timestamp); a recovery generation is
    /// (c, R.number, R.timestamp). Written once; every field is below 2^48.
    struct Origin {
        /// @notice The checkpoint height `c` the generation starts from.
        uint256 startHeight;
        /// @notice The origin L1 block: `R` for a recovery generation, `L1_0` for generation 0.
        uint256 l1BlockNumber;
        /// @notice The timestamp of that L1 block.
        uint256 l1Timestamp;
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

    /// @notice A registry entry that recovery forces to exit at `R` (spec 8 step 2).
    struct Exclusion {
        /// @notice The entry's bond id (its slot).
        uint256 bondId;
        /// @notice keccak256(abi.encode(ckPrefix, ckX)) of the slot's expected occupant.
        bytes32 entryKey;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted once, when `init` records L2 genesis (spec 10 step 5).
    /// @param genesisBlockHash The hash of L2 block 0.
    /// @param genesisStateRoot The state root of L2 block 0.
    /// @param l1Block `L1_0`, the L1 block of initialization.
    /// @param epochLenL2 `L`, the epoch length in L2 blocks.
    /// @param genesisCutoff The registry snapshot block of committee 0.
    /// @param committeeRecordHash The committee 0 record hash.
    /// @param committeeConfigHash The stored committee configuration hash.
    event EtnaInitialized(
        bytes32 genesisBlockHash,
        bytes32 genesisStateRoot,
        uint256 l1Block,
        uint256 epochLenL2,
        uint256 genesisCutoff,
        bytes32 committeeRecordHash,
        bytes32 committeeConfigHash
    );

    /// @notice Emitted when `land` settles `(c, h]` with a proof covering `(p, h]` (spec 6.1).
    /// @param parentHeight `p`, the proof origin.
    /// @param checkpointHeight `c`, the checkpoint the landing settled on.
    /// @param lastHeight `h`, the new checkpoint.
    /// @param cutHash The hash over the cut leaves at the grid points in `(p, h)` (appendix A).
    /// @param activeCommitteeSnapshot The selection snapshot of the committee signing `h`.
    /// @param version The landing statement version, 1.
    event Landed(
        uint256 indexed parentHeight,
        uint256 indexed checkpointHeight,
        uint256 indexed lastHeight,
        bytes32 cutHash,
        uint256 activeCommitteeSnapshot,
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

    /// @notice Emitted when governance recovery starts a new generation (spec 8).
    /// @param newGeneration The new recovery generation.
    /// @param checkpointHeight `c`, the checkpoint the generation starts from.
    /// @param l1BlockNumber The number of the execution block `R`.
    /// @param l1Timestamp The timestamp of `R`.
    /// @param exclusions The entries forced to exit at `R`, sorted strictly by bond id.
    /// @param fiToClear The blanked forced inclusion indices, strictly increasing.
    event Recovered(
        uint48 indexed newGeneration,
        uint256 checkpointHeight,
        uint256 l1BlockNumber,
        uint256 l1Timestamp,
        Exclusion[] exclusions,
        uint256[] fiToClear
    );

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox from L2 genesis (spec 10 step 5).
    /// @dev Only the owner, by upgrading the proxy from its bootstrap implementation. Validates the
    /// spec 10 deployment constraints it can check: non-zero genesis hash, state root and committee
    /// record; L >= 3 and L + 1 < 2^48; a genesis cutoff below block.number and at or after the
    /// registry's first checkpoint; the committee configuration bounds; forcedInclusionDelay in
    /// [1, 2^48); maxAnchorAge in [1152, 2^48); block.number and block.timestamp below 2^48. The
    /// registry's fixed Inbox must be this proxy and its l2ChainId this Inbox's (spec 4.1).
    /// Stores committeeConfigHash (slot 269) and the appendix B initial values: generation 0,
    /// checkpoint (0, genesis hash), the genesis record with L1_0 = block.number, the committee 0
    /// record and cutoff, activeCommitteeSnapshot = genesisCutoff, landings[0] = (0, 0, 0,
    /// genesis hash, 0) and origins[0] = (0, L1_0, block.timestamp). Saves the block-0
    /// SignalService checkpoint; any failure reverts everything.
    /// @param _params The genesis inputs.
    function init(InitParams calldata _params) external;

    /// @notice Lands a proven batch: settles `(c, h]` with a proof covering `(p, h]` (spec 6.1).
    /// @dev Permissionless and nonpayable; shares `recover`'s reentrancy lock. With K = 6 and `c`
    /// the latest checkpoint height read at execution, it requires, before any state change:
    /// 1. generationStartHeight() <= p <= c < h < 2^48 (c >= h means already settled), p and h
    ///    multiples of K, and h - p <= maxBatchBlocks;
    /// 2. landings[p].elHash != 0, and landings[p].generation == recoveryGeneration unless p is
    ///    the current generation's start height;
    /// 3. _leaves.length == (h - p) / K - 1 and landings[c].head equal to the queue head; if
    ///    c > p, _leaves[(c - p) / K - 1] == keccak256(abi.encode(c, elHash, cometHash,
    ///    uint256(head))) over landings[c];
    /// 4. head <= forcedInclusionHead <= tail and forcedInclusionHead - head <= h - c;
    /// 5. l1ReferenceBlockNumber < block.number with a non-zero hash from `blockhash` (256 blocks)
    ///    or the EIP-2935 history contract (8191 blocks), and 1 to 6 blobs;
    /// 6. proofVerifier.verifyProof(0, statement, _proof) succeeds.
    /// cutHash = keccak256(abi.encode(bytes32("ETNA_LAND_CUTS_V1"), uint256(generation), p, h,
    /// keccak256(abi.encodePacked(_leaves)))). The statement is the keccak256 of 21 static ABI
    /// words (672 bytes): bytes32("TAIKO_ETNA_LAND_V1"), block.chainid, l2ChainId, this proxy,
    /// stakingRegistry, generation, p, parentHash, parentCometHash, committeeConfigHash, h,
    /// lastBlockHash, lastCometHash, lastStateRoot, l1ReferenceBlockNumber, its block hash,
    /// keccak256(abi.encodePacked(blobHashes)), headBefore, forcedInclusionHead,
    /// activeCommitteeSnapshot and cutHash, where parentHash, parentCometHash and headBefore are
    /// the elHash, cometHash and head of landings[p] (appendix A). It then sets the checkpoint to
    /// (h, lastBlockHash), activeCommitteeSnapshot, the queue head and landings[h] = (c,
    /// generation, forcedInclusionHead, lastBlockHash, lastCometHash), saves the SignalService
    /// checkpoint (h, lastBlockHash, lastStateRoot) and emits `Landed`. It pays no fee.
    /// @param _input The batch's public inputs.
    /// @param _leaves The cut leaves at the grid points p + K, ..., h - K, in height order.
    /// @param _proof The two sub-proofs (spec 6.2).
    function land(
        LandInput calldata _input,
        bytes32[] calldata _leaves,
        bytes calldata _proof
    )
        external;

    /// @notice Appends a forced transaction to the queue and charges the current fee (spec 7.1).
    /// @dev Requires initialization and at most 8,192 bytes; the encoding is not checked. Charges
    /// getCurrentForcedInclusionFee() Gwei, which stays in the Inbox until swept, and refunds any
    /// overpayment to the caller. Stores keccak256(_tx), block.timestamp and block.number, each
    /// below 2^48.
    /// @param _tx The raw transaction bytes, published in `ForcedInclusionSaved`.
    function saveForcedInclusion(bytes calldata _tx) external payable;

    /// @notice Sends the Inbox's whole ETH balance to `protocolFeeRecipient` (spec 7.1).
    /// @dev Permissionless; reverts if the transfer fails. Leaves the queue untouched.
    function sweepProtocolFees() external;

    /// @notice Starts a new recovery generation at the current checkpoint `c` (spec 8, 8.3, 8.4).
    /// @dev Only the owner; shares `land`'s reentrancy lock and is atomic. Requires
    /// _expectedGeneration == recoveryGeneration(), _expectedC == lastCheckpoint().height,
    /// exclusions sorted strictly by bond id, and fiToClear strictly increasing within
    /// [head, tail). With R = block.number, the registry checks each exclusion's entry key and
    /// sets its exitEffectiveL1 to min(existing, R); each listed queue entry's txHash becomes
    /// keccak256(""). Increments the generation, which must stay below 2^48, writes
    /// origins[generation] = (c, R, block.timestamp) once and emits `Recovered`. The checkpoint,
    /// its landing record, the queue head and activeCommitteeSnapshot are kept.
    /// @param _expectedGeneration The recovery generation the call was authorized for.
    /// @param _expectedC The checkpoint height the call was authorized for.
    /// @param _exclusions The entries to force out, sorted strictly by bond id.
    /// @param _fiToClear The queue indices to blank, strictly increasing.
    function recover(
        uint48 _expectedGeneration,
        uint256 _expectedC,
        Exclusion[] calldata _exclusions,
        uint256[] calldata _fiToClear
    )
        external;

    /// @notice Returns whether `init` has run.
    /// @dev Slot 258 holds 3 once initialized.
    /// @return Whether the Inbox is initialized.
    function isInitialized() external view returns (bool);

    /// @notice Returns the recovery generation (slot 268), bound into every landing statement and
    /// CometBFT chain id.
    /// @return The recovery generation.
    function recoveryGeneration() external view returns (uint48);

    /// @notice Returns the committee configuration hash (slot 269).
    /// @return The configuration hash; zero before initialization.
    function committeeConfigHash() external view returns (bytes32);

    /// @notice Returns the latest landed checkpoint `c` (slots 270/271).
    /// @return The checkpoint; (0, genesis hash) right after initialization.
    function lastCheckpoint() external view returns (LandedCheckpoint memory);

    /// @notice Returns the genesis record (slots 272-274).
    /// @return The genesis record; zero before initialization.
    function genesis() external view returns (GenesisRecord memory);

    /// @notice Returns the committee 0 record hash (slot 278).
    /// @return The record hash; zero before initialization.
    function genesisCommitteeRecordHash() external view returns (bytes32);

    /// @notice Returns the registry snapshot block of committee 0 (slot 279).
    /// @return The genesis cutoff; zero before initialization.
    function genesisCutoff() external view returns (uint48);

    /// @notice Returns the forced inclusion delay in seconds (slot 282, bits 0-47).
    /// @return The forced inclusion delay; zero before initialization.
    function forcedInclusionDelay() external view returns (uint48);

    /// @notice Returns the maximum anchor age in seconds (slot 282, bits 48-95).
    /// @return The maximum anchor age; zero before initialization.
    function maxAnchorAge() external view returns (uint48);

    /// @notice Returns the selection snapshot of the committee that signed the latest checkpoint
    /// (slot 284).
    /// @dev Set to the genesis cutoff by `init` and advanced only by `land`; the registry's exit
    /// confirmation reads it.
    /// @return The L1 snapshot block.
    function activeCommitteeSnapshot() external view returns (uint256);

    /// @notice Returns the landing record of an L2 height (slot 285).
    /// @param _height The L2 height.
    /// @return The record; all zero if no landing ended at `_height`.
    function landings(uint256 _height) external view returns (Landing memory);

    /// @notice Returns the fixed origin of a recovery generation (slot 290).
    /// @param _generation The recovery generation.
    /// @return The origin; all zero if the generation has not started.
    function origins(uint256 _generation) external view returns (Origin memory);

    /// @notice Returns the current generation's start height,
    /// `origins(recoveryGeneration()).startHeight`.
    /// @return The start height.
    function generationStartHeight() external view returns (uint256);

    /// @notice Returns the current generation's origin L1 block,
    /// `origins(recoveryGeneration()).l1BlockNumber`.
    /// @dev `R` for a recovery generation; `L1_0` for generation 0, whose committee 0 is still
    /// selected at the genesis cutoff (spec 8.4).
    /// @return The origin L1 block.
    function recoverySnapshot() external view returns (uint256);

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

    /// @notice Returns the staking registry.
    /// @return The registry address.
    function stakingRegistry() external view returns (address);

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

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    /// @notice The Inbox is not initialized.
    error NotInitialized();
    /// @notice `maxBatchBlocks` is below 6.
    error InvalidMaxBatchBlocks();
    /// @notice The forced inclusion fee is zero.
    error ForcedInclusionFeeZero();
    /// @notice The forced inclusion fee doubling threshold is zero.
    error ForcedInclusionFeeDoubleThresholdZero();
    /// @notice The genesis block hash or state root is zero.
    error InvalidGenesis();
    /// @notice The epoch length is below 3 or its successor does not fit 48 bits.
    error InvalidEpochLength();
    /// @notice The genesis cutoff is not a past block at or after the registry's first
    /// checkpoint.
    error InvalidGenesisCutoff();
    /// @notice The committee 0 record hash is zero.
    error ZeroCommitteeRecord();
    /// @notice The committee configuration is out of bounds.
    error InvalidCommitteeConfig();
    /// @notice The forced inclusion delay is zero or does not fit 48 bits.
    error InvalidForcedInclusionDelay();
    /// @notice The maximum anchor age is below 1152 seconds or does not fit 48 bits.
    error InvalidMaxAnchorAge();
    /// @notice The registry's fixed Inbox or L2 chain id differs from this Inbox's.
    error RegistryMismatch();
    /// @notice A value does not fit its 48-bit storage field.
    error ValueOverflow();
    /// @notice The terminal height is already settled (`c >= h`).
    error AlreadySettled();
    /// @notice The proof origin is outside [generationStartHeight(), c] or `h` reaches 2^48.
    error InvalidRange();
    /// @notice `p` or `h` is not a multiple of 6.
    error OffGrid();
    /// @notice `h - p` exceeds `maxBatchBlocks`.
    error BatchTooLarge();
    /// @notice The proof origin has no landing record.
    error MissingOrigin();
    /// @notice The proof origin's record belongs to another generation.
    error ForeignGeneration();
    /// @notice The number of cut leaves is not `(h - p) / 6 - 1`.
    error LeafCountMismatch();
    /// @notice The checkpoint's recorded queue head differs from the stored queue head.
    error ForcedInclusionHeadMismatch();
    /// @notice The cut leaf at `c` differs from the one computed from `c`'s landing record.
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
    /// @notice The expected checkpoint height is not the current one.
    error CheckpointMismatch();
    /// @notice The exclusions are not sorted strictly by bond id.
    error ExclusionsNotSorted();
    /// @notice The forced inclusion indices to clear are not strictly increasing.
    error FiToClearNotSorted();
    /// @notice A forced inclusion index to clear is outside [head, tail).
    error FiIndexOutOfRange();
    /// @notice The new generation's origin is already written.
    error OriginAlreadyWritten();
    /// @notice The entry point does not accept ETH.
    error EtherNotAccepted();
}
