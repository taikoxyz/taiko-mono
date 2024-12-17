// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/console2.sol";

import "src/shared/libs/LibBytes.sol";
import "../CommonTest.sol";

contract TestLibBytes is CommonTest {
    function test_LibBytes_toString_largeThan64ByteString() public pure {
        bytes memory abiEncodedString = abi.encode("Test String");
        string memory result = LibBytes.toString(abiEncodedString);
        assertEq(result, "Test String");
    }

    function test_LibBytes_toString_32ByteFixedString() public pure {
        bytes memory fixedString = new bytes(32);
        for (uint8 i = 0; i < 10; i++) {
            fixedString[i] = bytes1(uint8(65 + i));
        }
        string memory result = LibBytes.toString(fixedString);
        assertEq(result, "ABCDEFGHIJ");
    }

    function test_LibBytes_toString_emptyData() public pure {
        bytes memory emptyData = new bytes(0);
        string memory result = LibBytes.toString(emptyData);
        assertEq(result, "");

        bytes memory fixedString = new bytes(33);
        for (uint8 i = 0; i < 10; i++) {
            fixedString[i] = bytes1(uint8(65 + i));
        }
        result = LibBytes.toString(fixedString);
        assertEq(result, "");
    }

    function test_LibBytes_revertWithExtractedError_validRevertData() public {
        string memory expectedMessage = "Custom error message";
        bytes memory revertData = abi.encodeWithSignature("Error(string)", expectedMessage);
        vm.expectRevert(bytes(expectedMessage));
        LibBytes.revertWithExtractedError(revertData);
    }

    function test_LibBytes_revertWithExtractedError_malformedData() public {
        // Length < 68
        bytes memory malformedData = hex"1234";
        vm.expectRevert(abi.encodeWithSelector(LibBytes.INNER_ERROR.selector, malformedData));
        LibBytes.revertWithExtractedError(malformedData);
    }

    function test_LibBytes_revertWithExtractedError_noRevertMessage() public {
        bytes memory emptyRevertData = new bytes(68);
        vm.expectRevert(bytes(""));
        LibBytes.revertWithExtractedError(emptyRevertData);
    }
}
