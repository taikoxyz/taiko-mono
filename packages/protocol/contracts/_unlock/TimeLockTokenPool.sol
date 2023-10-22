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
// BUGGY BUGGY BUGGY BUGGY BUGGY BUGGY BUGGY BUGGY BUGGY
contract TimeLockTokenPool is OwnableUpgradeable {
    using SafeERC20Upgradeable for ERC20Upgradeable;

    struct Grant {
        // If `grantStart` or `grantPeriod` is 0, `amount` indicates the total
        // tokens already owned by the recipient.
        // Otherwise, `amount` represents the total grant amount, governed by
        // the schedule set by `grantStart` and `grantPeriod`.
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
    uint256 public totalAmountWithdrawn;
    mapping(address recipient => Recipient) public recipients;
    uint256[47] private __gap;

    event Granted(address indexed user, Grant grant);
    event Settled(address indexed user, uint256 newlySettled);
    event Withdrawn(address indexed user, uint256 amount);

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
    function grant(address recipient, Grant calldata g) external onlyOwner { }

    /// @notice Puts a stop to all grants given to an address and settles
    /// withdrawal tokens. The recipient will still be able to get what he/she
    /// deserves to receive. This transaction simply invalidates all future
    /// unlocks.
    function settle(address recipient) external onlyOwner { }

    /// @notice Withdraws all withdrawal tokens.
    function withdraw() external { }

    function getGrantStatus(address recipient)
        public
        view
        returns (
            uint256 amountOwned,
            uint256 amountUnlocked,
            uint256 amountWithdrawn,
            uint256 amountWithdrawable
        )
    {
        amountOwned = _getAmountOwned(recipient);
        amountUnlocked = _getAmountUnlocked(recipient);
        amountWithdrawn = recipients[recipient].amountWithdrawn;
        amountWithdrawable = amountUnlocked - amountWithdrawn;
    }

    function getGrants(address recipient)
        public
        view
        returns (Grant[] memory)
    {
        return recipients[recipient].grants;
    }

    function _getAmountOwned(address recipient)
        private
        view
        returns (uint256 amount)
    {
        Recipient storage r = recipients[recipient];
        for (uint256 i; i < r.grants.length; ++i) {
            amount += _getAmountOwned(r.grants[i]);
        }
    }

    function _getAmountUnlocked(address recipient)
        private
        view
        returns (uint256 amount)
    {
        Recipient storage r = recipients[recipient];
        for (uint256 i; i < r.grants.length; ++i) {
            amount += _getAmountUnlocked(r.grants[i]);
        }
    }

    function _getAmountOwned(Grant memory g) private view returns (uint256) {
        if (g.amount == 0) return 0;
        if (g.grantStart == 0 || g.grantPeriod == 0) return g.amount;
        if (block.timestamp <= g.grantStart) return 0;
        if (block.timestamp >= g.grantStart + g.grantPeriod) return g.amount;

        return g.amount * uint64(block.timestamp - g.grantStart) / g.grantPeriod;
    }

    function _getAmountUnlocked(Grant memory g)
        private
        view
        returns (uint256)
    {
        uint256 amount = _getAmountOwned(g);
        if (amount == 0) return 0;
        if (g.unlockStart == 0 || g.unlockPeriod == 0) return amount;
        if (block.timestamp <= g.unlockStart) return 0;
        if (block.timestamp >= g.unlockStart + g.unlockPeriod) return amount;

        return amount * uint64(block.timestamp - g.unlockStart) / g.unlockPeriod;
    }
}

/// @title ProxiedGrantPool
/// @notice Proxied version of the parent contract.
contract ProxiedTimeLockTokenPool is Proxied, TimeLockTokenPool { }
