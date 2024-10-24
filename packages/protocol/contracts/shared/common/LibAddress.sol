// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

/// @title LibAddress
/// @dev Provides utilities for address-related operations.
/// @custom:security-contact security@taiko.xyz
library LibAddress {
    error ETH_TRANSFER_FAILED();

    /// @dev Sends Ether to the specified address. This method will not revert even if sending ether
    /// fails.
    /// This function is inspired by
    /// https://github.com/nomad-xyz/ExcessivelySafeCall/blob/main/src/ExcessivelySafeCall.sol
    /// @param _to The recipient address.
    /// @param _amount The amount of Ether to send in wei.
    /// @param _gasLimit The max amount gas to pay for this transaction.
    /// @return success_ true if the call is successful, false otherwise.
    function sendEther(
        address _to,
        uint256 _amount,
        uint256 _gasLimit,
        bytes memory _calldata
    )
        internal
        returns (bool success_)
    {
        // Check for zero-address transactions
        if (_to == address(0)) revert ETH_TRANSFER_FAILED();
        // dispatch message to recipient
        // by assembly calling "handle" function
        // we call via assembly to avoid memcopying a very large returndata
        // returned by a malicious contract
        assembly {
            success_ :=
                call(
                    _gasLimit, // gas
                    _to, // recipient
                    _amount, // ether value
                    add(_calldata, 0x20), // inloc
                    mload(_calldata), // inlen
                    0, // outloc
                    0 // outlen
                )
        }
    }

    /// @dev Sends Ether to the specified address. This method will revert if sending ether fails.
    /// @param _to The recipient address.
    /// @param _amount The amount of Ether to send in wei.
    /// @param _gasLimit The max amount gas to pay for this transaction.
    function sendEtherAndVerify(address _to, uint256 _amount, uint256 _gasLimit) internal {
        if (_amount == 0) return;
        if (!sendEther(_to, _amount, _gasLimit, "")) {
            revert ETH_TRANSFER_FAILED();
        }
    }

    /// @dev Sends Ether to the specified address. This method will revert if sending ether fails.
    /// @param _to The recipient address.
    /// @param _amount The amount of Ether to send in wei.
    function sendEtherAndVerify(address _to, uint256 _amount) internal {
        sendEtherAndVerify(_to, _amount, gasleft());
    }

    function supportsInterface(
        address _addr,
        bytes4 _interfaceId
    )
        internal
        view
        returns (bool result_)
    {
        (bool success, bytes memory data) =
            _addr.staticcall(abi.encodeCall(IERC165.supportsInterface, (_interfaceId)));
        if (success && data.length == 32) {
            result_ = abi.decode(data, (bool));
        }
    }
}
