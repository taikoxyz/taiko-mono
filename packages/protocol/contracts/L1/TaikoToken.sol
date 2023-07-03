// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20SnapshotUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import {Proxied} from "../common/Proxied.sol";

library LibTaikoTokenConfig {
    uint8 public constant DECIMALS = uint8(8);
}

/// @custom:security-contact hello@taiko.xyz
contract TaikoToken is
    EssentialContract,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20SnapshotUpgradeable,
    PausableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable
{
    event Mint(address account, uint256 amount);
    event Burn(address account, uint256 amount);

    error TKO_INVALID_ADDR();
    error TKO_INVALID_PREMINT_PARAMS();
    error TKO_MINT_DISALLOWED();

    /*//////////////////////////////////////////////////////////////
                         USER-FACING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function init(
        address _addressManager,
        string calldata _name,
        string calldata _symbol,
        address[] calldata _premintRecipients,
        uint256[] calldata _premintAmounts
    ) public initializer {
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

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyFromNamed("proto_broker") {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyFromNamed("proto_broker") {
        _burn(from, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (to == address(this)) revert TKO_INVALID_ADDR();
        return ERC20Upgradeable.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        if (to == address(this)) revert TKO_INVALID_ADDR();
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return LibTaikoTokenConfig.DECIMALS;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20SnapshotUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._mint(to, amount);

        // TODO: do we need the following check at all?
        if (totalSupply() > type(uint64).max) revert TKO_MINT_DISALLOWED();
        emit Mint(to, amount);
    }

    function _burn(address from, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._burn(from, amount);
        emit Burn(from, amount);
    }
}

contract ProxiedTaikoToken is Proxied, TaikoToken {}
