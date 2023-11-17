// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { NoncesUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/NoncesUpgradeable.sol";
import { ERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ERC20VotesUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ERC20PermitUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import { EssentialContract } from "../common/EssentialContract.sol";

/// @title TaikoToken
/// @dev Labeled in AddressResolver as "taiko_token"
/// @notice The TaikoToken (TKO), in the protocol is used for prover collateral
/// in the form of bonds. It is an ERC20 token with 18 decimal places of
/// precision.
contract TaikoToken is
    EssentialContract,
    ERC20VotesUpgradeable,
    ERC20PermitUpgradeable
{
    error TKO_INVALID_ADDR();
    error TKO_INVALID_PREMINT_PARAMS();

    /// @notice Initializes the TaikoToken contract and mints initial tokens.
    /// @param _owner The initial owner.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _recipient The address to receive initial token minting.
    function init(
        address _owner,
        string calldata _name,
        string calldata _symbol,
        address _recipient
    )
        public
        initializer
    {
        EssentialContract._init(_owner, address(0));
        ERC20Upgradeable.__ERC20_init(_name, _symbol);
        ERC20VotesUpgradeable.__ERC20Votes_init();
        ERC20PermitUpgradeable.__ERC20Permit_init(_name);

        // Mint 1 billion tokens
        _mint(_recipient, 1_000_000_000 ether);
    }

    /// @notice Mints new tokens to the specified address.
    /// @param to The address to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burns tokens from the specified address.
    /// @param from The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    /// @notice Transfers tokens to a specified address.
    /// @param to The address to transfer tokens to.
    /// @param amount The amount of tokens to transfer.
    /// @return A boolean indicating whether the transfer was successful or not.
    function transfer(
        address to,
        uint256 amount
    )
        public
        override
        returns (bool)
    {
        if (to == address(this)) revert TKO_INVALID_ADDR();
        return super.transfer(to, amount);
    }

    /// @notice Transfers tokens from one address to another.
    /// @param from The address to transfer tokens from.
    /// @param to The address to transfer tokens to.
    /// @param amount The amount of tokens to transfer.
    /// @return A boolean indicating whether the transfer was successful or not.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override
        returns (bool)
    {
        if (to == address(this)) revert TKO_INVALID_ADDR();
        return super.transferFrom(from, to, amount);
    }

    function nonces(address owner)
        public
        view
        virtual
        override(NoncesUpgradeable, ERC20PermitUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, amount);
    }
}
