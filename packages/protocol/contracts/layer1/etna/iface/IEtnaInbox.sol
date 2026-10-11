// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaInbox
/// @notice The L1 anchor of an Etna PoS chain that starts from L2 genesis.
/// @dev A fresh proxy is initialized with the L2 block-0 hash and state root, epoch parameters,
/// and the initial committee record. The node reads the genesis record, last checkpoint and
/// committee mapping directly from storage with EIP-1186 proofs. Their existing slots and packing
/// remain the interface to taiko-client-rs `crates/abci/src/l1/layout.rs`.
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

    /// @notice A committee record carried by a landed batch.
    struct CommitteeRecord {
        /// @notice The epoch whose committee the record defines.
        uint64 epoch;
        /// @notice The committee record hash.
        bytes32 recordHash;
    }

    /// @notice The batch of `land`: the L2 blocks after the last checkpoint up to `lastHeight`.
    struct LandInput {
        /// @notice The height of the batch's last block.
        uint64 lastHeight;
        /// @notice The hash of the batch's last block.
        bytes32 lastBlockHash;
        /// @notice The state root of the batch's last block.
        bytes32 lastStateRoot;
        /// @notice An L1 block such that every block of the batch has its anchor on the L1 header
        /// chain ending at this block's hash, i.e. at or after the last block's anchor number.
        /// @dev A lander picks a recent L1 block, so a landing outage longer than the EIP-2935
        /// window does not strand the batch.
        uint64 anchorNumber;
        /// @notice One record per epoch whose first block lies in the batch, in ascending order.
        CommitteeRecord[] records;
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

    /// @notice Emitted when a landed batch records the committee of an epoch.
    /// @param epoch The epoch.
    /// @param recordHash The committee record hash, now `committee(epoch)`.
    event CommitteeRecorded(uint64 indexed epoch, bytes32 recordHash);

    /// @notice Emitted when a batch is landed.
    /// @param firstHeight The height of the batch's first block.
    /// @param lastHeight The height of the batch's last block, the new checkpoint.
    /// @param lastBlockHash The hash of the batch's last block.
    /// @param lastStateRoot The state root of the batch's last block.
    /// @param anchorNumber The L1 block whose header chain holds every block's anchor.
    /// @param statementHash The landing statement hash the proof was verified against.
    /// @param lander The caller.
    event BatchLanded(
        uint64 firstHeight,
        uint64 lastHeight,
        bytes32 lastBlockHash,
        bytes32 lastStateRoot,
        uint64 anchorNumber,
        bytes32 statementHash,
        address indexed lander
    );

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes a fresh Etna proxy and its L2 block-0 checkpoint.
    /// @dev Call atomically in the proxy constructor. Requires non-zero genesis hash, state root
    /// and committee record, epochLenL2 >= 3, epochLenL1 > 0, and a past genesis cutoff at or
    /// after the registry's first checkpoint. The SignalService must authorize this proxy as its
    /// syncer: initialization saves its block-0 checkpoint too, and any failure rolls back all
    /// state. The owner supplies the trusted genesis values and the committee record computed
    /// from the registry snapshot. The node also requires L >= D_MAX - MARGIN_V + 3.
    /// @param _owner The owner; the proxy deployer if zero.
    /// @param _params The genesis parameters.
    function init(address _owner, GenesisParams calldata _params) external;

    /// @notice Lands a batch of Etna L2 blocks, the blocks after the last checkpoint up to
    /// `_input.lastHeight`, proven by `_proof`.
    /// @dev Permissionless. Requires, in order: Etna is active; the batch makes progress, covers
    /// at most `maxBatchBlocks` blocks and ends at or below `type(uint48).max` (the signal
    /// service key width); for every epoch `e` whose first block
    /// `h_first(e) = 1 + e * epochLenL2` lies in the batch, in ascending order,
    /// `_input.records` holds exactly one non-zero record with `epoch == e + 1` and
    /// `committee[e + 1]` is still empty (the record then becomes `committee[e + 1]`), and no
    /// other record; `anchorNumber` is a past L1 block whose hash is available, from `blockhash`
    /// for the last 256 blocks and from the EIP-2935 history contract for the last 8191; the
    /// transaction carries at least one blob, and the batch binds the hashes of all of them. Then
    /// makes `(lastHeight, lastBlockHash)` the last checkpoint, saves
    /// `(lastHeight, lastBlockHash, lastStateRoot)` in the signal service, emits `BatchLanded`
    /// and verifies `_proof` against the landing statement hash (see `hashLandStatement`) with a
    /// proposal age of 0.
    ///
    /// A valid proof attests that:
    /// - heights `parentHeight + 1` to `lastHeight` form a chain from the parent block hash to
    ///   `lastBlockHash` with post-state `lastStateRoot`, each executed under the Etna rules
    ///   (alethia-reth#248 plus the Etna node's header rules);
    /// - each height has a CometBFT commit with more than 2/3 of the voting power of its epoch
    ///   committee, under `chain_id = taiko-etna-<l2ChainId>-g<generation>`; the first epoch's
    ///   committee is `committee[0]` from initialization;
    /// - every block's anchor lies on the L1 header chain ending at `anchorHash`, the hash of
    ///   `anchorNumber`, so `anchorNumber` is at or after the last block's anchor number. A lander
    ///   picks a recent L1 block, so a landing outage longer than the 8191-block EIP-2935 window
    ///   does not strand the batch;
    /// - each record is the committee record derived from the witness carried in block
    ///   `h_first(e)`;
    /// - the blocks' data is encoded in the bound blobs (the encoding is defined with the lander
    ///   and the guest).
    ///
    /// Notes for guests: `keccak256(abi.encode(records))` hashes Solidity's ABI encoding of a
    /// dynamic array, which starts with the `0x20` offset word, then the length, then each
    /// record as two words. The statement does not bind `address(this)`, so the Inbox and
    /// registry addresses are constants of the guest program image: a proof for another Inbox
    /// needs another image.
    /// @param _input The batch.
    /// @param _proof The proof of the landing statement.
    function land(LandInput calldata _input, bytes calldata _proof) external;

    /// @notice Returns the landing statement hash a `land` proof attests to.
    /// @dev The hash is `keccak256(abi.encode(bytes32("TAIKO_ETNA_LAND_V1"), block.chainid,
    /// l2ChainId, _generation, _parentHeight, _parentHash, lastHeight, lastBlockHash,
    /// lastStateRoot, anchorNumber, _anchorHash, keccak256(abi.encode(records)),
    /// keccak256(abi.encodePacked(_blobHashes))))`, where `block.chainid` is a `uint256`, the
    /// generation, heights and anchor number are `uint64`s, and `records` and the other batch
    /// fields come from `_input`. `land` binds the current recovery generation, the last
    /// checkpoint as the parent, the anchor hash it reads and the transaction's blob hashes.
    /// @param _generation The recovery generation.
    /// @param _parentHeight The height of the block the batch builds on.
    /// @param _parentHash The hash of the block the batch builds on.
    /// @param _input The batch.
    /// @param _anchorHash The L1 block hash of `_input.anchorNumber`.
    /// @param _blobHashes The versioned hashes of the batch's blobs, in transaction order.
    /// @return The landing statement hash.
    function hashLandStatement(
        uint64 _generation,
        uint64 _parentHeight,
        bytes32 _parentHash,
        LandInput calldata _input,
        bytes32 _anchorHash,
        bytes32[] calldata _blobHashes
    )
        external
        view
        returns (bytes32);

    /// @notice Returns the latest landed L2 block.
    /// @return The latest landed checkpoint; zero before initialization.
    function lastCheckpoint() external view returns (LandedCheckpoint memory);

    /// @notice Returns the committee record hash of `_epoch`.
    /// @param _epoch The epoch.
    /// @return The committee record hash; zero if not recorded.
    function committee(uint64 _epoch) external view returns (bytes32);

    /// @notice Returns the genesis record at the existing activation-record slots.
    /// @return The genesis record; zero before initialization.
    function activation() external view returns (Activation memory);

    /// @notice Returns the L1 block of the epoch-0 committee snapshot.
    /// @return The genesis cutoff; zero before initialization.
    function genesisCutoff() external view returns (uint64);

    /// @notice Returns the status word consumed by the existing ABCI node.
    /// @dev The name is retained for node compatibility; there is no migration state machine.
    /// @return 3 after initialization, 0 before initialization.
    function migrationState() external view returns (uint8);

    /// @notice Returns the recovery generation bound into every landing statement.
    /// @dev Stays 0 until stall recovery (GOV-04) exists.
    /// @return The recovery generation.
    function recoveryGeneration() external view returns (uint64);
}
