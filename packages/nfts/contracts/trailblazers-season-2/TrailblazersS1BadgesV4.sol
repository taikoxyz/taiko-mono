// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../trailblazers-badges/TrailblazersBadgesV3.sol";
import "./BadgeRecruitment.sol";

contract TrailblazersBadgesV4 is TrailblazersBadgesV3 {
    /// @notice Duration for which a s1 badge is locked after recruitment is started
    uint256 public recruitmentLockDuration;
    /// @notice BadgeRecruitment contract
    BadgeRecruitment public recruitmentContract;
    /// @notice Mapping of badge token id to unlock timestamp
    mapping(uint256 tokenId => uint256 unlockTimestamp) public unlockTimestamps;

    /// @notice Errors
    error BADGE_LOCKED();
    error RECRUITMENT_LOCK_DURATION_NOT_SET();

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

    /// @notice Set recruitment contract
    /// @param _recruitmentContract Address of the recruitment contract
    /// @dev Only owner
    function setRecruitmentContract(address _recruitmentContract) public onlyOwner {
        recruitmentContract = BadgeRecruitment(_recruitmentContract);
    }

    /// @notice Set recruitment lock duration
    /// @param _duration Duration in seconds
    /// @dev Only owner
    function setRecruitmentLockDuration(uint256 _duration) public onlyOwner {
        recruitmentLockDuration = _duration;
    }

    /// @notice Start recruitment for a badge
    /// @param _badgeId Badge id
    function startRecruitment(uint256 _badgeId) public virtual {
        if (recruitmentLockDuration == 0) {
            revert RECRUITMENT_LOCK_DURATION_NOT_SET();
        }
        uint256 tokenId = getTokenId(_msgSender(), _badgeId);
        unlockTimestamps[tokenId] = block.timestamp + recruitmentLockDuration;
        recruitmentContract.startRecruitment(_msgSender(), _badgeId);
    }
}
