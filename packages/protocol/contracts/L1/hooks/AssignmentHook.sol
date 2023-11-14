// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { AddressResolver } from "../../common/AddressResolver.sol";
import { EssentialContract } from "../../common/EssentialContract.sol";
import { Proxied } from "../../common/Proxied.sol";
import { LibAddress } from "../../libs/LibAddress.sol";

import { TaikoData } from "../TaikoData.sol";

import { IHook } from "./IHook.sol";

contract AssignmentHook is EssentialContract, IHook {
    using LibAddress for address;
    // Max gas paying the prover. This should be large enough to prevent the
    // worst cases, usually block proposer shall be aware the risks and only
    // choose provers that cannot consume too much gas when receiving Ether.

    uint256 public constant MAX_GAS_PAYING_PROVER = 200_000;

    struct ProverAssignment {
        address feeToken;
        TaikoData.TierFee[] tierFees;
        uint64 expiry;
        uint64 maxBlockId;
        uint64 maxProposedIn;
        bytes32 metaHash;
        bytes signature;
    }

    error HOOK_ASSIGNMENT_EXPIRED();
    error HOOK_ASSIGNMENT_INVALID_SIG();
    error HOOK_ASSIGNMENT_INSUFFICIENT_FEE();
    error HOOK_TIER_NOT_FOUND();

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function postBlockProposed(
        TaikoData.Block memory blk,
        TaikoData.BlockMetadata memory meta,
        bytes memory data
    )
        external
        payable
        nonReentrant
        onlyFromNamed("taiko")
    {
        _payProverFeeAndTip(
            blk.assignedProver,
            meta.minTier,
            meta.blobHash,
            meta.id,
            blk.metaHash,
            abi.decode(data, (ProverAssignment))
        );
    }

    function hashAssignment(
        ProverAssignment memory assignment,
        address taikoAddress,
        bytes32 blobHash
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                "PROVER_ASSIGNMENT",
                taikoAddress,
                blobHash,
                assignment.feeToken,
                assignment.expiry,
                assignment.maxBlockId,
                assignment.maxProposedIn,
                assignment.tierFees
            )
        );
    }

    function _payProverFeeAndTip(
        address assignedProver,
        uint16 minTier,
        bytes32 blobHash,
        uint64 blockId,
        bytes32 metaHash,
        ProverAssignment memory assignment
    )
        private
        returns (uint256 proverFee)
    {
        // Check assignment validity
        if (
            block.timestamp > assignment.expiry
                || assignment.metaHash != 0 && metaHash != assignment.metaHash
                || assignment.maxBlockId != 0 && blockId > assignment.maxBlockId
                || assignment.maxProposedIn != 0
                    && block.number > assignment.maxProposedIn
        ) {
            revert HOOK_ASSIGNMENT_EXPIRED();
        }

        // Hash the assignment with the blobHash, this hash will be signed by
        // the prover, therefore, we add a string as a prefix.
        bytes32 hash = hashAssignment(assignment, address(this), blobHash);

        if (!assignedProver.isValidSignature(hash, assignment.signature)) {
            revert HOOK_ASSIGNMENT_INVALID_SIG();
        }

        // Find the prover fee using the minimal tier
        proverFee = _getProverFee(assignment.tierFees, minTier);

        // The proposer irrevocably pays a fee to the assigned prover, either in
        // Ether or ERC20 tokens.
        uint256 tip;
        if (assignment.feeToken == address(0)) {
            if (msg.value < proverFee) {
                revert HOOK_ASSIGNMENT_INSUFFICIENT_FEE();
            }

            unchecked {
                tip = msg.value - proverFee;
            }

            // Paying Ether
            assignedProver.sendEther(proverFee, MAX_GAS_PAYING_PROVER, "");
        } else {
            tip = msg.value;

            // Paying ERC20 tokens
            ERC20Upgradeable(assignment.feeToken).transferFrom(
                msg.sender, assignedProver, proverFee
            );
        }

        // block.coinbase can be address(0) in tests
        if (tip != 0 && block.coinbase != address(0)) {
            address(block.coinbase).sendEther(tip);
        }
    }

    function _getProverFee(
        TaikoData.TierFee[] memory tierFees,
        uint16 tierId
    )
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < tierFees.length; ++i) {
            if (tierFees[i].tier == tierId) return tierFees[i].fee;
        }
        revert HOOK_TIER_NOT_FOUND();
    }
}

/// @title ProxiedAssignmentHook
/// @notice Proxied version of the parent contract.
contract ProxiedAssignmentHook is Proxied, AssignmentHook { }
