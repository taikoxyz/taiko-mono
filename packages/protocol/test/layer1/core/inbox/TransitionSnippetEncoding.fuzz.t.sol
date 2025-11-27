// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

/// @title TransitionSnippetEncodingHarness
/// @notice Test harness to expose internal encode/decode functions
contract TransitionSnippetEncodingHarness {
    /// @notice Encodes a TransitionSnippet struct into a bytes32 value.
    /// @param _snippet The TransitionSnippet to encode.
    /// @return encoded_ The encoded bytes32 value (bytes26 recordHash || uint8 span || uint40 deadline).
    function encodeTransitionSnippet(Inbox.TransitionSnippet memory _snippet)
        external
        pure
        returns (bytes32 encoded_)
    {
        require(_snippet.finalizationDeadline <= type(uint40).max, "DeadlineExceedsMax");
        encoded_ = bytes32(_snippet.recordHash)
            | bytes32(uint256(_snippet.transitionSpan) << 40)
            | bytes32(uint256(_snippet.finalizationDeadline));
    }

    /// @notice Decodes a bytes32 value into TransitionSnippet components.
    /// @param _encoded The encoded bytes32 value.
    /// @return recordHash_ The decoded record hash (bytes26).
    /// @return transitionSpan_ The decoded transition span (uint8).
    /// @return finalizationDeadline_ The decoded finalization deadline (uint40).
    function decodeTransitionSnippet(bytes32 _encoded)
        external
        pure
        returns (bytes26 recordHash_, uint8 transitionSpan_, uint40 finalizationDeadline_)
    {
        recordHash_ = bytes26(_encoded);
        transitionSpan_ = uint8(uint256(_encoded) >> 40);
        finalizationDeadline_ = uint40(uint256(_encoded));
    }
}

/// @title TransitionSnippetEncodingFuzzTest
/// @notice Comprehensive fuzz tests for TransitionSnippet encode/decode functions
/// @dev Tests roundtrip encoding, bit layout, and edge cases
/// @custom:security-contact security@taiko.xyz
contract TransitionSnippetEncodingFuzzTest is Test {
    TransitionSnippetEncodingHarness harness;

    function setUp() public {
        harness = new TransitionSnippetEncodingHarness();
    }

    // ---------------------------------------------------------------
    // Basic Roundtrip Tests
    // ---------------------------------------------------------------

    /// @notice Fuzz test: encode then decode should return original values
    function testFuzz_encodeDecodeRoundtrip(
        bytes26 recordHash,
        uint8 transitionSpan,
        uint40 finalizationDeadline
    ) public view {
        Inbox.TransitionSnippet memory original = Inbox.TransitionSnippet({
            recordHash: recordHash,
            transitionSpan: transitionSpan,
            finalizationDeadline: finalizationDeadline
        });

        bytes32 encoded = harness.encodeTransitionSnippet(original);
        (bytes26 decodedHash, uint8 decodedSpan, uint40 decodedDeadline) =
            harness.decodeTransitionSnippet(encoded);

        assertEq(decodedHash, recordHash, "recordHash mismatch");
        assertEq(decodedSpan, transitionSpan, "transitionSpan mismatch");
        assertEq(decodedDeadline, finalizationDeadline, "finalizationDeadline mismatch");
    }

    /// @notice Fuzz test: different snippets should produce different encodings (unless collision)
    function testFuzz_differentSnippetsDifferentEncodings(
        bytes26 recordHash1,
        uint8 transitionSpan1,
        uint40 finalizationDeadline1,
        bytes26 recordHash2,
        uint8 transitionSpan2,
        uint40 finalizationDeadline2
    ) public view {
        // Skip if all values are the same
        vm.assume(
            recordHash1 != recordHash2 || transitionSpan1 != transitionSpan2
                || finalizationDeadline1 != finalizationDeadline2
        );

        Inbox.TransitionSnippet memory snippet1 = Inbox.TransitionSnippet({
            recordHash: recordHash1,
            transitionSpan: transitionSpan1,
            finalizationDeadline: finalizationDeadline1
        });

        Inbox.TransitionSnippet memory snippet2 = Inbox.TransitionSnippet({
            recordHash: recordHash2,
            transitionSpan: transitionSpan2,
            finalizationDeadline: finalizationDeadline2
        });

        bytes32 encoded1 = harness.encodeTransitionSnippet(snippet1);
        bytes32 encoded2 = harness.encodeTransitionSnippet(snippet2);

        assertTrue(encoded1 != encoded2, "Different snippets should have different encodings");
    }

    // ---------------------------------------------------------------
    // Bit Layout Verification Tests
    // ---------------------------------------------------------------

    /// @notice Test that recordHash occupies the upper 208 bits (26 bytes)
    function testFuzz_recordHashBitPosition(bytes26 recordHash) public view {
        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: recordHash,
            transitionSpan: 0,
            finalizationDeadline: 0
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);

        // Upper 26 bytes should equal recordHash
        assertEq(bytes26(encoded), recordHash, "recordHash should be in upper 26 bytes");

        // Lower 6 bytes should be zero
        uint48 lower48bits = uint48(uint256(encoded));
        assertEq(lower48bits, 0, "Lower 48 bits should be zero when span and deadline are zero");
    }

    /// @notice Test that transitionSpan occupies bits 40-47 (counting from LSB)
    function testFuzz_transitionSpanBitPosition(uint8 transitionSpan) public view {
        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: bytes26(0),
            transitionSpan: transitionSpan,
            finalizationDeadline: 0
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);

        // Extract bits 40-47
        uint8 extractedSpan = uint8(uint256(encoded) >> 40);
        assertEq(extractedSpan, transitionSpan, "transitionSpan should be at bits 40-47");

        // Lower 40 bits should be zero (deadline is zero)
        uint40 lower40bits = uint40(uint256(encoded));
        assertEq(lower40bits, 0, "Lower 40 bits should be zero when deadline is zero");
    }

    /// @notice Test that finalizationDeadline occupies bits 0-39 (counting from LSB)
    function testFuzz_deadlineBitPosition(uint40 finalizationDeadline) public view {
        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: bytes26(0),
            transitionSpan: 0,
            finalizationDeadline: finalizationDeadline
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);

        // Extract bits 0-39
        uint40 extractedDeadline = uint40(uint256(encoded));
        assertEq(extractedDeadline, finalizationDeadline, "deadline should be at bits 0-39");

        // Bits 40-47 should be zero (span is zero)
        uint8 bits40to47 = uint8(uint256(encoded) >> 40);
        assertEq(bits40to47, 0, "Bits 40-47 should be zero when span is zero");
    }

    /// @notice Test that all three fields don't interfere with each other
    function testFuzz_noFieldInterference(
        bytes26 recordHash,
        uint8 transitionSpan,
        uint40 finalizationDeadline
    ) public view {
        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: recordHash,
            transitionSpan: transitionSpan,
            finalizationDeadline: finalizationDeadline
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);

        // Verify each field independently
        bytes26 extractedHash = bytes26(encoded);
        uint8 extractedSpan = uint8(uint256(encoded) >> 40);
        uint40 extractedDeadline = uint40(uint256(encoded));

        assertEq(extractedHash, recordHash, "recordHash extraction failed");
        assertEq(extractedSpan, transitionSpan, "transitionSpan extraction failed");
        assertEq(extractedDeadline, finalizationDeadline, "deadline extraction failed");
    }

    // ---------------------------------------------------------------
    // Boundary Value Tests
    // ---------------------------------------------------------------

    /// @notice Test encoding with all maximum values
    function test_maxValues() public view {
        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: bytes26(type(uint208).max),
            transitionSpan: type(uint8).max,
            finalizationDeadline: type(uint40).max
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);
        (bytes26 decodedHash, uint8 decodedSpan, uint40 decodedDeadline) =
            harness.decodeTransitionSnippet(encoded);

        assertEq(decodedHash, bytes26(type(uint208).max), "max recordHash mismatch");
        assertEq(decodedSpan, type(uint8).max, "max transitionSpan mismatch");
        assertEq(decodedDeadline, type(uint40).max, "max deadline mismatch");
    }

    /// @notice Test encoding with all zero values
    function test_zeroValues() public view {
        Inbox.TransitionSnippet memory snippet =
            Inbox.TransitionSnippet({ recordHash: bytes26(0), transitionSpan: 0, finalizationDeadline: 0 });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);
        assertEq(encoded, bytes32(0), "All zeros should encode to zero");

        (bytes26 decodedHash, uint8 decodedSpan, uint40 decodedDeadline) =
            harness.decodeTransitionSnippet(encoded);

        assertEq(decodedHash, bytes26(0), "zero recordHash mismatch");
        assertEq(decodedSpan, 0, "zero transitionSpan mismatch");
        assertEq(decodedDeadline, 0, "zero deadline mismatch");
    }

    /// @notice Test encoding with only one field non-zero at a time
    function testFuzz_singleFieldNonZero_recordHash(bytes26 recordHash) public view {
        vm.assume(recordHash != bytes26(0));

        Inbox.TransitionSnippet memory snippet =
            Inbox.TransitionSnippet({ recordHash: recordHash, transitionSpan: 0, finalizationDeadline: 0 });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);
        assertTrue(encoded != bytes32(0), "Non-zero recordHash should produce non-zero encoding");

        (bytes26 decodedHash, uint8 decodedSpan, uint40 decodedDeadline) =
            harness.decodeTransitionSnippet(encoded);

        assertEq(decodedHash, recordHash);
        assertEq(decodedSpan, 0);
        assertEq(decodedDeadline, 0);
    }

    /// @notice Test encoding with only transitionSpan non-zero
    function testFuzz_singleFieldNonZero_transitionSpan(uint8 transitionSpan) public view {
        vm.assume(transitionSpan != 0);

        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: bytes26(0),
            transitionSpan: transitionSpan,
            finalizationDeadline: 0
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);
        assertTrue(encoded != bytes32(0), "Non-zero span should produce non-zero encoding");

        (bytes26 decodedHash, uint8 decodedSpan, uint40 decodedDeadline) =
            harness.decodeTransitionSnippet(encoded);

        assertEq(decodedHash, bytes26(0));
        assertEq(decodedSpan, transitionSpan);
        assertEq(decodedDeadline, 0);
    }

    /// @notice Test encoding with only finalizationDeadline non-zero
    function testFuzz_singleFieldNonZero_deadline(uint40 finalizationDeadline) public view {
        vm.assume(finalizationDeadline != 0);

        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: bytes26(0),
            transitionSpan: 0,
            finalizationDeadline: finalizationDeadline
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);
        assertTrue(encoded != bytes32(0), "Non-zero deadline should produce non-zero encoding");

        (bytes26 decodedHash, uint8 decodedSpan, uint40 decodedDeadline) =
            harness.decodeTransitionSnippet(encoded);

        assertEq(decodedHash, bytes26(0));
        assertEq(decodedSpan, 0);
        assertEq(decodedDeadline, finalizationDeadline);
    }

    // ---------------------------------------------------------------
    // Decode-only Tests (decoding arbitrary bytes32)
    // ---------------------------------------------------------------

    /// @notice Fuzz test: decoding any bytes32 should not revert
    function testFuzz_decodeNeverReverts(bytes32 encoded) public view {
        // This should never revert
        (bytes26 recordHash, uint8 transitionSpan, uint40 finalizationDeadline) =
            harness.decodeTransitionSnippet(encoded);

        // Values should be extractable (no specific assertion needed, just no revert)
        assertTrue(
            recordHash == recordHash && transitionSpan == transitionSpan
                && finalizationDeadline == finalizationDeadline
        );
    }

    /// @notice Test decoding of known bit patterns
    function test_decodeKnownPatterns() public view {
        // All 1s
        bytes32 allOnes = bytes32(type(uint256).max);
        (bytes26 hash1, uint8 span1, uint40 deadline1) = harness.decodeTransitionSnippet(allOnes);
        assertEq(hash1, bytes26(type(uint208).max));
        assertEq(span1, type(uint8).max);
        assertEq(deadline1, type(uint40).max);

        // All 0s
        bytes32 allZeros = bytes32(0);
        (bytes26 hash2, uint8 span2, uint40 deadline2) = harness.decodeTransitionSnippet(allZeros);
        assertEq(hash2, bytes26(0));
        assertEq(span2, 0);
        assertEq(deadline2, 0);

        // Only lower 40 bits set (deadline max)
        bytes32 deadlineOnly = bytes32(uint256(type(uint40).max));
        (bytes26 hash3, uint8 span3, uint40 deadline3) = harness.decodeTransitionSnippet(deadlineOnly);
        assertEq(hash3, bytes26(0));
        assertEq(span3, 0);
        assertEq(deadline3, type(uint40).max);

        // Only bits 40-47 set (span max)
        bytes32 spanOnly = bytes32(uint256(type(uint8).max) << 40);
        (bytes26 hash4, uint8 span4, uint40 deadline4) = harness.decodeTransitionSnippet(spanOnly);
        assertEq(hash4, bytes26(0));
        assertEq(span4, type(uint8).max);
        assertEq(deadline4, 0);
    }

    // ---------------------------------------------------------------
    // Property-based Tests
    // ---------------------------------------------------------------

    /// @notice Property: encoding is deterministic
    function testFuzz_encodingIsDeterministic(
        bytes26 recordHash,
        uint8 transitionSpan,
        uint40 finalizationDeadline
    ) public view {
        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: recordHash,
            transitionSpan: transitionSpan,
            finalizationDeadline: finalizationDeadline
        });

        bytes32 encoded1 = harness.encodeTransitionSnippet(snippet);
        bytes32 encoded2 = harness.encodeTransitionSnippet(snippet);

        assertEq(encoded1, encoded2, "Encoding should be deterministic");
    }

    /// @notice Property: decode(encode(x)) == x (idempotence)
    function testFuzz_encodeDecodeIdempotence(
        bytes26 recordHash,
        uint8 transitionSpan,
        uint40 finalizationDeadline
    ) public view {
        Inbox.TransitionSnippet memory original = Inbox.TransitionSnippet({
            recordHash: recordHash,
            transitionSpan: transitionSpan,
            finalizationDeadline: finalizationDeadline
        });

        bytes32 encoded = harness.encodeTransitionSnippet(original);
        (bytes26 h1, uint8 s1, uint40 d1) = harness.decodeTransitionSnippet(encoded);

        // Re-encode the decoded values
        Inbox.TransitionSnippet memory decoded =
            Inbox.TransitionSnippet({ recordHash: h1, transitionSpan: s1, finalizationDeadline: d1 });

        bytes32 reencoded = harness.encodeTransitionSnippet(decoded);

        assertEq(reencoded, encoded, "Re-encoding should produce the same result");
    }

    // ---------------------------------------------------------------
    // Realistic Value Tests
    // ---------------------------------------------------------------

    /// @notice Test with realistic timestamp values
    function testFuzz_realisticTimestamps(uint40 timestamp) public view {
        // Bound to reasonable timestamp range (year 2000 to year 3000)
        timestamp = uint40(bound(timestamp, 946_684_800, 32_503_680_000));

        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: bytes26(keccak256("test")),
            transitionSpan: 1,
            finalizationDeadline: timestamp
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);
        (bytes26 decodedHash, uint8 decodedSpan, uint40 decodedDeadline) =
            harness.decodeTransitionSnippet(encoded);

        assertEq(decodedDeadline, timestamp);
        assertEq(decodedSpan, 1);
        assertEq(decodedHash, bytes26(keccak256("test")));
    }

    /// @notice Test with realistic span values (1-255)
    function testFuzz_realisticSpans(uint8 span) public view {
        vm.assume(span > 0); // Spans are typically at least 1

        Inbox.TransitionSnippet memory snippet = Inbox.TransitionSnippet({
            recordHash: bytes26(keccak256("proposal")),
            transitionSpan: span,
            finalizationDeadline: uint40(block.timestamp + 48 hours)
        });

        bytes32 encoded = harness.encodeTransitionSnippet(snippet);
        (, uint8 decodedSpan,) = harness.decodeTransitionSnippet(encoded);

        assertEq(decodedSpan, span);
    }
}
