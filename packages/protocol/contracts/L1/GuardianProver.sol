// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";

import { LibTiers } from "./tiers/ITierProvider.sol";
import { TaikoData } from "./TaikoData.sol";
import { TaikoL1 } from "./TaikoL1.sol";

/// @title GuardianProver
contract GuardianProver is EssentialContract {
    uint256 public constant MAX_GUARDIANS = 5;
    uint256 public constant REQUIRED_GUARDINS = 3;
    uint256 private constant DONE = type(uint256).max;

    mapping(bytes32 => uint256 approvalBits) public blocks;
    uint256[49] private __gap;

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @dev Called by each of the 5 guardians
    function proveBlock(
        uint64 blockId,
        TaikoData.BlockEvidence calldata evidence
    )
        external
    {
        if (
            evidence.proof.length != 0
                && evidence.tier != LibTiers.TIER_GUARDIAN
        ) revert("invalid");
        bytes32 hash = keccak256(abi.encode(blockId, evidence));

        uint256 approvalBits = blocks[hash];
        require(approvalBits != DONE);
        approvalBits |= uint8(1 << getGuardianId(msg.sender));

        if (isApproved(approvalBits)) {
            bytes memory data = abi.encodeWithSignature(
                "proveBlock(uint64,bytes)", blockId, abi.encode(evidence)
            );
            (bool success, bytes memory result) =
                resolve("taiko", false).call(data);

            require(success, "Call failed");

            blocks[hash] = DONE;
        } else {
            blocks[hash] = approvalBits;
        }
    }

    function getGuardianId(address addr) public view returns (uint256 id) {
        // TODO: 5 guardian must have id: 1,2,...5.
        if (id == 0 || id > MAX_GUARDIANS) revert("bad guardian");
    }

    function isApproved(uint256 approvalBits) public pure returns (bool) {
        uint256 count;
        uint256 bits = approvalBits >> 1;
        for (uint256 i = 0; i < MAX_GUARDIANS; ++i) {
            if (bits & 1 == 1) ++count;
            if (count == REQUIRED_GUARDINS) return true;
            bits >>= 1;
        }
        return false;
    }
}

/// @title ProxiedGuardianProver
/// @notice Proxied version of the parent contract.
contract ProxiedGuardianProver is Proxied, GuardianProver { }
