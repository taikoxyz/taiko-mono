// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TrailblazersS1BadgesV5.sol";
import "./BadgeRecruitment.sol";
import "./BadgeRecruitmentV2.sol";

contract TrailblazersBadgesV6 is TrailblazersBadgesV5 {
    /// @notice Updated version function
    /// @return Version string
    function version() external pure virtual override returns (string memory) {
        return "V6";
    }
    /// @notice Errors

    error BADGE_LOCKED_SEASON_2();

    /// @notice Season end timestamps
    uint256 public season2EndTimestamp; // 1734350400
    uint256 public season3EndTimestamp; // 1742212800

    /// @notice Setter for season 2 end timestamps
    /// @param _ts Timestamp
    /// @dev Only owner can set the timestamp
    function setSeason2EndTimestamp(uint256 _ts) public virtual onlyOwner {
        season2EndTimestamp = _ts;
    }

    /// @notice Setter for season 3 end timestamps
    /// @param _ts Timestamp
    /// @dev Only owner can set the timestamp
    function setSeason3EndTimestamp(uint256 _ts) public virtual onlyOwner {
        season3EndTimestamp = _ts;
    }

    /// @notice Modifier to ensure a badge isn't locked on a recruitment for that season
    /// @param tokenId Badge token id
    modifier isNotLocked(uint256 tokenId) virtual {
        if (unlockTimestamps[tokenId] > 0 && block.timestamp < season2EndTimestamp) {
            // s2
            revert BADGE_LOCKED();
        } else if (
            unlockTimestamps[tokenId] == season3EndTimestamp
                && block.timestamp > season2EndTimestamp && block.timestamp < season3EndTimestamp
        ) {
            // s3
            revert BADGE_LOCKED_SEASON_2();
        }
        _;
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
        isNotLocked(tokenId)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /// @notice Start recruitment for a badge
    /// @param _badgeId Badge ID
    /// @param _tokenId Token ID
    function startRecruitment(
        uint256 _badgeId,
        uint256 _tokenId
    )
        public
        virtual
        override
        isNotLocked(_tokenId)
    {
        if (recruitmentLockDuration == 0) {
            revert RECRUITMENT_LOCK_DURATION_NOT_SET();
        }
        if (ownerOf(_tokenId) != _msgSender()) {
            revert NOT_OWNER();
        }

        if (block.timestamp < season2EndTimestamp) {
            unlockTimestamps[_tokenId] = season2EndTimestamp;
        } else {
            unlockTimestamps[_tokenId] = season3EndTimestamp;
        }

        recruitmentContractV2.startRecruitment(_msgSender(), _badgeId, _tokenId);
    }
}
