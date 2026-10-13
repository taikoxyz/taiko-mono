// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaInbox
/// @notice The L1 anchor of an Etna PoS chain that starts from L2 genesis.
/// @dev A fresh proxy is initialized with the L2 block-0 hash and state root, epoch parameters,
/// and the initial committee record and derivation configuration hash. The node authenticates
/// genesis and checkpoint storage with EIP-1186 proofs. Future committees derive from the
/// committed switch-parent anchor and are never published by landing transactions.
/// @custom:security-contact security@taiko.xyz
interface IEtnaInbox {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice The constructor parameters of the Etna Inbox implementation.
    struct Config {
        /// @notice The verifier of `land` proofs.
        address proofVerifier;
        /// @notice The L1 signal service that stores the L2 checkpoints.
        address signalService;
        /// @notice The Etna staking registry the committees derive from.
        address stakingRegistry;
        /// @notice The chain id of the Etna L2.
        uint64 l2ChainId;
        /// @notice The maximum number of L2 blocks one `land` call may cover.
        uint64 maxBatchBlocks;
        /// @notice The forced inclusion fee in Gwei with an empty queue.
        uint64 forcedInclusionFeeInGwei;
        /// @notice The number of pending forced inclusions at which the fee doubles.
        uint64 forcedInclusionFeeDoubleThreshold;
    }

    /// @notice The genesis parameters of a new Etna chain.
    struct GenesisParams {
        /// @notice The hash of L2 block 0.
        bytes32 genesisBlockHash;
        /// @notice The state root of L2 block 0.
        bytes32 genesisStateRoot;
        /// @notice The epoch length in L2 blocks.
        uint64 epochLenL2;
        /// @notice The epoch length in L1 blocks.
        uint64 epochLenL1;
        /// @notice A past L1 block whose registry snapshot defines committee 0.
        uint64 genesisCutoff;
        /// @notice The initial committee record hash, computed from that snapshot.
        bytes32 committeeRecordHash;
        /// @notice The non-zero commitment to the parent-anchor committee derivation configuration.
        bytes32 committeeConfigHash;
        /// @notice The forced inclusion delay in seconds, non-zero and below the 14-day expiry: an
        /// entry is due at an L2 block whose anchor timestamp is at least its timestamp plus it.
        uint64 forcedInclusionDelay;
        /// @notice The maximum anchor age in seconds, non-zero: every L2 block requires
        /// `block.timestamp - anchor.timestamp <= maxAnchorAge`.
        uint64 maxAnchorAge;
    }

    /// @notice The genesis record; named activation for the existing node storage interface.
    /// @dev Three storage words: `genesisHeight` (bits 0–63), `l1Block` (bits 64–127),
    /// `epochLenL2` (bits 128–191) and `epochLenL1` (bits 192–255), then `genesisBlockHash`, then
    /// `genesisStateRoot`.
    struct Activation {
        /// @notice The Etna genesis height, always 0.
        uint64 genesisHeight;
        /// @notice `L1_0`: the L1 block in which the proxy was initialized.
        uint64 l1Block;
        /// @notice `L`: the epoch length in L2 blocks.
        uint64 epochLenL2;
        /// @notice The epoch length in L1 blocks.
        uint64 epochLenL1;
        /// @notice `H*`: the block hash of `B*`.
        bytes32 genesisBlockHash;
        /// @notice `S*`: the state root of `B*`.
        bytes32 genesisStateRoot;
    }

    /// @notice The latest L2 block landed on L1 (block 0 after initialization).
    /// @dev Two storage words: `height` (bits 0–63), then `blockHash`.
    struct LandedCheckpoint {
        /// @notice The L2 block height.
        uint64 height;
        /// @notice The L2 block hash.
        bytes32 blockHash;
    }

    /// @notice The batch of `land`: the L2 blocks after the last checkpoint up to `lastHeight`.
    struct LandInput {
        /// @notice The height of the batch's last block.
        uint64 lastHeight;
        /// @notice The hash of the batch's last block.
        bytes32 lastBlockHash;
        /// @notice The state root of the batch's last block.
        bytes32 lastStateRoot;
        /// @notice The L1 reference block authenticating the batch's anchor header chain.
        /// @dev Every L2 block may have its own anchor; all must be on the L1 header chain ending
        /// at this reference block, whose number is at least the last block's anchor number.
        /// A lander picks a recent L1 block, so a landing outage longer than the EIP-2935
        /// window does not strand the batch.
        uint64 l1ReferenceBlockNumber;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a fresh Etna proxy is initialized from L2 genesis.
    /// @param genesisBlockHash The hash of L2 block 0.
    /// @param genesisStateRoot The state root of L2 block 0.
    /// @param l1Block The L1 initialization block.
    /// @param epochLenL2 The epoch length in L2 blocks.
    /// @param epochLenL1 The epoch length in L1 blocks.
    /// @param genesisCutoff The initial committee's registry snapshot block.
    /// @param committeeRecordHash The initial committee record hash.
    event EtnaInitialized(
        bytes32 genesisBlockHash,
        bytes32 genesisStateRoot,
        uint64 l1Block,
        uint64 epochLenL2,
        uint64 epochLenL1,
        uint64 genesisCutoff,
        bytes32 committeeRecordHash
    );

    /// @notice Emitted when a batch is landed.
    /// @param firstHeight The height of the batch's first block.
    /// @param lastHeight The height of the batch's last block, the new checkpoint.
    /// @param lastBlockHash The hash of the batch's last block.
    /// @param lastStateRoot The state root of the batch's last block.
    /// @param l1ReferenceBlockNumber The L1 block whose header chain holds every block's anchor.
    /// @param statementHash The landing statement hash the proof was verified against.
    /// @param lander The caller.
    event BatchLanded(
        uint64 firstHeight,
        uint64 lastHeight,
        bytes32 lastBlockHash,
        bytes32 lastStateRoot,
        uint64 l1ReferenceBlockNumber,
        bytes32 statementHash,
        address indexed lander
    );

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes a fresh Etna proxy and its L2 block-0 checkpoint.
    /// @dev Call atomically in the proxy constructor. Requires non-zero genesis hash, state root,
    /// committee record and derivation configuration hash, epochLenL2 >= 3, epochLenL1 > 0,
    /// a past genesis cutoff at or after the registry's first checkpoint, a forced inclusion
    /// delay in (0, 14 days) and a non-zero maximum anchor age. The SignalService must
    /// authorize this proxy as its
    /// syncer: initialization saves its block-0 checkpoint too, and any failure rolls back all
    /// state. The owner supplies the trusted genesis values and the committee record computed
    /// from the registry snapshot. The node also requires L >= D_MAX - MARGIN_V + 3.
    /// @param _owner The owner; the proxy deployer if zero.
    /// @param _params The genesis parameters.
    function init(address _owner, GenesisParams calldata _params) external;

    /// @notice Lands the L2 blocks after the last checkpoint up to `_input.lastHeight`.
    /// @dev Permissionless. Requires active status, progress, at most `maxBatchBlocks` blocks,
    /// and a last height at or below `type(uint48).max`. The reference is a past L1 block with
    /// a non-zero hash available through blockhash (256 blocks) or EIP-2935 (8191 blocks).
    /// At least one blob is required, and every actual transaction blob hash is bound in order.
    /// Saves the terminal checkpoint in the Inbox and SignalService, emits BatchLanded, then
    /// verifies the V5 statement with proposal age 0; verifier failure rolls back every write.
    /// No future committee record is an input or output of landing.
    ///
    /// A valid Etna proof must authenticate every Inbox/registry account and storage proof under
    /// the respective bound address and authenticated L1 state root. It must open the stored
    /// committeeConfigHash using the exact nine-word encoding (288 bytes):
    /// abi.encode(bytes32("ETNA_PARENT_ANCHOR_V1"), uint256(l2ChainId), address(stakingRegistry),
    /// uint256(vpUnit), uint256(sMin), uint64(nMax), uint64(heartbeatWindow), uint64(2), uint8(1)).
    /// The final words bind heartbeat lookahead 2 and retained membership algorithm version 1.
    /// Authenticate the genesis schedule and explicit genesisCutoff from Inbox storage.
    /// Committee 0 opens the plain slot-278 bootstrap record at genesisCutoff (slot 279).
    ///
    /// For t >= 1, H(t) = 1 + t * epochLenL2, S(t) = H(t) - 2 and D(t) = H(t) - 3, with
    /// checked arithmetic. At S(t), derive the incoming set at exactly the committed parent's
    /// anchor number, under that parent's authenticated L1 root; never the candidate's anchor.
    /// Authenticate complete registry entries/count/root and evaluate active/exit eligibility at
    /// that snapshot number. Preserve effective stake, earliest eligible bondId per pubkey,
    /// nMax ranking, MEM-08 ordering/root, voting-power division and overflow caps. Heartbeats
    /// retain target-epoch evaluation with lookahead 2 and exemptions for epochs 0, 1 and 2.
    /// Non-switch blocks forbid runtime committee witnesses. No empty-set fallback is implied.
    ///
    /// For arbitrary batch starts, authenticate the checkpoint EL header against the public
    /// parent hash, then consecutive descending parentHash links through each required D(t).
    /// Read the snapshot number only from D(t)'s generation-checked Etna anchor extraData;
    /// a separate derivation hint or the checkpoint's newer anchor cannot select the set.
    /// At nonzero checkpoint heights also authenticate the preceding EL header for the base-fee
    /// grandparent timestamp. Current/next starting epochs differ by at most one; checked
    /// history bounds require at most epochLenL2 + 2 links, without replaying old transactions.
    /// A later authenticated proving root whose number covers the snapshot may prove the last
    /// immutable registry checkpoint at/before it, the successor after it (when present), array
    /// length and complete entries/root. Recompute all parent/current/pending sets. In-batch
    /// switches still require the actual committed parent's exact root and snapshot number.
    ///
    /// Apply CometBFT H+2 timing: updates returned at S(t) and persisted at Commit activate at
    /// H(t). Verify the parent certificate, every current/pending certificate and current/next
    /// validator hash across S/S+1/H and arbitrary cuts, with strictly more than 2/3 distinct
    /// signer voting power under taiko-etna-<l2ChainId>-g<generation>. Anchor progress, status,
    /// generation and back-pressure rules still apply; deterministic Finalize/replay makes no
    /// new L1 calls. Epoch-first blocks need no publication witness.
    ///
    /// Prove contiguous execution from the parent hash to the terminal hash/state root, every
    /// anchor and actual proving L1 root on the header chain ending at the reference hash, and
    /// block data in the bound blobs. The blobs carry payload V2: each block's canonical CometBFT
    /// header and Etna envelope, where every header hashes to a certified block id, its data hash
    /// commits to the envelope and its last block id links the batch. Commits and signatures are
    /// proof witnesses, not blob data. A batch may start/end at any valid height without a
    /// previous batch's committee output. Envelope version 3, payload V2 and journal schema 4
    /// reject former V2/V4 histories, V1 payloads and older jobs; never discard or replace a
    /// signed nonce. The verifier must pin a guest
    /// enforcing these V5 rules. Dummy proof 0x00 is for development only; no real guest exists
    /// here and the dummy verifier does not establish consensus validity or ZK soundness.
    /// @param _input The four-field batch terminal checkpoint and reference block.
    /// @param _proof The proof of the V5 landing statement.
    function land(LandInput calldata _input, bytes calldata _proof) external;

    /// @notice Encodes the V5 landing statement for supplied batch public inputs.
    /// @dev Fifteen static ABI words (480 bytes): bytes32("TAIKO_ETNA_LAND_V5"), block.chainid,
    /// l2ChainId, address(this), address(stakingRegistry), _generation, _parentHeight, _parentHash,
    /// committeeConfigHash, lastHeight, lastBlockHash, lastStateRoot, l1ReferenceBlockNumber,
    /// _l1ReferenceBlockHash, keccak256(abi.encodePacked(_blobHashes)). Chain id is uint256;
    /// generation/heights are uint64, identities address and hashes bytes32. Identities and the
    /// config hash are read internally; call through the Inbox proxy to bind its address.
    /// This helper does not authenticate supplied batch values. land reads the stored parent
    /// and generation, resolves the reference hash and reads the actual transaction blob hashes.
    /// @param _generation The recovery generation.
    /// @param _parentHeight The parent checkpoint height.
    /// @param _parentHash The parent checkpoint block hash.
    /// @param _input The four-field batch.
    /// @param _l1ReferenceBlockHash The hash of `_input.l1ReferenceBlockNumber`.
    /// @param _blobHashes The versioned blob hashes in transaction order.
    /// @return statementHash_ The V5 statement hash.
    function hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        LandInput calldata _input,
        bytes32 _l1ReferenceBlockHash,
        bytes32[] calldata _blobHashes
    )
        external
        view
        returns (bytes32 statementHash_);

    /// @notice Returns the latest landed L2 block.
    /// @dev The initialized checkpoint is L2 block 0.
    /// @return The latest landed checkpoint; zero before initialization.
    function lastCheckpoint() external view returns (LandedCheckpoint memory);

    /// @notice Returns the authenticated committee derivation configuration commitment.
    /// @dev Stored at slot 269; installed once from the trusted genesis deployment input.
    /// @return configHash_ The configuration hash; zero before initialization.
    function committeeConfigHash() external view returns (bytes32 configHash_);

    /// @notice Returns the initial committee record commitment.
    /// @dev Stored directly at slot 278; no future epoch committee mapping exists.
    /// @return recordHash_ The genesis committee record hash; zero before initialization.
    function genesisCommitteeRecordHash() external view returns (bytes32 recordHash_);

    /// @notice Returns the genesis record at the existing activation-record slots.
    /// @dev The schedule and hashes are installed once during initialization.
    /// @return The genesis record; zero before initialization.
    function activation() external view returns (Activation memory);

    /// @notice Returns the L1 block of the epoch-0 committee snapshot.
    /// @dev Committee 0 alone uses this explicit snapshot; runtime sets use switch-parent anchors.
    /// @return The genesis cutoff; zero before initialization.
    function genesisCutoff() external view returns (uint64);

    /// @notice Returns the forced inclusion delay in seconds.
    /// @dev Stored at slot 282, bits 0–63; installed once from the trusted genesis input.
    /// @return The forced inclusion delay; zero before initialization.
    function forcedInclusionDelay() external view returns (uint64);

    /// @notice Returns the maximum age in seconds of an L2 block's anchor.
    /// @dev Stored at slot 282, bits 64–127; installed once from the trusted genesis input.
    /// @return The maximum anchor age; zero before initialization.
    function maxAnchorAge() external view returns (uint64);

    /// @notice Returns the status word consumed by the existing ABCI node.
    /// @dev The name is retained for node compatibility; there is no migration state machine.
    /// @return 3 after initialization, 0 before initialization.
    function migrationState() external view returns (uint8);

    /// @notice Returns the recovery generation bound into every landing statement.
    /// @dev Stays 0 until stall recovery (GOV-04) exists.
    /// @return The recovery generation.
    function recoveryGeneration() external view returns (uint64);
}
