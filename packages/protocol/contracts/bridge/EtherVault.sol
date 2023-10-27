// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { LibAddress } from "../libs/LibAddress.sol";
import { Proxied } from "../common/Proxied.sol";

/// @title EtherVault
/// @notice This contract is initialized with 2^128 Ether and allows authorized
/// addresses to release Ether.
/// @dev Only the contract owner can authorize or deauthorize addresses.
contract EtherVault is EssentialContract {
    using LibAddress for address;

    mapping(address addr => bool authorized) public isAuthorized;
    uint256[49] private __gap;

    event Authorized(address indexed addr, bool authorized);
    event EtherReleased(address indexed to, uint256 amount);

    error VAULT_PERMISSION_DENIED();
    error VAULT_INVALID_PARAMS();

    // TODO(dani): please remove authorization related code and use
    // `onlyFromNamed`
    modifier onlyAuthorized() {
        // Ensure the caller is authorized to perform the action
        if (!isAuthorized[msg.sender]) revert VAULT_PERMISSION_DENIED();
        _;
    }

    receive() external payable { }

    /// @notice Initializes the contract with an {AddressManager}.
    /// @param addressManager The address of the {AddressManager} contract.
    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /// @notice Transfers Ether from EtherVault to the sender, checking that the
    /// sender is authorized.
    /// @param amount Amount of Ether to send.
    function releaseEther(uint256 amount)
        public
        onlyAuthorized
        nonReentrant
        whenNotPaused
        // onlyFromNamed("bridge")
        onlyWhenNamed("ether_vault")
    {
        msg.sender.sendEther(amount);
        emit EtherReleased(msg.sender, amount);
    }

    /// @notice Sets the authorized status of an address, only the owner can
    /// call this function.
    /// @param addr Address to set the authorized status of.
    /// @param authorized Authorized status to set.
    function authorize(address addr, bool authorized) public onlyOwner {
        if (addr == address(0)) revert VAULT_INVALID_PARAMS();
        if (isAuthorized[addr] == authorized) revert VAULT_INVALID_PARAMS();

        isAuthorized[addr] = authorized;
        emit Authorized(addr, authorized);
    }
}

/// @title ProxiedEtherVault
/// @notice Proxied version of the parent contract.
contract ProxiedEtherVault is Proxied, EtherVault { }
