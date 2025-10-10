// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ICheckpointStore.sol";

/// @title ISignalServiceShasta
/// @notice The SignalService contract serves as a secure cross-chain message
/// passing system. It defines methods for sending and verifying signals with
/// merkle proofs. The trust assumption is that the target chain has secure
/// access to the merkle root (such as Taiko injects it in the anchor
/// transaction). With this, verifying a signal is reduced to simply verifying
/// a merkle proof.
/// @custom:security-contact security@taiko.xyz
interface ISignalServiceShasta is ICheckpointStore {
    /// @dev Proof struct for signal verification
    /// Maintains the same structure as the original `ISignalService.HopProof` for compatibility
    struct Proof {
        /// @notice Deprecated. Kept here for abi compatibility.
        /// @dev In a two chain message system, this is not needed.
        uint64 chainId;
        /// @notice The ID of a source chain block whose state root has been synced to the hop's
        /// destination chain.
        /// Note that this block ID must be greater than or equal to the block ID where the signal
        /// was sent on the source chain.
        uint64 blockId;
        /// @notice The state root of the source chain at the above blockId. This value must match
        /// the checkpoint stored in the destination chain's SignalService.
        bytes32 rootHash;
        /// @dev Deprecated. Kept here for abi compatibility
        uint8 deprecatedCacheOption;
        /// @notice The signal service's account proof. If this value is empty, then `rootHash` will
        /// be used as the signal root, otherwise, `rootHash` will be used as the state root.
        bytes[] accountProof;
        /// @notice The signal service's storage proof.
        bytes[] storageProof;
    }

    /// @notice Emitted when a signal is sent.
    /// @param app The address that initiated the signal.
    /// @param signal The signal (message) that was sent.
    /// @param slot The location in storage where this signal is stored.
    /// @param value The value of the signal.
    event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value);

    /// @notice Send a signal (message) by setting the storage slot to the same value as the signal
    /// itself.
    /// @param _signal The signal (message) to send.
    /// @return slot_ The location in storage where this signal is stored.
    function sendSignal(bytes32 _signal) external returns (bytes32 slot_);

    /// @notice Verifies if a signal has been received on the target chain.
    /// @param _chainId The identifier for the source chain from which the
    /// signal originated.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) to send.
    /// @param _proof Merkle proof that the signal was persisted on the
    /// source chain. If this proof is empty, then we check if this signal has been marked as
    /// received by calling proveSignalReceived.
    /// @return numCacheOps_ The number of newly cached items.
    function proveSignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        external
        returns (uint256 numCacheOps_);

    /// @notice Verifies if a signal has been received on the target chain.
    /// This is the "readonly" version of proveSignalReceived.
    /// @param _chainId The identifier for the source chain from which the
    /// signal originated.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) to send.
    /// @param _proof Merkle proof that the signal was persisted on the
    /// source chain. If this proof is empty, then we check if this signal has been marked as
    /// received by calling proveSignalReceived.
    function verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        external
        view;

    /// @notice Verifies if a particular signal has already been sent.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) that was sent.
    /// @return true if the signal has been sent, otherwise false.
    function isSignalSent(address _app, bytes32 _signal) external view returns (bool);

    /// @notice Verifies if a particular signal has already been sent.
    /// @param _signalSlot The location in storage where this signal is stored.
    function isSignalSent(bytes32 _signalSlot) external view returns (bool);
}
