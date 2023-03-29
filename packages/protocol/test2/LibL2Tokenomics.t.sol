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

    function calcScales(
        uint _maxGasExcess,
        uint _initialBasefee,
        uint256 _target
    ) internal view returns (uint _excess, uint _xscale, uint _yscale) {
        _excess = _maxGasExcess / 2;
        _xscale = 135305999368893231588 / _maxGasExcess;
        _yscale = T.basefee(_excess, _xscale, _initialBasefee, _target);
        console2.log("xscale =", _xscale);
        console2.log("yscale =", _yscale);
        console2.log("uint64.max", type(uint64).max);
        console2.log("uint128.max", type(uint128).max);
        console2.log("initial basefee (configged)   =", _initialBasefee);
        console2.log(
            "initial basefee (recauculated)=",
            T.basefee(_excess, _xscale, _yscale, _target)
        );
    }

    function test1559PurchaseMaxSizeGasWontOverflow() public {
        uint256 initialBasefee = 5000000000;
        uint256 maxGasToBuy = 15000000 * 512;
        uint target = 6000000;

        (uint gasExcess, uint xscale, uint yscale) = calcScales(
            maxGasToBuy,
            initialBasefee,
            target
        );

        uint expectedBaseFeeChange = 11; // 11 %%

        uint _basefee = initialBasefee;
        console2.log("basefee", _basefee);
        gasExcess += target;

        for (uint i = 0; i < 10; ++i) {
            uint newBasefee = T.basefee(gasExcess, xscale, yscale, target);
            uint ratio = (newBasefee * 100) / _basefee - 100;
            console2.log(
                "basefee",
                newBasefee,
                "+%",
                (newBasefee * 100) / _basefee - 100
            );
            assertEq(ratio, expectedBaseFeeChange);
            _basefee = newBasefee;
            gasExcess += target;
        }
    }
}
