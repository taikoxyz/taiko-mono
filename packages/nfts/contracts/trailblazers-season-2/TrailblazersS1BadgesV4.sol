// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../trailblazers-badges/TrailblazersBadgesV3.sol";
import "./BadgeMigration.sol";

contract TrailblazersBadgesV4 is TrailblazersBadgesV3 {
    /// @notice Duration for which a s1 badge is locked after migration is started
    uint256 public migrationLockDuration;
    /// @notice BadgeMigration contract
    BadgeMigration public migrationContract;
    /// @notice Mapping of badge token id to unlock timestamp
    mapping(uint256 tokenId => uint256 unlockTimestamp) public unlockTimestamps;

    /// @notice Errors
    error BADGE_LOCKED();
    error MIGRATION_LOCK_DURATION_NOT_SET();

    /// @notice Updated version function
    /// @return Version string
    function version() external pure virtual override returns (string memory) {
        return "V4";
    }

    /// @notice Overwritten update function that prevents locked badges from being transferred
    /// @param to Address to transfer badge to
    /// @param tokenId Badge token id
    /// @param auth Address to authorize transfer
    /// @return Address of the recipient
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        virtual
        override
        returns (address)
    {
        if (unlockTimestamps[tokenId] > block.timestamp) {
            revert BADGE_LOCKED();
        }
        return super._update(to, tokenId, auth);
    }

    /// @notice Set migration contract
    /// @param _migrationContract Address of the migration contract
    /// @dev Only owner
    function setMigrationContract(address _migrationContract) public onlyOwner {
        migrationContract = BadgeMigration(_migrationContract);
    }

    /// @notice Set migration lock duration
    /// @param _duration Duration in seconds
    /// @dev Only owner
    function setMigrationLockDuration(uint256 _duration) public onlyOwner {
        migrationLockDuration = _duration;
    }

    /// @notice Start migration for a badge
    /// @param _badgeId Badge id
    function startMigration(uint256 _badgeId) public {
        if (migrationLockDuration == 0) {
            revert MIGRATION_LOCK_DURATION_NOT_SET();
        }
        uint256 tokenId = getTokenId(_msgSender(), _badgeId);
        unlockTimestamps[tokenId] = block.timestamp + migrationLockDuration;
        migrationContract.startMigration(_msgSender(), _badgeId);
    }
}
