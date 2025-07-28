// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/libs/LibAddress.sol";
import "../IBondManager2.sol";
import { IInbox } from "../IInbox.sol";

/// @title LibBonds
/// @notice Library for managing bond deposits, withdrawals, and balance accounting in Taiko
/// protocol
/// @dev Handles bond management operations including:
///      - Bond deposits from users (ETH or ERC20 tokens)
///      - Bond withdrawals with balance validation
///      - Bond debiting with automatic deposits for insufficient balances
///      - Bond crediting for balance increases
///      - Support for both native ETH and ERC20 token bonds
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Public Functions
    // -------------------------------------------------------------------------

    /// @notice Withdraws bond from the user's balance
    /// @param $ The state storage
    /// @param _bondToken The bond token address (0 for ETH)
    /// @param _amount The amount to withdraw
    function withdrawBond(
        IInbox.State storage $,
        address _bondToken,
        uint256 _amount
    )
        public // reduce code size
    {
        uint256 balance = $.bondBalance[msg.sender];
        if (balance < _amount) revert InsufficientBond();

        emit IBondManager2.BondWithdrawn(msg.sender, _amount);

        $.bondBalance[msg.sender] -= _amount;

        if (_bondToken != address(0)) {
            IERC20(_bondToken).safeTransfer(msg.sender, _amount);
        } else {
            LibAddress.sendEtherAndVerify(msg.sender, _amount);
        }
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Deposits bond from a user
    /// @param _bondToken The bond token address (0 for ETH)
    /// @param _user The user depositing the bond
    /// @param _amount The amount to deposit
    /// @return amountDeposited_ The actual amount deposited
    function depositBond(
        address _bondToken,
        address _user,
        uint256 _amount
    )
        internal
        returns (uint256 amountDeposited_)
    {
        if (_bondToken != address(0)) {
            if (msg.value != 0) revert MsgValueNotZero();

            uint256 balance = IERC20(_bondToken).balanceOf(address(this));
            IERC20(_bondToken).safeTransferFrom(_user, address(this), _amount);
            amountDeposited_ = IERC20(_bondToken).balanceOf(address(this)) - balance;
        } else {
            if (msg.value != _amount) revert EtherNotPaidAsBond();
            amountDeposited_ = _amount;
        }
        emit IBondManager2.BondDeposited(_user, amountDeposited_);
    }

    /// @notice Debits bond from a user's balance
    /// @param $ The state storage
    /// @param _bondToken The bond token address (0 for ETH)
    /// @param _user The user whose bond is being debited
    /// @param _amount The amount to debit
    function debitBond(
        IInbox.State storage $,
        address _bondToken,
        address _user,
        uint256 _amount
    )
        internal
    {
        if (_amount == 0) return;

        uint256 balance = $.bondBalance[_user];
        if (balance >= _amount) {
            unchecked {
                $.bondBalance[_user] = balance - _amount;
            }
        } else if (_bondToken != address(0)) {
            uint256 amountDeposited = depositBond(_bondToken, _user, _amount);
            if (amountDeposited != _amount) revert InsufficientBond();
        } else {
            // Ether as bond must be deposited before proposing a batch
            revert InsufficientBond();
        }
        emit IBondManager2.BondDebited(_user, _amount);
    }

    /// @notice Credits bond to a user's balance
    /// @param $ The state storage
    /// @param _user The user receiving the credit
    /// @param _amount The amount to credit
    function creditBond(IInbox.State storage $, address _user, uint256 _amount) internal {
        if (_amount == 0) return;
        unchecked {
            $.bondBalance[_user] += _amount;
        }
        emit IBondManager2.BondCredited(_user, _amount);
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error EtherNotPaidAsBond();
    error InsufficientBond();
    error MsgValueNotZero();
}
