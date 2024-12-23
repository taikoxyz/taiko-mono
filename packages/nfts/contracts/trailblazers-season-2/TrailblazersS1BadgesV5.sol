// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TrailblazersS1BadgesV4.sol";
import "./BadgeRecruitment.sol";
import "./BadgeRecruitmentV2.sol";

contract TrailblazersBadgesV5 is TrailblazersBadgesV4 {
    /// @notice Errors
    error RECRUITMENT_ALREADY_COMPLETED();
    error NOT_OWNER();
    error NOT_IMPLEMENTED();
    error RECRUITMENT_NOT_FOUND();
    /// @notice Updated version function
    /// @return Version string

    function version() external pure virtual override returns (string memory) {
        return "V5";
    }
    /// @notice Recruitment contract

    BadgeRecruitmentV2 public recruitmentContractV2;
    /// @notice Setter for recruitment contract

    function setRecruitmentContractV2(address _recruitmentContractV2) public onlyOwner {
        recruitmentContractV2 = BadgeRecruitmentV2(_recruitmentContractV2);
    }

    /// @notice Start recruitment for a badge
    /// @param _badgeId Badge ID
    /// @param _tokenId Token ID
    function startRecruitment(uint256 _badgeId, uint256 _tokenId) public {
        if (recruitmentLockDuration == 0) {
            revert RECRUITMENT_LOCK_DURATION_NOT_SET();
        }
        if (ownerOf(_tokenId) != _msgSender()) {
            revert NOT_OWNER();
        }

        if (unlockTimestamps[_tokenId] > block.timestamp) {
            revert BADGE_LOCKED();
        }

        unlockTimestamps[_tokenId] = block.timestamp + recruitmentLockDuration;
        recruitmentContractV2.startRecruitment(_msgSender(), _badgeId, _tokenId);
    }

    /// @notice Deprecated of legacy function
    function startRecruitment(uint256 /*_badgeId*/ ) public virtual override {
        revert NOT_IMPLEMENTED();
    }

    /// @notice Reset an ongoing migration
    /// @param _tokenId Token ID
    /// @param _badgeId Badge ID
    /// @param _cycleId Cycle ID
    /// @dev Only the owner of the token can reset the migration
    function resetMigration(uint256 _tokenId, uint256 _badgeId, uint256 _cycleId) public virtual {
        if (ownerOf(_tokenId) != _msgSender()) {
            revert NOT_OWNER();
        }

        recruitmentContractV2.resetRecruitment(_msgSender(), _tokenId, _badgeId, _cycleId);
        unlockTimestamps[_tokenId] = 0;
    }
}
