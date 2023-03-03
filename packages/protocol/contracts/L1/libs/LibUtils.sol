// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibMath} from "../../libs/LibMath.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {Snippet} from "../../common/IXchainSync.sol";
import {TaikoData} from "../TaikoData.sol";

library LibUtils {
    using LibMath for uint256;

    bytes32 public constant BLOCK_DEADEND_HASH = bytes32(uint256(1));

    error L1_BLOCK_NUMBER();

    struct StateVariables {
        uint256 feeBase;
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 nextBlockId;
        uint64 lastProposedAt;
        uint64 avgBlockTime;
        uint64 latestVerifiedHeight;
        uint64 latestVerifiedId;
        uint64 avgProofTime;
    }

    function getProposedBlock(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id
    ) internal view returns (TaikoData.ProposedBlock storage) {
        return state.proposedBlocks[id % maxNumBlocks];
    }

    function getL2Snippet(
        TaikoData.State storage state,
        uint256 number,
        uint256 blockHashHistory
    ) internal view returns (Snippet memory) {
        uint256 _number = number;
        if (_number == 0) {
            _number = state.latestVerifiedHeight;
        } else if (
            _number + blockHashHistory <= state.latestVerifiedHeight ||
            _number > state.latestVerifiedHeight
        ) revert L1_BLOCK_NUMBER();

        return state.l2Snippets[_number % blockHashHistory];
    }

    function getStateVariables(
        TaikoData.State storage state
    ) internal view returns (StateVariables memory) {
        return
            StateVariables({
                feeBase: state.feeBase,
                genesisHeight: state.genesisHeight,
                genesisTimestamp: state.genesisTimestamp,
                nextBlockId: state.nextBlockId,
                lastProposedAt: state.lastProposedAt,
                avgBlockTime: state.avgBlockTime,
                latestVerifiedHeight: state.latestVerifiedHeight,
                latestVerifiedId: state.latestVerifiedId,
                avgProofTime: state.avgProofTime
            });
    }

    // Implement "Incentive Multipliers", see the whitepaper.
    function getTimeAdjustedFee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bool isProposal,
        uint64 tNow,
        uint64 tLast,
        uint64 tAvg
    ) internal view returns (uint256 newFeeBase, uint256 tRelBp) {
        if (tAvg == 0) {
            newFeeBase = state.feeBase;
            // tRelBp = 0;
        } else {
            uint256 _tAvg = tAvg > config.proofTimeCap
                ? config.proofTimeCap
                : tAvg;
            uint256 tGrace = (config.feeGracePeriodPctg * _tAvg) / 100;
            uint256 tMax = (config.feeMaxPeriodPctg * _tAvg) / 100;
            uint256 a = tLast + tGrace;
            uint256 b = tNow > a ? tNow - a : 0;
            tRelBp = (b.min(tMax) * 10000) / tMax; // [0 - 10000]
            uint256 alpha = 10000 +
                ((config.rewardMultiplierPctg - 100) * tRelBp) /
                100;
            if (isProposal) {
                newFeeBase = (state.feeBase * 10000) / alpha; // fee
            } else {
                newFeeBase = (state.feeBase * alpha) / 10000; // reward
            }
        }
    }

    // Implement "Slot-availability Multipliers", see the whitepaper.
    function getSlotsAdjustedFee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bool isProposal,
        uint256 feeBase
    ) internal view returns (uint256) {
        // m is the `n'` in the whitepaper
        uint256 m = 1000 *
            (config.maxNumBlocks - 1) +
            config.slotSmoothingFactor;
        // n is the number of unverified blocks
        uint256 n = 1000 * (state.nextBlockId - state.latestVerifiedId - 1);
        // k is `m − n + 1` or `m − n - 1`in the whitepaper
        uint256 k = isProposal ? m - n - 1000 : m - n + 1000;
        return (feeBase * (m - 1000) * m) / (m - n) / k;
    }

    // Implement "Bootstrap Discount Multipliers", see the whitepaper.
    function getBootstrapDiscountedFee(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 feeBase
    ) internal view returns (uint256) {
        uint256 halves = uint256(block.timestamp - state.genesisTimestamp) /
            config.bootstrapDiscountHalvingPeriod;
        uint256 gamma = 1024 - (1024 >> halves);
        return (feeBase * gamma) / 1024;
    }

    function hashMetadata(
        TaikoData.BlockMetadata memory meta
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(meta));
    }

    function hashTxList(bytes memory txList) internal pure returns (bytes32) {
        return keccak256(txList);
    }

    function hashZKProof(
        bytes memory zkProofAbiEncoded
    ) internal pure returns (bytes32) {
        return keccak256(zkProofAbiEncoded);
    }

    function movingAverage(
        uint256 maValue,
        uint256 newValue,
        uint256 maf
    ) internal pure returns (uint256) {
        if (maValue == 0) {
            return newValue;
        }
        uint256 _ma = (maValue * (maf - 1) + newValue) / maf;
        return _ma > 0 ? _ma : maValue;
    }
}
