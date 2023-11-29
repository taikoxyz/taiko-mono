// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "../../common/EssentialContract.sol";
import "../tiers/ITierProvider.sol";
import "../TaikoData.sol";

/// @title GuardianProver
/// @dev Labeled in AddressResolver as "guardian_prover"
contract GuardianProver is EssentialContract {
    uint256 public constant MIN_NUM_GUARDIANS = 5;
    mapping(address guardian => uint256 id) public guardianIds; // slot 1
    mapping(uint32 version => mapping(bytes32 => uint256 approvalBits)) public approvals; // slot 2
    address[] public guardians; // slot 3
    uint32 public version; // slot 4
    uint32 public minGuardians;

    uint256[46] private __gap;

    event GuardiansUpdated(uint32 version, address[] guardians);
    event Approved(uint64 indexed blockId, uint256 approvalBits, bool proofSubmitted);

    error INVALID_GUARDIAN();
    error INVALID_GUARDIAN_SET();
    error INVALID_MIN_GUARDIANS();
    error INVALID_PROOF();
    error PROVING_FAILED();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        _Essential_init(_addressManager);
    }

    /// @notice Set the set of guardians
    /// @param _guardians The new set of guardians
    function setGuardians(
        address[] memory _guardians,
        uint8 _minGuardians
    )
        external
        onlyOwner
        nonReentrant
    {
        if (_guardians.length < MIN_NUM_GUARDIANS || _guardians.length > type(uint8).max) {
            revert INVALID_GUARDIAN_SET();
        }
        if (
            _minGuardians == 0 || _minGuardians < _guardians.length / 2
                || _minGuardians > _guardians.length
        ) revert INVALID_MIN_GUARDIANS();

        // Delete current guardians data
        for (uint256 i; i < guardians.length; ++i) {
            delete guardianIds[guardians[i]];
        }
        assembly {
            sstore(guardians.slot, 0)
        }

        for (uint256 i; i < _guardians.length;) {
            address guardian = _guardians[i];
            if (guardian == address(0)) revert INVALID_GUARDIAN();
            if (guardianIds[guardian] != 0) revert INVALID_GUARDIAN_SET();

            // Save and index the guardian
            guardians.push(guardian);
            guardianIds[guardian] = ++i;
        }

        emit GuardiansUpdated(++version, _guardians);
    }

    /// @dev Called by guardians to approve a guardian proof
    function approve(
        TaikoData.BlockMetadata calldata meta,
        TaikoData.Transition calldata tran,
        TaikoData.TierProof calldata proof
    )
        external
        nonReentrant
    {
        uint256 id = guardianIds[msg.sender];
        if (id == 0) revert INVALID_GUARDIAN();

        if (proof.tier != LibTiers.TIER_GUARDIAN) revert INVALID_PROOF();

        bytes32 hash = keccak256(abi.encode(meta, tran));
        uint256 approvalBits = approvals[version][hash];

        approvalBits |= 1 << id;

        if (_isApproved(approvalBits)) {
            bytes memory data = abi.encodeWithSignature(
                "proveBlock(uint64,bytes)", meta.id, abi.encode(meta, tran, proof)
            );

            (bool success,) = resolve("taiko", false).call(data);
            if (!success) revert PROVING_FAILED();

            delete approvals[version][hash];
            emit Approved(meta.id, approvalBits, true);
        } else {
            approvals[version][hash] = approvalBits;
            emit Approved(meta.id, approvalBits, false);
        }
    }

    function _isApproved(uint256 approvalBits) private view returns (bool) {
        uint256 count;
        uint256 bits = approvalBits >> 1;
        for (uint256 i; i < guardians.length; ++i) {
            if (bits & 1 == 1) ++count;
            if (count == minGuardians) return true;
            bits >>= 1;
        }
        return false;
    }
}
