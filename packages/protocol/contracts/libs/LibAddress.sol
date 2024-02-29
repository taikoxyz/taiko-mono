// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../thirdparty/nomad-xyz/ExcessivelySafeCall.sol";

/// @title LibAddress
/// @dev Provides utilities for address-related operations.
/// @custom:security-contact security@taiko.xyz
library LibAddress {
    bytes4 private constant _EIP1271_MAGICVALUE = 0x1626ba7e;

    error ETH_TRANSFER_FAILED();

    /// @dev Sends Ether to the specified address.
    /// @param _to The recipient address.
    /// @param _amount The amount of Ether to send in wei.
    /// @param _gasLimit The max amount gas to pay for this transaction.
    function sendEther(address _to, uint256 _amount, uint256 _gasLimit) internal {
        // Check for zero-address transactions
        if (_to == address(0)) revert ETH_TRANSFER_FAILED();

        // Attempt to send Ether to the recipient address
        (bool success,) = ExcessivelySafeCall.excessivelySafeCall(
            _to,
            _gasLimit,
            _amount,
            64, // return max 64 bytes
            ""
        );

        // Ensure the transfer was successful
        if (!success) revert ETH_TRANSFER_FAILED();
    }

    /// @dev Sends Ether to the specified address.
    /// @param _to The recipient address.
    /// @param _amount The amount of Ether to send in wei.
    function sendEther(address _to, uint256 _amount) internal {
        sendEther(_to, _amount, gasleft());
    }

    function supportsInterface(
        address _addr,
        bytes4 _interfaceId
    )
        internal
        view
        returns (bool result_)
    {
        if (!Address.isContract(_addr)) return false;

        try IERC165(_addr).supportsInterface(_interfaceId) returns (bool _result) {
            result_ = _result;
        } catch { }
    }

    function isValidSignature(
        address _addr,
        bytes32 _hash,
        bytes memory _sig
    )
        internal
        view
        returns (bool)
    {
        if (Address.isContract(_addr)) {
            return IERC1271(_addr).isValidSignature(_hash, _sig) == _EIP1271_MAGICVALUE;
        } else {
            return ECDSA.recover(_hash, _sig) == _addr;
        }
    }

    function isSenderEOA() internal view returns (bool) {
        return msg.sender == tx.origin;
    }
}
