// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { Proxied } from "../common/Proxied.sol";

/// @title TimeLockTokenPool
contract TimeLockTokenPool is OwnableUpgradeable {
    using SafeERC20Upgradeable for ERC20Upgradeable;

    struct Grant {
        uint256 amount;
        // If non-zero, indicates the start time for the recipient to receive
        // tokens, subject to an unlocking schedule.
        uint64 grantStart;
        // If non-zero, specifies the total seconds required for the recipient
        // to fully own all granted tokens.
        uint64 grantPeriod;
        // If non-zero, indicates the start time for the recipient to unlock
        // tokens.
        uint64 unlockStart;
        // If non-zero, specifies the total seconds required for the recipient
        // to fully unlock all owned tokens.
        uint64 unlockPeriod;
    }

    struct Recipient {
        uint256 amountWithdrawn;
        Grant[] grants;
    }

    address public taikoToken;
    uint256 public totalGranted;
    uint256 public totalAmountWithdrawn;
    mapping(address recipient => Recipient) public recipients;
    uint256[47] private __gap;

    event Granted(address indexed recipient, Grant grant);
    event Settled(address indexed recipient, uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount);

    error INVALID_PARAM();
    error NOTHING_TO_SETTLE();
    error NOTHING_TO_WITHDRAW();

    function init(address _taikoToken) external initializer {
        OwnableUpgradeable.__Ownable_init_unchained();

        if (_taikoToken == address(0)) revert INVALID_PARAM();
        taikoToken = _taikoToken;
    }

    /// @notice Gives a new grant to a address with its own unlock schedule.
    /// This transaction should happen on a regular basis, e.g., quarterly.
    function grant(address recipient, Grant memory g) external onlyOwner {
        if (recipient == address(0)) revert INVALID_PARAM();
        if (g.amount == 0) revert INVALID_PARAM();

        totalGranted += g.amount;
        recipients[recipient].grants.push(g);
        emit Granted(recipient, g);
    }

    /// @notice Puts a stop to all grants given to an address and settles
    /// withdrawal tokens. The recipient will still be able to get what he/she
    /// deserves to receive. This transaction simply invalidates all future
    /// unlocks.
    function settle(address recipient) external onlyOwner {
        Recipient storage r = recipients[recipient];
        uint256 amountReturned;
        for (uint256 i; i < r.grants.length; ++i) {
            amountReturned += _settleGrant(r.grants[i]);
        }
        if (amountReturned == 0) revert NOTHING_TO_SETTLE();
        emit Settled(recipient, amountReturned);
    }

    /// @notice Withdraws all withdrawal tokens.
    function withdraw() external {
        Recipient storage r = recipients[msg.sender];
        uint256 amount;

        for (uint256 i; i < r.grants.length; ++i) {
            amount += _getAmountUnlocked(r.grants[i]);
        }

        amount -= r.amountWithdrawn;
        if (amount == 0) revert NOTHING_TO_WITHDRAW();

        r.amountWithdrawn += amount;
        totalAmountWithdrawn += amount;
        ERC20Upgradeable(taikoToken).transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getMyGrantSummary(address recipient)
        public
        view
        returns (
            uint256 amountOwned,
            uint256 amountUnlocked,
            uint256 amountWithdrawn,
            uint256 amountWithdrawable
        )
    {
        Recipient storage r = recipients[recipient];
        for (uint256 i; i < r.grants.length; ++i) {
            amountOwned += _getAmountOwned(r.grants[i]);
            amountUnlocked += _getAmountUnlocked(r.grants[i]);
        }

        amountWithdrawn = r.amountWithdrawn;
        amountWithdrawable = amountUnlocked - amountWithdrawn;
    }

    function getMyGrants(address recipient)
        public
        view
        returns (Grant[] memory)
    {
        return recipients[recipient].grants;
    }

    function _settleGrant(Grant storage g)
        private
        returns (uint256 amountReturned)
    {
        uint256 amount = _getAmountOwned(g);

        amountReturned = g.amount - amount;
        g.amount = amount;

        g.grantStart = 0;
        g.grantPeriod = 0;
    }

    function _getAmountOwned(Grant memory g) private view returns (uint256) {
        return _calcAmount(g.amount, g.grantStart, g.grantPeriod);
    }

    function _getAmountUnlocked(Grant memory g)
        private
        view
        returns (uint256)
    {
        return _calcAmount(_getAmountOwned(g), g.unlockStart, g.unlockPeriod);
    }

    function _calcAmount(
        uint256 amount,
        uint64 start,
        uint64 period
    )
        private
        view
        returns (uint256)
    {
        if (amount == 0) return 0;
        if (start == 0) return amount;
        if (block.timestamp <= start) return 0;

        if (period == 0) return amount;
        if (block.timestamp >= start + period) return amount;

        return amount * uint64(block.timestamp - start) / period;
    }
}

/// @title ProxiedGrantPool
/// @notice Proxied version of the parent contract.
contract ProxiedTimeLockTokenPool is Proxied, TimeLockTokenPool { }
