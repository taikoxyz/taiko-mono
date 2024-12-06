// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../trailblazers-badges/TrailblazersBadgesV3.sol";
import "./BadgeRecruitment.sol";

contract BadgeRecruitmentV2 is BadgeRecruitment {
    error HASH_ALREADY_CLAIMED();

    mapping(bytes32 _hash => bool _isUsed) public usedClaimHashes;

    function version() external view virtual returns (string memory) {
        return "v2";
    }
    /// @notice Start a recruitment for a badge using the user's experience points
    /// @param _hash The hash to sign of the signature
    /// @param _v The signature V field
    /// @param _r The signature R field
    /// @param _s The signature S field
    /// @param _exp The user's experience points

    function startRecruitment(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _exp
    )
        external
        virtual
        override
        isNotMigrating(_msgSender())
    {
        bytes32 calculatedHash_ = generateClaimHash(HashType.Start, _msgSender(), _exp);

        if (calculatedHash_ != _hash) {
            revert HASH_MISMATCH();
        }

        if (usedClaimHashes[_hash]) {
            revert HASH_ALREADY_CLAIMED();
        }

        (address recovered_,,) = ECDSA.tryRecover(_hash, _v, _r, _s);
        if (recovered_ != randomSigner) {
            revert NOT_RANDOM_SIGNER();
        }

        if (_exp < userExperience[_msgSender()]) {
            revert EXP_TOO_LOW();
        }

        userExperience[_msgSender()] = _exp;

        RecruitmentCycle memory cycle_ = recruitmentCycles[recruitmentCycleId];
        if (cycle_.startTime > block.timestamp || cycle_.endTime < block.timestamp) {
            revert RECRUITMENT_NOT_ENABLED();
        }
        uint256 randomSeed_ = randomFromSignature(_hash, _v, _r, _s);
        uint256 s1BadgeId_ = cycle_.s1BadgeIds[randomSeed_ % cycle_.s1BadgeIds.length];

        if (
            recruitmentCycleUniqueMints[recruitmentCycleId][_msgSender()][s1BadgeId_][RecruitmentType
                .Claim]
        ) {
            revert ALREADY_MIGRATED_IN_CYCLE();
        }

        _startRecruitment(_msgSender(), s1BadgeId_, 0, RecruitmentType.Claim);
        usedClaimHashes[_hash] = true;
    }

    /// @notice Start a recruitment for a badge using the user's experience points
    /// @param _hash The hash to sign of the signature
    /// @param _v The signature V field
    /// @param _r The signature R field
    /// @param _s The signature S field
    /// @param _exp The user's experience points
    /// @param _s1BadgeId The badge ID (s1)
    function startRecruitment(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _exp,
        uint256 _s1BadgeId
    )
        external
        virtual
        override
        isNotMigrating(_msgSender())
        recruitmentOpen(_s1BadgeId)
        hasntMigratedInCycle(_s1BadgeId, _msgSender(), RecruitmentType.Claim)
    {
        bytes32 calculatedHash_ = generateClaimHash(HashType.Start, _msgSender(), _s1BadgeId);

        if (calculatedHash_ != _hash) {
            revert HASH_MISMATCH();
        }

        if (usedClaimHashes[_hash]) {
            revert HASH_ALREADY_CLAIMED();
        }

        (address recovered_,,) = ECDSA.tryRecover(_hash, _v, _r, _s);
        if (recovered_ != randomSigner) {
            revert NOT_RANDOM_SIGNER();
        }

        if (_exp < userExperience[_msgSender()]) {
            revert EXP_TOO_LOW();
        }

        userExperience[_msgSender()] = _exp;
        _startRecruitment(_msgSender(), _s1BadgeId, 0, RecruitmentType.Claim);
        usedClaimHashes[calculatedHash_] = true;
    }
}
