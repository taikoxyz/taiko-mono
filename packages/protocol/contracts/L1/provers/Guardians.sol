// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";

/// @title Guardians
/// @notice A contract that manages a set of guardians and their approvals.
/// @custom:security-contact security@taiko.xyz
abstract contract Guardians is EssentialContract {
    /// @notice Contains the index of the guardian in `guardians` plus one (zero means not a
    /// guardian)
    /// @dev Slot 1
    mapping(address guardian => uint256 id) public guardianIds;

    /// @notice Mapping to store the approvals for a given hash, for a given version
    mapping(uint32 version => mapping(bytes32 hash => uint256 approvalBits)) internal _approvals;

    /// @notice The set of guardians
    /// @dev Slot 3
    address[] public guardians;

    /// @notice The version of the guardians
    /// @dev Slot 4
    uint32 public version;

    /// @notice The minimum number of guardians required to approve
    uint32 public minGuardians;

    uint256[46] private __gap;

    /// @notice Emitted when the set of guardians is updated
    /// @param version The new version
    /// @param guardians The new set of guardians
    event GuardiansUpdated(uint32 version, address[] guardians);

    /// @notice Emitted when an approval is made
    /// @param operationId The operation ID
    /// @param approvalBits The new approval bits
    /// @param minGuardiansReached If the proof was submitted
    event Approved(uint256 indexed operationId, uint256 approvalBits, bool minGuardiansReached);

    error INVALID_GUARDIAN();
    error INVALID_GUARDIAN_SET();
    error INVALID_MIN_GUARDIANS();
    error INVALID_PROOF();

    /// @notice Set the set of guardians
    /// @param _newGuardians The new set of guardians
    /// @param _minGuardians The minimum required to sign
    function setGuardians(
        address[] memory _newGuardians,
        uint8 _minGuardians
    )
        external
        onlyOwner
        nonReentrant
    {
        // We need at most 255 guardians (so the approval bits fit in a uint256)
        if (_newGuardians.length == 0 || _newGuardians.length > type(uint8).max) {
            revert INVALID_GUARDIAN_SET();
        }
        // Minimum number of guardians to approve is at least equal or greater than half the
        // guardians (rounded up) and less or equal than the total number of guardians
        if (_minGuardians == 0 || _minGuardians > _newGuardians.length) {
            revert INVALID_MIN_GUARDIANS();
        }

        // Delete the current guardians
        for (uint256 i; i < guardians.length; ++i) {
            delete guardianIds[guardians[i]];
        }
        delete guardians;

        // Set the new guardians
        for (uint256 i; i < _newGuardians.length; ++i) {
            address guardian = _newGuardians[i];
            if (guardian == address(0)) revert INVALID_GUARDIAN();
            // This makes sure there are not duplicate addresses
            if (guardianIds[guardian] != 0) revert INVALID_GUARDIAN_SET();

            // Save and index the guardian
            guardians.push(guardian);
            guardianIds[guardian] = guardians.length;
        }

        // Bump the version so previous approvals get invalidated
        ++version;

        minGuardians = _minGuardians;
        emit GuardiansUpdated(version, _newGuardians);
    }

    /// @notice Returns if the hash is approved
    /// @param _hash The hash to check
    /// @return true if the hash is approved
    function isApproved(bytes32 _hash) public view returns (bool) {
        return isApproved(_approvals[version][_hash]);
    }

    /// @notice Returns the number of guardians
    /// @return The number of guardians
    function numGuardians() public view returns (uint256) {
        return guardians.length;
    }

    function approve(uint256 _blockId, bytes32 _hash) internal returns (bool approved_) {
        uint256 id = guardianIds[msg.sender];
        if (id == 0) revert INVALID_GUARDIAN();

        uint32 _version = version;

        unchecked {
            _approvals[_version][_hash] |= 1 << (id - 1);
        }

        uint256 _approval = _approvals[_version][_hash];
        approved_ = isApproved(_approval);
        emit Approved(_blockId, _approval, approved_);
    }

    function deleteApproval(bytes32 _hash) internal {
        delete _approvals[version][_hash];
    }

    function isApproved(uint256 _approvalBits) internal view returns (bool) {
        uint256 count;
        uint256 bits = _approvalBits;
        uint256 guardiansLength = guardians.length;
        unchecked {
            for (uint256 i; i < guardiansLength; ++i) {
                if (bits & 1 == 1) ++count;
                if (count == minGuardians) return true;
                bits >>= 1;
            }
        }
        return false;
    }
}
