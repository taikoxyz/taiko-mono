// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibProposing {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    event BlockProposed(uint256 indexed id, TaikoData.BlockMetadata meta);

    error L1_ID();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_METADATA();
    error L1_NOT_SOLO_PROPOSER();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST();

    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockMetadataInput memory input,
        bytes calldata txList
    ) internal returns (bytes32 metaHash) {
        // For alpha-2 testnet, the network only allows an special address
        // to propose but anyone to prove. This is the first step of testing
        // the tokenomics.
        if (
            config.enableSoloProposer &&
            msg.sender != resolver.resolve("solo_proposer", false)
        ) revert L1_NOT_SOLO_PROPOSER();

        if (txList.length > config.maxBytesPerTxList) revert L1_TX_LIST();

        if (
            input.beneficiary == address(0) ||
            input.gasLimit > config.blockMaxGasLimit
        ) revert L1_INVALID_METADATA();

        // We need txListHash as with EIP-4844, txList is no longer
        // accssible to EVM.
        if (input.txListHash != keccak256(txList)) revert L1_TX_LIST_HASH();

        if (state.nextBlockId >= state.lastBlockId + config.maxNumBlocks)
            revert L1_TOO_MANY_BLOCKS();

        // After The Merge, L1 mixHash contains the prevrandao
        // from the beacon chain. Since multiple Taiko blocks
        // can be proposed in one Ethereum block, we need to
        // add salt to this random number as L2 mixHash

        uint256 mixHash;
        unchecked {
            mixHash = block.prevrandao * state.nextBlockId;
        }

        TaikoData.BlockMetadata memory meta = TaikoData.BlockMetadata({
            id: state.nextBlockId,
            l1Height: block.number - 1,
            l1Hash: blockhash(block.number - 1),
            beneficiary: input.beneficiary,
            txListHash: input.txListHash,
            mixHash: bytes32(mixHash),
            gasLimit: input.gasLimit,
            timestamp: uint64(block.timestamp)
        });

        uint256 deposit;
        if (config.enableTokenomics) {
            uint256 newFeeBase;
            {
                uint256 fee;
                (newFeeBase, fee, deposit) = LibTokenomics.getBlockFee(
                    state,
                    config
                );

                uint256 burnAmount = fee + deposit;
                if (state.balances[msg.sender] <= burnAmount)
                    revert L1_INSUFFICIENT_TOKEN();

                state.balances[msg.sender] -= burnAmount;
            }
            // Update feeBase and avgBlockTime
            state.feeBaseSzabo = LibTokenomics.toSzabo(
                LibUtils.movingAverage({
                    maValue: LibTokenomics.fromSzabo(state.feeBaseSzabo),
                    newValue: newFeeBase,
                    maf: config.feeBaseMAF
                })
            );
        }

        metaHash = keccak256(abi.encode(meta));
        state.proposedBlocks[
            state.nextBlockId % config.maxNumBlocks
        ] = TaikoData.ProposedBlock({
            metaHash: metaHash,
            deposit: deposit,
            proposer: msg.sender,
            proposedAt: meta.timestamp,
            nextForkChoiceId: 1
        });

        if (state.lastProposedAt > 0) {
            state.avgBlockTime = LibUtils
                .movingAverage({
                    maValue: state.avgBlockTime,
                    newValue: (meta.timestamp - state.lastProposedAt) * 1000,
                    maf: config.blockTimeMAF
                })
                .toUint64();
        }

        state.lastProposedAt = meta.timestamp;

        emit BlockProposed(state.nextBlockId, meta);
        unchecked {
            ++state.nextBlockId;
        }
    }

    function getProposedBlock(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id
    ) internal view returns (TaikoData.ProposedBlock storage) {
        if (id <= state.lastBlockId || id >= state.nextBlockId) {
            revert L1_ID();
        }

        return state.proposedBlocks[id % maxNumBlocks];
    }
}
