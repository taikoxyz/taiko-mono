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
/// `crates/abci/src/l1/layout.rs`).
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
