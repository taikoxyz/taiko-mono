// SPDX-License-Identifier: MIT

//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/**
 * @title ISignalService
 * @notice This interface defines methods for sending and verifying signals
 * across chains.
 */
interface ISignalService {
    /**
     * @notice Emit a signal by setting the specified key to a value of 1.
     * @param signal The unique identifier for the signal to be emitted.
     * @return storageSlot The location in storage where this signal is stored.
     */
    function sendSignal(bytes32 signal)
        external
        returns (bytes32 storageSlot);

    /**
     * @notice Verifies if a particular signal has already been emitted.
     * @param app The address that initiated the signal.
     * @param signal The unique identifier for the signal to verify.
     * @return True if the signal has been emitted, otherwise false.
     */
    function isSignalSent(
        address app,
        bytes32 signal
    )
        external
        view
        returns (bool);

    /**
     * @notice Verifies if a signal has been acknowledged on the target chain.
     * @param srcChainId The identifier for the source chain from which the
     * signal originated.
     * @param app The address that initiated the signal.
     * @param signal The unique identifier for the signal to verify.
     * @param proof Data proving the signal was emitted on the source chain.
     * @return True if the signal has been acknowledged, otherwise false.
     */
    function isSignalReceived(
        uint256 srcChainId,
        address app,
        bytes32 signal,
        bytes calldata proof
    )
        external
        view
        returns (bool);
}
