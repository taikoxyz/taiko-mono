// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LibL2Tokenomics as T} from "../contracts/L1/libs/LibL2Tokenomics.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {
    LibFixedPointMath as M
} from "../contracts/thirdparty/LibFixedPointMath.sol";

contract TestLibL2Tokenomics is Test {
    using SafeCastUpgradeable for uint256;

    function test1559PurchaseMaxSizeGasWontOverflow() public view {
        uint64 basefeeInitial = 5000000000;
        uint64 l2GasExcessMax = 15000000 * 256;
        uint64 gasTarget = 6000000;
        uint64 expected2X1XRatio = 111; // 11 %%

        (uint64 l2GasExcess, uint64 xscale, uint256 yscale) = T
            .calcL2BasefeeParams(
                l2GasExcessMax,
                basefeeInitial,
                gasTarget,
                expected2X1XRatio
            );

        uint64 _basefee = basefeeInitial;
        console2.log("basefee", _basefee);
        l2GasExcess += gasTarget;

        for (uint i = 0; i < 10; ++i) {
            uint64 newBasefee = T
                .calcL2Basefee(l2GasExcess, xscale, yscale << 64, gasTarget)
                .toUint64();
            uint ratio = (newBasefee * 100) / _basefee - 100;
            console2.log("basefee", newBasefee, "+%", ratio);
            _basefee = newBasefee;
            l2GasExcess += gasTarget;
        }
    }
}
