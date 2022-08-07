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

    /**********************
     * Constants          *
     **********************/

    // TODO(daniel): do simulation to find values for these constants.
    uint64 public constant FEE_PREMIUM_BLOCK_THRESHOLD = 256;
    uint64 public constant FEE_ADJUSTMENT_FACTOR = 32;
    uint64 public constant PROVING_DELAY_AVERAGING_FACTOR = 64;
    uint64 public constant FEE_PREMIUM_MAX_MUTIPLIER = 4;
    uint64 public constant FEE_BIPS = 1000; // 10%
    uint64 internal constant MILIS_PER_SECOND = 1E3;

    /**********************
     * State Variables    *
     **********************/

    uint64 internal _avgNumUnprovenBlocks;
    uint64 internal _avgProvingDelay;
    uint128 public suggestedGasPrice;
    uint256[49] private __gap;

    /**********************
     * Public Functions   *
     **********************/
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

    function payProvers(
        uint256 blockId,
        uint64 proposedAt,
        uint64 provenAt,
        uint128 proposerFee,
        address[] memory provers
    ) public virtual override returns (uint128 totalProverFee) {
        totalProverFee = ProtoBrokerBase.payProvers(
            blockId,
            proposedAt,
            provenAt,
            proposerFee,
            provers
        );

        _avgProvingDelay = _calcAverage(
            _avgProvingDelay,
            (provenAt - proposedAt) * MILIS_PER_SECOND,
            PROVING_DELAY_AVERAGING_FACTOR
        ).toUint64();

        suggestedGasPrice = Lib1559Math
            .adjustTargetReverse(
                suggestedGasPrice,
                (proposerFee * 1000000) / totalProverFee,
                1000000,
                FEE_ADJUSTMENT_FACTOR
            )
            .toUint128();
    }

    function getStats()
        public
        view
        returns (uint64 avgNumUnprovenBlocks, uint64 avgProvingDelay)
    {
        avgNumUnprovenBlocks = _avgNumUnprovenBlocks / MILIS_PER_SECOND;
        avgProvingDelay = _avgProvingDelay / MILIS_PER_SECOND;
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _amountToMintToDAOThreshold,
        uint128 _suggestedGasPrice
    ) internal virtual {
        ProtoBrokerBase._init(_addressManager, _amountToMintToDAOThreshold);

        suggestedGasPrice = _suggestedGasPrice;
    }

    function calculateProverFees(
        uint128 proposerFee,
        uint64 provingDelay,
        address[] memory provers
    )
        internal
        virtual
        override
        returns (uint128[] memory proverFees, uint128 totalFees)
    {
        uint256 size = provers.length;
        require(size > 0 && size <= 10, "invalid provers");

        proverFees = new uint128[](size);
        totalFees = _calculateProverFee(proposerFee, provingDelay);

        uint128 tenPctg = totalFees / 10;

        proverFees[0] = tenPctg * uint128(11 - size);
        for (uint256 i = 1; i < size; i++) {
            proverFees[i] = tenPctg;
        }
    }

    function getProposerGasPrice(uint64 numUnprovenBlocks)
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

    /**********************
     * Private Functions  *
     **********************/
    function _calculateProverFee(uint128 proposerFee, uint64 provingDelay)
        private
        view
        returns (uint128)
    {
        // start to paying additional rewards above 125% of average proving delay
        uint64 threshold = (_avgProvingDelay * 125) / 10;
        uint64 provingDelayNano = provingDelay * MILIS_PER_SECOND;
        uint128 feeBaseline = (proposerFee * (10000 - FEE_BIPS)) / 10000;

        if (provingDelayNano < threshold) {
            return feeBaseline;
        }

        uint256 fee = (uint256(feeBaseline) * (provingDelayNano - threshold)) /
            _avgProvingDelay +
            feeBaseline;

        return fee.toUint128();
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
