// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TestBase } from "../TestBase.sol";
import { TaikoL2 } from "../../contracts/L2/TaikoL2.sol";

contract TestTaikoL2 is TestBase {
    using SafeCastUpgradeable for uint256;

    // same as `block_gas_limit` in foundry.toml
    uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;

    TaikoL2 public L2;
    uint256 private logIndex;

    function setUp() public {
        uint16 rand = 2;
        TaikoL2.EIP1559Params memory param1559 = TaikoL2.EIP1559Params({
            basefee: (uint256(BLOCK_GAS_LIMIT * 10) * rand).toUint64(),
            gasIssuedPerSecond: 1_000_000,
            gasExcessMax: (uint256(15_000_000) * 256 * rand).toUint64(),
            gasTarget: (uint256(6_000_000) * rand).toUint64(),
            ratio2x1x: 11_177
        });

        L2 = new TaikoL2();
        address dummyAddressManager = getRandomAddress();
        L2.init(dummyAddressManager, param1559);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);
    }

    function test_L2_AnchorTx_with_constant_block_time() external {
        uint256 firstBasefee;
        for (uint256 i = 0; i < 100; i++) {
            uint256 basefee = _getBasefeeAndPrint2(0, BLOCK_GAS_LIMIT);
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

    function test_L2_AnchorTx_with_decreasing_block_time() external {
        uint256 prevBasefee;

        for (uint256 i = 0; i < 32; i++) {
            uint256 basefee = _getBasefeeAndPrint2(0, BLOCK_GAS_LIMIT);
            vm.fee(basefee);

            assertGe(basefee, prevBasefee);
            prevBasefee = basefee;

            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchor(BLOCK_GAS_LIMIT);

            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 30 - i);
        }
    }

    function test_L2_AnchorTx_with_increasing_block_time() external {
        uint256 prevBasefee;

        for (uint256 i = 0; i < 30; i++) {
            uint256 basefee = _getBasefeeAndPrint2(0, BLOCK_GAS_LIMIT);
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
    function test_L2_AnchorTx_revert_in_same_block() external {
        uint256 expectedBasefee = _getBasefeeAndPrint2(0, BLOCK_GAS_LIMIT);
        vm.fee(expectedBasefee);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        _anchor(BLOCK_GAS_LIMIT);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(); // L2_PUBLIC_INPUT_HASH_MISMATCH
        _anchor(BLOCK_GAS_LIMIT);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_from_wrong_signer() external {
        uint256 expectedBasefee = _getBasefeeAndPrint2(0, BLOCK_GAS_LIMIT);
        vm.fee(expectedBasefee);
        vm.expectRevert();
        _anchor(BLOCK_GAS_LIMIT);
    }

    function test_L2_AnchorTx_signing(bytes32 digest) external {
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

    function test_L2_getBasefee() external {
        uint64 timeSinceParent = uint64(block.timestamp - L2.parentTimestamp());
        assertEq(_getBasefeeAndPrint(timeSinceParent, 0), 317_609_019);

        timeSinceParent += 100;
        assertEq(_getBasefeeAndPrint(timeSinceParent, 0), 54_544_902);

        timeSinceParent += 10_000;
        assertEq(_getBasefeeAndPrint(timeSinceParent, 0), 1);
    }

    function _getBasefeeAndPrint(
        uint64 timeSinceParent,
        uint32 parentGasUsed
    )
        private
        returns (uint256 _basefee)
    {
        uint256 gasIssued =
            L2.getEIP1559Config().gasIssuedPerSecond * timeSinceParent;
        string memory _msg = string.concat(
            "#",
            Strings.toString(logIndex++),
            ": gasExcess=",
            Strings.toString(L2.gasExcess()),
            ", timeSinceParent=",
            Strings.toString(timeSinceParent),
            ", gasIssued=",
            Strings.toString(gasIssued),
            ", parentGasUsed=",
            Strings.toString(parentGasUsed)
        );
        _basefee = L2.getBasefee(timeSinceParent, parentGasUsed);
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

    function _getBasefeeAndPrint2(
        uint32 timeSinceNow,
        uint32 gasLimit
    )
        private
        returns (uint256 _basefee)
    {
        return _getBasefeeAndPrint(
            uint32(timeSinceNow + block.timestamp - L2.parentTimestamp()),
            gasLimit
        );
    }

    function _anchor(uint32 parentGasLimit) private {
        bytes32 l1Hash = getRandomBytes32();
        bytes32 l1SignalRoot = getRandomBytes32();
        L2.anchor(l1Hash, l1SignalRoot, 12_345, parentGasLimit);
    }
}
