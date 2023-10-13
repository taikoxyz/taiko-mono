// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { SafeERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibAddress } from "../libs/LibAddress.sol";

/// @title EtherVault
/// @notice This contract is initialized with 2^128 Ether and allows authorized
/// addresses to release Ether.
/// @dev Only the contract owner can authorize or deauthorize addresses.
contract EtherVault is EssentialContract {
    using LibAddress for address;

    mapping(address addr => bool isAuthorized) private _authorizedAddrs; // Authorized
        // addresses
    uint256[49] private __gap;

    event Authorized(address indexed addr, bool authorized);
    event EtherReleased(address indexed to, uint256 amount);

    error VAULT_PERMISSION_DENIED();
    error VAULT_INVALID_RECIPIENT();
    error VAULT_INVALID_PARAMS();

    modifier onlyAuthorized() {
        // Ensure the caller is authorized to perform the action
        if (!isAuthorized(msg.sender)) revert VAULT_PERMISSION_DENIED();
        _;
    }

    /// @notice Function to receive Ether.
    /// @dev Only authorized addresses can send Ether to the contract.
    receive() external payable {
        // EthVault's balance must == 0 OR the sender isAuthorized.
        if (address(this).balance != 0 && !isAuthorized(msg.sender)) {
            revert VAULT_PERMISSION_DENIED();
        }
    }

    /// @notice Initializes the contract with an {AddressManager}.
    /// @param addressManager The address of the {AddressManager} contract.
    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /// @notice Transfers Ether from EtherVault to the sender, checking that the
    /// sender is authorized.
    /// @param amount Amount of Ether to send.
    function releaseEther(uint256 amount) public onlyAuthorized nonReentrant {
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
    {
        if (amount == 0) return;
        if (recipient == address(0)) revert VAULT_INVALID_RECIPIENT();

        recipient.sendEther(amount);
        emit EtherReleased(recipient, amount);
    }

    /// @notice Sets the authorized status of an address, only the owner can
    /// call this function.
    /// @param addr Address to set the authorized status of.
    /// @param authorized Authorized status to set.
    function authorize(address addr, bool authorized) public onlyOwner {
        if (addr == address(0) || _authorizedAddrs[addr] == authorized) {
            revert VAULT_INVALID_PARAMS();
        }
        _authorizedAddrs[addr] = authorized;
        emit Authorized(addr, authorized);
    }

    /// @notice Gets the authorized status of an address.
    /// @param addr Address to get the authorized status of.
    function isAuthorized(address addr) public view returns (bool) {
        return _authorizedAddrs[addr];
    }
}

/// @title ProxiedEtherVault
/// @notice Proxied version of the parent contract.
contract ProxiedEtherVault is Proxied, EtherVault { }
