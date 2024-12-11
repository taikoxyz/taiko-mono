// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./BadgeRecruitment.sol";

contract BadgeRecruitmentV2 is BadgeRecruitment {
    /// @notice Events
    event RecruitmentReset(address indexed user, uint256 indexed s1TokenId, uint256 s1BadgeId);

    /// @notice Errors
    error RECRUITMENT_ALREADY_COMPLETED();

    /// @notice Updated version function
    function version() external pure virtual returns (string memory) {
        return "V2";
    }

    /// @notice Start a recruitment for a badge
    /// @param _s1BadgeId The badge ID (s1)
    /// @dev Not all badges are eligible for recruitment at the same time
    /// @dev Defines a cooldown for the recruitment to be complete
    /// @dev the cooldown is lesser the higher the Pass Tier
    /// @dev Must be called from the s1 badges contract
    function startRecruitment(
        address _user,
        uint256 _s1BadgeId,
        uint256 _s1TokenId
    )
        external
        virtual
        onlyRole(S1_BADGES_ROLE)
        recruitmentOpen(_s1BadgeId)
        isNotMigrating(_user)
        hasntMigratedInCycle(_s1BadgeId, _user, RecruitmentType.Migration)
    {
        if (s1Badges.ownerOf(_s1TokenId) != _user) {
            revert TOKEN_NOT_OWNED();
        }
        _startRecruitment(_user, _s1BadgeId, _s1TokenId, RecruitmentType.Migration);
    }

    /// @notice Disable all current recruitments
    /// @dev Bypasses the default date checks
    function forceDisableAllRecruitments() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        forceDisableRecruitments();
    }

    /// @notice Get the active recruitment for a user
    /// @param _user The user address
    /// @return The active recruitment
    function getActiveRecruitmentsFor(address _user) public view returns (Recruitment[] memory) {
        if (recruitments[_user].length == 0) {
            revert RECRUITMENT_NOT_STARTED();
        }
        return recruitments[_user];
    }

    /// @notice Reset a recruitment that hasn't been completed
    /// @param _user The user address
    /// @param _recruitmentIdx The recruitment index
    /// @param _s1TokenId The s1 token ID
    /// @dev Must be called from the s1 badges contract
    function resetRecruitment(
        address _user,
        uint256 _recruitmentIdx,
        uint256 _s1TokenId
    )
        public
        virtual
        onlyRole(S1_BADGES_ROLE)
    {
        Recruitment memory recruitment_ = recruitments[_user][_recruitmentIdx];
        if (recruitment_.s1TokenId != _s1TokenId) {
            revert RECRUITMENT_NOT_STARTED();
        }

        if (recruitment_.s2TokenId != 0) {
            revert RECRUITMENT_ALREADY_COMPLETED();
        }

        // reset
        uint256 s1BadgeId_ = recruitment_.s1BadgeId;

        //delete
        delete recruitments[_user][_recruitmentIdx];
        recruitmentCycleUniqueMints[recruitmentCycleId][_user][s1BadgeId_][RecruitmentType.Undefined]
        = false;
        recruitmentCycleUniqueMints[recruitmentCycleId][_user][s1BadgeId_][RecruitmentType.Claim] =
            false;
        recruitmentCycleUniqueMints[recruitmentCycleId][_user][s1BadgeId_][RecruitmentType.Migration]
        = false;

        emit RecruitmentReset(_user, _s1TokenId, s1BadgeId_);
    }
}
