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
    uint128 public suggestedGasPrice;

    uint256[49] private __gap;

    function getStats()
        public
        view
        returns (uint64 avgNumUnprovenBlocks, uint64 avgProvingDelay)
    {
        avgNumUnprovenBlocks = _avgNumUnprovenBlocks / NANO_PER_SECOND;
        avgProvingDelay = _avgProvingDelay / NANO_PER_SECOND;
    }

    function chargeProposer(
        uint256 blockId,
        address proposer,
        uint128 gasLimit,
        uint64 numUnprovenBlocks
    )
        public
        virtual
        override
        onlyFromNamed("taiko_l1")
        returns (uint128 proposerFee)
    {
        proposerFee = ProtoBrokerBase.chargeProposer(
            blockId,
            proposer,
            gasLimit,
            numUnprovenBlocks
        );

        _avgNumUnprovenBlocks = _calcAverage(
            _avgNumUnprovenBlocks,
            numUnprovenBlocks,
            512
        ).toUint64();
    }

    function payProver(
        uint256 blockId,
        address prover,
        uint256 uncleId,
        uint64 proposedAt,
        uint64 provenAt,
        uint128 proposerFee
    ) public virtual override returns (uint128 proverFee) {
        proverFee = ProtoBrokerBase.payProver(
            blockId,
            prover,
            uncleId,
            proposedAt,
            provenAt,
            proposerFee
        );

        if (uncleId == 0) {
            _avgProvingDelay = _calcAverage(
                _avgProvingDelay,
                (provenAt - proposedAt) * NANO_PER_SECOND,
                512
            ).toUint64();

            // uint256 ratio = (proposerFee * 1000000) / proverFee;

            // TODO: use 1559 to adjust _suggestedGasPrice.
        }
    }

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _unsettledProverFeeThreshold,
        uint128 _suggestedGasPrice
    ) internal virtual {
        ProtoBrokerBase._init(_addressManager, _unsettledProverFeeThreshold);

        suggestedGasPrice = _suggestedGasPrice;
    }

    function _getProverFee(uint128 proposerFee, uint64 provingDelay)
        internal
        virtual
        override
        returns (uint128)
    {
        uint64 threshold = _avgProvingDelay * 2;
        uint64 provingDelayNano = provingDelay * NANO_PER_SECOND;

        uint128 gasFeeAfterTax = (proposerFee * 95) / 100;

        if (provingDelayNano < threshold) {
            return gasFeeAfterTax;
        }

        uint256 fee = (uint256(gasFeeAfterTax) *
            (provingDelayNano - threshold)) /
            _avgProvingDelay +
            gasFeeAfterTax;

        return fee.toUint128();
    }

    function _getProposerGasPrice(
        uint64 /*numUnprovenBlocks*/
    ) public view virtual override returns (uint128) {
        //TODO: _avgNumUnprovenBlocks
        return suggestedGasPrice;
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
