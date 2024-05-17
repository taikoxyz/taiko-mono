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

import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { BridgedERC20 } from "../../tokenvault/BridgedERC20.sol";

/// @title Simple ERC20 Vault
/// @notice This contract manages an ERC20 token vault designed for storing and approving tokens for
/// airdrops,
/// as well as allowing the owner to withdraw tokens.
/// @dev The contract uses OwnableUpgradeable for access control and interacts with BridgedERC20
/// tokens.
contract SimpleERC20Vault is OwnableUpgradeable {
    /// @notice Initializes the vault and sets up the contract with ownership rights.
    /// @dev This function calls the initializer for OwnableUpgradeable to set up the contract owner
    /// upon deployment.
    function init() external initializer {
        __Ownable_init();
    }

    /// @notice Approves a specified amount of tokens to an actor, allowing them to distribute these
    /// tokens.
    /// @param token The ERC20 token address whose tokens are to be approved.
    /// @param approvedActor The actor (typically another contract) approved to distribute the
    /// tokens.
    /// @param amount The amount of tokens that the approved actor is allowed to handle.
    /// @dev Can only be called by the owner of the vault.
    function approveAirdropContract(
        address token,
        address approvedActor,
        uint256 amount
    )
        public
        onlyOwner
    {
        BridgedERC20(token).approve(approvedActor, amount);
    }

    /// @notice Withdraws all tokens of a specified type to a given address.
    /// @param token The ERC20 token address from which funds will be withdrawn.
    /// @param to The destination address for the withdrawn tokens.
    /// @dev Can only be called by the owner. Withdraws the total balance of the specified token.
    function withdrawFunds(address token, address to) public onlyOwner {
        BridgedERC20(token).transfer(to, BridgedERC20(token).balanceOf(address(this)));
    }

    /// @notice Mints a large amount of tokens directly to a specified address.
    /// @param token The ERC20 token address whose tokens are to be minted.
    /// @param to The address that will receive the newly minted tokens.
    /// @dev This function is restricted to the contract owner and mints 50 billion tokens.
    function mintToVault(address token, address to) public onlyOwner {
        BridgedERC20(token).mint(address(to), 50_000_000_000e18);
    }
}
