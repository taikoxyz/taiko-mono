// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";

/// @notice TaikoToken was `EssentialContract, ERC20SnapshotUpgradeable, ERC20VotesUpgradeable`.
/// We use this contract to take 50 more slots to remove `ERC20SnapshotUpgradeable` from the parent
/// contract list.
/// We can simplify the code since we no longer need to maintain upgradability with Hekla.
// solhint-disable contract-name-camelcase
abstract contract EssentialContract_ is EssentialContract {
    // solhint-disable var-name-mixedcase
    uint256[50] private __slots_previously_used_by_ERC20SnapshotUpgradeable;
}

/// @title TaikoToken
/// @notice The TaikoToken (TKO), in the protocol is used for prover collateral
/// in the form of bonds. It is an ERC20 token with 18 decimal places of
/// precision.
/// @dev Labeled in AddressResolver as "taiko_token"
/// @custom:security-contact security@taiko.xyz
contract TaikoToken is EssentialContract_, ERC20VotesUpgradeable {
    uint256[50] private __gap;

    error TKO_INVALID_ADDR();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
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
        __Essential_init(_owner);
        __Context_init_unchained();
        __ERC20_init(_name, _symbol);
        __ERC20Votes_init();
        __ERC20Permit_init(_name);

        // Mint 1 billion tokens
        _mint(_recipient, 1_000_000_000 ether);
    }

    /// @notice Burns tokens from the specified address.
    /// @param _from The address to burn tokens from.
    /// @param _amount The amount of tokens to burn.
    function burn(address _from, uint256 _amount) public onlyOwner {
        return _burn(_from, _amount);
    }

    /// @notice Transfers tokens to a specified address.
    /// @param _to The address to transfer tokens to.
    /// @param _amount The amount of tokens to transfer.
    /// @return A boolean indicating whether the transfer was successful or not.
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        if (_to == address(this)) revert TKO_INVALID_ADDR();
        return super.transfer(_to, _amount);
    }

    /// @notice Transfers tokens from one address to another.
    /// @param _from The address to transfer tokens from.
    /// @param _to The address to transfer tokens to.
    /// @param _amount The amount of tokens to transfer.
    /// @return A boolean indicating whether the transfer was successful or not.
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    )
        public
        override
        returns (bool)
    {
        if (_to == address(this)) revert TKO_INVALID_ADDR();
        return super.transferFrom(_from, _to, _amount);
    }
}
