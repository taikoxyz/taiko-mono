// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@oz/utils/Strings.sol";
import { SafeCastUpgradeable } from "@ozu/utils/math/SafeCastUpgradeable.sol";
import { TestBase } from "../TestBase.sol";
import { TaikoL2 } from "../../contracts/L2/TaikoL2.sol";

contract TaikoL2NoBasefeeCheck is TaikoL2 {
    function getConfig() public pure override returns (Config memory config) {
        config.blockGasTarget = 20_000_000;
        config.minBasefee = 1_000_000_000 / 10_000; // 1/10000 Gwei;
        config.checkBasefee = false;
    }
}

contract TestTaikoL2 is TestBase {
    using SafeCastUpgradeable for uint256;

    // same as `block_gas_limit` in foundry.toml
    uint32 public constant GAS_USED = 30_000_000;

    TaikoL2 public L2;

    function setUp() public {
        L2 = new TaikoL2NoBasefeeCheck();
        address dummyAddressManager = getRandomAddress();
        uint64 basefee = 10 * 1_000_000_000; // 10 Gwei
        L2.init(dummyAddressManager, basefee);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);
    }

    function test_L2_AnchorTxs() external {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchor(GAS_USED);
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 30);
        }
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_in_same_block() external {
        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        _anchor(GAS_USED);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(); // L2_PUBLIC_INPUT_HASH_MISMATCH
        _anchor(GAS_USED);
    }

    // skip over a block without Anchor will also fail
    function test_L2_AnchorTx_revert_if_skip_anchor() external {
        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        _anchor(GAS_USED);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(); // L2_PUBLIC_INPUT_HASH_MISMATCH
        _anchor(GAS_USED);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_from_wrong_signer() external {
        vm.expectRevert();
        _anchor(GAS_USED);
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

    function _anchor(uint32 parentGasUsed) private {
        bytes32 l1Hash = getRandomBytes32();
        bytes32 l1SignalRoot = getRandomBytes32();
        L2.anchor(l1Hash, l1SignalRoot, 12_345, parentGasUsed);
    }
}
