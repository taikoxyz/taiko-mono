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
    uint128 internal gasPriceNow;

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
        uint64 numPendingBlocks,
        uint64 numUnprovenBlocks,
        address proposer,
        uint128 gasLimit
    )
        external
        virtual
        override
        onlyFromNamed("taiko_l1")
        returns (uint128 gasPrice)
    {
        uint128 fee = estimateFee(gasLimit);
        gasPrice = gasPriceNow;
        require(charge(proposer, fee), "failed to charge");
        emit FeeCharged(blockId, proposer, fee);

        postChargeProposer(
            blockId,
            numPendingBlocks,
            numUnprovenBlocks,
            proposer,
            gasLimit
        );
    }

    function payProver(
        uint256 blockId,
        uint256 uncleId,
        address prover,
        uint128 gasPriceAtProposal,
        uint128 gasLimit,
        uint64 proposedAt,
        uint64 provenAt
    ) external virtual override onlyFromNamed("taiko_l1") {
        uint128 actualGasPrice = calculateActualGasPrice(
            gasPriceAtProposal,
            provenAt - proposedAt
        );

        uint128 fee = actualGasPrice * (gasLimit + gasLimitBase());

        for (uint256 i = 0; i < uncleId; i++) {
            fee /= 2;
        }

        if (fee > 0) {
            if (!pay(prover, fee)) {
                unsettledProverFee += fee;
            }

            if (unsettledProverFee > unsettledProverFeeThreshold) {
                if (pay(resolve("dao_vault"), unsettledProverFee - 1)) {
                    unsettledProverFee = 1;
                }
            }
        }

        emit FeePaid(blockId, prover, fee);
        postPayProver(
            blockId,
            uncleId,
            prover,
            gasPriceAtProposal,
            gasLimit,
            proposedAt,
            provenAt,
            actualGasPrice
        );
    }

    function gasLimitBase() public view virtual override returns (uint128) {
        return 1000000;
    }

    function currentGasPrice() public view virtual override returns (uint128) {
        return gasPriceNow;
    }

    function estimateFee(uint128 gasLimit)
        public
        view
        virtual
        override
        returns (uint128)
    {
        return gasPriceNow * (gasLimit + gasLimitBase());
    }

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _gasPriceNow,
        uint256 _unsettledProverFeeThreshold
    ) internal virtual {
        require(_unsettledProverFeeThreshold > 0, "threshold too small");
        EssentialContract._init(_addressManager);
        gasPriceNow = _gasPriceNow;
        unsettledProverFeeThreshold = _unsettledProverFeeThreshold;
    }

    function calculateActualGasPrice(
        uint128 gasPriceAtProposal,
        uint64 /*provingDelay*/
    ) internal virtual returns (uint128) {
        return gasPriceAtProposal;
    }

    function postChargeProposer(
        uint256, /*blockId*/
        uint64, /*numPendingBlocks*/
        uint64, /*numUnprovenBlocks*/
        address, /*proposer*/
        uint128 /*gasLimit*/
    ) internal virtual {}

    function postPayProver(
        uint256, /*blockId*/
        uint256, /*uncleId*/
        address, /*prover*/
        uint128, /*gasPriceAtProposal*/
        uint128, /*gasLimit*/
        uint64, /*proposedAt*/
        uint64, /*provenAt*/
        uint128 /*actualGasPrice*/
    ) internal virtual {}

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
}
