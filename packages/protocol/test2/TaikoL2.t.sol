// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/L2/TaikoL2.sol";

contract ReadBlockhashVsCalldata is Test {
    TaikoL2 public L2;

    function setUp() public {
        L2 = new TaikoL2();
        L2.init(address(1)); // Dummy address manager address.
        vm.roll(block.number + 1);
    }

    function testAnchorTxs() external {
        for (uint256 i = 0; i < 1000; i++) {
            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            L2.anchor(12345, keccak256("a"), keccak256("b"));
            vm.roll(block.number + 1);
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
