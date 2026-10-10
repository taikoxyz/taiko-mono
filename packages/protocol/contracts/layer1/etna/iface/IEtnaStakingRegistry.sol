// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaStakingRegistry
/// @notice The TAIKO staking registry the Etna PoS node derives its committees from.
/// @dev Validators register an Ed25519 consensus key with a TAIKO stake, heartbeat once per
/// heartbeat window, request an exit and withdraw after the withdrawal delay. Entries are
/// append-only and indexed by bond id. Every L1 block that changes an entry ends with one
/// checkpoint holding the entry count and the entries Merkle root at the end of that block.
///
/// The node reads `checkpoints` and `entries` straight from storage with EIP-1186 proofs, so the
/// field order and packing of both structs, and their ERC-7201 location, are part of the
/// node-facing layout (taiko-client-rs `crates/abci/src/l1/layout.rs`).
/// @custom:security-contact security@taiko.xyz
interface IEtnaStakingRegistry {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice The registry as it stands at the end of one L1 block that changed an entry.
    /// @dev Two storage words: `l1Block` (bits 0–63) and `count` (bits 64–95), then
    /// `entriesRoot`.
    struct Checkpoint {
        /// @notice The L1 block whose entry changes this checkpoint captures.
        uint64 l1Block;
        /// @notice The number of entries (exited ones included) at the end of `l1Block`.
        uint32 count;
        /// @notice The entries Merkle root over the first `count` entries.
        bytes32 entriesRoot;
    }

    /// @notice One registration, indexed by its bond id.
    /// @dev Three storage words: `pubkey`, `effStake`, then `activeFromL1` (bits 0–63),
    /// `exitEffectiveL1` (bits 64–127), `lastHeartbeatAt` (bits 128–191) and
    /// `lastHeartbeatSeq` (bits 192–255).
    struct Entry {
        /// @notice The Ed25519 consensus public key.
        bytes32 pubkey;
        /// @notice The effective stake in TAIKO base units.
        uint256 effStake;
        /// @notice The first L1 block at which the entry may be selected.
        uint64 activeFromL1;
        /// @notice The L1 block at which the exit takes effect; `type(uint64).max` if none was
        /// requested.
        uint64 exitEffectiveL1;
        /// @notice The start L1 block of the heartbeat window of the last accepted heartbeat
        /// (MEM-13(2b)); 0 until the first heartbeat (registration is not one).
        uint64 lastHeartbeatAt;
        /// @notice The number of accepted heartbeats; 0 means none. A first heartbeat in window
        /// 0 leaves `lastHeartbeatAt` at 0, so this, not `lastHeartbeatAt`, tells whether the
        /// entry has a heartbeat (MEM-13(3)).
        uint64 lastHeartbeatSeq;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a validator registers.
    /// @param bondId The new entry's bond id.
    /// @param owner The bond owner (the caller).
    /// @param pubkey The Ed25519 consensus public key.
    /// @param amount The TAIKO stake pulled from the owner.
    /// @param activeFromL1 The first L1 block at which the entry may be selected.
    event Registered(
        uint256 indexed bondId,
        address indexed owner,
        bytes32 pubkey,
        uint256 amount,
        uint64 activeFromL1
    );

    /// @notice Emitted when a heartbeat is accepted.
    /// @param bondId The entry's bond id.
    /// @param windowStart The start L1 block of the heartbeat window, now the entry's
    /// `lastHeartbeatAt`.
    /// @param seq The entry's new `lastHeartbeatSeq`, the number of heartbeats accepted so far.
    event HeartbeatRecorded(uint256 indexed bondId, uint64 windowStart, uint64 seq);

    /// @notice Emitted when the bond owner requests an exit.
    /// @param bondId The entry's bond id.
    /// @param exitEffectiveL1 The L1 block at which the exit takes effect.
    event ExitRequested(uint256 indexed bondId, uint64 exitEffectiveL1);

    /// @notice Emitted when an exited entry's stake is withdrawn.
    /// @param bondId The entry's bond id.
    /// @param to The recipient of the stake.
    /// @param amount The TAIKO amount transferred.
    event StakeWithdrawn(uint256 indexed bondId, address indexed to, uint256 amount);

    /// @notice Emitted when the current block's checkpoint is appended or overwritten.
    /// @param index The checkpoint's index.
    /// @param l1Block The L1 block the checkpoint captures (the current block).
    /// @param count The number of entries at this point of the block.
    /// @param entriesRoot The entries Merkle root at this point of the block.
    event CheckpointWritten(
        uint256 indexed index, uint64 l1Block, uint32 count, bytes32 entriesRoot
    );

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Registers `_pubkey` with a stake of `_amount` TAIKO pulled from the caller, who
    /// becomes the bond owner.
    /// @dev Reverts if `_amount` is below the minimum stake, `_pubkey` is zero, the registry
    /// holds `MAX_ENTRIES` entries, or another entry holds `_pubkey` and its exit is not yet
    /// effective. The entry becomes active `activationDelay` blocks later, has no exit and no
    /// heartbeat (`lastHeartbeatAt = 0`, `lastHeartbeatSeq = 0`). Writes the current block's
    /// checkpoint.
    /// @param _pubkey The Ed25519 consensus public key.
    /// @param _amount The TAIKO stake; the caller must have approved it.
    /// @return bondId_ The new entry's bond id (its index).
    function register(bytes32 _pubkey, uint256 _amount) external returns (uint256 bondId_);

    /// @notice Records a heartbeat for `_bondId` in the current heartbeat window.
    /// @dev Only the bond owner, and only before the exit takes effect. With
    /// `windowStart = floor(block.number / heartbeatWindow) * heartbeatWindow`, the heartbeat
    /// is accepted if the entry has none yet (`lastHeartbeatSeq == 0`) or `windowStart` exceeds
    /// `lastHeartbeatAt`: at most one heartbeat per window, and `lastHeartbeatAt` never
    /// decreases. It then sets `lastHeartbeatAt = windowStart`, increments `lastHeartbeatSeq`
    /// and writes the current block's checkpoint.
    ///
    /// A first heartbeat in window 0 is valid and leaves `lastHeartbeatAt` at 0, so
    /// `lastHeartbeatAt` alone cannot tell "heartbeat in window 0" from "no heartbeat". The
    /// sequence is MEM-13(3)'s "has a heartbeat" guard: the node counts an entry as live only
    /// if `lastHeartbeatSeq > 0 && lastHeartbeatAt >= floor`, where `floor` is the start of
    /// the oldest window it still accepts.
    ///
    /// The bond owner's address heartbeats directly; MEM-13's ECDSA heartbeat key and relayed
    /// signed heartbeats are a follow-up.
    /// @param _bondId The entry's bond id.
    function heartbeat(uint256 _bondId) external;

    /// @notice Requests the exit of `_bondId`.
    /// @dev Only the bond owner, once. The exit takes effect at
    /// `max(block.number, activeFromL1) + exitDelay`. Writes the current block's checkpoint.
    /// @param _bondId The entry's bond id.
    function requestExit(uint256 _bondId) external;

    /// @notice Transfers the stake of `_bondId` to `_to`.
    /// @dev Only the bond owner, once, and only from `exitEffectiveL1 + withdrawalDelay` on. The
    /// entry itself is left unchanged, so no checkpoint is written.
    /// @param _bondId The entry's bond id.
    /// @param _to The recipient of the stake.
    function withdraw(uint256 _bondId, address _to) external;

    /// @notice Returns the number of checkpoints.
    /// @return The number of checkpoints.
    function checkpointCount() external view returns (uint256);

    /// @notice Returns checkpoint `_index`; reverts if it does not exist.
    /// @param _index The checkpoint index.
    /// @return The checkpoint.
    function checkpointAt(uint256 _index) external view returns (Checkpoint memory);

    /// @notice Returns the number of entries (exited ones included), which is the next bond id.
    /// @return The number of entries.
    function entryCount() external view returns (uint256);

    /// @notice Returns entry `_bondId`; reverts if it does not exist.
    /// @param _bondId The bond id.
    /// @return The entry.
    function entryAt(uint256 _bondId) external view returns (Entry memory);

    /// @notice Returns the entries Merkle root over all current entries.
    /// @dev Equals the latest checkpoint's `entriesRoot` (`bytes32(0)` before the first entry).
    /// @return The entries Merkle root.
    function entriesRoot() external view returns (bytes32);

    /// @notice Returns the owner of `_bondId`, or `address(0)` if it does not exist.
    /// @param _bondId The bond id.
    /// @return The bond owner.
    function bondOwnerOf(uint256 _bondId) external view returns (address);

    /// @notice Returns whether the stake of `_bondId` was withdrawn (false if it does not
    /// exist).
    /// @param _bondId The bond id.
    /// @return Whether the stake was withdrawn.
    function isWithdrawn(uint256 _bondId) external view returns (bool);
}
