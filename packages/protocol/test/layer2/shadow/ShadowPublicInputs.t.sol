// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IShadow} from "../src/iface/IShadow.sol";
import {ShadowPublicInputs} from "../src/lib/ShadowPublicInputs.sol";

/// @dev Test harness to expose library functions with calldata parameters.
contract ShadowPublicInputsHarness {
    function toArray(IShadow.PublicInput calldata _input) external pure returns (uint256[] memory) {
        return ShadowPublicInputs.toArray(_input);
    }

    function powDigestIsValid(bytes32 _powDigest) external pure returns (bool) {
        return ShadowPublicInputs.powDigestIsValid(_powDigest);
    }
}

contract ShadowPublicInputsTest is Test {
    ShadowPublicInputsHarness internal harness;

    function setUp() public {
        harness = new ShadowPublicInputsHarness();
    }
    /// @notice Test serialization against known vector to ensure circuit compatibility.
    /// @dev This test verifies the exact byte layout documented in docs/CIRCUIT_PUBLIC_INPUTS.md
    function test_toArray_serializationVector() external view {
        // Known test vector
        uint48 blockNumber = 12345;
        bytes32 stateRoot = hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
        uint256 chainId = 1;
        uint256 noteIndex = 7;
        uint256 amount = 1 ether;
        address recipient = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
        bytes32 nullifier = hex"2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40";
        // powDigest with trailing 24 zero bits (last 3 bytes = 0)
        bytes32 powDigest = hex"4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c00000000";

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: chainId,
            noteIndex: noteIndex,
            amount: amount,
            recipient: recipient,
            nullifier: nullifier,
            powDigest: powDigest
        });

        uint256[] memory result = harness.toArray(input);

        // Verify total length
        assertEq(result.length, 120, "Public inputs length should be 120");

        // Index 0: blockNumber as field element
        assertEq(result[0], 12345, "blockNumber mismatch");

        // Index 1-32: stateRoot bytes (big-endian)
        assertEq(result[1], 0x01, "stateRoot[0] mismatch");
        assertEq(result[2], 0x02, "stateRoot[1] mismatch");
        assertEq(result[32], 0x20, "stateRoot[31] mismatch");

        // Index 33: chainId as field element
        assertEq(result[33], 1, "chainId mismatch");

        // Index 34: noteIndex as field element
        assertEq(result[34], 7, "noteIndex mismatch");

        // Index 35: amount as field element
        assertEq(result[35], 1 ether, "amount mismatch");

        // Index 36-55: recipient bytes (big-endian)
        // 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF
        assertEq(result[36], 0xDE, "recipient[0] mismatch");
        assertEq(result[37], 0xAD, "recipient[1] mismatch");
        assertEq(result[38], 0xBE, "recipient[2] mismatch");
        assertEq(result[39], 0xEF, "recipient[3] mismatch");
        assertEq(result[55], 0xEF, "recipient[19] mismatch");

        // Index 56-87: nullifier bytes (big-endian)
        assertEq(result[56], 0x21, "nullifier[0] mismatch");
        assertEq(result[57], 0x22, "nullifier[1] mismatch");
        assertEq(result[87], 0x40, "nullifier[31] mismatch");

        // Index 88-119: powDigest bytes (big-endian)
        assertEq(result[88], 0x41, "powDigest[0] mismatch");
        assertEq(result[89], 0x42, "powDigest[1] mismatch");
        // Trailing zeros (PoW requirement)
        assertEq(result[117], 0x00, "powDigest[29] should be 0");
        assertEq(result[118], 0x00, "powDigest[30] should be 0");
        assertEq(result[119], 0x00, "powDigest[31] should be 0");
    }

    /// @notice Test that powDigestIsValid correctly validates trailing zeros.
    function test_powDigestIsValid_trailingZeros() external view {
        // Valid: trailing 24 bits are zero
        bytes32 valid1 = bytes32(uint256(1) << 24); // 0x...01000000
        bytes32 valid2 = bytes32(uint256(0xFF) << 24); // 0x...FF000000
        bytes32 valid3 = bytes32(uint256(0xABCDEF) << 24);

        assertTrue(harness.powDigestIsValid(valid1), "valid1 should pass");
        assertTrue(harness.powDigestIsValid(valid2), "valid2 should pass");
        assertTrue(harness.powDigestIsValid(valid3), "valid3 should pass");

        // Invalid: trailing bits not all zero
        bytes32 invalid1 = bytes32(uint256(1)); // LSB is 1
        bytes32 invalid2 = bytes32(uint256(0x800000)); // bit 23 is set
        bytes32 invalid3 = bytes32(uint256(0xFFFFFF)); // all trailing 24 bits set

        assertFalse(harness.powDigestIsValid(invalid1), "invalid1 should fail");
        assertFalse(harness.powDigestIsValid(invalid2), "invalid2 should fail");
        assertFalse(harness.powDigestIsValid(invalid3), "invalid3 should fail");
    }

    /// @notice Test edge case: maximum values.
    function test_toArray_maxValues() external view {
        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: type(uint48).max,
            stateRoot: bytes32(type(uint256).max),
            chainId: type(uint256).max,
            noteIndex: type(uint256).max,
            amount: type(uint256).max,
            recipient: address(type(uint160).max),
            nullifier: bytes32(type(uint256).max),
            powDigest: bytes32(type(uint256).max - 0xFFFFFF) // Valid PoW with trailing zeros
        });

        uint256[] memory result = harness.toArray(input);

        assertEq(result.length, 120, "Length should be 120");
        assertEq(result[0], type(uint48).max, "Max blockNumber");
        assertEq(result[33], type(uint256).max, "Max chainId");

        // All stateRoot bytes should be 0xFF
        for (uint256 i = 1; i <= 32; i++) {
            assertEq(result[i], 0xFF, "stateRoot byte should be 0xFF");
        }

        // All recipient bytes should be 0xFF
        for (uint256 i = 36; i <= 55; i++) {
            assertEq(result[i], 0xFF, "recipient byte should be 0xFF");
        }
    }
}
