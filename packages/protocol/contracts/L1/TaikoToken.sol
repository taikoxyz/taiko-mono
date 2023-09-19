// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ERC20BurnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import { ERC20SnapshotUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import {
    ERC20Upgradeable,
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IMintableERC20 } from "../common/IMintableERC20.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { Proxied } from "../common/Proxied.sol";

/// @title TaikoToken
/// @notice The TaikoToken (TKO), in the protocol is used for prover collateral
/// in the form of bonds. It is an ERC20 token with 18 decimal places of
/// precision.
contract TaikoToken is
    EssentialContract,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20SnapshotUpgradeable,
    PausableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    IMintableERC20
{
    error TKO_INVALID_ADDR();
    error TKO_INVALID_PREMINT_PARAMS();

    /// @notice Initializes the TaikoToken contract and mints initial tokens to
    /// specified recipients.
    /// @param _addressManager The {AddressManager} address.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _premintRecipients An array of addresses to receive initial token
    /// minting.
    /// @param _premintAmounts An array of token amounts to mint for each
    /// corresponding recipient.
    function init(
        address _addressManager,
        string calldata _name,
        string calldata _symbol,
        address[] calldata _premintRecipients,
        uint256[] calldata _premintAmounts
    )
        public
        initializer
    {
        EssentialContract._init(_addressManager);
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __ERC20Snapshot_init();
        __Pausable_init();
        __ERC20Permit_init(_name);
        __ERC20Votes_init();

        for (uint256 i = 0; i < _premintRecipients.length; ++i) {
            _mint(_premintRecipients[i], _premintAmounts[i]);
        }
    }

    /// @notice Creates a new token snapshot.
    function snapshot() public onlyOwner {
        _snapshot();
    }

    /// @notice Pauses token transfers.
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpauses token transfers.
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @notice Mints new tokens to the specified address.
    /// @param to The address to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(
        address to,
        uint256 amount
    )
        public
        onlyFromNamed2("erc20_vault", "taiko")
    {
        _mint(to, amount);
    }

    /// @notice Burns tokens from the specified address.
    /// @param from The address to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(
        address from,
        uint256 amount
    )
        public
        onlyFromNamed2("erc20_vault", "taiko")
    {
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
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) revert TKO_INVALID_ADDR();
        return ERC20Upgradeable.transfer(to, amount);
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
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) revert TKO_INVALID_ADDR();
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20SnapshotUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(
        address to,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._mint(to, amount);
    }

    function _burn(
        address from,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._burn(from, amount);
    }
}

/// @title ProxiedTaikoToken
/// @notice Proxied version of the TaikoToken contract.
contract ProxiedTaikoToken is Proxied, TaikoToken { }
