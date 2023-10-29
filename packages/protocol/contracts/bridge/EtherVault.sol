// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AuthorizableContract } from "../common/AuthorizableContract.sol";
import { LibAddress } from "../libs/LibAddress.sol";
import { Proxied } from "../common/Proxied.sol";

/// @title EtherVault
/// @dev Labeled in AddressResolver as "ether_vault"
/// @notice This contract is initialized with 2^128 Ether and allows authorized
/// addresses to release Ether.
///
/// @dev Authorization Guide:
/// For facilitating multi-hop bridging, authorize all deployed TaikoL1 and
/// Bridge
/// contracts involved in the bridging path..
contract EtherVault is AuthorizableContract {
    using LibAddress for address;

    uint256[50] private __gap;

    event Authorized(address indexed addr, bool authorized);
    event EtherReleased(address indexed to, uint256 amount);

    error VAULT_INVALID_RECIPIENT();
    error VAULT_INVALID_PARAMS();

    receive() external payable { }

    /// @notice Initializes the contract with an {AddressManager}.
    function init() external initializer {
        AuthorizableContract._init();
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
        onlyFromAuthorized
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
