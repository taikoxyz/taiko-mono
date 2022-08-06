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

// import "../../libs/LibMath.sol";
import "./AbstractProtoBroker.sol";

abstract contract StatsBasedProtoBroker is AbstractProtoBroker {
    using SafeCastUpgradeable for uint256;
    // using LibMath for uint256;

    uint256 public constant STAT_AVERAGING_FACTOR = 2048;
    uint64 public constant NANO_PER_SECOND = 1E9;

    uint64 public avgPendingSize;
    uint64 public avgProvingDelay;
    uint64 public avgProvingDelayWithUncles;
    uint64 public avgFinalizationDelay;

    uint256[49] private __gap;

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _gasPriceNow,
        uint256 _unsettledProverFeeThreshold
    ) internal virtual override {
        AbstractProtoBroker._init(
            _addressManager,
            _gasPriceNow,
            _unsettledProverFeeThreshold
        );
    }

    function postChargeProposer(
        uint256, /*blockId*/
        uint256 numPendingBlocks,
        uint256, /*numUnprovenBlocks*/
        address, /*proposer*/
        uint128 /*gasLimit*/
    ) internal virtual override {
        // Update stats first.
        avgPendingSize = _calcAverage(avgPendingSize, uint64(numPendingBlocks));
    }

    function postPayProver(
        uint256, /*blockId*/
        uint256 uncleId,
        address, /*prover*/
        uint128, /*gasPriceAtProposal*/
        uint128, /*gasLimit*/
        uint64 proposedAt,
        uint64 provenAt
    ) internal virtual override {
        // Update stats
        if (uncleId == 0) {
            avgFinalizationDelay = _calcAverage(
                avgFinalizationDelay,
                uint64(block.timestamp - proposedAt)
            );

            avgProvingDelay = _calcAverage(
                avgProvingDelay,
                provenAt - proposedAt
            );
        }

        avgProvingDelayWithUncles = _calcAverage(
            avgProvingDelayWithUncles,
            provenAt - proposedAt
        );
    }

    function _calcAverage(uint64 avg, uint64 current)
        private
        pure
        returns (uint64)
    {
        if (current == 0) return avg;
        if (avg == 0) return current;

        uint256 _avg = ((STAT_AVERAGING_FACTOR - 1) *
            avg +
            current *
            NANO_PER_SECOND) / STAT_AVERAGING_FACTOR;
        return _avg.toUint64();
    }
}
