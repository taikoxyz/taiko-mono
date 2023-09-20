// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IMintableERC20 } from "../../common/IMintableERC20.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibDepositing } from "./LibDepositing.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibTiers } from "./LibTiers.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
library LibProposing {
    using Address for address;
    using ECDSA for bytes32;
    using LibAddress for address;
    using LibAddress for address payable;
    using LibMath for uint256;

    bytes4 internal constant EIP1271_MAGICVALUE = 0x1626ba7e;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 assignmentBond,
        uint256 proverFee,
        uint256 reward,
        TaikoData.BlockMetadata meta
    );

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_ASSIGNMENT_EXPIRED();
    error L1_ASSIGNMENT_INVALID_SIGNATURE();
    error L1_ASSIGNMENT_INVALID_PARAMS();
    error L1_ASSIGNMENT_INSUFFICIENT_TX_VALUE();
    error L1_ASSIGNMENT_TIER_NOT_FUND();

    error L1_TOO_MANY_BLOCKS();
    error L1_TXLIST_INVALID_RANGE();
    error L1_TXLIST_MISMATCH();
    error L1_TXLIST_NOT_FOUND();
    error L1_TXLIST_TOO_LARGE();
    error L1_UNAUTHORIZED();

    /// @dev Proposes a Taiko L2 block.
    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        bytes32 txListHash,
        TaikoData.ProverAssignment memory assignment,
        bytes calldata txList
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        // Taiko, as a Rased Rollup, enables permissionless block proposals.  However,
        // if the "proposer" address is set to a non-zero value, we ensure that
        // only that specific address has the authority to propose blocks.
        address proposer = resolver.resolve("proposer", true);
        if (proposer != address(0) && msg.sender != proposer) {
            revert L1_UNAUTHORIZED();
        }

        if (txList.length > config.blockMaxTxListBytes) {
            revert L1_TXLIST_TOO_LARGE();
        }

        // It's necessary to verify that the txHash matches the provided hash.
        // However, when we employ a blob for the txList, the verification
        // process will differ.
        if (txListHash != keccak256(txList)) {
            revert L1_TXLIST_MISMATCH();
        }

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.
        TaikoData.SlotB memory b = state.slotB;
        if (b.numBlocks >= b.lastVerifiedBlockId + config.blockMaxProposals + 1)
        {
            revert L1_TOO_MANY_BLOCKS();
        }

        // In situations where the network lacks sufficient transactions for the
        // proposer to profit, they are still obligated to pay the prover the
        // proving fee, which can be a substantial cost compared to the total L2
        // transaction fees collected. As a solution, Taiko mints additional
        // Taiko tokens per second as block rewards. It's important to note that
        // if multiple blocks are proposed within the same L1 block, only the
        // first one will receive the block reward.

        TaikoToken tt = TaikoToken(resolver.resolve("taiko_token", false));

        // The block reward doesn't undergo automatic halving; instead, we
        // depend on Taiko DAO to make necessary adjustments to the rewards.
        uint256 reward;

        if (config.proposerRewardPerSecond > 0 && config.proposerRewardMax > 0)
        {
            // Unchecked is safe as block.timestamp is always greater than
            // block.proposedAt (proposed in the past)
            unchecked {
                uint256 blockTime = block.timestamp
                    - state.blocks[(b.numBlocks - 1) % config.blockRingBufferSize]
                        .proposedAt;

                if (blockTime > 0) {
                    reward = (config.proposerRewardPerSecond * blockTime).min(
                        config.proposerRewardMax
                    );

                    // Reward must be minted
                    tt.mint(msg.sender, reward);
                }
            }
        }

        // Initialize metadata to compute a metaHash, which forms a part of
        // the block data to be stored on-chain for future integrity checks.
        // If we choose to persist all data fields in the metadata, it will
        // require additional storage slots.
        meta.l1Hash = blockhash(meta.l1Height);

        // Following the Merge, the L1 mixHash incorporates the prevrandao
        // value from the beacon chain. Given the possibility of multiple
        // Taiko blocks being proposed within a single Ethereum block, we
        // must introduce a salt to this random number as the L2 mixHash.
        meta.mixHash = bytes32(block.prevrandao * b.numBlocks);

        meta.txListHash = txListHash;
        meta.timestamp = uint64(block.timestamp);
        meta.gasLimit = config.blockMaxGasLimit;
        unchecked {
            meta.l1Height = uint64(block.number - 1);
        }

        // Each transaction must handle a specific quantity of L1-to-L2
        // Ether deposits.
        meta.depositsProcessed =
            LibDepositing.processDeposits(state, config, msg.sender);

        // Now, it's essential to initialize the block that will be stored
        // on L1. We should aim to utilize as few storage slots as possible,
        // alghouth using a ring buffer can minimize storage writes once
        // the buffer reaches its capacity.
        TaikoData.Block storage blk =
            state.blocks[b.numBlocks % config.blockRingBufferSize];

        // Please note that all fields must be re-initialized since we are
        // utilizing an existing ring buffer slot, not creating a new storage
        // slot.
        blk.metaHash = _hashMetadata(meta);

        // Safeguard the assignment bond to ensure its preservation,
        // particularly in scenarios where it might be altered after the
        // block's proposal but before it has been proven or verified.
        blk.assignmentBond = config.assignmentBond;
        blk.blockId = b.numBlocks;
        blk.proposedAt = meta.timestamp;

        // For a new block, the next transition ID is always 1, not 0.
        blk.nextTransitionId = 1;

        // For unverified block, its verifiedTransitionId is always 0.
        blk.verifiedTransitionId = 0;

        // The LibTiers play a crucial role in determining the minimum tier
        // required for the block's validity proof. It's imperative to
        // maintain a certain percentage of blocks for each tier to ensure
        // that provers are consistently available when needed.
        blk.minTier = LibTiers.getMinTier(uint256(blk.metaHash));

        // Verify assignment authorization; if prover's address is an IProver
        // contract, transfer Ether and call "validateAssignment" for
        // verification.
        // Prover can charge ERC20/NFT as fees; msg.value can be zero. Taiko
        // doesn't mandate Ether as the only proofing fee.

        uint256 proverFee;
        (blk.assignedProver, proverFee) = _validateAssignment({
            proposer: msg.sender,
            minTier: blk.minTier,
            txListHash: txListHash,
            assignment: assignment
        });

        // The assigned prover burns Taiko tokens, referred to as the
        // "assignment bond." This bond remains non-refundable to the
        // assigned prover under two conditions: if the block's verification
        // transition is not the initial one or if it was generated and
        // validated by different provers. Instead, a portion of the assignment
        // bond serves as a reward for the actual prover.
        tt.burn(blk.assignedProver, config.assignmentBond);

        // Increment the counter (cursor) by 1.
        unchecked {
            ++state.slotB.numBlocks;
        }

        emit BlockProposed({
            blockId: blk.blockId,
            assignedProver: blk.assignedProver,
            assignmentBond: config.assignmentBond,
            proverFee: proverFee,
            reward: reward,
            meta: meta
        });
    }

    function _hashAssignment(
        bytes32 txListHash,
        TaikoData.ProverAssignment memory assignment
    )
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(txListHash, msg.value, assignment.expiry)
        );
    }

    /// @dev Hashing the block metadata.
    function _hashMetadata(TaikoData.BlockMetadata memory meta)
        private
        pure
        returns (bytes32 hash)
    {
        uint256[5] memory inputs;
        inputs[0] = uint256(meta.l1Hash);
        inputs[1] = uint256(meta.mixHash);
        inputs[2] = uint256(meta.txListHash);
        inputs[3] = (uint256(meta.timestamp) << 192)
            | (uint256(meta.l1Height) << 128) | (uint256(meta.gasLimit) << 96);
        inputs[4] = uint256(keccak256(abi.encode(meta.depositsProcessed)));

        assembly {
            hash := keccak256(inputs, mul(5, 32))
        }
    }

    function _validateAssignment(
        address proposer,
        uint16 minTier,
        bytes32 txListHash,
        TaikoData.ProverAssignment memory assignment
    )
        internal
        returns (address prover, uint256 fee)
    {
        // Checl txList not zero
        if (txListHash == 0 || proposer == address(0)) {
            revert L1_ASSIGNMENT_INVALID_PARAMS();
        }

        // Check assignment not expired
        if (block.timestamp >= assignment.expiry) {
            revert L1_ASSIGNMENT_EXPIRED();
        }

        // Recover the prover address
        prover = keccak256(
            abi.encode(
                "PROVER_ASSIGNMENT",
                txListHash,
                assignment.feeToken,
                assignment.expiry,
                assignment.tierFees
            )
        ).recover(assignment.signature);

        // The prover address cannot be zero
        if (prover == address(0)) revert L1_ASSIGNMENT_INVALID_SIGNATURE();

        // Find the fee for the min tier
        fee = _findFee(assignment.tierFees, minTier);

        if (assignment.feeToken == address(0)) {
            // feeToken is Ether
            if (msg.value < fee) revert L1_ASSIGNMENT_INSUFFICIENT_TX_VALUE();
            prover.sendEther(fee);
            unchecked {
                // Return the extra Ether to the proposer
                uint256 refund = msg.value - fee;
                if (refund != 0) proposer.sendEther(refund);
            }
        } else {
            // ERC20 token as fee. We send back Ether if msg.value is nonzero.
            if (msg.value != 0) proposer.sendEther(msg.value);
            ERC20(assignment.feeToken).transferFrom(proposer, prover, fee);
        }
    }

    function _findFee(
        TaikoData.TierFee[] memory tierFees,
        uint16 tierId
    )
        private
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < tierFees.length; ++i) {
            if (tierFees[i].tier == tierId) {
                return tierFees[i].fee;
            }
        }
        revert L1_ASSIGNMENT_TIER_NOT_FUND();
    }
}
