// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {LibTxDecoder} from "../../libs/LibTxDecoder.sol";
import {TaikoToken} from "../TaikoToken.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../TaikoData.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";

library LibProposing {
    using LibTxDecoder for bytes;
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.BlockMetadata;
    using LibUtils for TaikoData.State;

    event BlockCommitted(uint64 commitSlot, bytes32 commitHash);
    event BlockProposed(uint256 indexed id, TaikoData.BlockMetadata meta);

    error L1_COMMITTED();
    error L1_EXTRA_DATA();
    error L1_GAS_LIMIT();
    error L1_ID();
    error L1_INPUT_SIZE();
    error L1_METADATA_FIELD();
    error L1_NOT_COMMITTED();
    error L1_SOLO_PROPOSER();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST();

    function commitBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 commitSlot,
        bytes32 commitHash
    ) public {
        assert(config.commitConfirmations > 0);

        bytes32 hash = _aggregateCommitHash(block.number, commitHash);

        if (state.commits[msg.sender][commitSlot] == hash)
            revert L1_COMMITTED();

        state.commits[msg.sender][commitSlot] = hash;

        emit BlockCommitted({commitSlot: commitSlot, commitHash: commitHash});
    }

    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        bytes[] calldata inputs
    ) public {
        // For alpha-2 testnet, the network only allows an special address
        // to propose but anyone to prove. This is the first step of testing
        // the tokenomics.

        // TODO(daniel): remove this special address.
        address soloProposer = resolver.resolve("solo_proposer", true);
        if (soloProposer != address(0) && soloProposer != msg.sender)
            revert L1_SOLO_PROPOSER();

        if (inputs.length != 2) revert L1_INPUT_SIZE();
        TaikoData.BlockMetadata memory meta = abi.decode(
            inputs[0],
            (TaikoData.BlockMetadata)
        );
        _verifyBlockCommit({
            state: state,
            commitConfirmations: config.commitConfirmations,
            meta: meta
        });
        _validateMetadata(config, meta);

        {
            bytes calldata txList = inputs[1];
            // perform validation and populate some fields
            if (
                txList.length < 0 ||
                txList.length > config.maxBytesPerTxList ||
                meta.txListHash != txList.hashTxList()
            ) revert L1_TX_LIST();

            if (
                state.nextBlockId >=
                state.latestVerifiedId + config.maxNumBlocks
            ) revert L1_TOO_MANY_BLOCKS();

            meta.id = state.nextBlockId;
            meta.l1Height = block.number - 1;
            meta.l1Hash = blockhash(block.number - 1);
            meta.timestamp = uint64(block.timestamp);

            // After The Merge, L1 mixHash contains the prevrandao
            // from the beacon chain. Since multiple Taiko blocks
            // can be proposed in one Ethereum block, we need to
            // add salt to this random number as L2 mixHash
            meta.mixHash = keccak256(
                abi.encodePacked(block.prevrandao, state.nextBlockId)
            );
        }

        uint256 deposit;
        if (config.enableTokenomics) {
            uint256 newFeeBase;
            {
                uint256 fee;
                (newFeeBase, fee, deposit) = getBlockFee(state, config);
                TaikoToken(resolver.resolve("tko_token", false)).burn(
                    msg.sender,
                    fee + deposit
                );
            }
            // Update feeBase and avgBlockTime
            state.feeBase = LibUtils.movingAverage({
                maValue: state.feeBase,
                newValue: newFeeBase,
                maf: config.feeBaseMAF
            });
        }

        _saveProposedBlock(
            state,
            config.maxNumBlocks,
            state.nextBlockId,
            TaikoData.ProposedBlock({
                metaHash: meta.hashMetadata(),
                deposit: deposit,
                proposer: msg.sender,
                proposedAt: meta.timestamp
            })
        );

        state.avgBlockTime = LibUtils
            .movingAverage({
                maValue: state.avgBlockTime,
                newValue: meta.timestamp - state.lastProposedAt,
                maf: config.blockTimeMAF
            })
            .toUint64();

        state.lastProposedAt = meta.timestamp;

        emit BlockProposed(state.nextBlockId++, meta);
    }

    function getBlockFee(
        TaikoData.State storage state,
        TaikoData.Config memory config
    ) public view returns (uint256 newFeeBase, uint256 fee, uint256 deposit) {
        (newFeeBase, ) = LibUtils.getTimeAdjustedFee({
            state: state,
            config: config,
            isProposal: true,
            tNow: uint64(block.timestamp),
            tLast: state.lastProposedAt,
            tAvg: state.avgBlockTime,
            tCap: config.blockTimeCap
        });
        fee = LibUtils.getSlotsAdjustedFee({
            state: state,
            config: config,
            isProposal: true,
            feeBase: newFeeBase
        });
        fee = LibUtils.getBootstrapDiscountedFee(state, config, fee);
        deposit = (fee * config.proposerDepositPctg) / 100;
    }

    function isCommitValid(
        TaikoData.State storage state,
        uint256 commitConfirmations,
        uint256 commitSlot,
        uint256 commitHeight,
        bytes32 commitHash
    ) public view returns (bool) {
        assert(commitConfirmations > 0);
        bytes32 hash = _aggregateCommitHash(commitHeight, commitHash);
        return
            state.commits[msg.sender][commitSlot] == hash &&
            block.number >= commitHeight + commitConfirmations;
    }

    function getProposedBlock(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id
    ) internal view returns (TaikoData.ProposedBlock storage) {
        if (id <= state.latestVerifiedId || id >= state.nextBlockId) {
            revert L1_ID();
        }
        return state.getProposedBlock(maxNumBlocks, id);
    }

    function _saveProposedBlock(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id,
        TaikoData.ProposedBlock memory blk
    ) private {
        state.proposedBlocks[id % maxNumBlocks] = blk;
    }

    function _verifyBlockCommit(
        TaikoData.State storage state,
        uint256 commitConfirmations,
        TaikoData.BlockMetadata memory meta
    ) private view {
        if (commitConfirmations == 0) {
            return;
        }
        bytes32 commitHash = _calculateCommitHash(
            meta.beneficiary,
            meta.txListHash
        );

        if (
            !isCommitValid({
                state: state,
                commitConfirmations: commitConfirmations,
                commitSlot: meta.commitSlot,
                commitHeight: meta.commitHeight,
                commitHash: commitHash
            })
        ) revert L1_NOT_COMMITTED();
    }

    function _validateMetadata(
        TaikoData.Config memory config,
        TaikoData.BlockMetadata memory meta
    ) private pure {
        if (
            meta.id != 0 ||
            meta.l1Height != 0 ||
            meta.l1Hash != 0 ||
            meta.mixHash != 0 ||
            meta.timestamp != 0 ||
            meta.beneficiary == address(0) ||
            meta.txListHash == 0
        ) revert L1_METADATA_FIELD();

        if (meta.gasLimit > config.blockMaxGasLimit) revert L1_GAS_LIMIT();
        if (meta.extraData.length > 32) {
            revert L1_EXTRA_DATA();
        }
    }

    function _calculateCommitHash(
        address beneficiary,
        bytes32 txListHash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(beneficiary, txListHash));
    }

    function _aggregateCommitHash(
        uint256 commitHeight,
        bytes32 commitHash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(commitHash, commitHeight));
    }
}
