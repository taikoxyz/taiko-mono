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

import "./ProtoBrokerBase.sol";

abstract contract ProtoBrokerWithDynamicFees is ProtoBrokerBase {
    using SafeCastUpgradeable for uint256;

    uint256 public constant STAT_AVERAGING_FACTOR = 2048;
    uint64 internal constant NANO_PER_SECOND = 1E9;

    uint64 internal _avgPendingSize;
    uint64 internal _avgProvingDelay;
    uint64 internal _avgProvingDelayWithUncles;
    uint64 internal _avgFinalizationDelay;

    uint256[49] private __gap;

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

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _gasPriceNow,
        uint256 _unsettledProverFeeThreshold
    ) internal virtual override {
        ProtoBrokerBase._init(
            _addressManager,
            _gasPriceNow,
            _unsettledProverFeeThreshold
        );
    }

    function calculateActualGasPrice(
        uint128 gasPriceAtProposal,
        uint64 provingDelay
    ) internal virtual override returns (uint128) {
        uint64 threshold = _avgProvingDelay * 2;
        uint64 provingDelayNano = provingDelay * NANO_PER_SECOND;

        uint128 gasPriceAtProposalAfterTax = (gasPriceAtProposal * 95) / 100;

        if (provingDelayNano < threshold) {
            return gasPriceAtProposalAfterTax;
        }

        uint256 fee = (uint256(gasPriceAtProposalAfterTax) *
            (provingDelayNano - threshold)) /
            _avgProvingDelay +
            gasPriceAtProposalAfterTax;

        return fee.toUint128();
    }

    function postChargeProposer(
        uint256, /*blockId*/
        uint256 numPendingBlocks,
        uint256, /*numUnprovenBlocks*/
        address, /*proposer*/
        uint128 /*gasLimit*/
    ) internal virtual override {
        // Update stats first.
        _avgPendingSize = _calcAverageTime(
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
        uint64 provenAt,
        uint128 actualGasPrice
    ) internal virtual override {
        if (uncleId == 0) {
            _avgFinalizationDelay = _calcAverageTime(
                _avgFinalizationDelay,
                uint64(block.timestamp - proposedAt)
            );

            _avgProvingDelay = _calcAverageTime(
                _avgProvingDelay,
                provenAt - proposedAt
            );

            gasPriceNow = (gasPriceNow * 15 + actualGasPrice) / 16;
        }

        _avgProvingDelayWithUncles = _calcAverageTime(
            _avgProvingDelayWithUncles,
            provenAt - proposedAt
        );
    }

    function _calcAverageTime(uint64 avg, uint64 current)
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
