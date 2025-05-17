// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";

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
        require(_to != address(0), ETH_TRANSFER_FAILED());
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
        require(sendEther(_to, _amount, _gasLimit, ""), ETH_TRANSFER_FAILED());
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

    function isContract(address _addr) internal view returns (bool) {
        return Address.isContract(_addr) // code size > 0
            && delegationOf(_addr) == address(0); // not an EOA with 7702 delegation
    }

    /// @dev Copied from https://github.com/Vectorized/solady/blob/main/src/accounts/LibEIP7702.sol
    /// @notice Returns the delegation address of an account.
    /// @param account The account to get the delegation address of.
    /// @return result The delegation address of the account.
    function delegationOf(address account) internal view returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            extcodecopy(account, 0x00, 0x00, 0x20)
            // Note: Checking that it starts with hex"ef01" is the most general and futureproof.
            // 7702 bytecode is `abi.encodePacked(hex"ef01", uint8(version), address(delegation))`.
            result := mul(shr(96, mload(0x03)), eq(0xef01, shr(240, mload(0x00))))
        }
    }
}
