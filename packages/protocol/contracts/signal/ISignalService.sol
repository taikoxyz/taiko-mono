// SPDX-License-Identifier: MIT

//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity 0.8.24;

/// @title ISignalService
/// @notice The SignalService contract serves as a secure cross-chain message
/// passing system. It defines methods for sending and verifying signals with
/// merkle proofs. The trust assumption is that the target chain has secure
/// access to the merkle root (such as Taiko injects it in the anchor
/// transaction). With this, verifying a signal is reduced to simply verifying
/// a merkle proof.

interface ISignalService {
    /// @notice Send a signal (message) by setting the storage slot to a value of 1.
    /// @param signal The signal (message) to send.
    /// @return slot The location in storage where this signal is stored.
    function sendSignal(bytes32 signal) external returns (bytes32 slot);

    /// @notice Relay a data from a remote chain locally as a signal. The signal is calculated
    /// uniquely from chainId, kind, and data.
    /// @param chainId The remote chainId.
    /// @param kind A value to mark the data type.
    /// @param data The remote data.
    /// @return slot The location in storage where this signal is stored.
    function relayChainData(
        uint64 chainId,
        bytes32 kind,
        bytes32 data
    )
        external
        returns (bytes32 slot);

    /// @notice Verifies if a signal has been received on the target chain.
    /// @param chainId The identifier for the source chain from which the
    /// signal originated.
    /// @param app The address that initiated the signal.
    /// @param signal The signal (message) to send.
    /// @param proof Merkle proof that the signal was persisted on the
    /// source chain.
    /// @return True if the signal has been received, otherwise false.
    function proveSignalReceived(
        uint64 chainId,
        address app,
        bytes32 signal,
        bytes calldata proof
    )
        external
        returns (bool);

    /// @notice Verifies if a particular signal has already been sent.
    /// @param app The address that initiated the signal.
    /// @param signal The signal (message) to send.
    /// @return True if the signal has been sent, otherwise false.
    function isSignalSent(address app, bytes32 signal) external view returns (bool);
}
