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

    uint64 internal _avgNumUnprovenBlocks;
    uint64 internal _avgProvingDelay;

    uint256[49] private __gap;

    function getStats()
        public
        view
        returns (uint64 avgNumUnprovenBlocks, uint64 avgProvingDelay)
    {
        avgNumUnprovenBlocks = _avgNumUnprovenBlocks / NANO_PER_SECOND;
        avgProvingDelay = _avgProvingDelay / NANO_PER_SECOND;
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

    function calculateActualGasPrice(uint128 askPrice, uint64 provingDelay)
        internal
        virtual
        override
        returns (uint128)
    {
        uint64 threshold = _avgProvingDelay * 2;
        uint64 provingDelayNano = provingDelay * NANO_PER_SECOND;

        uint128 askPriceAfterTax = (askPrice * 95) / 100;

        if (provingDelayNano < threshold) {
            return askPriceAfterTax;
        }

        uint256 fee = (uint256(askPriceAfterTax) *
            (provingDelayNano - threshold)) /
            _avgProvingDelay +
            askPriceAfterTax;

        return fee.toUint128();
    }

    function postChargeProposer(
        uint64, /* numPendingBlocks*/
        uint64 numUnprovenBlocks,
        uint128 /*gasLimit*/
    ) internal virtual override {
        _avgNumUnprovenBlocks = _calcAverage(
            _avgNumUnprovenBlocks,
            numUnprovenBlocks,
            512
        ).toUint64();
    }

    function postPayProver(
        uint256 uncleId,
        uint128 askPrice,
        uint128 bidPrice,
        uint64 proposedAt,
        uint64 provenAt
    ) internal virtual override {
        if (uncleId != 0) return;

        _avgProvingDelay = _calcAverage(
            _avgProvingDelay,
            (provenAt - proposedAt) * NANO_PER_SECOND,
            512
        ).toUint64();

        uint256 ratio = (bidPrice * 1000000) / askPrice;

        // TODO: use 1559 to adjust gasPriceNow.
        gasPriceNow = _calcAverage(gasPriceNow, bidPrice, 512).toUint128();
    }

    function _calcAverage(
        uint256 avg,
        uint256 current,
        uint256 factor
    ) private pure returns (uint256) {
        if (current == 0) return avg;
        if (avg == 0) return current;

        return ((factor - 1) * avg + current) / factor;
    }
}
