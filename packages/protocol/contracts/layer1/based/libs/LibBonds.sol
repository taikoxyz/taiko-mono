// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/libs/LibAddress.sol";
import { ITaikoInbox as I } from "../ITaikoInbox.sol";
import "../IBondManager.sol";

/// @title LibBonds
/// @custom:security-contact security@taiko.xyz
library LibBonds {
    using LibAddress for address;
    using SafeERC20 for IERC20;

    function withdrawBond(I.State storage $, address _bondToken, uint256 _amount) public {
        uint256 balance = $.bondBalance[msg.sender];
        require(balance >= _amount, I.InsufficientBond());

        emit IBondManager.BondWithdrawn(msg.sender, _amount);

        $.bondBalance[msg.sender] -= _amount;

        if (_bondToken != address(0)) {
            IERC20(_bondToken).safeTransfer(msg.sender, _amount);
        } else {
            LibAddress.sendEtherAndVerify(msg.sender, _amount);
        }
    }

    function depositBond(
        address _bondToken,
        address _user,
        uint256 _amount
    )
        internal
        returns (uint256 amountDeposited_)
    {
        if (_bondToken != address(0)) {
            require(msg.value == 0, I.MsgValueNotZero());

            uint256 balance = IERC20(_bondToken).balanceOf(address(this));
            IERC20(_bondToken).safeTransferFrom(_user, address(this), _amount);
            amountDeposited_ = IERC20(_bondToken).balanceOf(address(this)) - balance;
        } else {
            require(msg.value == _amount, I.EtherNotPaidAsBond());
            amountDeposited_ = _amount;
        }
        emit IBondManager.BondDeposited(_user, amountDeposited_);
    }

    function debitBond(
        I.State storage $,
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
            require(amountDeposited == _amount, I.InsufficientBond());
        } else {
            // Ether as bond must be deposited before proposing a batch
            revert I.InsufficientBond();
        }
        emit IBondManager.BondDebited(_user, _amount);
    }

    function creditBond(I.State storage $, address _user, uint256 _amount) internal {
        if (_amount == 0) return;
        unchecked {
            $.bondBalance[_user] += _amount;
        }
        emit IBondManager.BondCredited(_user, _amount);
    }
}
