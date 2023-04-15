// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {ISignalService} from "../../signal/ISignalService.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    error L1_INVALID_CONFIG();
    error L1_INVALID_L21559_PARAMS();

    event BlockVerified(uint256 indexed id, bytes32 blockHash);
    event XchainSynced(
        uint256 indexed srcHeight,
        bytes32 blockHash,
        bytes32 signalRoot
    );

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint64 feeBase,
        bytes32 genesisBlockHash
    ) internal {
        _checkConfig(config);

        uint64 timeNow = uint64(block.timestamp);
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = timeNow;
        state.feeBase = feeBase;
        state.numBlocks = 1;
        // Set state.staticRefs
        {
            address l1SignalService = resolver.resolve("signal_service", false);
            address l2SignalService = resolver.resolve(
                config.chainId,
                "signal_service",
                false
            );
            address taikoL2 = resolver.resolve(
                config.chainId,
                "taiko_l2",
                false
            );

            uint256[3] memory inputs;
            inputs[0] = uint160(l1SignalService);
            inputs[1] = uint160(l2SignalService);
            inputs[2] = uint160(taikoL2);
            bytes32 staticRefs;
            assembly {
                staticRefs := keccak256(inputs, mul(32, 3))
            }
            state.staticRefs = staticRefs;
        }

        TaikoData.Block storage blk = state.blocks[0];
        blk.proposedAt = timeNow;
        blk.nextForkChoiceId = 2;
        blk.verifiedForkChoiceId = 1;

        TaikoData.ForkChoice storage fc = state.blocks[0].forkChoices[1];
        fc.blockHash = genesisBlockHash;
        fc.provenAt = timeNow;

        emit BlockVerified(0, genesisBlockHash);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 maxBlocks
    ) internal {
        uint256 i = state.lastVerifiedBlockId;
        TaikoData.Block storage blk = state.blocks[i % config.ringBufferSize];

        uint256 fcId = blk.verifiedForkChoiceId;
        assert(fcId > 0);

        bytes32 blockHash = blk.forkChoices[fcId].blockHash;
        uint32 gasUsed = blk.forkChoices[fcId].gasUsed;
        bytes32 signalRoot;

        uint64 processed;
        unchecked {
            ++i;
        }

        while (i < state.numBlocks && processed < maxBlocks) {
            blk = state.blocks[i % config.ringBufferSize];
            assert(blk.blockId == i);

            fcId = LibUtils.getForkChoiceId(state, blk, blockHash, gasUsed);

            if (fcId == 0) break;

            TaikoData.ForkChoice storage fc = blk.forkChoices[fcId];

            if (
                fc.prover == address(0) || // oracle proof
                block.timestamp < fc.provenAt + config.proofCooldownPeriod // too young
            ) break;

            blockHash = fc.blockHash;
            gasUsed = fc.gasUsed;
            signalRoot = fc.signalRoot;

            _markBlockVerified({
                state: state,
                config: config,
                blk: blk,
                fcId: uint24(fcId),
                fc: fc
            });

            unchecked {
                ++i;
                ++processed;
            }
        }

        if (processed > 0) {
            unchecked {
                state.lastVerifiedBlockId += processed;
            }

            if (config.relaySignalRoot) {
                // Send the L2's signal root to the signal service so other TaikoL1
                // deployments, if they share the same signal service, can relay the
                // signal to their corresponding TaikoL2 contract.
                ISignalService(resolver.resolve("signal_service", false))
                    .sendSignal(signalRoot);
            }
            emit XchainSynced(state.lastVerifiedBlockId, blockHash, signalRoot);
        }
    }

    function _markBlockVerified(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.Block storage blk,
        TaikoData.ForkChoice storage fc,
        uint24 fcId
    ) private {
        if (config.enableTokenomics) {
            (
                uint256 newFeeBase,
                uint256 amount,
                uint256 premiumRate
            ) = LibTokenomics.getProofReward({
                    state: state,
                    config: config,
                    provenAt: fc.provenAt,
                    proposedAt: blk.proposedAt
                });

            // reward the prover
            _addToBalance(state, fc.prover, amount);

            unchecked {
                // premiumRate in [0-10000]
                amount = (blk.deposit * (10000 - premiumRate)) / 10000;
            }
            _addToBalance(state, blk.proposer, amount);

            // Update feeBase and avgProofTime
            state.feeBase = LibUtils
                .movingAverage({
                    maValue: state.feeBase,
                    newValue: newFeeBase,
                    maf: config.feeBaseMAF
                })
                .toUint64();
        }

        uint256 proofTime;
        unchecked {
            proofTime = (fc.provenAt - blk.proposedAt) * 1000;
        }
        state.avgProofTime = LibUtils
            .movingAverage({
                maValue: state.avgProofTime,
                newValue: proofTime,
                maf: config.provingConfig.avgTimeMAF
            })
            .toUint64();

        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = fcId;

        emit BlockVerified(blk.blockId, fc.blockHash);
    }

    function _addToBalance(
        TaikoData.State storage state,
        address account,
        uint256 amount
    ) private {
        if (amount == 0) return;
        if (state.balances[account] == 0) {
            // Reduce refund to 1 wei as a penalty if the proposer
            // has 0 TKO outstanding balance.
            state.balances[account] = 1;
        } else {
            state.balances[account] += amount;
        }
    }

    function _checkConfig(TaikoData.Config memory config) private pure {
        if (
            config.chainId <= 1 ||
            config.maxNumProposedBlocks == 1 ||
            config.ringBufferSize <= config.maxNumProposedBlocks + 1 ||
            config.maxNumVerifiedBlocks == 0 ||
            config.blockMaxGasLimit == 0 ||
            config.maxTransactionsPerBlock == 0 ||
            config.maxBytesPerTxList == 0 ||
            // EIP-4844 blob size up to 128K
            config.maxBytesPerTxList > 128 * 1024 ||
            config.minTxGasLimit == 0 ||
            config.slotSmoothingFactor == 0 ||
            // EIP-4844 blob deleted after 30 days
            config.txListCacheExpiry > 30 * 24 hours ||
            config.rewardBurnBips >= 10000
        ) revert L1_INVALID_CONFIG();

        _checkFeeConfig(config.proposingConfig);
        _checkFeeConfig(config.provingConfig);
    }

    function _checkFeeConfig(
        TaikoData.FeeConfig memory feeConfig
    ) private pure {
        if (feeConfig.avgTimeMAF <= 1 || feeConfig.dampingFactorBips > 10000)
            revert L1_INVALID_CONFIG();
    }
}
