// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/shared/common/IAddressResolver.sol";
import "src/shared/common/LibStrings.sol";
import "./TaikoData.sol";

/// @title LibBonds
/// @notice A library that offers helper functions to handle bonds.
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    /// @notice Emitted when tokens are deposited into a user's bond balance.
    /// @param user The address of the user who deposited the tokens.
    /// @param amount The amount of tokens deposited.
    event BondDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when tokens are withdrawn from a user's bond balance.
    /// @param user The address of the user who withdrew the tokens.
    /// @param amount The amount of tokens withdrawn.
    event BondWithdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when a token is credited back to a user's bond balance.
    /// @param user The address of the user whose bond balance is credited.
    /// @param blockId The ID of the block to credit for.
    /// @param amount The amount of tokens credited.
    event BondCredited(address indexed user, uint256 blockId, uint256 amount);

    /// @notice Emitted when a token is debited from a user's bond balance.
    /// @param user The address of the user whose bond balance is debited.
    /// @param blockId The ID of the block to debit for.
    /// @param amount The amount of tokens debited.
    event BondDebited(address indexed user, uint256 blockId, uint256 amount);

    /// @notice Deposits TAIKO tokens to be used as bonds.
    /// @param _state The current state of TaikoData.
    /// @param _resolver The address resolver interface.
    /// @param _amount The amount of tokens to deposit.
    function depositBond(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        uint256 _amount
    )
        internal
    {
        emit BondDeposited(msg.sender, _amount);
        _state.bondBalance[msg.sender] += _amount;
        _tko(_resolver).transferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Withdraws TAIKO tokens.
    /// @param _state The current state of TaikoData.
    /// @param _resolver The address resolver interface.
    /// @param _amount The amount of tokens to withdraw.
    function withdrawBond(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        uint256 _amount
    )
        internal
    {
        emit BondWithdrawn(msg.sender, _amount);
        _state.bondBalance[msg.sender] -= _amount;
        _tko(_resolver).transfer(msg.sender, _amount);
    }

    /// @notice Debits TAIKO tokens as bonds.
    /// @param _state The current state of TaikoData.
    /// @param _resolver The address resolver interface.
    /// @param _user The address of the user to debit.
    /// @param _blockId The ID of the block to debit for.
    /// @param _amount The amount of tokens to debit.
    function debitBond(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        address _user,
        uint256 _blockId,
        uint256 _amount
    )
        internal
    {
        if (_amount == 0) return;

        uint256 balance = _state.bondBalance[_user];
        if (balance >= _amount) {
            unchecked {
                _state.bondBalance[_user] = balance - _amount;
            }
        } else {
            emit BondDeposited(msg.sender, _amount);
            _tko(_resolver).transferFrom(_user, address(this), _amount);
        }
        emit BondDebited(_user, _blockId, _amount);
    }

    /// @notice Credits TAIKO tokens to a user's bond balance.
    /// @param _state The current state of TaikoData.
    /// @param _user The address of the user to credit.
    /// @param _blockId The ID of the block to credit for.
    /// @param _amount The amount of tokens to credit.
    function creditBond(
        TaikoData.State storage _state,
        address _user,
        uint256 _blockId,
        uint256 _amount
    )
        internal
    {
        if (_amount == 0) return;
        unchecked {
            _state.bondBalance[_user] += _amount;
        }
        emit BondCredited(_user, _blockId, _amount);
    }

    /// @notice Gets a user's current TAIKO token bond balance.
    /// @param _state The current state of TaikoData.
    /// @param _user The address of the user.
    /// @return The current token balance.
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

    /// @dev Resolves the TAIKO token address using the address resolver.
    /// @param _resolver The address resolver interface.
    /// @return tko_ The IERC20 interface of the TAIKO token.
    function _tko(IAddressResolver _resolver) private view returns (IERC20) {
        return IERC20(_resolver.resolve(LibStrings.B_TAIKO_TOKEN, false));
    }
}
