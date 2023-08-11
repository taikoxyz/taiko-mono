// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/**
 * @title LibAddress Library
 * @notice Provides utilities for address-related operations.
 *
 * This library offers a collection of methods to manage addresses in smart
 * contracts. These methods allow for safely sending Ether and fetching the
 * code hash of an address.
 */

library LibAddress {
    /**
     * @dev Sends Ether to the specified address.
     * It is recommended to avoid using `.transfer()` due to potential
     * reentrancy issues.
     * Reference:
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now
     *
     * @param to The recipient address.
     * @param amount The amount of Ether to send in wei.
     *
     * @notice If either the amount is zero or the recipient address is the zero
     * address, the function will simply return.
     */
    function sendEther(address to, uint256 amount) internal {
        // Check for zero-value or zero-address transactions
        if (amount == 0 || to == address(0)) return;

        // Attempt to send Ether to the recipient address
        (bool success,) = payable(to).call{ value: amount }("");

        // Ensure the transfer was successful
        require(success, "ETH transfer failed");
    }
}
