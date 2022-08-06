// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../libs/LibMath.sol";
import "./AbstractBroker.sol";

abstract contract StatsBasedBroker is AbstractBroker {
    using LibMath for uint256;
    uint256 public constant STAT_AVERAGING_FACTOR = 2048;
    uint64 public constant NANO_PER_SECOND = 1E9;

    uint64 public avgPendingSize;
    uint64 public avgProvingDelay;
    uint64 public avgProvingDelayWithUncles;
    uint64 public avgFinalizationDelay;

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _gasPriceNow,
        uint256 _unsettledProverFeeThreshold
    ) internal virtual override {
        AbstractBroker._init(
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
        avgPendingSize = uint64(
            _calcAverage(avgPendingSize, numPendingBlocks, type(uint64).max)
        );
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
            avgFinalizationDelay = uint64(
                _calcAverage(
                    avgFinalizationDelay,
                    uint64(block.timestamp - proposedAt),
                    type(uint64).max
                )
            );

            avgProvingDelay = uint64(
                _calcAverage(
                    avgProvingDelay,
                    provenAt - proposedAt,
                    type(uint64).max
                )
            );
        }

        avgProvingDelayWithUncles = uint64(
            _calcAverage(
                avgProvingDelayWithUncles,
                provenAt - proposedAt,
                type(uint128).max
            )
        );
    }

    function _calcAverage(
        uint256 avg,
        uint256 current,
        uint256 max
    ) private pure returns (uint256) {
        if (current == 0) return avg;
        if (avg == 0) return current;

        uint256 _avg = ((STAT_AVERAGING_FACTOR - 1) *
            avg +
            current *
            NANO_PER_SECOND) / STAT_AVERAGING_FACTOR;
        return _avg.min(max);
    }
}
