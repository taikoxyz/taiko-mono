// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { TaikoL1 } from "../../contracts/L1/TaikoL1.sol";
import { SGXVerifier } from "../../contracts/L1/verifiers/SGXVerifier.sol";
import { TaikoL1TestBase } from "./TaikoL1TestBase.sol";

contract SgxVerifier is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
    }

    function test_addToRegistryByOwner() external {
        address[] memory trustedInstances = new address[](3);
        trustedInstances[0] = SGX_X_1;
        trustedInstances[1] = SGX_Y;
        trustedInstances[2] = SGX_Z;
        sv.registerInstance(trustedInstances);
    }

    function test_addToRegistryByOwner_WithoutOwnerRole() external {
        address[] memory trustedInstances = new address[](3);
        trustedInstances[0] = SGX_X_0;
        trustedInstances[1] = SGX_Y;
        trustedInstances[2] = SGX_Z;

        vm.expectRevert();
        vm.prank(Bob, Bob);
        sv.registerInstance(trustedInstances);
    }

    function test_addToRegistryBySgxInstance() external {
        address[] memory trustedInstances = new address[](2);
        trustedInstances[0] = SGX_Y;
        trustedInstances[1] = SGX_Z;

        bytes memory signature =
            createAddRegistrySignature(SGX_X_1, trustedInstances, 0x4);

        vm.prank(Bob, Bob);
        sv.registerBySgxInstance(SGX_X_1, trustedInstances, signature);
    }

    function createAddRegistrySignature(
        address newAddress,
        address[] memory trustedInstances,
        uint256 privKey
    )
        public
        pure
        returns (bytes memory signature)
    {
        bytes32 digest = keccak256(
            abi.encode("REGISTER_SGX_INSTANCE", newAddress, trustedInstances)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
