// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../libs/LibMath.sol";
import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Utils {
    using LibMath for uint256;

    uint64 public constant MASK_HALT = 1 << 0;

    event Halted(bool halted);

    function halt(LibData.State storage state, bool toHalt) internal {
        require(isHalted(state) != toHalt, "L1:precondition");
        setBit(state, MASK_HALT, toHalt);
        emit Halted(toHalt);
    }

    function isHalted(
        LibData.State storage state
    ) internal view returns (bool) {
        return isBitOne(state, MASK_HALT);
    }

    // Implement "Incentive Multipliers", see the whitepaper.
    function getTimeAdjustedFee(
        LibData.State storage state,
        bool isProposal,
        uint64 tNow,
        uint64 tLast,
        uint64 tAvg,
        uint64 tCap
    ) internal view returns (uint256) {
        if (tAvg == 0) {
            return state.feeBase;
        }
        uint256 _tAvg = tAvg > tCap ? tCap : tAvg;
        uint256 tGrace = (LibConstants.K_FEE_GRACE_PERIOD * _tAvg) / 100;
        uint256 tMax = (LibConstants.K_FEE_MAX_PERIOD * _tAvg) / 100;
        uint256 a = tLast + tGrace;
        uint256 b = tNow > a ? tNow - a : 0;
        uint256 tRel = (b.min(tMax) * 10000) / tMax; // [0 - 10000]
        uint256 alpha = 10000 +
            ((LibConstants.K_REWARD_MULTIPLIER - 100) * tRel) /
            100;
        if (isProposal) {
            return (state.feeBase * 10000) / alpha; // fee
        } else {
            return (state.feeBase * alpha) / 10000; // reward
        }
    }

    // Implement "Slot-availability Multipliers", see the whitepaper.
    function getSlotsAdjustedFee(
        LibData.State storage state,
        bool isProposal,
        uint256 fee
    ) internal view returns (uint256) {
        // m is the `n'` in the whitepaper
        uint256 m = LibConstants.K_MAX_NUM_BLOCKS -
            1 +
            LibConstants.K_FEE_PREMIUM_LAMDA;
        // n is the number of unverified blocks
        uint256 n = state.nextBlockId - state.latestVerifiedId - 1;
        // k is `m − n + 1` or `m − n - 1`in the whitepaper
        uint256 k = isProposal ? m - n - 1 : m - n + 1;
        return (fee * (m - 1) * m) / (m - n) / k;
    }

    // Implement "Bootstrap Discount Multipliers", see the whitepaper.
    function getBootstrapDiscountedFee(
        LibData.State storage state,
        uint256 fee
    ) internal view returns (uint256) {
        uint256 halves = uint256(block.timestamp - state.genesisTimestamp) /
            LibConstants.K_HALVING;
        uint256 gamma = 1024 - (1024 >> halves);
        return (fee * gamma) / 1024;
    }

    // Returns a deterministic deadline for uncle proof submission.
    function uncleProofDeadline(
        LibData.State storage state,
        LibData.ForkChoice storage fc
    ) internal view returns (uint64) {
        return fc.provenAt + state.avgProofTime;
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

    function setBit(
        LibData.State storage state,
        uint64 mask,
        bool one
    ) private {
        state.statusBits = one
            ? state.statusBits | mask
            : state.statusBits & ~mask;
    }

    function isBitOne(
        LibData.State storage state,
        uint64 mask
    ) private view returns (bool) {
        return state.statusBits & mask != 0;
    }
}
