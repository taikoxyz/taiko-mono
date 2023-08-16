// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IMintableERC20 } from "../../common/IMintableERC20.sol";
import { IProver } from "../IProver.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibEthDepositing } from "./LibEthDepositing.sol";
import { LibL2Consts } from "../../L2/LibL2Consts.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

library LibProposing {
    using Address for address;
    using LibAddress for address;
    using LibAddress for address payable;
    using LibMath for uint256;
    using LibUtils for TaikoData.State;

    event BlockProposed(
        uint256 indexed blockId,
        address indexed prover,
        uint32 feePerGas,
        TaikoData.BlockMetadata meta
    );

    error L1_BLOCK_ID();
    error L1_FEE_PER_GAS_TOO_SMALL();
    error L1_FEE_PER_GAS_TOO_LARGE();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_METADATA();
    error L1_INVALID_PROVER();
    error L1_PERMISSION_DENIED();
    error L1_TOO_MANY_BLOCKS();
    error L1_TOO_MANY_OPEN_BLOCKS();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();

    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockMetadataInput memory input,
        bytes calldata txList
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        // If permissioned proposer is enabled, we check only this proposer can
        // propose blocks.
        {
            address proposer = resolver.resolve("proposer", true);
            if (proposer != address(0) && msg.sender != proposer) {
                revert L1_PERMISSION_DENIED();
            }
        }

        // Validate block input then cache txList info if requested
        {
            bool cacheTxListInfo = _validateBlock({
                state: state,
                config: config,
                input: input,
                txList: txList
            });

            if (cacheTxListInfo) {
                unchecked {
                    state.txListInfo[input.txListHash] = TaikoData.TxListInfo({
                        validSince: uint64(block.timestamp),
                        size: uint24(txList.length)
                    });
                }
            }
        }

        // Init the metadata
        meta.id = state.slotB.numBlocks;

        unchecked {
            meta.timestamp = uint64(block.timestamp);
            meta.l1Height = uint64(block.number - 1);
            meta.l1Hash = blockhash(block.number - 1);

            // After The Merge, L1 mixHash contains the prevrandao
            // from the beacon chain. Since multiple Taiko blocks
            // can be proposed in one Ethereum block, we need to
            // add salt to this random number as L2 mixHash
            meta.mixHash = bytes32(block.prevrandao * state.slotB.numBlocks);
        }

        meta.txListHash = input.txListHash;
        meta.txListByteStart = input.txListByteStart;
        meta.txListByteEnd = input.txListByteEnd;
        meta.gasLimit = config.blockMaxGasLimit;
        meta.beneficiary = input.beneficiary;
        meta.treasury = resolver.resolve(config.chainId, "treasury", false);
        meta.depositsProcessed =
            LibEthDepositing.processDeposits(state, config, input.beneficiary);

        // Init the block
        TaikoData.Block storage blk =
            state.blocks[state.slotB.numBlocks % config.blockRingBufferSize];

        blk.metaHash = LibUtils.hashMetadata(meta);
        blk.blockId = meta.id;
        blk.gasLimit = meta.gasLimit;
        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = 0;
        blk.proposer = msg.sender;
        blk.proposedAt = meta.timestamp;

        unchecked {
            blk.proofWindow = uint16(
                (
                    uint256(state.slotC.avgProofDelay)
                        * config.proofWindowMultiplier / 100
                ).min(config.proofMaxWindow).max(config.proofMinWindow)
            );
        }

        // Assign a prover and get the actual feePerGas. Not that the return
        // prover may be address(0) to indicate this block is open.
        (blk.prover, blk.feePerGas, blk.bond) = _assignProver({
            state: state,
            config: config,
            proofWindow: blk.proofWindow,
            gasLimit: meta.gasLimit,
            blockId: blk.blockId,
            prover: input.prover,
            maxFeePerGas: input.maxFeePerGas,
            assignmentParams: input.assignmentParams
        });

        TaikoToken tt = TaikoToken(resolver.resolve("taiko_token", false));

        if (blk.prover == address(0)) {
            // This is an open block
            if (state.slotB.numOpenBlocks >= config.rewardOpenMaxCount) {
                revert L1_TOO_MANY_OPEN_BLOCKS();
            }
            assert(blk.bond == 0);
            blk.proofWindow = 0;
            unchecked {
                ++state.slotB.numOpenBlocks;
            }
        } else {
            // Burn the bond, if this assigned prover fails to prove the block,
            // additonal tokens will be minted to the actual prover.
            tt.burn(blk.prover, blk.bond);
        }

        // Proposer burns a deposit to cover proving fees, the remaining fee
        // will be refunded when the block is verified.
        // Note that proposer does not deposit more to cover the extra payment
        // to the prover that proves this block after it becomes open.
        {
            uint64 blockDeposit =
                _calcBlockFee(config, meta.gasLimit, blk.feePerGas);
            tt.burn(msg.sender, blockDeposit);
        }

        // Emit an event
        unchecked {
            emit BlockProposed({
                blockId: state.slotB.numBlocks++,
                prover: blk.prover,
                feePerGas: blk.feePerGas,
                meta: meta
            });
        }
    }

    function getBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockId
    )
        internal
        view
        returns (TaikoData.Block storage blk)
    {
        blk = state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();
    }

    function _assignProver(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint16 proofWindow,
        uint32 gasLimit,
        uint64 blockId,
        address prover,
        uint32 maxFeePerGas,
        bytes memory assignmentParams
    )
        private
        returns (address _prover, uint32 _feePerGas, uint64 _bond)
    {
        if (prover != address(0) && prover.isContract()) {
            // This isan IProver contract
            (_prover, _feePerGas) = IProver(prover).onBlockAssigned({
                proposer: msg.sender,
                blockId: blockId,
                maxFeePerGas: maxFeePerGas,
                proofWindow: proofWindow,
                params: assignmentParams
            });
        } else {
            // Prover is address(0) or an EOA address
            _feePerGas = maxFeePerGas;
        }

        if (_prover == address(1)) {
            // Do not allow address(1) as it is our oracle prover
            revert L1_INVALID_PROVER();
        }

        if (_prover == address(0)) {
            // For an open block, we make sure more the proposer pays more
            uint256 minFeePerGas = uint256(state.slotC.avgFeePerGas)
                * config.rewardOpenMultipler / 100;

            _feePerGas =
                uint32(minFeePerGas.max(maxFeePerGas).min(type(uint32).max));
        } else {
            // Not an open block
            if (_feePerGas > maxFeePerGas) revert L1_FEE_PER_GAS_TOO_LARGE();

            // We calculate how much bond the prover shall burn.
            // To cover open block reward, we have to use the max of _feePerGas
            // and state.slotC.avgFeePerGas in the calculation in case
            // _feePerGas is really small or zero.
            uint32 bondFeePerGas = _feePerGas > state.slotC.avgFeePerGas
                ? _feePerGas
                : state.slotC.avgFeePerGas;

            _bond = _calcBlockFee(config, gasLimit, bondFeePerGas)
                * config.proofBondMultiplier;
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

        if (
            state.slotB.numBlocks
                >= state.slotC.lastVerifiedBlockId + config.blockMaxProposals + 1
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

    function _calcBlockFee(
        TaikoData.Config memory config,
        uint32 gasAmount,
        uint32 feePerGas
    )
        private
        pure
        returns (uint64)
    {
        uint32 _gas =
            gasAmount + LibL2Consts.ANCHOR_GAS_COST + config.blockFeeBaseGas;
        unchecked {
            return uint64(_gas) * feePerGas;
        }
    }
}
