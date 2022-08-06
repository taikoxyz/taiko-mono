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
import "./IBroker.sol";

abstract contract AbstractBroker is IBroker, EssentialContract {
    uint256 public unsettledProverFeeThreshold;
    uint256 public unsettledProverFee;
    uint128 internal gasPriceNow;

    event FeeTransacted(
        uint256 indexed blockId,
        address indexed account,
        uint128 amount,
        bool inbound
    );

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _gasPriceNow,
        uint256 _unsettledProverFeeThreshold
    ) internal {
        require(_unsettledProverFeeThreshold > 0, "threshold too small");
        EssentialContract._init(_addressManager);
        gasPriceNow = _gasPriceNow;
        unsettledProverFeeThreshold = _unsettledProverFeeThreshold;
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

    function chargeProposer(
        uint256 blockId,
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
        emit FeeTransacted(blockId, proposer, fee, false);
    }

    function payProver(
        uint256 blockId,
        uint256 uncleId,
        address prover,
        uint128 gasPriceAtProposal,
        uint128 gasLimit,
        uint64 provingDelay
    ) external virtual override onlyFromNamed("taiko_l1") {
        uint128 fee = calculateActualFee(
            blockId,
            uncleId,
            prover,
            gasPriceAtProposal,
            gasLimit,
            provingDelay
        );
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

        emit FeeTransacted(blockId, prover, fee, false);
    }

    function pay(address recipient, uint256 amount)
        internal
        virtual
        returns (bool success);

    function charge(address recipient, uint256 amount)
        internal
        virtual
        returns (bool success);

    function calculateActualFee(
        uint256 blockId,
        uint256 uncleId,
        address prover,
        uint128 gasPriceAtProposal,
        uint128 gasLimit,
        uint64 provingDelay
    ) internal virtual returns (uint128);
}
