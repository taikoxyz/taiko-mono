// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { TaikoL1 } from "../../contracts/L1/TaikoL1.sol";
import { SgxVerifier } from "../../contracts/L1/verifiers/SgxVerifier.sol";
import { TaikoL1TestBase } from "./TaikoL1TestBase.sol";

contract TestSgxVerifier is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
    }

    function test_addInstanceByOwner() external {
        sv.addInstance(SGX_X_1);
        sv.addInstance(SGX_Y);
        sv.addInstance(SGX_Z);
    }

    function test_addInstanceByOwner_WithoutOwnerRole() external {
        vm.expectRevert();
        vm.prank(Bob, Bob);
        sv.addInstance(SGX_X_0);
        vm.prank(Bob, Bob);
        sv.addInstance(SGX_Y);
        vm.prank(Bob, Bob);
        sv.addInstance(SGX_Z);
    }

    function test_addInstanceBySgxInstance() external {
        address[] memory newInstances = new address[](3);
        newInstances[0] = SGX_X_1;
        newInstances[1] = SGX_Y;
        newInstances[2] = SGX_Z;

        vm.prank(Bob, Bob);
        sv.addInstanceBySgx(1, _sign(0x4, newInstances), newInstances);
    }

    function _sign(
        uint256 privKey,
        address[] memory newInstances
    )
        public
        pure
        returns (bytes memory signature)
    {
        bytes32 hash = keccak256(abi.encode("ADD_NEW_INSTANCES", newInstances));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, hash);
        signature = abi.encodePacked(r, s, v);
    }
}
