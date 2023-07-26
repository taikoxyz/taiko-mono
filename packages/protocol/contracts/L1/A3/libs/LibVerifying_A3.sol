// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../../common/AddressResolver.sol";
import {ISignalService} from "../../../signal/ISignalService.sol";
import {LibTokenomics_A3} from "./LibTokenomics_A3.sol";
import {LibUtils_A3} from "./LibUtils_A3.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../../TaikoData.sol";

library LibVerifying_A3 {
    using SafeCastUpgradeable for uint256;
    using LibUtils_A3 for TaikoData.State;

    event BlockVerified(uint256 indexed id, bytes32 blockHash, uint64 reward);

    event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot);

    error L1_INVALID_CONFIG();

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash,
        uint64 initBlockFee,
        uint64 initProofTimeTarget,
        uint64 initProofTimeIssued,
        uint16 adjustmentQuotient
    ) internal {
        if (
            config.chainId <= 1 || config.blockMaxProposals == 1
                || config.blockRingBufferSize <= config.blockMaxProposals + 1
                || config.blockMaxGasLimit == 0 || config.blockMaxTransactions == 0
                || config.blockMaxTxListBytes == 0
            // EIP-4844 blob size up to 128K
            || config.blockMaxTxListBytes > 128 * 1024 || config.ethDepositMaxCountPerBlock == 0
                || config.ethDepositMaxCountPerBlock < config.ethDepositMinCountPerBlock
            // EIP-4844 blob deleted after 30 days
            || config.blockTxListExpiry > 30 * 24 hours || config.ethDepositGas == 0
                || config.ethDepositMaxFee == 0 || config.ethDepositMaxFee >= type(uint96).max
                || adjustmentQuotient == 0 || initProofTimeTarget == 0 || initProofTimeIssued == 0
        ) revert L1_INVALID_CONFIG();

        uint64 timeNow = uint64(block.timestamp);
        state.slot6.genesisHeight = uint64(block.number);
        state.slot6.genesisTimestamp = timeNow;

        state.slot8.blockFee = initBlockFee;
        state.slot8.proofTimeIssued = initProofTimeIssued;
        state.slot8.proofTimeTarget = initProofTimeTarget;
        state.slot6.adjustmentQuotient = adjustmentQuotient;
        state.slot7.numBlocks = 1;

        TaikoData.Block_A3 storage blk = state.blocks_A3[0];
        blk.proposedAt = timeNow;
        blk.nextForkChoiceId = 2;
        blk.verifiedForkChoiceId = 1;

        TaikoData.ForkChoice storage fc = state.blocks_A3[0].forkChoices[1];
        fc.blockHash = genesisBlockHash;
        fc.provenAt = timeNow;

        emit BlockVerified(0, genesisBlockHash, 0);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 maxBlocks
    ) internal {
        uint256 i = state.slot8.lastVerifiedBlockId;
        TaikoData.Block_A3 storage blk = state.blocks_A3[i % config.blockRingBufferSize];

        uint256 fcId = blk.verifiedForkChoiceId;
        assert(fcId > 0);
        bytes32 blockHash = blk.forkChoices[fcId].blockHash;
        uint32 gasUsed = blk.forkChoices[fcId].gasUsed;
        bytes32 signalRoot;

        uint64 processed;
        unchecked {
            ++i;
        }

        address systemProver = resolver.resolve("system_prover", true);
        while (i < state.slot7.numBlocks && processed < maxBlocks) {
            blk = state.blocks_A3[i % config.blockRingBufferSize];
            assert(blk.blockId == i);

            fcId = LibUtils_A3.getForkChoiceId(state, blk, blockHash, gasUsed);

            if (fcId == 0) break;

            TaikoData.ForkChoice storage fc = blk.forkChoices[fcId];

            if (fc.prover == address(0)) break;

            uint256 proofCooldownPeriod = fc.prover == address(1)
                ? config.systemProofCooldownPeriod
                : config.proofCooldownPeriod;

            if (block.timestamp < fc.provenAt + proofCooldownPeriod) break;

            blockHash = fc.blockHash;
            gasUsed = fc.gasUsed;
            signalRoot = fc.signalRoot;

            _markBlockVerified({
                state: state,
                blk: blk,
                fcId: uint24(fcId),
                fc: fc,
                systemProver: systemProver
            });

            unchecked {
                ++i;
                ++processed;
            }
        }

        if (processed > 0) {
            if (config.relaySignalRoot) {
                // Send the L2's signal root to the signal service so other TaikoL1
                // deployments, if they share the same signal service, can relay the
                // signal to their corresponding TaikoL2 contract.
                ISignalService(resolver.resolve("signal_service", false)).sendSignal(signalRoot);
            }
            emit CrossChainSynced(state.slot8.lastVerifiedBlockId, blockHash, signalRoot);
        }
    }

    function _markBlockVerified(
        TaikoData.State storage state,
        TaikoData.Block_A3 storage blk,
        TaikoData.ForkChoice storage fc,
        uint24 fcId,
        address systemProver
    ) private {
        uint64 proofTime;
        unchecked {
            proofTime = uint64(fc.provenAt - blk.proposedAt);
        }

        uint64 reward = LibTokenomics_A3.getProofReward(state, proofTime);

        (state.slot8.proofTimeIssued, state.slot8.blockFee) =
            LibTokenomics_A3.getNewBlockFeeAndProofTimeIssued(state, proofTime);

        unchecked {
            state.slot7.accBlockFees -= reward;
            state.slot7.accProposedAt -= blk.proposedAt;
            ++state.slot8.lastVerifiedBlockId;
        }

        // reward the prover
        if (reward != 0) {
            address prover = fc.prover != address(1) ? fc.prover : systemProver;

            // systemProver may become address(0) after a block is proven
            if (prover != address(0)) {
                if (state.taikoTokenBalances[prover] == 0) {
                    // Reduce refund to 1 wei as a penalty if the proposer
                    // has 0 TKO outstanding balance.
                    state.taikoTokenBalances[prover] = 1;
                } else {
                    state.taikoTokenBalances[prover] += reward;
                }
            }
        }

        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = fcId;

        emit BlockVerified(blk.blockId, fc.blockHash, reward);
    }
}
