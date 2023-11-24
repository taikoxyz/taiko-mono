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
    uint256 public constant NUM_GUARDIANS = 5;
    uint256 public constant REQUIRED_GUARDIANS = 3;

    mapping(address guardian => uint256 id) public guardianIds; // slot 1
    mapping(bytes32 => uint256 approvalBits) public approvals; // slot 2
    address[NUM_GUARDIANS] public guardians; //  slots 3,4,5,6,7
    uint256[43] private __gap2;

    // Cannot use NUM_GUARDIANS below in event directly otherwise hardhat will
    // fail
    event GuardiansUpdated(address[5]);
    event Approved(uint64 indexed blockId, uint256 approvalBits, bool proofSubmitted);

    error INVALID_GUARDIAN();
    error INVALID_GUARDIAN_SET();
    error INVALID_PROOF();
    error PROVING_FAILED();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        _init(_addressManager);
    }

    /// @notice Set the set of guardians
    /// @param _guardians The new set of guardians
    function setGuardians(address[NUM_GUARDIANS] memory _guardians)
        external
        onlyOwner
        nonReentrant
    {
        for (uint256 i; i < NUM_GUARDIANS; ++i) {
            address guardian = _guardians[i];
            if (guardian == address(0)) revert INVALID_GUARDIAN();

            // In case there is a pending 'approval' and we call setGuardians()
            // with an existing guardian but with different array position (id),
            // then accidentally 2 guardian signatures could lead to firing away
            // a proveBlock() transaction.
            uint256 id = guardianIds[guardian];

            if (id != 0) {
                if (id != i + 1) revert INVALID_GUARDIAN_SET();
            } else {
                delete guardianIds[guardians[i]];
                guardianIds[guardian] = i + 1;
                guardians[i] = guardian;
            }
        }

        emit GuardiansUpdated(_guardians);
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
        uint256 approvalBits = approvals[hash];

        approvalBits |= 1 << id;

        if (_isApproved(approvalBits)) {
            bytes memory data = abi.encodeWithSignature(
                "proveBlock(uint64,bytes)", meta.id, abi.encode(meta, tran, proof)
            );

            (bool success,) = resolve("taiko", false).call(data);

            if (!success) revert PROVING_FAILED();
            delete approvals[hash];

            emit Approved(meta.id, approvalBits, true);
        } else {
            approvals[hash] = approvalBits;
            emit Approved(meta.id, approvalBits, false);
        }
    }

    function _isApproved(uint256 approvalBits) private pure returns (bool) {
        uint256 count;
        uint256 bits = approvalBits >> 1;
        for (uint256 i; i < NUM_GUARDIANS; ++i) {
            if (bits & 1 == 1) ++count;
            if (count == REQUIRED_GUARDIANS) return true;
            bits >>= 1;
        }
        return false;
    }
}
