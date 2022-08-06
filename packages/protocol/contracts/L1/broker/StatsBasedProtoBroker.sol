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

import "./AbstractProtoBroker.sol";

abstract contract StatsBasedProtoBroker is AbstractProtoBroker {
    using SafeCastUpgradeable for uint256;

    uint256 public constant STAT_AVERAGING_FACTOR = 2048;
    uint64 public constant NANO_PER_SECOND = 1E9;

    uint64 internal _avgPendingSize;
    uint64 internal _avgProvingDelay;
    uint64 internal _avgProvingDelayWithUncles;
    uint64 internal _avgFinalizationDelay;

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

    function getStats()
        public
        view
        returns (
            uint64 avgPendingSize,
            uint64 avgProvingDelay,
            uint64 avgProvingDelayWithUncles,
            uint64 avgFinalizationDelay
        )
    {
        avgPendingSize = _avgPendingSize / NANO_PER_SECOND;
        avgProvingDelay = _avgProvingDelay / NANO_PER_SECOND;
        avgProvingDelayWithUncles =
            _avgProvingDelayWithUncles /
            NANO_PER_SECOND;
        avgFinalizationDelay = avgFinalizationDelay / NANO_PER_SECOND;
    }

    function postChargeProposer(
        uint256, /*blockId*/
        uint256 numPendingBlocks,
        uint256, /*numUnprovenBlocks*/
        address, /*proposer*/
        uint128 /*gasLimit*/
    ) internal virtual override {
        // Update stats first.
        _avgPendingSize = _calcAverage(
            _avgPendingSize,
            uint64(numPendingBlocks)
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
            _avgFinalizationDelay = _calcAverage(
                _avgFinalizationDelay,
                uint64(block.timestamp - proposedAt)
            );

            _avgProvingDelay = _calcAverage(
                _avgProvingDelay,
                provenAt - proposedAt
            );
        }

        _avgProvingDelayWithUncles = _calcAverage(
            _avgProvingDelayWithUncles,
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
