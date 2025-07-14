// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecProverAuthTest is Test {
    using LibCodec for IInbox.ProverAuth;

    // Test constants
    address private constant TEST_PROVER = address(0x1234567890123456789012345678901234567890);
    address private constant TEST_FEE_TOKEN = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
    uint48 private constant TEST_FEE = 1000; // in Gwei
    uint48 private constant TEST_VALID_UNTIL = 2000;
    uint48 private constant TEST_BATCH_ID = 3000;
    bytes private constant TEST_SIGNATURE = hex"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12";

    // -------------------------------------------------------------------------
    // Tests for packProverAuth
    // -------------------------------------------------------------------------

    function test_packProverAuth_basic() public view {
        // Create a ProverAuth struct
        IInbox.ProverAuth memory auth = IInbox.ProverAuth({
            prover: TEST_PROVER,
            feeToken: TEST_FEE_TOKEN,
            fee: TEST_FEE,
            validUntil: TEST_VALID_UNTIL,
            batchId: TEST_BATCH_ID,
            signature: TEST_SIGNATURE
        });

        // Pack the ProverAuth
        bytes memory packed = LibCodec.packProverAuth(auth);

        // Verify the packed length (58 bytes fixed + signature length)
        assertEq(packed.length, 58 + TEST_SIGNATURE.length, "Invalid packed length");

        // Verify fixed fields
        assertEq(_extractAddress(packed, 0), TEST_PROVER, "Invalid prover");
        assertEq(_extractAddress(packed, 20), TEST_FEE_TOKEN, "Invalid feeToken");
        assertEq(_extractUint48(packed, 40), TEST_FEE, "Invalid fee");
        assertEq(_extractUint48(packed, 46), TEST_VALID_UNTIL, "Invalid validUntil");
        assertEq(_extractUint48(packed, 52), TEST_BATCH_ID, "Invalid batchId");

        // Verify signature
        bytes memory packedSignature = _extractBytes(packed, 58, TEST_SIGNATURE.length);
        assertEq(keccak256(packedSignature), keccak256(TEST_SIGNATURE), "Invalid signature");
    }

    function test_packProverAuth_emptySignature() public view {
        // Create a ProverAuth struct with empty signature
        IInbox.ProverAuth memory auth = IInbox.ProverAuth({
            prover: TEST_PROVER,
            feeToken: TEST_FEE_TOKEN,
            fee: TEST_FEE,
            validUntil: TEST_VALID_UNTIL,
            batchId: TEST_BATCH_ID,
            signature: ""
        });

        // Pack the ProverAuth
        bytes memory packed = LibCodec.packProverAuth(auth);

        // Verify the packed length (58 bytes fixed + 0 for empty signature)
        assertEq(packed.length, 58, "Invalid packed length");
    }

    function test_packProverAuth_zeroValues() public view {
        // Create a ProverAuth struct with zero values
        IInbox.ProverAuth memory auth = IInbox.ProverAuth({
            prover: address(0),
            feeToken: address(0),
            fee: 0,
            validUntil: 0,
            batchId: 0,
            signature: TEST_SIGNATURE
        });

        // Pack the ProverAuth
        bytes memory packed = LibCodec.packProverAuth(auth);

        // Verify zero values are preserved
        assertEq(_extractAddress(packed, 0), address(0), "Invalid prover");
        assertEq(_extractAddress(packed, 20), address(0), "Invalid feeToken");
        assertEq(_extractUint48(packed, 40), 0, "Invalid fee");
        assertEq(_extractUint48(packed, 46), 0, "Invalid validUntil");
        assertEq(_extractUint48(packed, 52), 0, "Invalid batchId");
    }

    // -------------------------------------------------------------------------
    // Tests for unpackProverAuth
    // -------------------------------------------------------------------------

    function test_unpackProverAuth_basic() public view {
        // Create and pack a ProverAuth struct
        IInbox.ProverAuth memory originalAuth = IInbox.ProverAuth({
            prover: TEST_PROVER,
            feeToken: TEST_FEE_TOKEN,
            fee: TEST_FEE,
            validUntil: TEST_VALID_UNTIL,
            batchId: TEST_BATCH_ID,
            signature: TEST_SIGNATURE
        });

        bytes memory packed = LibCodec.packProverAuth(originalAuth);

        // Unpack the ProverAuth
        IInbox.ProverAuth memory unpackedAuth = LibCodec.unpackProverAuth(packed);

        // Verify all fields match
        assertEq(unpackedAuth.prover, originalAuth.prover, "Prover mismatch");
        assertEq(unpackedAuth.feeToken, originalAuth.feeToken, "FeeToken mismatch");
        assertEq(unpackedAuth.fee, originalAuth.fee, "Fee mismatch");
        assertEq(unpackedAuth.validUntil, originalAuth.validUntil, "ValidUntil mismatch");
        assertEq(unpackedAuth.batchId, originalAuth.batchId, "BatchId mismatch");
        assertEq(keccak256(unpackedAuth.signature), keccak256(originalAuth.signature), "Signature mismatch");
    }

    function test_unpackProverAuth_emptySignature() public view {
        // Create and pack a ProverAuth struct with empty signature
        IInbox.ProverAuth memory originalAuth = IInbox.ProverAuth({
            prover: TEST_PROVER,
            feeToken: TEST_FEE_TOKEN,
            fee: TEST_FEE,
            validUntil: TEST_VALID_UNTIL,
            batchId: TEST_BATCH_ID,
            signature: ""
        });

        bytes memory packed = LibCodec.packProverAuth(originalAuth);

        // Unpack the ProverAuth
        IInbox.ProverAuth memory unpackedAuth = LibCodec.unpackProverAuth(packed);

        // Verify empty signature
        assertEq(unpackedAuth.signature.length, 0, "Signature should be empty");
    }

    function test_unpackProverAuth_revertInvalidLength() public {
        // Create a packed byte array that's too short
        bytes memory packed = new bytes(57); // One byte short

        // Should revert with InvalidDataLength error
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackProverAuth(packed);
    }

    function test_packProverAuth_revertSignatureTooLong() public {
        // Create a ProverAuth struct with signature longer than uint10 max (1023)
        bytes memory longSignature = new bytes(1024); // Too long

        IInbox.ProverAuth memory auth = IInbox.ProverAuth({
            prover: TEST_PROVER,
            feeToken: TEST_FEE_TOKEN,
            fee: TEST_FEE,
            validUntil: TEST_VALID_UNTIL,
            batchId: TEST_BATCH_ID,
            signature: longSignature
        });

        // Should revert with ProverAuthSignatureTooLarge error
        vm.expectRevert(LibCodec.ProverAuthSignatureTooLarge.selector);
        LibCodec.packProverAuth(auth);
    }

    function test_packProverAuth_maxSignatureLength() public view {
        // Create a ProverAuth struct with signature at uint10 max (1023)
        bytes memory maxSignature = new bytes(1023); // Exactly at the limit

        IInbox.ProverAuth memory auth = IInbox.ProverAuth({
            prover: TEST_PROVER,
            feeToken: TEST_FEE_TOKEN,
            fee: TEST_FEE,
            validUntil: TEST_VALID_UNTIL,
            batchId: TEST_BATCH_ID,
            signature: maxSignature
        });

        // Should succeed
        bytes memory packed = LibCodec.packProverAuth(auth);
        assertEq(packed.length, 58 + 1023, "Invalid packed length for max signature");

        // Verify round-trip
        IInbox.ProverAuth memory unpacked = LibCodec.unpackProverAuth(packed);
        assertEq(unpacked.signature.length, 1023, "Signature length mismatch");
    }

    // -------------------------------------------------------------------------
    // Fuzz tests
    // -------------------------------------------------------------------------

    function testFuzz_packUnpackProverAuth(
        address prover,
        address feeToken,
        uint48 fee,
        uint48 validUntil,
        uint48 batchId,
        bytes memory signature
    ) public view {
        // Limit signature length to uint10 max (1023)
        vm.assume(signature.length <= 1023);

        // Create a ProverAuth struct
        IInbox.ProverAuth memory originalAuth = IInbox.ProverAuth({
            prover: prover,
            feeToken: feeToken,
            fee: fee,
            validUntil: validUntil,
            batchId: batchId,
            signature: signature
        });

        // Pack and unpack
        bytes memory packed = LibCodec.packProverAuth(originalAuth);
        IInbox.ProverAuth memory unpackedAuth = LibCodec.unpackProverAuth(packed);

        // Verify all fields match
        assertEq(unpackedAuth.prover, originalAuth.prover, "Prover mismatch");
        assertEq(unpackedAuth.feeToken, originalAuth.feeToken, "FeeToken mismatch");
        assertEq(unpackedAuth.fee, originalAuth.fee, "Fee mismatch");
        assertEq(unpackedAuth.validUntil, originalAuth.validUntil, "ValidUntil mismatch");
        assertEq(unpackedAuth.batchId, originalAuth.batchId, "BatchId mismatch");
        assertEq(keccak256(unpackedAuth.signature), keccak256(originalAuth.signature), "Signature mismatch");
    }

    // -------------------------------------------------------------------------
    // Gas benchmarks
    // -------------------------------------------------------------------------

    function test_packProverAuth_gas() public {
        IInbox.ProverAuth memory auth = IInbox.ProverAuth({
            prover: TEST_PROVER,
            feeToken: TEST_FEE_TOKEN,
            fee: TEST_FEE,
            validUntil: TEST_VALID_UNTIL,
            batchId: TEST_BATCH_ID,
            signature: TEST_SIGNATURE
        });

        uint256 gasBefore = gasleft();
        LibCodec.packProverAuth(auth);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for packProverAuth", gasUsed);
    }

    function test_unpackProverAuth_gas() public {
        IInbox.ProverAuth memory auth = IInbox.ProverAuth({
            prover: TEST_PROVER,
            feeToken: TEST_FEE_TOKEN,
            fee: TEST_FEE,
            validUntil: TEST_VALID_UNTIL,
            batchId: TEST_BATCH_ID,
            signature: TEST_SIGNATURE
        });

        bytes memory packed = LibCodec.packProverAuth(auth);

        uint256 gasBefore = gasleft();
        LibCodec.unpackProverAuth(packed);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for unpackProverAuth", gasUsed);
    }

    // -------------------------------------------------------------------------
    // Helper functions
    // -------------------------------------------------------------------------

    function _extractAddress(bytes memory data, uint256 offset) private pure returns (address) {
        require(data.length >= offset + 20, "Invalid offset for address");
        address result;
        assembly {
            result := shr(96, mload(add(add(data, 0x20), offset)))
        }
        return result;
    }

    function _extractUint48(bytes memory data, uint256 offset) private pure returns (uint48) {
        require(data.length >= offset + 6, "Invalid offset for uint48");
        uint48 result;
        assembly {
            result := shr(208, mload(add(add(data, 0x20), offset)))
        }
        return result;
    }

    function _extractBytes(bytes memory data, uint256 offset, uint256 length) private pure returns (bytes memory) {
        require(data.length >= offset + length, "Invalid offset/length for bytes");
        bytes memory result = new bytes(length);
        assembly {
            let dataPtr := add(add(data, 0x20), offset)
            let resultPtr := add(result, 0x20)
            for { let i := 0 } lt(i, length) { i := add(i, 32) } {
                let chunk := mload(add(dataPtr, i))
                mstore(add(resultPtr, i), chunk)
            }
        }
        return result;
    }
}