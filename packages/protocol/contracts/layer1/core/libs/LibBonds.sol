// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBondManager } from "../iface/IBondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title LibBonds
/// @notice Library for bond accounting and liveness slashing.
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Storage for bond balances.
    struct Storage {
        mapping(address account => uint256 balance) bondBalance;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Credits a bond to an address.
    /// @param $ Storage reference.
    /// @param _account The account to credit.
    /// @param _amount The amount to credit.
    function creditBond(Storage storage $, address _account, uint256 _amount) internal {
        $.bondBalance[_account] = $.bondBalance[_account] + _amount;

        // TODO: remove event and rely on the caller's to emit an event?
        emit IBondManager.BondCredited(_account, _amount);
    }

    /// @dev Debits a bond from an address.
    /// @param $ Storage reference.
    /// @param _account The account to debit.
    /// @param _amount The amount to debit.
    function debitBond(Storage storage $, address _account, uint256 _amount) internal {
        uint256 balance = $.bondBalance[_account];
        if (balance < _amount) revert InsufficientBondBalance();
        unchecked {
            $.bondBalance[_account] = balance - _amount;
        }

        emit IBondManager.BondDebited(_account, _amount);
    }

    /// @dev Deposits bond tokens for a recipient.
    /// @param $ Storage reference.
    /// @param _bondToken The ERC20 bond token.
    /// @param _depositor The address providing tokens.
    /// @param _recipient The address receiving the bond credit.
    /// @param _amount The amount to deposit.
    function deposit(
        Storage storage $,
        IERC20 _bondToken,
        address _depositor,
        address _recipient,
        uint256 _amount
    )
        internal
    {
        if (_recipient == address(0)) revert InvalidRecipient();

        creditBond($, _recipient, _amount);
        _bondToken.safeTransferFrom(_depositor, address(this), _amount);
        emit IBondManager.BondDeposited(_depositor, _recipient, _amount);
    }

    /// @dev Withdraws bond tokens to a recipient.
    /// @param $ Storage reference.
    /// @param _bondToken The ERC20 bond token.
    /// @param _from The address whose balance is debited.
    /// @param _to The recipient address.
    /// @param _amount The amount to withdraw.
    function withdraw(
        Storage storage $,
        IERC20 _bondToken,
        address _from,
        address _to,
        uint256 _amount
    )
        internal
    {
        debitBond($, _from, _amount);
        _bondToken.safeTransfer(_to, _amount);
        emit IBondManager.BondWithdrawn(_from, _amount);
    }

    /// @dev Processes a liveness bond transfer for a late proof using the reserved bond.
    /// @param $ Storage reference.
    /// @param _livenessBond The liveness bond amount.
    /// @param _payer The address whose bond was reserved.
    /// @param _payee The address receiving the reward.
    /// @param _caller The address receiving the caller reward when payer == payee.
    /// @return debitedAmount_ The amount debited from the payer.
    function processLivenessBond(
        Storage storage $,
        uint256 _livenessBond,
        address _payer,
        address _payee,
        address _caller
    )
        internal
        returns (uint256 debitedAmount_)
    {
        uint256 payeeAmount;
        uint256 callerAmount;

        if (_payer == _payee) {
            // TODO: do we need math with better precision?
            payeeAmount = (debited * 4) / 10; // 40%
            callerAmount = debited / 10; // 10%

            if (payeeAmount > 0) creditBond($, _payee, payeeAmount);
            if (callerAmount > 0) creditBond($, _caller, callerAmount);
        } else {
            payeeAmount = debited / 2; // 50% (rounds down, favors burn on odd amounts)
            if (payeeAmount > 0) creditBond($, _payee, payeeAmount);
        }

        emit IBondManager.LivenessBondProcessed(
            _payer, _payee, _caller, debited, payeeAmount, callerAmount
        );
        return debited;
    }

    /// @dev Returns the bond balance of an account.
    /// @param $ Storage reference.
    /// @param _account The account to query.
    function getBondBalance(Storage storage $, address _account) internal view returns (uint256) {
        return $.bondBalance[_account];
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InsufficientBondBalance();
    error InvalidRecipient();
}
