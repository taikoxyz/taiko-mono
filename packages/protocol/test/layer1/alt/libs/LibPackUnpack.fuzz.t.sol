// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibPackUnpack } from "src/layer1/alt/libs/LibPackUnpack.sol";

/// @title LibPackUnpackFuzzTest
/// @notice Comprehensive fuzzy tests for LibPackUnpack with various complex data structures
/// @dev Tests pack/unpack roundtrip properties with different combinations of data types
/// @custom:security-contact security@taiko.xyz
contract LibPackUnpackFuzzTest is Test {
    // ---------------------------------------------------------------
    // Test Structs - Various complexity levels
    // ---------------------------------------------------------------

    struct SimpleStruct {
        uint8 flag;
        uint16 counter;
        uint24 value;
    }

    struct MediumStruct {
        uint8 version;
        uint24 blockNumber;
        uint40 timestamp;
        uint48 deadline;
        address operator;
        bool isActive;
    }

    struct ComplexStruct {
        uint8 protocolVersion;
        uint16 chainId;
        uint24 epochNumber;
        uint40 proposalId;
        uint48 blockHeight;
        bytes27 transitionHash;
        bytes32 blockHash;
        address proposer;
        address prover;
        bool finalized;
        uint8 proofTier;
    }

    struct ProposalStruct {
        uint40 proposalId;
        address proposer;
        uint40 timestamp;
        uint40 originBlockNumber;
        bool isForcedInclusion;
        uint8 basefeeSharingPctg;
        bytes32 coreStateHash;
        uint24 blobOffset;
        uint40 blobTimestamp;
        uint16 numBlobs;
    }

    // ---------------------------------------------------------------
    // Pack/Unpack Functions for each struct
    // ---------------------------------------------------------------

    function packSimpleStruct(
        uint256 _pos,
        SimpleStruct memory _struct
    )
        internal
        pure
        returns (uint256 newPos_)
    {
        newPos_ = LibPackUnpack.packUint8(_pos, _struct.flag);
        newPos_ = LibPackUnpack.packUint16(newPos_, _struct.counter);
        newPos_ = LibPackUnpack.packUint24(newPos_, _struct.value);
    }

    function unpackSimpleStruct(uint256 _pos)
        internal
        pure
        returns (SimpleStruct memory struct_, uint256 newPos_)
    {
        (struct_.flag, newPos_) = LibPackUnpack.unpackUint8(_pos);
        (struct_.counter, newPos_) = LibPackUnpack.unpackUint16(newPos_);
        (struct_.value, newPos_) = LibPackUnpack.unpackUint24(newPos_);
    }

    function packMediumStruct(
        uint256 _pos,
        MediumStruct memory _struct
    )
        internal
        pure
        returns (uint256 newPos_)
    {
        newPos_ = LibPackUnpack.packUint8(_pos, _struct.version);
        newPos_ = LibPackUnpack.packUint24(newPos_, _struct.blockNumber);
        newPos_ = LibPackUnpack.packUint40(newPos_, _struct.timestamp);
        newPos_ = LibPackUnpack.packUint48(newPos_, _struct.deadline);
        newPos_ = LibPackUnpack.packAddress(newPos_, _struct.operator);
        newPos_ = LibPackUnpack.packUint8(newPos_, _struct.isActive ? 1 : 0);
    }

    function unpackMediumStruct(uint256 _pos)
        internal
        pure
        returns (MediumStruct memory struct_, uint256 newPos_)
    {
        uint8 isActiveByte;
        (struct_.version, newPos_) = LibPackUnpack.unpackUint8(_pos);
        (struct_.blockNumber, newPos_) = LibPackUnpack.unpackUint24(newPos_);
        (struct_.timestamp, newPos_) = LibPackUnpack.unpackUint40(newPos_);
        (struct_.deadline, newPos_) = LibPackUnpack.unpackUint48(newPos_);
        (struct_.operator, newPos_) = LibPackUnpack.unpackAddress(newPos_);
        (isActiveByte, newPos_) = LibPackUnpack.unpackUint8(newPos_);
        struct_.isActive = isActiveByte == 1;
    }

    function packComplexStruct(
        uint256 _pos,
        ComplexStruct memory _struct
    )
        internal
        pure
        returns (uint256 newPos_)
    {
        newPos_ = LibPackUnpack.packUint8(_pos, _struct.protocolVersion);
        newPos_ = LibPackUnpack.packUint16(newPos_, _struct.chainId);
        newPos_ = LibPackUnpack.packUint24(newPos_, _struct.epochNumber);
        newPos_ = LibPackUnpack.packUint40(newPos_, _struct.proposalId);
        newPos_ = LibPackUnpack.packUint48(newPos_, _struct.blockHeight);
        newPos_ = LibPackUnpack.packBytes27(newPos_, _struct.transitionHash);
        newPos_ = LibPackUnpack.packBytes32(newPos_, _struct.blockHash);
        newPos_ = LibPackUnpack.packAddress(newPos_, _struct.proposer);
        newPos_ = LibPackUnpack.packAddress(newPos_, _struct.prover);
        newPos_ = LibPackUnpack.packUint8(newPos_, _struct.finalized ? 1 : 0);
        newPos_ = LibPackUnpack.packUint8(newPos_, _struct.proofTier);
    }

    function unpackComplexStruct(uint256 _pos)
        internal
        pure
        returns (ComplexStruct memory struct_, uint256 newPos_)
    {
        uint8 finalizedByte;
        (struct_.protocolVersion, newPos_) = LibPackUnpack.unpackUint8(_pos);
        (struct_.chainId, newPos_) = LibPackUnpack.unpackUint16(newPos_);
        (struct_.epochNumber, newPos_) = LibPackUnpack.unpackUint24(newPos_);
        (struct_.proposalId, newPos_) = LibPackUnpack.unpackUint40(newPos_);
        (struct_.blockHeight, newPos_) = LibPackUnpack.unpackUint48(newPos_);
        (struct_.transitionHash, newPos_) = LibPackUnpack.unpackBytes27(newPos_);
        (struct_.blockHash, newPos_) = LibPackUnpack.unpackBytes32(newPos_);
        (struct_.proposer, newPos_) = LibPackUnpack.unpackAddress(newPos_);
        (struct_.prover, newPos_) = LibPackUnpack.unpackAddress(newPos_);
        (finalizedByte, newPos_) = LibPackUnpack.unpackUint8(newPos_);
        struct_.finalized = finalizedByte == 1;
        (struct_.proofTier, newPos_) = LibPackUnpack.unpackUint8(newPos_);
    }

    function packProposalStruct(
        uint256 _pos,
        ProposalStruct memory _struct
    )
        internal
        pure
        returns (uint256 newPos_)
    {
        newPos_ = LibPackUnpack.packUint40(_pos, _struct.proposalId);
        newPos_ = LibPackUnpack.packAddress(newPos_, _struct.proposer);
        newPos_ = LibPackUnpack.packUint40(newPos_, _struct.timestamp);
        newPos_ = LibPackUnpack.packUint40(newPos_, _struct.originBlockNumber);
        newPos_ = LibPackUnpack.packUint8(newPos_, _struct.isForcedInclusion ? 1 : 0);
        newPos_ = LibPackUnpack.packUint8(newPos_, _struct.basefeeSharingPctg);
        newPos_ = LibPackUnpack.packBytes32(newPos_, _struct.coreStateHash);
        newPos_ = LibPackUnpack.packUint24(newPos_, _struct.blobOffset);
        newPos_ = LibPackUnpack.packUint40(newPos_, _struct.blobTimestamp);
        newPos_ = LibPackUnpack.packUint16(newPos_, _struct.numBlobs);
    }

    function unpackProposalStruct(uint256 _pos)
        internal
        pure
        returns (ProposalStruct memory struct_, uint256 newPos_)
    {
        uint8 forcedInclusionByte;
        (struct_.proposalId, newPos_) = LibPackUnpack.unpackUint40(_pos);
        (struct_.proposer, newPos_) = LibPackUnpack.unpackAddress(newPos_);
        (struct_.timestamp, newPos_) = LibPackUnpack.unpackUint40(newPos_);
        (struct_.originBlockNumber, newPos_) = LibPackUnpack.unpackUint40(newPos_);
        (forcedInclusionByte, newPos_) = LibPackUnpack.unpackUint8(newPos_);
        struct_.isForcedInclusion = forcedInclusionByte == 1;
        (struct_.basefeeSharingPctg, newPos_) = LibPackUnpack.unpackUint8(newPos_);
        (struct_.coreStateHash, newPos_) = LibPackUnpack.unpackBytes32(newPos_);
        (struct_.blobOffset, newPos_) = LibPackUnpack.unpackUint24(newPos_);
        (struct_.blobTimestamp, newPos_) = LibPackUnpack.unpackUint40(newPos_);
        (struct_.numBlobs, newPos_) = LibPackUnpack.unpackUint16(newPos_);
    }

    // ---------------------------------------------------------------
    // Fuzzy tests for simple structs
    // ---------------------------------------------------------------

    function testFuzz_simpleStruct(uint8 flag, uint16 counter, uint24 value) public pure {
        SimpleStruct memory original = SimpleStruct({ flag: flag, counter: counter, value: value });

        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        packSimpleStruct(ptr, original);
        (SimpleStruct memory unpacked,) = unpackSimpleStruct(ptr);

        assertEq(unpacked.flag, original.flag);
        assertEq(unpacked.counter, original.counter);
        assertEq(unpacked.value, original.value);
    }

    function testFuzz_mediumStruct(
        uint8 version,
        uint24 blockNumber,
        uint40 timestamp,
        uint48 deadline,
        address operator,
        bool isActive
    )
        public
        pure
    {
        MediumStruct memory original = MediumStruct({
            version: version,
            blockNumber: blockNumber,
            timestamp: timestamp,
            deadline: deadline,
            operator: operator,
            isActive: isActive
        });

        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        packMediumStruct(ptr, original);
        (MediumStruct memory unpacked,) = unpackMediumStruct(ptr);

        assertEq(unpacked.version, original.version);
        assertEq(unpacked.blockNumber, original.blockNumber);
        assertEq(unpacked.timestamp, original.timestamp);
        assertEq(unpacked.deadline, original.deadline);
        assertEq(unpacked.operator, original.operator);
        assertEq(unpacked.isActive, original.isActive);
    }

    function testFuzz_complexStruct(
        uint8 protocolVersion,
        uint16 chainId,
        uint24 epochNumber,
        uint40 proposalId,
        uint48 blockHeight,
        bytes27 transitionHash,
        bytes32 blockHash,
        address proposer,
        address prover,
        bool finalized,
        uint8 proofTier
    )
        public
        pure
    {
        ComplexStruct memory original = ComplexStruct({
            protocolVersion: protocolVersion,
            chainId: chainId,
            epochNumber: epochNumber,
            proposalId: proposalId,
            blockHeight: blockHeight,
            transitionHash: transitionHash,
            blockHash: blockHash,
            proposer: proposer,
            prover: prover,
            finalized: finalized,
            proofTier: proofTier
        });

        bytes memory buffer = new bytes(200);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        packComplexStruct(ptr, original);
        (ComplexStruct memory unpacked,) = unpackComplexStruct(ptr);

        assertEq(unpacked.protocolVersion, original.protocolVersion);
        assertEq(unpacked.chainId, original.chainId);
        assertEq(unpacked.epochNumber, original.epochNumber);
        assertEq(unpacked.proposalId, original.proposalId);
        assertEq(unpacked.blockHeight, original.blockHeight);
        assertEq(unpacked.transitionHash, original.transitionHash);
        assertEq(unpacked.blockHash, original.blockHash);
        assertEq(unpacked.proposer, original.proposer);
        assertEq(unpacked.prover, original.prover);
        assertEq(unpacked.finalized, original.finalized);
        assertEq(unpacked.proofTier, original.proofTier);
    }

    function testFuzz_proposalStruct(
        uint40 proposalId,
        address proposer,
        uint40 timestamp,
        uint40 originBlockNumber,
        bool isForcedInclusion,
        uint8 basefeeSharingPctg,
        bytes32 coreStateHash,
        uint24 blobOffset,
        uint40 blobTimestamp,
        uint16 numBlobs
    )
        public
        pure
    {
        ProposalStruct memory original = ProposalStruct({
            proposalId: proposalId,
            proposer: proposer,
            timestamp: timestamp,
            originBlockNumber: originBlockNumber,
            isForcedInclusion: isForcedInclusion,
            basefeeSharingPctg: basefeeSharingPctg,
            coreStateHash: coreStateHash,
            blobOffset: blobOffset,
            blobTimestamp: blobTimestamp,
            numBlobs: numBlobs
        });

        bytes memory buffer = new bytes(200);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        packProposalStruct(ptr, original);
        (ProposalStruct memory unpacked,) = unpackProposalStruct(ptr);

        assertEq(unpacked.proposalId, original.proposalId);
        assertEq(unpacked.proposer, original.proposer);
        assertEq(unpacked.timestamp, original.timestamp);
        assertEq(unpacked.originBlockNumber, original.originBlockNumber);
        assertEq(unpacked.isForcedInclusion, original.isForcedInclusion);
        assertEq(unpacked.basefeeSharingPctg, original.basefeeSharingPctg);
        assertEq(unpacked.coreStateHash, original.coreStateHash);
        assertEq(unpacked.blobOffset, original.blobOffset);
        assertEq(unpacked.blobTimestamp, original.blobTimestamp);
        assertEq(unpacked.numBlobs, original.numBlobs);
    }

    // ---------------------------------------------------------------
    // Advanced fuzzy tests with multiple structs and sequential packing
    // ---------------------------------------------------------------

    function testFuzz_multipleStructsPacked(
        uint8 flag1,
        uint16 counter1,
        uint24 value1,
        uint8 version2,
        uint24 blockNumber2,
        uint40 timestamp2,
        uint48 deadline2,
        address operator2,
        bool isActive2
    )
        public
        pure
    {
        SimpleStruct memory struct1 =
            SimpleStruct({ flag: flag1, counter: counter1, value: value1 });

        MediumStruct memory struct2 = MediumStruct({
            version: version2,
            blockNumber: blockNumber2,
            timestamp: timestamp2,
            deadline: deadline2,
            operator: operator2,
            isActive: isActive2
        });

        bytes memory buffer = new bytes(200);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        // Pack both structs sequentially
        uint256 newPtr1 = packSimpleStruct(ptr, struct1);
        uint256 newPtr2 = packMediumStruct(newPtr1, struct2);

        // Unpack both structs
        (SimpleStruct memory unpacked1, uint256 readPtr1) = unpackSimpleStruct(ptr);
        (MediumStruct memory unpacked2, uint256 readPtr2) = unpackMediumStruct(readPtr1);

        // Verify positions match
        assertEq(newPtr1, readPtr1);
        assertEq(newPtr2, readPtr2);

        // Verify first struct
        assertEq(unpacked1.flag, struct1.flag);
        assertEq(unpacked1.counter, struct1.counter);
        assertEq(unpacked1.value, struct1.value);

        // Verify second struct
        assertEq(unpacked2.version, struct2.version);
        assertEq(unpacked2.blockNumber, struct2.blockNumber);
        assertEq(unpacked2.timestamp, struct2.timestamp);
        assertEq(unpacked2.deadline, struct2.deadline);
        assertEq(unpacked2.operator, struct2.operator);
        assertEq(unpacked2.isActive, struct2.isActive);
    }

    // ---------------------------------------------------------------
    // Property-based tests for pack/unpack invariants
    // ---------------------------------------------------------------

    function testFuzz_positionIncrements_integers(
        uint8 val8,
        uint16 val16,
        uint24 val24,
        uint40 val40,
        uint48 val48
    )
        public
        pure
    {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint256 pos = ptr;
        uint256 nextPos;

        nextPos = LibPackUnpack.packUint8(pos, val8);
        assertEq(nextPos, pos + 1);
        pos = nextPos;

        nextPos = LibPackUnpack.packUint16(pos, val16);
        assertEq(nextPos, pos + 2);
        pos = nextPos;

        nextPos = LibPackUnpack.packUint24(pos, val24);
        assertEq(nextPos, pos + 3);
        pos = nextPos;

        nextPos = LibPackUnpack.packUint40(pos, val40);
        assertEq(nextPos, pos + 5);
        pos = nextPos;

        nextPos = LibPackUnpack.packUint48(pos, val48);
        assertEq(nextPos, pos + 6);

        // Total should be 1+2+3+5+6 = 17 bytes
        assertEq(nextPos, ptr + 17);
    }

    function testFuzz_positionIncrements_largeTypes(
        bytes27 valBytes27,
        bytes32 valBytes32,
        address valAddress
    )
        public
        pure
    {
        bytes memory buffer = new bytes(200);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint256 pos = ptr;
        uint256 nextPos;

        nextPos = LibPackUnpack.packBytes27(pos, valBytes27);
        assertEq(nextPos, pos + 27);
        pos = nextPos;

        nextPos = LibPackUnpack.packBytes32(pos, valBytes32);
        assertEq(nextPos, pos + 32);
        pos = nextPos;

        nextPos = LibPackUnpack.packAddress(pos, valAddress);
        assertEq(nextPos, pos + 20);

        // Total should be 27+32+20 = 79 bytes
        assertEq(nextPos, ptr + 79);
    }

    function testFuzz_largeDataStructures(uint256 numElements) public pure {
        numElements = bound(numElements, 1, 50);

        bytes memory buffer = new bytes(numElements * 100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        // Pack multiple simple structs
        uint256 pos = ptr;
        for (uint256 i = 0; i < numElements; i++) {
            SimpleStruct memory testStruct = SimpleStruct({
                flag: uint8(i % 256), counter: uint16(i % 65_536), value: uint24(i % 16_777_216)
            });
            pos = packSimpleStruct(pos, testStruct);
        }

        // Unpack and verify
        uint256 readPos = ptr;
        for (uint256 i = 0; i < numElements; i++) {
            (SimpleStruct memory unpacked, uint256 newReadPos) = unpackSimpleStruct(readPos);
            assertEq(unpacked.flag, uint8(i % 256));
            assertEq(unpacked.counter, uint16(i % 65_536));
            assertEq(unpacked.value, uint24(i % 16_777_216));
            readPos = newReadPos;
        }

        assertEq(pos, readPos);
    }

    function testFuzz_booleanFlags(bool flag1, bool flag2) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint8 val1 = flag1 ? 1 : 0;
        uint8 val2 = flag2 ? 1 : 0;

        uint256 pos = ptr;
        pos = LibPackUnpack.packUint8(pos, val1);
        pos = LibPackUnpack.packUint8(pos, val2);

        uint256 readPos = ptr;
        (uint8 read1, uint256 newReadPos1) = LibPackUnpack.unpackUint8(readPos);
        (uint8 read2, uint256 newReadPos2) = LibPackUnpack.unpackUint8(newReadPos1);

        assertEq(pos, newReadPos2);
        assertEq(read1, val1);
        assertEq(read2, val2);
    }
}
