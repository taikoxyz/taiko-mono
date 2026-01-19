// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBondManager } from "../iface/IBondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

/// @title LibBonds
/// @notice Library for bond ledger operations and settlement.
/// @dev When _bondToken is address(0), native ETH is used for bonds instead of ERC20 tokens.
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    using SafeERC20 for IERC20;
    using LibAddress for address;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    uint256 internal constant GWEI_UNIT = 1 gwei;

    // ---------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------

    /// @dev Storage layout for bond balances. Each bond packs into one slot.
    struct Storage {
        mapping(address account => IBondManager.Bond bond) bonds;
    }

    // ---------------------------------------------------------------
    // Internal Functions meant to be called by contracts that use this library
    // ---------------------------------------------------------------

    /// @dev Deposits bond tokens in gwei units and credits the recipient.
    /// If `_cancelWithdrawal` is true, the pending withdrawal request is cleared.
    /// When _bondToken is address(0), native ETH is used and msg.value must equal the deposit amount.
    /// (after converting to wei)
    function deposit(
        Storage storage $,
        IERC20 _bondToken,
        address _depositor,
        address _recipient,
        uint64 _amount,
        bool _cancelWithdrawal
    )
        internal
    {
        if (_recipient == address(0)) revert InvalidAddress();

        _creditBond($, _recipient, _amount);
        if (_cancelWithdrawal && $.bonds[_recipient].withdrawalRequestedAt != 0) {
            $.bonds[_recipient].withdrawalRequestedAt = 0;
        }

        uint256 tokenAmount = _toTokenAmount(_amount);
        if (address(_bondToken) == address(0)) {
            // Native ETH bond: verify msg.value matches the deposit amount
            if (msg.value != tokenAmount) revert InvalidETHAmount();
        } else {
            // ERC20 bond: transfer tokens from depositor
            _bondToken.safeTransferFrom(_depositor, address(this), tokenAmount);
        }

        emit IBondManager.BondDeposited(_depositor, _recipient, _amount);
    }

    /// @dev Withdraws bond tokens in gwei units to a recipient.
    /// If the full balance is withdrawn, the pending withdrawal request is cleared.
    /// When _bondToken is address(0), native ETH is sent instead of ERC20 tokens.
    function withdraw(
        Storage storage $,
        IERC20 _bondToken,
        address _from,
        address _to,
        uint64 _amount,
        uint64 _minBond,
        uint48 _withdrawalDelay
    )
        internal
        returns (uint64 debited_)
    {
        if (_to == address(0)) revert InvalidAddress();

        IBondManager.Bond storage bond_ = $.bonds[_from];
        uint64 balance = bond_.balance;
        uint64 amount = _amount > balance ? balance : _amount;

        if (
            bond_.withdrawalRequestedAt == 0
                || block.timestamp < bond_.withdrawalRequestedAt + _withdrawalDelay
        ) {
            require(balance - amount >= _minBond, MustMaintainMinBond());
        }

        debited_ = _debitBond($, _from, amount);
        if (debited_ == balance && bond_.withdrawalRequestedAt != 0) {
            bond_.withdrawalRequestedAt = 0;
        }

        uint256 tokenAmount = _toTokenAmount(debited_);
        if (address(_bondToken) == address(0)) {
            // Native ETH bond: send ETH to recipient
            _to.sendEtherAndVerify(tokenAmount);
        } else {
            // ERC20 bond: transfer tokens to recipient
            _bondToken.safeTransfer(_to, tokenAmount);
        }
        emit IBondManager.BondWithdrawn(_from, debited_);
    }

    /// @dev Requests a withdrawal. Withdrawals are unrestricted after the delay.
    function requestWithdrawal(
        Storage storage $,
        address _account,
        uint48 _withdrawalDelay
    )
        internal
    {
        IBondManager.Bond memory bond_ = $.bonds[_account];
        if (bond_.balance == 0) revert NoBondToWithdraw();
        if (bond_.withdrawalRequestedAt != 0) revert WithdrawalAlreadyRequested();

        bond_.withdrawalRequestedAt = uint48(block.timestamp);
        $.bonds[_account] = bond_;
        emit IBondManager.WithdrawalRequested(_account, uint48(block.timestamp + _withdrawalDelay));
    }

    /// @dev Cancels a pending withdrawal request.
    function cancelWithdrawal(Storage storage $, address _account) internal {
        IBondManager.Bond storage bond_ = $.bonds[_account];
        if (bond_.withdrawalRequestedAt == 0) revert NoWithdrawalRequested();

        bond_.withdrawalRequestedAt = 0;
        emit IBondManager.WithdrawalCancelled(_account);
    }

    /// @dev Returns the bond state for an account.
    function getBond(
        Storage storage $,
        address _account
    )
        internal
        view
        returns (IBondManager.Bond memory)
    {
        return $.bonds[_account];
    }

    /// @dev Checks if an account has sufficient bond and is active.
    function hasSufficientBond(
        Storage storage $,
        address _account,
        uint64 _minBond
    )
        internal
        view
        returns (bool)
    {
        IBondManager.Bond storage bond_ = $.bonds[_account];
        return bond_.balance >= _minBond && bond_.withdrawalRequestedAt == 0;
    }

    /// @dev Applies a liveness bond slash with a 50/50 split (payee/burn).
    /// @param $ Storage reference.
    /// @param _payer Account whose bond is debited.
    /// @param _payee Account credited with half of the debited bond.
    /// @param _livenessBond Liveness bond amount in gwei.
    function settleLivenessBond(
        Storage storage $,
        address _payer,
        address _payee,
        uint64 _livenessBond
    )
        internal
    {
        // We try to debit the full liveness bond, but since it is best effort
        // the amount may be lower.
        uint64 debited = _debitBond($, _payer, _livenessBond);
        if (debited == 0) return;

        uint64 payeeAmount = debited / 2;
        uint64 slashedAmount = debited - payeeAmount;
        if (payeeAmount > 0) {
            _creditBond($, _payee, payeeAmount);
        }

        emit IBondManager.LivenessBondSettled(
            _payer, _payee, _livenessBond, payeeAmount, slashedAmount
        );
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Debits a bond with best effort.
    function _debitBond(
        Storage storage $,
        address _account,
        uint64 _amount
    )
        private
        returns (uint64 debited_)
    {
        IBondManager.Bond storage bond_ = $.bonds[_account];

        if (bond_.balance <= _amount) {
            debited_ = bond_.balance;
            bond_.balance = 0;
        } else {
            debited_ = _amount;
            bond_.balance = bond_.balance - _amount;
        }
    }

    /// @dev Credits a bond balance.
    function _creditBond(Storage storage $, address _account, uint64 _amount) private {
        IBondManager.Bond storage bond_ = $.bonds[_account];
        bond_.balance = bond_.balance + _amount;
    }

    /// @dev Converts bond amounts in gwei to token units (18 decimals).
    function _toTokenAmount(uint64 _amount) private pure returns (uint256) {
        return uint256(_amount) * GWEI_UNIT;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidAddress();
    error InvalidETHAmount();
    error MustMaintainMinBond();
    error NoBondToWithdraw();
    error NoWithdrawalRequested();
    error WithdrawalAlreadyRequested();
}
