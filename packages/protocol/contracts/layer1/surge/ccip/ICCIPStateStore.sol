// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICCIPStateStore
/// @notice Interface for storing and syncing L2 chain state for CCIP integration
/// @custom:security-contact security@nethermind.io
interface ICCIPStateStore {
    /// @notice Structure representing synced L2 state
    /// @param syncedAt Timestamp when the state was synced
    /// @param stateRoot The state root of the L2 block
    /// @param blockHash The hash of the L2 block
    struct SyncedState {
        uint256 syncedAt;
        bytes32 stateRoot;
        bytes32 blockHash;
    }

    /// @notice Syncs L2 chain state using a provided TEE proof
    /// @dev The proof contains: blockhash (32 bytes) || stateroot (32 bytes) || signature (65 bytes)
    /// The signature must be from a registered TDX instance and signs keccak256(blockhash || stateroot).
    /// @param _proof The TEE proof data containing blockhash, stateroot, and signature
    function syncState(bytes calldata _proof) external;

    /// @notice Retrieves the latest synced state
    /// @return The synced state containing timestamp, state root, and block hash
    function getSyncedState() external view returns (SyncedState memory);
}
