// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

interface ISignalService {
    /**
     * Send a signal by storing the key with a value of 1.
     *
     * @param signal The signal to send.
     * @return storageSlot The slot in storage that this signal is persisted.
     */
    function sendSignal(bytes32 signal) external returns (bytes32 storageSlot);

    /**
     * Check if a signal has been sent (key stored with a value of 1).
     *
     * @param app The address that sent this message.
     * @param signal The signal to check.
     */
    function isSignalSent(
        address app,
        bytes32 signal
    ) external view returns (bool);

    /**
     * Check if signal has been received on the destination chain (current).
     *
     * @param srcChainId The source chain ID.
     * @param app The address that sent this message.
     * @param signal The signal to check.
     * @param proof The proof of the signal being sent on the source chain.
     */
    function isSignalReceived(
        uint256 srcChainId,
        address app,
        bytes32 signal,
        bytes calldata proof
    ) external view returns (bool);
}
