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
        bytes32 genesisBlockHash,
        uint64 initBasefee,
        uint64 initProofTimeIssued

    ) internal {
        _checkConfig(config);

        uint64 timeNow = uint64(block.timestamp);
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = timeNow;

        state.basefee = initBasefee;
        state.proofTimeIssued = initProofTimeIssued;
        state.numBlocks = 1;

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
            if (fc.prover == address(0)) break;

            _markBlockVerified({
                state: state,
                config: config,
                blk: blk,
                fcId: uint24(fcId),
                fc: fc
            });

            blockHash = fc.blockHash;
            gasUsed = fc.gasUsed;
            signalRoot = fc.signalRoot;

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
    ) private returns (bytes32 blockHash, bytes32 signalRoot) {
        if (config.proofTimeTarget != 0) {
            uint256 proofTime;
            unchecked {
                proofTime = (fc.provenAt - blk.proposedAt);
            }

            (
                uint64 reward,
                uint64 proofTimeIssued,
                uint64 newBasefee
            ) = LibTokenomics.calculateBasefee(
                    state,
                    config,
                    uint64(proofTime)
                );

            state.basefee = newBasefee;
            state.proofTimeIssued = proofTimeIssued;

            unchecked {
                state.rewardPool -= reward;
                state.accProposedAt -= blk.proposedAt;
            }

            // reward the prover
            _addToBalance(state, fc.prover, reward);
        }

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
            // EIP-4844 blob deleted after 30 days
            config.txListCacheExpiry > 30 * 24 hours
        ) revert L1_INVALID_CONFIG();
    }
}
