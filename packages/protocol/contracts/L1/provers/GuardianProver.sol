// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../common/EssentialContract.sol";
import "../tiers/ITierProvider.sol";
import "../ITaikoL1.sol";

/// @title GuardianProver
/// @notice A contract that manages a set of guardians and their approvals.
/// @custom:security-contact security@taiko.xyz
contract GuardianProver is EssentialContract {
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

    uint256[45] private __gap;

    /// @notice Emitted when the set of guardians is updated
    /// @param version The new version
    /// @param guardians The new set of guardians
    event GuardiansUpdated(uint32 version, address[] guardians);

    /// @notice Emitted when an approval is made
    /// @param metaId The block's meta ID
    /// @param approvalBits The new approval bits
    /// @param proofSubmitted If the proof was submitted
    event Approved(uint256 indexed metaId, uint256 approvalBits, bool proofSubmitted);

    /// @notice Emitted when a guardian proof is approved.
    /// @param addr The address of the guardian.
    /// @param blockId The block ID.
    /// @param blockHash The block hash.
    /// @param approved If the proof is approved.
    event GuardianApproval(
        address indexed addr, uint256 indexed blockId, bytes32 blockHash, bool approved
    );

    error INVALID_GUARDIAN();
    error INVALID_GUARDIAN_SET();
    error INVALID_MIN_GUARDIANS();
    error INVALID_PROOF();
    error INVALID_SIGNATURES();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

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
        if (_newGuardians.length == 0 || _newGuardians.length > type(uint8).max) {
            revert INVALID_GUARDIAN_SET();
        }
        // Minimum number of guardians to approve is non zero and not greater than the total number
        // of guardians.
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

    /// @dev Called by guardians to approve a guardian proof
    /// @param _meta The block's metadata.
    /// @param _tran The valid transition.
    /// @param _proof The tier proof.
    /// @return approved_ If the minimum number of participants sent the same proof, and proving
    /// transaction is fired away returns true, false otherwise.
    function approve(
        TaikoData.BlockMetadata calldata _meta,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        whenNotPaused
        nonReentrant
        returns (bool approved_)
    {
        if (_proof.tier != LibTiers.TIER_GUARDIAN) revert INVALID_PROOF();
        bytes32 hash = keccak256(abi.encode(_meta, _tran));
        approved_ = approve(_meta.id, hash);

        if (approved_) {
            deleteApproval(hash);
            ITaikoL1(resolve("taiko", false)).proveBlock(_meta.id, abi.encode(_meta, _tran, _proof));
        }

        emit GuardianApproval(msg.sender, _meta.id, _tran.blockHash, approved_);
    }

    /// @dev Called by guardians to approve a guardian proof with a list of signatures.
    /// @param _meta The block's metadata.
    /// @param _tran The valid transition.
    /// @param _proof The tier proof.
    /// @param _signatures The guardians' signatures.
    function approveWithSignatures(
        TaikoData.BlockMetadata calldata _meta,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof,
        bytes[] calldata _signatures
    )
        external
        whenNotPaused
        nonReentrant
    {
        if (_proof.tier != LibTiers.TIER_GUARDIAN) revert INVALID_PROOF();
        if (_signatures.length < minGuardians) revert INVALID_SIGNATURES();

        bytes32 hash = keccak256(abi.encode("APPROVE", _meta, _tran));
        address lastGuardian;

        for (uint256 i; i < minGuardians; ++i) {
            address guardian = ECDSA.recover(hash, _signatures[i]);
            if (uint160(guardian) <= uint160(lastGuardian) || guardianIds[guardian] == 0) {
                revert INVALID_SIGNATURES();
            }
            lastGuardian = guardian;
        }

        deleteApproval(hash);
        ITaikoL1(resolve("taiko", false)).proveBlock(_meta.id, abi.encode(_meta, _tran, _proof));

        emit GuardianApproval(address(0), _meta.id, _tran.blockHash, true);
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

    function approve(uint256 _metaId, bytes32 _hash) internal returns (bool approved_) {
        uint256 id = guardianIds[msg.sender];
        if (id == 0) revert INVALID_GUARDIAN();

        unchecked {
            _approvals[version][_hash] |= 1 << (id - 1);
        }

        uint256 _approval = _approvals[version][_hash];
        approved_ = isApproved(_approval);
        emit Approved(_metaId, _approval, approved_);
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
