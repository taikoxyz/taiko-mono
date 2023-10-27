// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibAddress } from "../libs/LibAddress.sol";
import { AuthorizableContract } from "../common/AuthorizableContract.sol";
import { Proxied } from "../common/Proxied.sol";

/// @title EtherVault
/// @notice This contract is initialized with 2^128 Ether and allows authorized
/// addresses to release Ether.
/// @dev Only the contract owner can authorize or deauthorize addresses.
contract EtherVault is AuthorizableContract {
    using LibAddress for address;

    uint256[50] private __gap;

    event EtherReleased(address indexed to, uint256 amount);

    error VAULT_INVALID_RECIPIENT();

    receive() external payable { }

    /// @notice Transfers Ether from EtherVault to the sender, checking that the
    /// sender is authorized.
    /// @param amount Amount of Ether to send.
    function releaseEther(uint256 amount)
        public
        onlyAuthorized
        nonReentrant
        whenNotPaused
    {
        msg.sender.sendEther(amount);
        emit EtherReleased(msg.sender, amount);
    }

    /// @notice Transfers Ether from EtherVault to a designated address,
    /// checking that the sender is authorized.
    /// @param recipient Address to receive Ether.
    /// @param amount Amount of ether to send.
    function releaseEther(
        address recipient,
        uint256 amount
    )
        public
        onlyAuthorized
        nonReentrant
        whenNotPaused
    {
        if (recipient == address(0)) revert VAULT_INVALID_RECIPIENT();

        recipient.sendEther(amount);
        emit EtherReleased(recipient, amount);
    }
}

/// @title ProxiedEtherVault
/// @notice Proxied version of the parent contract.
contract ProxiedEtherVault is Proxied, EtherVault { }
