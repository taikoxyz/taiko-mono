// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoL2} from "../contracts/L2/TaikoL2.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestTaikoL2 is Test {
    using SafeCastUpgradeable for uint256;

    TaikoL2 public L2;

    function setUp() public {
        uint16 rand = 2;
        TaikoL2.EIP1559Params memory param1559 = TaikoL2.EIP1559Params({
            basefee: (uint(5000000000) * rand).toUint64(),
            gasIssuedPerSecond: 1000000,
            gasExcessMax: (uint(15000000) * 256 * rand).toUint64(),
            gasTarget: (uint(6000000) * rand).toUint64(),
            ratio2x1x: 111
        });

        L2 = new TaikoL2();
        L2.init(address(1), param1559); // Dummy address manager address.
        vm.roll(block.number + 1);

        console2.log("basefee =", uint256(L2.basefee()));
        console2.log("xscale =", uint256(L2.xscale()));
        console2.log("yscale =", uint256(L2.yscale()));
        console2.log("gasExcess =", uint256(L2.gasExcess()));
    }

    function testAnchorTxsMultiple() external {
        uint32 gasLimit = 30000000; // same as `block_gas_limit` in foundry.toml
        for (uint256 i = 0; i < 100; i++) {
            console2.log("i:", i);

            uint64 expectedBasefee = L2.getBasefee(0, gasLimit);
            console2.log("-----------__-,,,,");

            vm.fee(expectedBasefee);
            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            L2.anchor(12345, keccak256("a"), keccak256("b"));
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 20 * i);
        }
    }

    // calling anchor in the same block more than once should fail
    function testAnchorTxsFailInTheSameBlock() external {
        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        L2.anchor(12345, keccak256("a"), keccak256("b"));

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert();
        L2.anchor(12345, keccak256("a"), keccak256("b"));
    }

    // calling anchor in the same block more than once should fail
    function testAnchorTxsFailByNonTaikoL2Signer() external {
        vm.expectRevert();
        L2.anchor(12345, keccak256("a"), keccak256("b"));
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
}
