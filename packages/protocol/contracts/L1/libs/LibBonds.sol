// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../common/IAddressResolver.sol";
import "../../common/LibStrings.sol";
import "../TaikoData.sol";

/// @title LibBonds
/// @notice A library that offers helper functions to handle bonds.
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    event BondCredited(address indexed user, uint256 amount);
    event BondDedited(address indexed user, uint256 amount);

    function depositBond(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        uint256 _amount
    )
        internal
    {
        IERC20 tko = IERC20(_resolver.resolve(LibStrings.B_TAIKO_TOKEN, false));
        tko.transferFrom(msg.sender, address(this), _amount);
        _state.bondBalance[msg.sender] += _amount;
    }

    function withdrawBond(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        uint256 _amount
    )
        internal
    {
        _state.bondBalance[msg.sender] -= _amount;
        IERC20 tko = IERC20(_resolver.resolve(LibStrings.B_TAIKO_TOKEN, false));
        tko.transfer(msg.sender, _amount);
    }

    function debitBond(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        address _user,
        uint256 _amount
    )
        internal
    {
        uint256 balance = _state.bondBalance[_user];

        if (balance >= _amount) {
            unchecked {
                _state.bondBalance[_user] = balance - _amount;
            }
        } else {
            IERC20 tko = IERC20(_resolver.resolve(LibStrings.B_TAIKO_TOKEN, false));
            tko.transferFrom(_user, address(this), _amount);
        }
        emit BondDedited(_user, _amount);
    }

    function creditBond(TaikoData.State storage _state, address _user, uint256 _amount) internal {
        _state.bondBalance[_user] += _amount;
        emit BondCredited(_user, _amount);
    }

    function bondBalanceOf(
        TaikoData.State storage _state,
        address _user
    )
        internal
        view
        returns (uint256)
    {
        return _state.bondBalance[_user];
    }
}
