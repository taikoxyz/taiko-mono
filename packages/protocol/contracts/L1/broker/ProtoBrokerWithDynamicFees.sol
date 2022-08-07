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
import "../../libs/Lib1559Math.sol";
import "./ProtoBrokerBase.sol";

abstract contract ProtoBrokerWithDynamicFees is ProtoBrokerBase {
    using SafeCastUpgradeable for uint256;
    using LibMath for uint256;

    /**********************
     * Constants          *
     **********************/

    // TODO(daniel): do simulation to find values for these constants.
    uint256 public constant FEE_PREMIUM_BLOCK_THRESHOLD = 256;
    uint256 public constant FEE_ADJUSTMENT_FACTOR = 32;
    uint256 public constant PROVING_DELAY_AVERAGING_FACTOR = 64;
    uint256 public constant FEE_PREMIUM_MAX_MUTIPLIER = 4;
    uint256 public constant FEE_BIPS = 750; // 7.5%
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
        uint256 gasLimit,
        uint256 numUnprovenBlocks
    )
        public
        virtual
        override
        onlyFromNamed("taiko_l1")
        returns (uint256 proposerFee)
    {
        proposerFee = ProtoBrokerBase.chargeProposer(
            blockId,
            proposer,
            gasLimit,
            numUnprovenBlocks
        );

        _avgNumUnprovenBlocks = _updateAverage(
            _avgNumUnprovenBlocks,
            numUnprovenBlocks,
            512
        ).toUint64();
    }

    function payProvers(
        uint256 blockId,
        uint256 proposedAt,
        uint256 provenAt,
        uint256 proposerFee,
        address[] memory provers
    ) public virtual override returns (uint256 totalProverFee) {
        totalProverFee = ProtoBrokerBase.payProvers(
            blockId,
            proposedAt,
            provenAt,
            proposerFee,
            provers
        );

        _avgProvingDelay = _updateAverage(
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
        returns (uint256 avgNumUnprovenBlocks, uint256 avgProvingDelay)
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
        uint256 proposerFee,
        uint256 provingDelay,
        address[] memory provers
    )
        internal
        virtual
        override
        returns (uint256[] memory proverFees, uint256 totalFees)
    {
        uint256 size = provers.length;
        require(size > 0 && size <= 10, "invalid provers");

        proverFees = new uint256[](size);
        totalFees = _calculateProverFee(proposerFee, provingDelay);

        uint256 tenPctg = totalFees / 10;

        proverFees[0] = tenPctg * (11 - size);
        for (uint256 i = 1; i < size; i++) {
            proverFees[i] = tenPctg;
        }
    }

    function getProposerGasPrice(uint256 numUnprovenBlocks)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        uint256 threshold = _avgNumUnprovenBlocks > FEE_PREMIUM_BLOCK_THRESHOLD
            ? _avgNumUnprovenBlocks
            : FEE_PREMIUM_BLOCK_THRESHOLD;

        if (numUnprovenBlocks <= threshold) {
            return suggestedGasPrice;
        } else {
            uint256 premium = (10000 * numUnprovenBlocks) / (2 * threshold);
            premium = premium.min(FEE_PREMIUM_MAX_MUTIPLIER * 10000);
            return (suggestedGasPrice * premium) / 10000;
        }
    }

    /**********************
     * Private Functions  *
     **********************/
    function _calculateProverFee(uint256 proposerFee, uint256 provingDelay)
        private
        view
        returns (uint256)
    {
        // start to paying additional rewards above 150% of average proving delay
        uint256 threshold = (_avgProvingDelay * 150) / 100;
        uint256 provingDelayNano = provingDelay * MILIS_PER_SECOND;
        uint256 feeBaseline = (proposerFee * (10000 - FEE_BIPS)) / 10000;

        if (provingDelayNano < threshold) {
            return feeBaseline;
        }

        uint256 fee = (feeBaseline * (provingDelayNano - threshold)) /
            _avgProvingDelay +
            feeBaseline;

        return fee;
    }

    function _updateAverage(
        uint256 avg,
        uint256 current,
        uint256 factor
    ) private pure returns (uint256) {
        if (current == 0) return avg;
        if (avg == 0) return current;

        return ((factor - 1) * avg + current) / factor;
    }
}
