// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IMintableERC20 } from "../../common/IMintableERC20.sol";
import { IProver } from "../IProver.sol";
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
        uint256 reward,
        TaikoData.BlockMetadata meta
    );

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_INVALID_ASSIGNMENT();
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

        // Every proposed block in Taiko must include a non-zero prover referred
        // to as the "assigned prover." We enforce that the assigned prover must
        // indeed be non-zero, and the prover assignment has not expired.
        if (
            assignment.prover == address(0)
                || assignment.expiry <= block.timestamp
        ) {
            revert L1_INVALID_ASSIGNMENT();
        }

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.
        TaikoData.SlotB memory b = state.slotB;
        if (b.numBlocks >= b.lastVerifiedBlockId + config.blockMaxProposals + 1)
        {
            revert L1_TOO_MANY_BLOCKS();
        }

        // The assigned prover burns Taiko tokens, referred to as the
        // "assignment bond." This bond remains non-refundable to the assigned
        // prover under two conditions: if the block's verification transition
        // is not the initial one or if it was generated and validated by
        // different provers. Instead, a portion of the assignment bond serves
        // as a reward for the actual prover.
        TaikoToken tt = TaikoToken(resolver.resolve("taiko_token", false));
        tt.burn(assignment.prover, config.assignmentBond);

        // It is now essential to verify that the assignment has received proper
        // authorization.
        if (config.skipAssignmentVerificaiton) {
            // For testing only
            assignment.prover.sendEther(msg.value);
        } else if (!assignment.prover.isContract()) {
            // To verify an EOA (Externally Owned Account) prover, we perform a
            // straightforward check of an ECDSA signature.
            if (
                _hashAssignment(txListHash, assignment).recover(assignment.data)
                    != assignment.prover
            ) {
                revert L1_INVALID_ASSIGNMENT();
            }
            assignment.prover.sendEther(msg.value);
        } else if (
            assignment.prover.supportsInterface(type(IProver).interfaceId)
        ) {
            // When the prover's address corresponds to an IProver contract, we
            // transfer Ether and invoke its "onBlockAssigned" function for
            // verification. Within this function, the prover has the option to
            // charge other tokens like ERC20 or NFT as prooving fees, so the
            // value of msg.value can be zero. Taiko does not mandate Ether as
            // the exclusive proofing fees.
            IProver(assignment.prover).onBlockAssigned{ value: msg.value }(
                b.numBlocks, txListHash, assignment
            );
        } else if (
            assignment.prover.supportsInterface(type(IERC1271).interfaceId)
        ) {
            // If the prover is a contract implementing EIP1271, we invoke its
            // "isValidSignature" function for ECDSA signature verification.
            if (
                IERC1271(assignment.prover).isValidSignature(
                    _hashAssignment(txListHash, assignment), assignment.data
                ) != EIP1271_MAGICVALUE
            ) {
                revert L1_INVALID_ASSIGNMENT();
            }
            assignment.prover.sendEther(msg.value);
        } else {
            revert L1_INVALID_ASSIGNMENT();
        }

        // In situations where the network lacks sufficient transactions for the
        // proposer to profit, they are still obligated to pay the prover the
        // proving fee, which can be a substantial cost compared to the total L2
        // transaction fees collected. As a solution, Taiko mints additional
        // Taiko tokens per second as block rewards. It's important to note that
        // if multiple blocks are proposed within the same L1 block, only the
        // first one will receive the block reward.

        // The block reward doesn't undergo automatic halving; instead, we
        // depend on Taiko DAO to make necessary adjustments to the rewards.
        uint256 reward;
        if (config.proposerRewardPerSecond > 0 && config.proposerRewardMax > 0)
        {
            // Unchecked is safe:
            // - block.timestamp is always greater than block.proposedAt
            // (proposed in the past)
            // - 1x state.taikoTokenBalances[addr] uint256 could theoretically
            // store the whole token supply
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

        // Unchecked is safe:
        // - equation is done among same variable types
        // - incrementation (state.slotB.numBlocks++) is fine for 584K years if
        // we propose at every second
        unchecked {
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
            meta.l1Height = uint64(block.number - 1);
            meta.gasLimit = config.blockMaxGasLimit;

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
            // utilizing an existing ring buffer slot, not creating a new
            // storage slot.
            blk.metaHash = keccak256(abi.encode(meta));
            blk.assignedProver = assignment.prover;

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

            // Increment the counter (cursor) by 1.
            ++state.slotB.numBlocks;

            emit BlockProposed({
                blockId: blk.blockId,
                assignedProver: assignment.prover,
                assignmentBond: config.assignmentBond,
                reward: reward,
                meta: meta
            });
        }
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
}
