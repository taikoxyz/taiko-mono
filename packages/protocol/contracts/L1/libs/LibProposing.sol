// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IMintableERC20 } from "../../common/IMintableERC20.sol";
import { IProver } from "../IProver.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibEthDepositing } from "./LibEthDepositing.sol";
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

    event BlockProposed(
        uint256 indexed blockId,
        address indexed prover,
        TaikoData.BlockMetadata meta
    );

    error L1_ASSIGNMENT_EXPIRED();
    error L1_BLOCK_ID();
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

        // Check prover
        if (assignment.prover == address(0) || assignment.prover == address(1))
        {
            revert L1_INVALID_PROVER();
        }

        if (assignment.expiry <= block.timestamp) {
            revert L1_ASSIGNMENT_EXPIRED();
        }

        // Verify prover authorization and pay the prover Ether as proving fee.
        // Note that this payment is permanent. If the prover failed to prove
        // the block, its bond is used to pay the actual prover.
        if (assignment.prover.isContract()) {
            IProver(assignment.prover).onBlockAssigned{ value: msg.value }(
                input, assignment
            );
        } else {
            bytes32 hash =
                keccak256(abi.encode(input, msg.value, assignment.expiry));
            if (assignment.prover != hash.recover(assignment.data)) {
                revert L1_INVALID_PROVER_SIG();
            }
            assignment.prover.sendEther(msg.value);
        }

        // Burn the prover's bond to this address
        TaikoToken(resolver.resolve("taiko_token", false)).burn(
            assignment.prover, config.proofBond
        );

        if (_validateBlock(state, config, input, txList)) {
            // returns true if we need to cache the txList info
            state.txListInfo[input.txListHash] = TaikoData.TxListInfo({
                validSince: uint64(block.timestamp),
                size: uint24(txList.length)
            });
        }

        // Init the metadata
        unchecked {
            meta.id = state.slotB.numBlocks;
            meta.timestamp = uint64(block.timestamp);
            meta.l1Height = uint64(block.number - 1);
            meta.l1Hash = blockhash(block.number - 1);

            // After The Merge, L1 mixHash contains the prevrandao
            // from the beacon chain. Since multiple Taiko blocks
            // can be proposed in one Ethereum block, we need to
            // add salt to this random number as L2 mixHash
            meta.mixHash = bytes32(block.prevrandao * state.slotB.numBlocks);

            meta.txListHash = input.txListHash;
            meta.txListByteStart = input.txListByteStart;
            meta.txListByteEnd = input.txListByteEnd;
            meta.gasLimit = config.blockMaxGasLimit;
            meta.beneficiary = input.beneficiary;
            meta.depositsProcessed = LibEthDepositing.processDeposits(
                state, config, input.beneficiary
            );

            // Init the block
            TaikoData.Block storage blk =
                state.blocks[state.slotB.numBlocks % config.blockRingBufferSize];
            blk.metaHash = LibUtils.hashMetadata(meta);
            blk.prover = assignment.prover;
            blk.proposedAt = meta.timestamp;
            blk.nextForkChoiceId = 1;
            blk.verifiedForkChoiceId = 0;

            emit BlockProposed({
                blockId: state.slotB.numBlocks++,
                prover: blk.prover,
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
        LibUtils.checkBlockId(state, blockId);
        blk = state.blocks[blockId % config.blockRingBufferSize];
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

        if (
            state.slotB.numBlocks
                >= state.slotB.lastVerifiedBlockId + config.blockMaxProposals + 1
        ) {
            revert L1_TOO_MANY_BLOCKS();
        }

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
}
