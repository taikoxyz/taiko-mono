// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaInbox
/// @notice The Etna implementation of the Inbox proxy: the L1 anchor of the Etna PoS chain.
/// @dev The Shasta Inbox proxy migrates in place in two upgrades: the Shasta implementation's
/// `freeze()` stops new proposals, and once every Shasta proposal is proven the owner upgrades to
/// the Etna implementation and calls `activateEtna` in the same transaction. The last finalized
/// Shasta block becomes the Etna genesis `B*` and the starting checkpoint.
///
/// The Etna node reads the activation record, the last checkpoint, the committee mapping, the
/// genesis cutoff and the migration state straight from storage with EIP-1186 proofs, so their
/// slots and packing are part of the node-facing layout (taiko-client-rs
/// `crates/abci/src/l1/layout.rs`). Anyone may then `land` batches of Etna blocks with a validity
/// proof, which advances the last checkpoint and records each new epoch's committee.
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
        /// @notice The ERC20 token of the legacy Shasta bonds.
        address bondToken;
        /// @notice The chain id of the Etna L2.
        uint64 l2ChainId;
        /// @notice The maximum number of L2 blocks one `land` call may cover.
        uint64 maxBatchBlocks;
        /// @notice The legacy Shasta minimum bond in gwei, kept for the bond exit.
        uint64 minBond;
        /// @notice The legacy Shasta bond withdrawal delay in seconds, kept for the bond exit.
        uint48 withdrawalDelay;
    }

    /// @notice The owner's parameters of `activateEtna`.
    struct ActivationParams {
        /// @notice `B*`: the last finalized Shasta L2 block, the Etna genesis.
        uint64 genesisHeight;
        /// @notice `L`: the epoch length in L2 blocks.
        uint64 epochLenL2;
        /// @notice The epoch length in L1 blocks.
        uint64 epochLenL1;
        /// @notice The L1 block at which the epoch-0 committee snapshot is taken.
        uint64 genesisCutoff;
        /// @notice `committee[0]`, computed off-chain from the registry at `genesisCutoff`.
        bytes32 committeeRecordHash;
    }

    /// @notice The activation record.
    /// @dev Three storage words: `genesisHeight` (bits 0–63), `l1Block` (bits 64–127),
    /// `epochLenL2` (bits 128–191) and `epochLenL1` (bits 192–255), then `genesisBlockHash`, then
    /// `genesisStateRoot`.
    struct Activation {
        /// @notice `B*`: the Etna genesis height.
        uint64 genesisHeight;
        /// @notice `L1_0`: the L1 block in which Etna was activated.
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

    /// @notice The latest L2 block landed on L1 (`B*` right after activation).
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

    /// @notice Emitted when the owner activates Etna.
    /// @param genesisHeight `B*`.
    /// @param genesisBlockHash `H*`.
    /// @param genesisStateRoot `S*`.
    /// @param l1Block `L1_0`, the activation block.
    /// @param epochLenL2 `L`, the epoch length in L2 blocks.
    /// @param epochLenL1 The epoch length in L1 blocks.
    /// @param genesisCutoff The L1 block of the epoch-0 committee snapshot.
    /// @param committeeRecordHash `committee[0]`.
    event EtnaActivated(
        uint64 genesisHeight,
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

    /// @notice Activates Etna on the frozen and drained Shasta Inbox.
    /// @dev Owner only; meant for `upgradeToAndCall` in the upgrade from the Shasta
    /// implementation. Requires, in order: the Inbox is frozen; every Shasta proposal is proven;
    /// the signal service holds a checkpoint at `genesisHeight` whose block hash is the Shasta
    /// last finalized block hash; `epochLenL2 >= 3` and `epochLenL1 > 0`; `genesisCutoff` is a
    /// past L1 block at or after the registry's first checkpoint; `committeeRecordHash` is
    /// non-zero. Then records the activation (`L1_0 = block.number`, the checkpoint's block hash
    /// and state root as `H*` and `S*`), the genesis cutoff, `committee[0]` and the starting
    /// checkpoint `(B*, H*)`, and moves the migration state to `ETNA_ACTIVE`, so it runs once.
    /// The node also requires `L >= D_MAX - MARGIN_V + 3`, which the contract cannot check.
    /// @param _params The activation parameters.
    function activateEtna(ActivationParams calldata _params) external;

    /// @notice Lands a batch of Etna L2 blocks, the blocks after the last checkpoint up to
    /// `_input.lastHeight`, proven by `_proof`.
    /// @dev Permissionless. Requires, in order: Etna is active; the batch makes progress, covers
    /// at most `maxBatchBlocks` blocks and ends at or below `type(uint48).max` (the signal
    /// service key width); `_input.records` holds exactly one non-zero record, with
    /// `epoch == e + 1` and in ascending order, for every epoch `e` whose first block
    /// `h_first(e) = genesisHeight + 1 + e * epochLenL2` lies in the batch, and each becomes
    /// `committee[e + 1]`, and `committee[e + 1]` is still empty; `anchorNumber` is a past L1
    /// block whose hash is available, from `blockhash` for the last 256 blocks and from the
    /// EIP-2935 history contract for the last 8191; the transaction carries at least one blob,
    /// and the batch binds the hashes of all of them. Then makes `(lastHeight, lastBlockHash)` the
    /// last checkpoint, saves `(lastHeight, lastBlockHash, lastStateRoot)` in the signal service,
    /// emits `BatchLanded` and verifies `_proof` against the landing statement hash (see
    /// `hashLandStatement`) with a proposal age of 0.
    ///
    /// A valid proof attests that:
    /// - heights `parentHeight + 1` to `lastHeight` form a chain from the parent block hash to
    ///   `lastBlockHash` with post-state `lastStateRoot`, each executed under the Etna rules
    ///   (alethia-reth#248 plus the Etna node's header rules);
    /// - each height has a CometBFT commit with more than 2/3 of the voting power of its epoch
    ///   committee, under `chain_id = taiko-etna-<l2ChainId>-g<generation>`; the first epoch's
    ///   committee is `committee[0]` from activation;
    /// - every block's anchor lies on the L1 header chain ending at `anchorHash`, the hash of
    ///   `anchorNumber`, so `anchorNumber` is at or after the last block's anchor number. A lander
    ///   picks a recent L1 block, so a landing outage longer than the 8191-block EIP-2935 window
    ///   does not strand the batch; the chosen block must only be at most 8191 blocks old when
    ///   `land` executes;
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
    /// @return The latest landed checkpoint; zero before activation.
    function lastCheckpoint() external view returns (LandedCheckpoint memory);

    /// @notice Returns the committee record hash of `_epoch`.
    /// @param _epoch The epoch.
    /// @return The committee record hash; zero if not recorded.
    function committee(uint64 _epoch) external view returns (bytes32);

    /// @notice Returns the activation record.
    /// @return The activation record; zero before activation.
    function activation() external view returns (Activation memory);

    /// @notice Returns the L1 block of the epoch-0 committee snapshot.
    /// @return The genesis cutoff; zero before activation.
    function genesisCutoff() external view returns (uint64);

    /// @notice Returns the migration state (`LibInboxMigration`).
    /// @return The migration state: `FROZEN` before activation, `ETNA_ACTIVE` after.
    function migrationState() external view returns (uint8);

    /// @notice Returns the recovery generation bound into every landing statement.
    /// @dev Stays 0 until stall recovery (GOV-04) exists.
    /// @return The recovery generation.
    function recoveryGeneration() external view returns (uint64);
}
