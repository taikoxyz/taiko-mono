// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/libs/LibAddress.sol";
import "./ITaikoInbox.sol";

/// @title LibBonds
/// @notice This library handles bond-related operations for the Taiko protocol
/// @dev This library's functions are made public to be used by TaikoInbox and LibProposing.
/// @custom:security-contact security@nethermind.io
library LibBonds {
    using SafeERC20 for IERC20;

    /// @notice Debits bond from a user's balance or handles deposit if insufficient balance
    /// @param _state The TaikoInbox state
    /// @param _user The user address
    /// @param _amount The amount to debit
    /// @param _bondToken The bond token address (address(0) for ETH)
    function debitBond(
        ITaikoInbox.State storage _state,
        address _user,
        uint256 _amount,
        address _bondToken
    )
        internal
    {
        if (_amount == 0) return;

        uint256 balance = _state.bondBalance[_user];
        if (balance >= _amount) {
            unchecked {
                _state.bondBalance[_user] = balance - _amount;
            }
        } else if (_bondToken != address(0)) {
            uint256 amountDeposited = handleDeposit(_user, _amount, _bondToken);
            require(amountDeposited == _amount, ITaikoInbox.InsufficientBond());
        } else {
            // Ether as bond must be deposited before proposing a batch
            revert ITaikoInbox.InsufficientBond();
        }
        emit ITaikoInbox.BondDebited(_user, _amount);
    }

    /// @notice Credits bond to a user's balance
    /// @param _state The TaikoInbox state
    /// @param _user The user address
    /// @param _amount The amount to credit
    function creditBond(
        ITaikoInbox.State storage _state,
        address _user,
        uint256 _amount
    )
        internal
    {
        if (_amount == 0) return;
        _state.bondBalance[_user] += _amount;
    }

    /// @notice Handles bond deposit from user
    /// @param _user The user address
    /// @param _amount The amount to deposit
    /// @param _bondToken The bond token address (address(0) for ETH)
    /// @return amountDeposited_ The actual amount deposited
    function handleDeposit(
        address _user,
        uint256 _amount,
        address _bondToken
    )
        internal
        returns (uint256 amountDeposited_)
    {
        if (_bondToken != address(0)) {
            require(msg.value == 0, ITaikoInbox.MsgValueNotZero());

            uint256 balance = IERC20(_bondToken).balanceOf(address(this));
            IERC20(_bondToken).safeTransferFrom(_user, address(this), _amount);
            amountDeposited_ = IERC20(_bondToken).balanceOf(address(this)) - balance;
        } else {
            require(msg.value == _amount, ITaikoInbox.EtherNotPaidAsBond());
            amountDeposited_ = _amount;
        }
        emit ITaikoInbox.BondDeposited(_user, amountDeposited_);
    }

    /// @notice Handles bond withdrawal to user
    /// @param _user The user address
    /// @param _amount The amount to withdraw
    /// @param _bondToken The bond token address (address(0) for ETH)
    function handleWithdrawal(address _user, uint256 _amount, address _bondToken) internal {
        if (_bondToken != address(0)) {
            IERC20(_bondToken).safeTransfer(_user, _amount);
        } else {
            LibAddress.sendEtherAndVerify(_user, _amount);
        }
        emit ITaikoInbox.BondWithdrawn(_user, _amount);
    }
}
