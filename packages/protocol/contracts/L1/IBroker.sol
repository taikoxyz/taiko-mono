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

import "../common/EssentialContract.sol";
import "../libs/LibMath.sol";
import "../thirdparty/ERC20Upgradeable.sol";

/// @author dantaik <dan@taiko.xyz>
interface IBroker {
    event ProverPaid(
        address indexed prover,
        uint256 id,
        uint256 proverFee,
        uint256 reward
    );

    function enterDeal(
        address prover,
        uint256 proverGasPrice,
        uint256 gasLimit
    ) external returns (uint128 proverFee);

    function calculateActualProverFee(
        uint128 predictedProverFee,
        uint128 provingDelay,
        uint256 sequenceId
    ) external pure returns (uint128 proverFee);

    function payProver(
        address prover,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 provingDelay,
        uint256 sequenceId
    ) external;
}

abstract contract DefaultBroker is IBroker, EssentialContract {
    using SafeCastUpgradeable for uint256;

    uint256 public constant BLOCK_GAS_LIMIT_EXTRA = 1000000; // TODO
    uint256 public constant ETH_TRANSFER_GAS_LIMIT = 25000;
    uint256 unsettledProverFeeThreshold;
    uint256 unsettledProverFee;

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint256 _unsettledProverFeeThreshold
    ) internal initializer {
        require(_unsettledProverFeeThreshold > 0, "threshold too small");
        EssentialContract._init(_addressManager);
        unsettledProverFeeThreshold = _unsettledProverFeeThreshold;
    }

    function enterDeal(
        address prover,
        uint256 proverGasPrice,
        uint256 gasLimit
    ) external override onlyFromNamed("taiko") returns (uint128 proverFee) {
        proverFee = (proverGasPrice * (gasLimit + BLOCK_GAS_LIMIT_EXTRA))
            .toUint128();
        // ERC20Upgradeable.transferFrom(prover, address(this), proverFee);
    }

    // function payProver(address prover, uint256 proverFee)
    //     external
    //     onlyFromNamed("taiko")
    // {
    //     if (proverFee > 0) {
    //         if (!pay(prover, proverFee)) {
    //             unsettledProverFee += proverFee;
    //         }
    //     }

    //     if (unsettledProverFee > unsettledProverFeeThreshold) {
    //         if (pay(resolve("dao_vault"), unsettledProverFee - 1)) {
    //             unsettledProverFee = 1;
    //         }
    //     }

    //     // emit ProverPaid(
    //     //     evidence.prover,
    //     //     id,
    //     //     evidence.proverFee,
    //     //     evidence.reward
    //     // );
    // }

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
