// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LibL2Consts} from "../contracts/L2/LibL2Consts.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL2} from "../contracts/L2/TaikoL2.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestTaikoL2 is Test {
    using SafeCastUpgradeable for uint256;

    uint64 public constant BLOCK_GAS_LIMIT = 30000000; // same as `block_gas_limit` in foundry.toml

    TaikoL2 public L2;
    uint256 private logIndex;
    uint64 private ANCHOR_GAS_COST = LibL2Consts.ANCHOR_GAS_COST;

    function setUp() public {
        uint16 rand = 2;
        TaikoL2.EIP1559Params memory param1559 = TaikoL2.EIP1559Params({
            basefee: (uint256(BLOCK_GAS_LIMIT * 10) * rand).toUint64(),
            gasIssuedPerSecond: 1000000,
            gasExcessMax: (uint256(15000000) * 256 * rand).toUint64(),
            gasTarget: (uint256(6000000) * rand).toUint64(),
            ratio2x1x: 11177
        });

        L2 = new TaikoL2();
        L2.init(address(1), param1559); // Dummy address manager address.

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);
    }

    function testAnchorTxsBlocktimeConstant() external {
        uint256 firstBasefee;
        for (uint256 i = 0; i < 100; i++) {
            uint256 basefee = _getBasefeeAndPrint(0, BLOCK_GAS_LIMIT);
            vm.fee(basefee);

            if (firstBasefee == 0) {
                firstBasefee = basefee;
            } else {
                assertEq(firstBasefee, basefee);
            }

            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchor(BLOCK_GAS_LIMIT);

            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 30);
        }
    }

    function testAnchorTxsBlocktimeDecreasing() external {
        uint256 prevBasefee;

        for (uint256 i = 0; i < 32; i++) {
            uint256 basefee = _getBasefeeAndPrint(0, BLOCK_GAS_LIMIT);
            vm.fee(basefee);

            assertGe(basefee, prevBasefee);
            prevBasefee = basefee;

            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchor(BLOCK_GAS_LIMIT);

            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 30 - i);
        }
    }

    function testAnchorTxsBlocktimeIncreasing() external {
        uint256 prevBasefee;

        for (uint256 i = 0; i < 30; i++) {
            uint256 basefee = _getBasefeeAndPrint(0, BLOCK_GAS_LIMIT);
            vm.fee(basefee);

            if (prevBasefee != 0) {
                assertLe(basefee, prevBasefee);
            }
            prevBasefee = basefee;

            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchor(BLOCK_GAS_LIMIT);

            vm.roll(block.number + 1);

            vm.warp(block.timestamp + 30 + i);
        }
    }

    // calling anchor in the same block more than once should fail
    function testAnchorTxsFailInTheSameBlock() external {
        uint256 expectedBasefee = _getBasefeeAndPrint(0, BLOCK_GAS_LIMIT);
        vm.fee(expectedBasefee);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        _anchor(BLOCK_GAS_LIMIT);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert();
        _anchor(BLOCK_GAS_LIMIT);
    }

    // calling anchor in the same block more than once should fail
    function testAnchorTxsFailByNonTaikoL2Signer() external {
        uint256 expectedBasefee = _getBasefeeAndPrint(0, BLOCK_GAS_LIMIT);
        vm.fee(expectedBasefee);
        vm.expectRevert();
        _anchor(BLOCK_GAS_LIMIT);
    }

    function testAnchorSigning(bytes32 digest) external {
        (uint8 v, uint256 r, uint256 s) = L2.signAnchor(digest, uint8(1));
        address signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        (v, r, s) = L2.signAnchor(digest, uint8(2));
        signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        vm.expectRevert();
        L2.signAnchor(digest, uint8(0));

        vm.expectRevert();
        L2.signAnchor(digest, uint8(3));
    }

    function testGetBasefee() external {
        uint32 timeSinceParent = uint32(block.timestamp - L2.parentTimestamp());
        assertEq(_getBasefeeAndPrint(timeSinceParent, 0, 0), 317609019);
        assertEq(_getBasefeeAndPrint(timeSinceParent, 1, 0), 317609019);
        assertEq(_getBasefeeAndPrint(timeSinceParent, 1000000, 0), 320423332);
        assertEq(_getBasefeeAndPrint(timeSinceParent, 5000000, 0), 332018053);
        assertEq(_getBasefeeAndPrint(timeSinceParent, 10000000, 0), 347305199);

        timeSinceParent = uint32(100 + block.timestamp - L2.parentTimestamp());
        assertEq(_getBasefeeAndPrint(timeSinceParent, 0, 0), 54544902);
        assertEq(_getBasefeeAndPrint(timeSinceParent, 1, 0), 54544902);
        assertEq(_getBasefeeAndPrint(timeSinceParent, 1000000, 0), 55028221);
        assertEq(_getBasefeeAndPrint(timeSinceParent, 5000000, 0), 57019452);
        assertEq(_getBasefeeAndPrint(timeSinceParent, 10000000, 0), 59644805);
    }

    function _getBasefeeAndPrint(uint32 timeSinceParent, uint64 gasLimit, uint64 parentGasUsed)
        private
        returns (uint256 _basefee)
    {
        uint256 gasIssued = L2.gasIssuedPerSecond() * timeSinceParent;
        string memory _msg = string.concat(
            "#",
            Strings.toString(logIndex++),
            ": gasExcess=",
            Strings.toString(L2.gasExcess()),
            ", timeSinceParent=",
            Strings.toString(timeSinceParent),
            ", gasIssued=",
            Strings.toString(gasIssued),
            ", gasLimit=",
            Strings.toString(gasLimit),
            ", parentGasUsed=",
            Strings.toString(parentGasUsed)
        );
        _basefee = L2.getBasefee(timeSinceParent, gasLimit, parentGasUsed);
        assertTrue(_basefee != 0);

        _msg = string.concat(
            _msg,
            ", gasExcess(changed)=",
            Strings.toString(L2.gasExcess()),
            ", basefee=",
            Strings.toString(_basefee)
        );

        console2.log(_msg);
    }

    function _getBasefeeAndPrint(uint32 timeSinceNow, uint64 gasLimit)
        private
        returns (uint256 _basefee)
    {
        return _getBasefeeAndPrint(
            uint32(timeSinceNow + block.timestamp - L2.parentTimestamp()),
            gasLimit,
            gasLimit + ANCHOR_GAS_COST
        );
    }

    function _anchor(uint64 parentGasLimit) private {
        L2.anchor(keccak256("a"), keccak256("b"), 12345, parentGasLimit + ANCHOR_GAS_COST);
    }
}
