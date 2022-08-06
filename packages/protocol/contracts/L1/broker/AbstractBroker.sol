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
    uint256 internal gasPriceNow;

    event FeeTransacted(
        uint256 indexed blockId,
        address indexed account,
        uint256 amount,
        bool inbound
    );

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint256 _gasPriceNow,
        uint256 _unsettledProverFeeThreshold
    ) internal initializer {
        require(_unsettledProverFeeThreshold > 0, "threshold too small");
        EssentialContract._init(_addressManager);
        gasPriceNow = _gasPriceNow;
        unsettledProverFeeThreshold = _unsettledProverFeeThreshold;
    }

    function gasLimitBase() public view virtual override returns (uint256) {
        return 1000000;
    }

    function currentGasPrice() public view virtual override returns (uint256) {
        return gasPriceNow;
    }

    function estimateFee(uint256 gasLimit)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return gasPriceNow * (gasLimit + gasLimitBase());
    }

    function chargeProposer(
        uint256 blockId,
        address proposer,
        uint256 gasLimit
    ) external virtual override onlyFromNamed("taiko_l1") {
        uint256 fee = estimateFee(gasLimit);
        require(charge(proposer, fee), "failed to charge");
        emit FeeTransacted(blockId, proposer, fee, false);
    }

    function payProver(
        uint256 blockId,
        address prover,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 provingDelay,
        uint256 uncleId
    ) external virtual override onlyFromNamed("taiko_l1") {
        uint256 prepaid = gasPrice * (gasLimit + gasLimitBase());
        uint256 fee;

        if (fee > 0) {
            if (!pay(prover, fee)) {
                unsettledProverFee += fee;
            }
        }

        if (unsettledProverFee > unsettledProverFeeThreshold) {
            if (pay(resolve("dao_vault"), unsettledProverFee - 1)) {
                unsettledProverFee = 1;
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
}

// IMintableERC20(resolve("tai_token")).mint(
//     resolve("dao_vault"),
//     daoReward
// );
