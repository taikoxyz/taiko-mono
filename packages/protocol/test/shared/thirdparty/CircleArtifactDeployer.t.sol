// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { CircleArtifactDeployer } from "script/shared/circle/CircleArtifactDeployer.sol";

contract CircleArtifactDeployerHarness is CircleArtifactDeployer {
    function hexStringToBytes(string memory rawHex) external pure returns (bytes memory decoded_) {
        return _hexStringToBytes(rawHex);
    }
}

contract TestCircleArtifactDeployer is Test {
    CircleArtifactDeployerHarness private harness;

    function setUp() public {
        harness = new CircleArtifactDeployerHarness();
    }

    function test_hexStringToBytes_decodesLowercaseHex() public view {
        assertEq(harness.hexStringToBytes("0x1234"), hex"1234");
    }

    function test_hexStringToBytes_decodesUppercaseHex() public view {
        assertEq(harness.hexStringToBytes("0xABCD"), hex"abcd");
    }

    function test_hexStringToBytes_revertsOnMissingPrefix() public {
        vm.expectRevert(bytes("CIRCLE_INVALID_HEX"));
        harness.hexStringToBytes("1234");
    }

    function test_hexStringToBytes_revertsOnOddLength() public {
        vm.expectRevert(bytes("CIRCLE_INVALID_HEX_LENGTH"));
        harness.hexStringToBytes("0x123");
    }

    function test_hexStringToBytes_revertsOnInvalidCharacter() public {
        vm.expectRevert(bytes("CIRCLE_INVALID_HEX_CHAR"));
        harness.hexStringToBytes("0x12gg");
    }
}
