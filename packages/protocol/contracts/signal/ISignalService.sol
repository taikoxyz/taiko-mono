// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

interface ISignalService {
    /**
     * Send a signal by storing the key with a value of 1.
     *
     * @param user The user address sending the signal.
     * @param signal The signal to send.
     */
    function sendSignal(address user, bytes32 signal) external;

    /**
     * Check if a signal has been sent (key stored with a value of 1).
     *
     * @param user The sender address of the signal.
     * @param signal The signal to check.
     */
    function isSignalSent(
        address app,
        address user,
        bytes32 signal
    ) external view returns (bool);

    /**
     * Check if signal has been received on the destination chain (current).
     *
     * @param app Address of the source bridge where the bridge
     *                  was initiated.
     * @param user Address of the sender of the signal
     *               (also should be app).
     * @param signal The signal to check.
     * @param proof The proof of the signal being sent on the source chain.
     */
    function isSignalReceived(
        address app,
        address user,
        bytes32 signal,
        bytes calldata proof
    ) external view returns (bool);
}
