// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LibL2Tokenomics} from "../contracts/L1/libs/LibL2Tokenomics.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestLibL2Tokenomics is Test {
    using SafeCastUpgradeable for uint256;

    uint256 initialBaseFee = 5000000000;
    uint256 gasTargetPerSecond = 1000000;
    uint256 gasExcess = gasTargetPerSecond * 1000;
    uint256 gasPoolProduct = gasExcess ** 2 * initialBaseFee;

    function test1559Basefee() public {
        _purchaseGas(gasTargetPerSecond * 12, 12);
        _purchaseGas(gasTargetPerSecond * 12, 12);
        _purchaseGas(gasTargetPerSecond * 12, 0);
        _purchaseGas(gasTargetPerSecond * 12, 0);
        _purchaseGas(gasTargetPerSecond * 12, 0);
        _purchaseGas(gasTargetPerSecond * 12, 0);
        _purchaseGas(gasTargetPerSecond * 12, 0);
        _purchaseGas(gasTargetPerSecond * 12, 0);
        _purchaseGas(gasTargetPerSecond * 12, 0);
    }

    function _purchaseGas(uint256 amount, uint256 blockTime) private {
        uint64 basefee;
        uint256 gasPurchaseCost;
        (gasExcess, basefee, gasPurchaseCost) = LibL2Tokenomics.calc1559Basefee(
            gasExcess,
            gasTargetPerSecond,
            gasPoolProduct,
            amount,
            blockTime
        );
        console2.log("===== gasPurchaseCost:", gasPurchaseCost);
        console2.log("=====         basefee:", basefee);
    }
}
