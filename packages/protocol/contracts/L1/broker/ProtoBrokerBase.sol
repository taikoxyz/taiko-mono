// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/EssentialContract.sol";
import "./IProtoBroker.sol";

abstract contract ProtoBrokerBase is IProtoBroker, EssentialContract {
    uint256 public unsettledProverFeeThreshold;
    uint256 public unsettledProverFee;
    uint128 internal _suggestedGasPrice;

    uint256[47] private __gap;

    event FeeCharged(
        uint256 indexed blockId,
        address indexed account,
        uint128 amount
    );
    event FeePaid(
        uint256 indexed blockId,
        address indexed account,
        uint128 amount
    );

    function chargeProposer(
        uint256 blockId,
        uint64 numUnprovenBlocks,
        address proposer,
        uint128 gasLimit
    ) public virtual override returns (uint128 gasFeeReceived) {
        gasFeeReceived = estimateGasFee(gasLimit, numUnprovenBlocks);

        require(charge(proposer, gasFeeReceived), "failed to charge");
        emit FeeCharged(blockId, proposer, gasFeeReceived);
    }

    function payProver(
        uint256 blockId,
        uint256 uncleId,
        address prover,
        uint128 gasFeeReceived,
        uint64 proposedAt,
        uint64 provenAt
    ) public virtual override returns (uint128 gasFeePaid) {
        gasFeePaid = _calculateGasFeePaid(
            gasFeeReceived,
            provenAt - proposedAt
        );

        for (uint256 i = 0; i < uncleId; i++) {
            gasFeePaid /= 2;
        }

        if (gasFeePaid > 0) {
            if (!pay(prover, gasFeePaid)) {
                unsettledProverFee += gasFeePaid;
            }

            if (unsettledProverFee > unsettledProverFeeThreshold) {
                if (pay(resolve("dao_vault"), unsettledProverFee - 1)) {
                    unsettledProverFee = 1;
                }
            }
        }

        emit FeePaid(blockId, prover, gasFeePaid);
    }

    function _calclateGasPrice(
        uint64 /*numUnprovenBlocks*/
    ) internal view virtual returns (uint128) {
        return _suggestedGasPrice;
    }

    function estimateGasFee(uint128 gasLimit, uint64 numUnprovenBlocks)
        public
        view
        virtual
        override
        returns (uint128)
    {
        uint128 gasPrice = _calclateGasPrice(numUnprovenBlocks);
        return _calculateGasFee(gasPrice, gasLimit);
    }

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 __suggestedGasPrice,
        uint256 _unsettledProverFeeThreshold
    ) internal virtual {
        require(_unsettledProverFeeThreshold > 0, "threshold too small");
        EssentialContract._init(_addressManager);
        _suggestedGasPrice = __suggestedGasPrice;
        unsettledProverFeeThreshold = _unsettledProverFeeThreshold;
    }

    function _calculateGasFeePaid(
        uint128 gasFeeReceived,
        uint64 /*provingDelay*/
    ) internal virtual returns (uint128) {
        return gasFeeReceived;
    }

    function pay(
        address, /*recipient*/
        uint256 /*amount*/
    )
        internal
        virtual
        returns (
            bool /*success*/
        );

    function charge(
        address, /*recipient*/
        uint256 /*amount*/
    )
        internal
        virtual
        returns (
            bool /*success*/
        );

    function _calculateGasFee(uint128 gasPrice, uint128 gasLimit)
        internal
        pure
        returns (uint128)
    {
        return gasPrice * (gasLimit + _gasLimitBase());
    }

    function _gasLimitBase() internal pure virtual returns (uint128) {
        return 1000000;
    }
}
