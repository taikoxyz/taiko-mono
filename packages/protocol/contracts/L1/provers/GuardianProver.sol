// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { Proxied } from "../../common/Proxied.sol";

import { LibTiers } from "../tiers/ITierProvider.sol";
import { TaikoData } from "../TaikoData.sol";

/// @title GuardianProver
contract GuardianProver is EssentialContract {
    event GuardiansAdded(address[]);

    uint256 public constant NUM_GUARDIANS = 5;
    uint256 public constant REQUIRED_GUARDIANS = 3;
    uint256 private constant DONE = type(uint256).max;

    mapping(address signer => uint256 id) public guardians;
    mapping(bytes32 => uint256 approvalBits) public blocks;

    uint256[48] private __gap;

    error INVALID_GUARDIAN_SET();
    error INVALID_GUARDIAN();
    error INVALID_PROOF();
    error MULTISIG_DONE();
    error PROVING_FAILED(bytes);

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @notice Adds or modify guardians
    /// @param multisigParticipants The address array of the guardians.
    function changeGuardians(address[] memory multisigParticipants)
        external
        onlyOwner
    {
        // Always send 5 addresses, even if you just want to modify 1 address,
        // so that (Bob, 0, 0, 0, 0) will set Bob only with index 1.
        if (multisigParticipants.length != NUM_GUARDIANS) {
            revert INVALID_GUARDIAN_SET();
        }

        for (uint256 i = 1; i <= NUM_GUARDIANS; i++) {
                guardians[multisigParticipants[i - 1]] = i;
        }

        emit GuardiansAdded(multisigParticipants);
    }

    /// @dev Called by each of the 5 guardians
    function proveBlock(
        uint64 blockId,
        TaikoData.BlockEvidence memory evidence,
        bool unprovable
    )
        external
    {
        if (
            evidence.proof.length != 0
                && evidence.tier != LibTiers.TIER_GUARDIAN
        ) revert INVALID_PROOF();
        bytes32 hash = keccak256(abi.encode(blockId, evidence, unprovable));

        uint256 approvalBits = blocks[hash];

        if(approvalBits == DONE) {
            revert MULTISIG_DONE();
        }

        approvalBits |= uint8(1 << getGuardianId(msg.sender));

        if (isApproved(approvalBits)) {
            if (unprovable) {
                evidence.proof =
                    bytes.concat(bytes32(keccak256("RETURN_LIVENESS_BOND")));
            }

            bytes memory data = abi.encodeWithSignature(
                "proveBlock(uint64,bytes)", blockId, abi.encode(evidence)
            );

            (bool success, bytes memory result) =
                resolve("taiko", false).call(data);
            if (!success) {
                revert PROVING_FAILED(result);
            }
            blocks[hash] = DONE;
        } else {
            blocks[hash] = approvalBits;
        }
    }

    function getGuardianId(address addr) public view returns (uint256 id) {
        id = guardians[addr];
        if (id == 0 || id > NUM_GUARDIANS) revert INVALID_GUARDIAN();
    }

    function isApproved(uint256 approvalBits) public pure returns (bool) {
        uint256 count;
        uint256 bits = approvalBits >> 1;
        for (uint256 i = 0; i < NUM_GUARDIANS; ++i) {
            if (bits & 1 == 1) ++count;
            if (count == REQUIRED_GUARDIANS) return true;
            bits >>= 1;
        }
        return false;
    }
}

/// @title ProxiedGuardianProver
/// @notice Proxied version of the parent contract.
contract ProxiedGuardianProver is Proxied, GuardianProver { }
