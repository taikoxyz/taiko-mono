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
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

library LibProposing {
    using Address for address;
    using ECDSA for bytes32;
    using LibAddress for address;
    using LibAddress for address payable;
    using LibMath for uint256;
    using LibUtils for TaikoData.State;

    bytes4 internal constant EIP1271_MAGICVALUE = 0x1626ba7e;

    event BlockProposed(
        uint256 indexed blockId,
        address indexed prover,
        uint256 reward,
        TaikoData.BlockMetadata meta
    );

    error L1_INVALID_ASSIGNMENT();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_METADATA();
    error L1_INVALID_PROPOSER();
    error L1_INVALID_PROVER();
    error L1_INVALID_PROVER_SIG();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();

    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockMetadataInput memory input,
        TaikoData.ProverAssignment memory assignment,
        bytes calldata txList
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        // Check proposer
        address proposer = resolver.resolve("proposer", true);
        if (proposer != address(0) && msg.sender != proposer) {
            revert L1_INVALID_PROPOSER();
        }

        // Check prover assignment
        if (
            assignment.prover == address(0)
                || assignment.prover == LibUtils.ORACLE_PROVER
                || assignment.expiry <= block.timestamp
        ) {
            revert L1_INVALID_ASSIGNMENT();
        }

        // Too many unverified blocks?
        TaikoData.SlotB memory b = state.slotB;
        if (b.numBlocks >= b.lastVerifiedBlockId + config.blockMaxProposals + 1)
        {
            revert L1_TOO_MANY_BLOCKS();
        }

        TaikoToken tt = TaikoToken(resolver.resolve("taiko_token", false));
        if (state.taikoTokenBalances[assignment.prover] >= config.proofBond) {
            // Safe, see the above constraint
            unchecked {
                state.taikoTokenBalances[assignment.prover] -= config.proofBond;
            }
        } else {
            tt.transferFrom(assignment.prover, address(this), config.proofBond);
        }

        // Pay prover after verifying assignment
        if (config.skipProverAssignmentVerificaiton) {
            // For testing only
            assignment.prover.sendEther(msg.value);
        } else if (!assignment.prover.isContract()) {
            if (
                _hashAssignment(input, assignment).recover(assignment.data)
                    != assignment.prover
            ) {
                revert L1_INVALID_PROVER_SIG();
            }
            assignment.prover.sendEther(msg.value);
        } else if (
            assignment.prover.supportsInterface(type(IProver).interfaceId)
        ) {
            IProver(assignment.prover).onBlockAssigned{ value: msg.value }(
                b.numBlocks, input, assignment
            );
        } else if (
            assignment.prover.supportsInterface(type(IERC1271).interfaceId)
        ) {
            if (
                IERC1271(assignment.prover).isValidSignature(
                    _hashAssignment(input, assignment), assignment.data
                ) != EIP1271_MAGICVALUE
            ) {
                revert L1_INVALID_PROVER_SIG();
            }
            assignment.prover.sendEther(msg.value);
        } else {
            revert L1_INVALID_PROVER();
        }

        // Reward the proposer
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
                    tt.mint(input.beneficiary, reward);
                }
            }
        }

        if (_validateBlock(state, config, input, txList)) {
            // returns true if we need to cache the txList info
            state.txListInfo[input.txListHash] = TaikoData.TxListInfo({
                validSince: uint64(block.timestamp),
                size: uint24(txList.length)
            });
        }

        // Init the metadata
        // Unchecked is safe:
        // - equation is done among same variable types
        // - incrementation (state.slotB.numBlocks++) is fine for 584K years if
        // we propose at every second
        unchecked {
            meta.id = b.numBlocks;
            meta.timestamp = uint64(block.timestamp);
            meta.l1Height = uint64(block.number - 1);
            meta.l1Hash = blockhash(block.number - 1);

            // After The Merge, L1 mixHash contains the prevrandao
            // from the beacon chain. Since multiple Taiko blocks
            // can be proposed in one Ethereum block, we need to
            // add salt to this random number as L2 mixHash
            meta.mixHash = bytes32(block.prevrandao * b.numBlocks);

            meta.txListHash = input.txListHash;
            meta.txListByteStart = input.txListByteStart;
            meta.txListByteEnd = input.txListByteEnd;
            meta.gasLimit = config.blockMaxGasLimit;
            meta.beneficiary = input.beneficiary;
            meta.depositsProcessed =
                LibDepositing.processDeposits(state, config, input.beneficiary);

            // Init the block
            TaikoData.Block storage blk =
                state.blocks[b.numBlocks % config.blockRingBufferSize];

            blk.metaHash = LibUtils.hashMetadata(meta);
            blk.prover = assignment.prover;
            blk.proofBond = config.proofBond;
            blk.blockId = meta.id;
            blk.proposedAt = meta.timestamp;
            blk.nextTransitionId = 1;
            blk.verifiedTransitionId = 0;
            blk.proofWindow = config.proofWindow;

            emit BlockProposed({
                blockId: state.slotB.numBlocks++,
                prover: blk.prover,
                reward: reward,
                meta: meta
            });
        }
    }

    function getBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId
    )
        internal
        view
        returns (TaikoData.Block storage blk)
    {
        blk = state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) {
            revert L1_INVALID_BLOCK_ID();
        }
    }

    function _validateBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.BlockMetadataInput memory input,
        bytes calldata txList
    )
        private
        view
        returns (bool cacheTxListInfo)
    {
        if (input.beneficiary == address(0)) revert L1_INVALID_METADATA();

        uint64 timeNow = uint64(block.timestamp);
        // handling txList
        {
            uint24 size = uint24(txList.length);
            if (size > config.blockMaxTxListBytes) revert L1_TX_LIST();

            if (input.txListByteStart > input.txListByteEnd) {
                revert L1_TX_LIST_RANGE();
            }

            if (config.blockTxListExpiry == 0) {
                // caching is disabled
                if (input.txListByteStart != 0 || input.txListByteEnd != size) {
                    revert L1_TX_LIST_RANGE();
                }
            } else {
                // caching is enabled
                if (size == 0) {
                    // This blob shall have been submitted earlier
                    TaikoData.TxListInfo memory info =
                        state.txListInfo[input.txListHash];

                    if (input.txListByteEnd > info.size) {
                        revert L1_TX_LIST_RANGE();
                    }

                    if (
                        info.size == 0
                            || info.validSince + config.blockTxListExpiry < timeNow
                    ) {
                        revert L1_TX_LIST_NOT_EXIST();
                    }
                } else {
                    if (input.txListByteEnd > size) revert L1_TX_LIST_RANGE();
                    if (input.txListHash != keccak256(txList)) {
                        revert L1_TX_LIST_HASH();
                    }

                    cacheTxListInfo = input.cacheTxListInfo;
                }
            }
        }
    }

    function _hashAssignment(
        TaikoData.BlockMetadataInput memory input,
        TaikoData.ProverAssignment memory assignment
    )
        private
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(input, msg.value, assignment.expiry));
    }
}
