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

/// @title GrantPool
contract GrantPool is OwnableUpgradeable {
    using SafeERC20Upgradeable for ERC20Upgradeable;

    uint256 public constant UNLOCK_WINDOW = 4 * 365 days;

    struct Grant {
        uint64 startedAt;
        uint256 amount;
    }

    struct Recipient {
        uint256 unlockedAmount;
        uint256 totalWithdrawn;
        uint64 withdrawnAt;
        Grant[] grants;
    }

    address public token;
    mapping(address recipient => Recipient) public recipients;

    event Withdrawn(address indexed user, uint256 amount);
    event Settled(address indexed user, uint256 newlySettled);
    event Granted(address indexed user, Grant grant);

    function init(address _token) external initializer {
        OwnableUpgradeable.__Ownable_init_unchained();
        token = _token;
    }

    function grant(
        address recipient,
        uint64 startedAt,
        uint256 amount
    )
        external
        onlyOwner
    {
        require(recipient != address(0), "zero addr");
        require(startedAt > block.timestamp, "invalid time");
        require(amount > 0, "invalid amount");

        Grant memory g = Grant(startedAt, amount);
        recipients[recipient].grants.push(g);
        emit Granted(recipient, g);
    }

    function settle(address recipient) external onlyOwner {
        Recipient storage r = recipients[recipient];
        require(r.grants.length > 0, "nothing to settle");

        uint256 newlySettled;
        for (uint256 i; i < r.grants.length; ++i) {
            newlySettled += _getGrantUnlocked(r.grants[i]);
        }

        r.unlockedAmount += newlySettled;
        delete r.grants;

        emit Settled(recipient, newlySettled);
    }

    function withdraw() external {
        uint256 amount = getWithdrawable(msg.sender);
        require(amount > 0, "zero withdrawable");

        recipients[msg.sender].withdrawnAt = uint64(block.timestamp);
        recipients[msg.sender].totalWithdrawn += amount;
        ERC20Upgradeable(token).transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getWithdrawable(address recipient) public view returns (uint256) {
        return
            getTotalUnlocked(recipient) - recipients[recipient].totalWithdrawn;
    }

    function getTotalUnlocked(address recipient)
        public
        view
        returns (uint256 totalUnlocked)
    {
        Recipient storage r = recipients[recipient];
        totalUnlocked = r.unlockedAmount;

        for (uint256 i; i < r.grants.length; ++i) {
            totalUnlocked += _getGrantUnlocked(r.grants[i]);
        }
    }

    function _getGrantUnlocked(Grant memory g) private view returns (uint256) {
        if (g.startedAt == 0) return 0;
        if (block.timestamp <= g.startedAt) return 0;
        if (block.timestamp >= UNLOCK_WINDOW) return g.amount;

        return g.amount * (block.timestamp - g.startedAt) / UNLOCK_WINDOW;
    }
}

/// @title ProxiedGrantPool
/// @notice Proxied version of the parent contract.
contract ProxiedGrantPool is Proxied, GrantPool { }
