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
import "../../libs/Lib1559Math.sol";
import "./ProtoBrokerBase.sol";

abstract contract ProtoBrokerWithDynamicFees is ProtoBrokerBase {
    using SafeCastUpgradeable for uint256;
    using LibMath for uint256;

    // TODO(daniel): do simulation to find values for these constants.
    uint64 public constant FEE_PREMIUM_BLOCK_THRESHOLD = 256;
    uint64 public constant FEE_ADJUSTMENT_FACTOR = 32;
    uint64 public constant PROVING_DELAY_AVERAGING_FACTOR = 64;
    uint64 public constant FEE_PREMIUM_MAX_MUTIPLIER = 4;
    uint64 public constant FEE_BIPS = 500; // 5%

    uint64 internal constant MILI_PER_SECOND = 1E3;

    uint64 internal _avgNumUnprovenBlocks;
    uint64 internal _avgProvingDelay;
    uint128 public suggestedGasPrice;

    uint256[49] private __gap;

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
                (provenAt - proposedAt) * MILI_PER_SECOND,
                PROVING_DELAY_AVERAGING_FACTOR
            ).toUint64();

            _suggestedGasPrice = Lib1559Math
                .adjustTarget(
                    _suggestedGasPrice,
                    (proposerFee * 1000000) / proverFee,
                    1000000,
                    FEE_ADJUSTMENT_FACTOR
                )
                .toUint128();
        }
    }

    function getStats()
        public
        view
        returns (uint64 avgNumUnprovenBlocks, uint64 avgProvingDelay)
    {
        avgNumUnprovenBlocks = _avgNumUnprovenBlocks / MILI_PER_SECOND;
        avgProvingDelay = _avgProvingDelay / MILI_PER_SECOND;
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
        uint64 provingDelayNano = provingDelay * MILI_PER_SECOND;

        uint128 gasFeeAfterTax = (proposerFee * (10000 - FEE_BIPS)) / 10000;

        if (provingDelayNano < threshold) {
            return gasFeeAfterTax;
        }

        uint256 fee = (uint256(gasFeeAfterTax) *
            (provingDelayNano - threshold)) /
            _avgProvingDelay +
            gasFeeAfterTax;

        return fee.toUint128();
    }

    function _getProposerGasPrice(uint64 numUnprovenBlocks)
        internal
        view
        virtual
        override
        returns (uint128)
    {
        uint64 threshold = _avgNumUnprovenBlocks > FEE_PREMIUM_BLOCK_THRESHOLD
            ? _avgNumUnprovenBlocks
            : FEE_PREMIUM_BLOCK_THRESHOLD;

        if (numUnprovenBlocks <= threshold) {
            return suggestedGasPrice;
        } else {
            uint256 premium = (10000 * numUnprovenBlocks) / (2 * threshold);
            premium = premium.min(FEE_PREMIUM_MAX_MUTIPLIER * 10000);
            return (suggestedGasPrice * uint128(premium)) / 10000;
        }
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
