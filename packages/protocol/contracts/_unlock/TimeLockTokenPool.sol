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
        uint64 effectiveAt;
        uint64 unlockWindow;
        uint128 amount;
    }

    struct Recipient {
        uint128 unlockedAmount;
        uint128 totalWithdrawn;
        Grant[] grants;
    }

    address public taikoToken;
    uint256 public totalWithdrawn;
    mapping(address recipient => Recipient) public recipients;
    uint256[47] private __gap;

    event Granted(address indexed user, Grant grant);
    event Settled(address indexed user, uint128 newlySettled);
    event Withdrawn(address indexed user, uint128 amount);

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
    function grant(
        address recipient,
        uint64 effectiveAt,
        uint64 unlockWindow,
        uint128 amount
    )
        external
        onlyOwner
    {
        if (recipient == address(0)) revert INVALID_PARAM();
        if (effectiveAt < block.timestamp - 30 days) revert INVALID_PARAM();
        if (amount == 0) revert INVALID_PARAM();

        uint64 _unlockWindow;
        if (unlockWindow != 0) {
            if (unlockWindow < 365 days) revert INVALID_PARAM();
            if (unlockWindow > 4 * 365 days) revert INVALID_PARAM();
            _unlockWindow = unlockWindow;
        } else {
            _unlockWindow = 4 * 365 days;
        }

        Grant memory g = Grant(effectiveAt, _unlockWindow, amount);
        recipients[recipient].grants.push(g);
        emit Granted(recipient, g);
    }

    /// @notice Puts a stop to all grants given to an address and settles
    /// withdrawal tokens. The recipient will still be able to get what he/she
    /// deserves to receive. This transaction simply invalidates all future
    /// unlocks.
    function settle(address recipient) external onlyOwner {
        Recipient storage r = recipients[recipient];
        if (r.grants.length == 0) revert NOTHING_TO_SETTLE();

        uint128 newlySettled;
        for (uint256 i; i < r.grants.length; ++i) {
            newlySettled += _getGrantUnlocked(r.grants[i]);
        }

        r.unlockedAmount += newlySettled;
        delete r.grants;

        emit Settled(recipient, newlySettled);
    }

    /// @notice Withdraws all withdrawal tokens.
    function withdraw() external {
        uint128 amount = getWithdrawable(msg.sender);
        if (amount == 0) revert NOTHING_TO_WITHDRAW();

        recipients[msg.sender].totalWithdrawn += amount;
        totalWithdrawn += totalWithdrawn;
        ERC20Upgradeable(taikoToken).transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Returns the amount of withdrawable tokens for a given recipient.
    function getWithdrawable(address recipient) public view returns (uint128) {
        return
            getTotalUnlocked(recipient) - recipients[recipient].totalWithdrawn;
    }

    /// @notice Returns the amount of tokens ever unlocked for a given
    /// recipient.
    function getTotalUnlocked(address recipient)
        public
        view
        returns (uint128 totalUnlocked)
    {
        Recipient storage r = recipients[recipient];
        totalUnlocked = r.unlockedAmount;

        for (uint256 i; i < r.grants.length; ++i) {
            totalUnlocked += _getGrantUnlocked(r.grants[i]);
        }
    }

    /// @notice Returns the amount of tokens ever unlocked from a single grant.
    function _getGrantUnlocked(Grant memory g) private view returns (uint128) {
        if (g.effectiveAt == 0 || g.unlockWindow == 0) return 0;
        if (block.timestamp <= g.effectiveAt) return 0;
        if (block.timestamp >= g.effectiveAt + g.unlockWindow) return g.amount;

        return
            g.amount / g.unlockWindow * uint64(block.timestamp - g.effectiveAt);
    }
}

/// @title ProxiedGrantPool
/// @notice Proxied version of the parent contract.
contract ProxiedTimeLockTokenPool is Proxied, TimeLockTokenPool { }
