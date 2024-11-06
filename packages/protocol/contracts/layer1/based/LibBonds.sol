// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "src/shared/common/IResolver.sol";
import "src/shared/common/LibAddress.sol";
import "src/shared/common/LibStrings.sol";
import "./TaikoData.sol";

/// @title LibBonds
/// @notice A library that offers helper functions to handle bonds.
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    /// @dev Emitted when tokens are deposited into a user's bond balance.
    /// @param user The address of the user who deposited the tokens.
    /// @param amount The amount of tokens deposited.
    event BondDeposited(address indexed user, uint256 amount);

    /// @dev Emitted when tokens are withdrawn from a user's bond balance.
    /// @param user The address of the user who withdrew the tokens.
    /// @param amount The amount of tokens withdrawn.
    event BondWithdrawn(address indexed user, uint256 amount);

    /// @dev Emitted when a token is credited back to a user's bond balance.
    /// @param user The address of the user whose bond balance is credited.
    /// @param blockId The ID of the block to credit for.
    /// @param amount The amount of tokens credited.
    event BondCredited(address indexed user, uint256 blockId, uint256 amount);

    /// @dev Emitted when a token is debited from a user's bond balance.
    /// @param user The address of the user whose bond balance is debited.
    /// @param blockId The ID of the block to debit for.
    /// @param amount The amount of tokens debited.
    event BondDebited(address indexed user, uint256 blockId, uint256 amount);

    error L1_INVALID_MSG_VALUE();
    error L1_ETH_NOT_PAID_AS_BOND();

    /// @dev Deposits TAIKO tokens to be used as bonds.
    /// @param _state Pointer to the protocol's storage.
    /// @param _resolver The address resolver.
    /// @param _amount The amount of tokens to deposit.
    function depositBond(
        TaikoData.State storage _state,
        IResolver _resolver,
        uint256 _amount
    )
        public
    {
        _state.bondBalance[msg.sender] += _amount;
        _handleDeposit(_resolver, msg.sender, _amount);
    }

    /// @dev Withdraws TAIKO tokens.
    /// @param _state Pointer to the protocol's storage.
    /// @param _resolver The address resolver.
    /// @param _amount The amount of tokens to withdraw.
    function withdrawBond(
        TaikoData.State storage _state,
        IResolver _resolver,
        uint256 _amount
    )
        public
    {
        emit BondWithdrawn(msg.sender, _amount);
        _state.bondBalance[msg.sender] -= _amount;

        address bondToken = _bondToken(_resolver);
        if (bondToken != address(0)) {
            IERC20(bondToken).transfer(msg.sender, _amount);
        } else {
            LibAddress.sendEtherAndVerify(msg.sender, _amount);
        }
    }

    /// @dev Gets a user's current TAIKO token bond balance.
    /// @param _state Pointer to the protocol's storage.
    /// @param _user The address of the user.
    /// @return The current token balance.
    function bondBalanceOf(
        TaikoData.State storage _state,
        address _user
    )
        public
        view
        returns (uint256)
    {
        return _state.bondBalance[_user];
    }

    /// @dev Debits TAIKO tokens as bonds.
    /// @param _state Pointer to the protocol's storage.
    /// @param _resolver The address resolver.
    /// @param _user The address of the user to debit.
    /// @param _blockId The ID of the block to debit for.
    /// @param _amount The amount of tokens to debit.
    function debitBond(
        TaikoData.State storage _state,
        IResolver _resolver,
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
            // Note that the following function call will revert if bond asset is Ether.
            _handleDeposit(_resolver, _user, _amount);
        }
        emit BondDebited(_user, _blockId, _amount);
    }

    /// @dev Credits TAIKO tokens to a user's bond balance.
    /// @param _state Pointer to the protocol's storage.
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

    /// @dev Handles the deposit of bond tokens or Ether.
    /// @param _resolver The address resolver.
    /// @param _user The user who made the deposit
    /// @param _amount The amount of tokens or Ether to deposit.
    function _handleDeposit(IResolver _resolver, address _user, uint256 _amount) private {
        address bondToken = _bondToken(_resolver);

        if (bondToken != address(0)) {
            require(msg.value == 0, L1_INVALID_MSG_VALUE());
            IERC20(bondToken).transferFrom(_user, address(this), _amount);
        } else {
            require(msg.value == _amount, L1_ETH_NOT_PAID_AS_BOND());
        }
        emit BondDeposited(_user, _amount);
    }

    /// @dev Resolves the bond token address using the address resolver, returns address(0) if Ether
    /// is used as bond asset.
    /// @param _resolver The address resolver.
    /// @return The IERC20 interface of the TAIKO token.
    function _bondToken(IResolver _resolver) private view returns (address) {
        return _resolver.resolve(block.chainid, LibStrings.B_BOND_TOKEN, true);
    }
}
