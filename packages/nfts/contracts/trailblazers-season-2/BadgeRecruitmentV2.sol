// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./BadgeRecruitment.sol";

contract BadgeRecruitmentV2 is BadgeRecruitment {
    /// @notice Events
    event RecruitmentReset(
        uint256 indexed cycleId, address indexed user, uint256 indexed s1TokenId, uint256 s1BadgeId
    );

    /// @notice Errors
    error RECRUITMENT_ALREADY_COMPLETED();
    error RECRUITMENT_NOT_FOUND();
    error NOT_ENOUGH_TIME_LEFT();

    modifier recruitmentHasTimeLeft(address _user) {
        uint256 endCycleTime = recruitmentCycles[recruitmentCycleId].endTime;
        uint256 potentialRecruitmentEndTime = block.timestamp + this.getConfig().cooldownRecruitment;

        if (potentialRecruitmentEndTime > endCycleTime) {
            revert NOT_ENOUGH_TIME_LEFT();
        }
        _;
    }

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
        recruitmentHasTimeLeft(_user)
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

        emit RecruitmentCycleToggled(
            recruitmentCycleId,
            recruitmentCycles[recruitmentCycleId].startTime,
            recruitmentCycles[recruitmentCycleId].endTime,
            recruitmentCycles[recruitmentCycleId].s1BadgeIds,
            false
        );
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
    /// @param _s1TokenId The s1 token ID
    /// @param _s1BadgeId The s1 badge ID
    /// @param _recruitmentCycle The recruitment index
    /// @dev Must be called from the s1 badges contract
    function resetRecruitment(
        address _user,
        uint256 _s1TokenId,
        uint256 _s1BadgeId,
        uint256 _recruitmentCycle
    )
        public
        virtual
        onlyRole(S1_BADGES_ROLE)
    {
        if (
            !recruitmentCycleUniqueMints[_recruitmentCycle][_user][_s1BadgeId][RecruitmentType
                .Migration]
                && !recruitmentCycleUniqueMints[_recruitmentCycle][_user][_s1BadgeId][RecruitmentType.Claim]
                && !recruitmentCycleUniqueMints[_recruitmentCycle][_user][_s1BadgeId][RecruitmentType
                    .Undefined]
        ) {
            revert RECRUITMENT_NOT_FOUND();
        }

        bool found = false;

        for (uint256 i = 0; i < recruitments[_user].length; i++) {
            if (
                recruitments[_user][i].recruitmentCycle == _recruitmentCycle
                    && recruitments[_user][i].s1TokenId == _s1TokenId
                    && recruitments[_user][i].s2TokenId == 0
            ) {
                delete recruitments[_user][i];
                found = true;
                break;
            }
        }

        if (!found) {
            revert RECRUITMENT_NOT_FOUND();
        }

        recruitmentCycleUniqueMints[_recruitmentCycle][_user][_s1BadgeId][RecruitmentType.Undefined]
        = false;
        recruitmentCycleUniqueMints[_recruitmentCycle][_user][_s1BadgeId][RecruitmentType.Claim] =
            false;
        recruitmentCycleUniqueMints[_recruitmentCycle][_user][_s1BadgeId][RecruitmentType.Migration]
        = false;

        emit RecruitmentReset(_recruitmentCycle, _user, _s1TokenId, _s1BadgeId);
    }

    /// @notice Set the s2 badges contract
    /// @param _s2Badges The s2 badges contract address
    /// @dev Must be called from the admin account
    function setS2BadgesContract(address _s2Badges) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        s2Badges = TrailblazersBadgesS2(_s2Badges);
    }
}
