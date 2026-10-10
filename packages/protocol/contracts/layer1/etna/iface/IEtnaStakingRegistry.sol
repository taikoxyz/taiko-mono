// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaStakingRegistry
/// @notice The TAIKO staking registry the Etna PoS node derives its committees from.
/// @dev The node reads `checkpoints` and `entries` straight from storage with EIP-1186 proofs,
/// so the field order and packing of both structs are part of the node-facing layout.
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
}
