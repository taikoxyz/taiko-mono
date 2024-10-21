// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/shared/common/IAddressResolver.sol";
import "src/shared/common/LibAddress.sol";
import "src/shared/common/LibStrings.sol";
import "./TaikoData.sol";

/// @title LibBonds
/// @notice A library that offers helper functions to handle bonds.
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    using LibAddress for address;

    /// @dev Emitted when token is credited back to a user's bond balance.
    event BondCredited(address indexed user, uint256 amount);

    /// @dev Emitted when token is debited from a user's bond balance.
    event BondDebited(address indexed user, uint256 amount);

    error L1_INVALID_MSG_VALUE();

    /// @dev Deposits Taiko token to be used as bonds.
    /// @param _state Current TaikoData.State.
    /// @param _resolver Address resolver interface.
    /// @param _amount The amount of token to deposit.
    function depositBond(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        uint256 _amount
    )
        internal
    {
        _state.bondBalance[msg.sender] += _amount;
        _depositBond(_resolver, _amount);
    }

    /// @dev Withdraws Taiko token.
    /// @param _state Current TaikoData.State.
    /// @param _resolver Address resolver interface.
    /// @param _amount The amount of token to withdraw.
    function withdrawBond(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        uint256 _amount
    )
        internal
    {
        _state.bondBalance[msg.sender] -= _amount;

        address bondToken = _resolver.resolve(LibStrings.B_TAIKO_TOKEN, true);
        if (bondToken == address(0)) {
            msg.sender.sendEtherAndVerify(_amount);
        } else {
            IERC20(bondToken).transfer(msg.sender, _amount);
        }
    }

    /// @dev Debits Taiko tokens as bonds.
    /// @param _state Current TaikoData.State.
    /// @param _resolver Address resolver interface.
    /// @param _user The user address to debit.
    /// @param _amount The amount of token to debit.
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
            _depositBond(_resolver, _amount);
        }
        emit BondDebited(_user, _amount);
    }

    /// @dev Credits Taiko tokens to user's bond balance.
    /// @param _state Current TaikoData.State.
    /// @param _user The user address to credit.
    /// @param _amount The amount of token to credit.
    function creditBond(TaikoData.State storage _state, address _user, uint256 _amount) internal {
        _state.bondBalance[_user] += _amount;
        emit BondCredited(_user, _amount);
    }

    /// @dev Gets a user's current Taiko token bond balance.
    /// @param _state Current TaikoData.State.
    /// @param _user The user address to credit.
    /// @return  The current token balance.
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

    function _depositBond(IAddressResolver _resolver, uint256 _amount) private {
        address bondToken = _resolver.resolve(LibStrings.B_TAIKO_TOKEN, true);
        if (bondToken == address(0)) {
            require(msg.value == _amount, L1_INVALID_MSG_VALUE());
        } else {
            require(msg.value == 0, L1_INVALID_MSG_VALUE());
            IERC20(bondToken).transferFrom(msg.sender, address(this), _amount);
        }
    }
}
