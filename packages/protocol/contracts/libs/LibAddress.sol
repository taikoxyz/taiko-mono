// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../thirdparty/nomad-xyz/ExcessivelySafeCall.sol";
/// @title LibAddress
/// @custom:security-contact security@taiko.xyz
/// @dev Provides utilities for address-related operations.

library LibAddress {
    bytes4 private constant EIP1271_MAGICVALUE = 0x1626ba7e;

    error ETH_TRANSFER_FAILED();

    /// @dev Sends Ether to the specified address.
    /// @param to The recipient address.
    /// @param amount The amount of Ether to send in wei.
    /// @param gasLimit The max amount gas to pay for this transaction.
    function sendEther(address to, uint256 amount, uint256 gasLimit) internal {
        // Check for zero-address transactions
        if (to == address(0)) revert ETH_TRANSFER_FAILED();

        // Attempt to send Ether to the recipient address
        (bool success,) = ExcessivelySafeCall.excessivelySafeCall(
            to,
            gasLimit,
            amount,
            64, // return max 64 bytes
            ""
        );

        // Ensure the transfer was successful
        if (!success) revert ETH_TRANSFER_FAILED();
    }

    /// @dev Sends Ether to the specified address.
    /// @param to The recipient address.
    /// @param amount The amount of Ether to send in wei.
    function sendEther(address to, uint256 amount) internal {
        sendEther(to, amount, gasleft());
    }

    function supportsInterface(
        address addr,
        bytes4 interfaceId
    )
        internal
        view
        returns (bool result)
    {
        if (!Address.isContract(addr)) return false;

        try IERC165(addr).supportsInterface(interfaceId) returns (bool _result) {
            result = _result;
        } catch { }
    }

    function isValidSignature(
        address addr,
        bytes32 hash,
        bytes memory sig
    )
        internal
        view
        returns (bool valid)
    {
        if (Address.isContract(addr)) {
            return IERC1271(addr).isValidSignature(hash, sig) == EIP1271_MAGICVALUE;
        } else {
            return ECDSA.recover(hash, sig) == addr;
        }
    }

    function isSenderEOA() internal view returns (bool) {
        return msg.sender == tx.origin;
    }
}
