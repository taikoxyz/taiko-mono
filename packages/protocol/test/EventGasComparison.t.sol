// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { console2 } from "forge-std/src/console2.sol";

contract EventGasComparison is CommonTest {
    TestWithBytes testBytes;
    TestWithStructured testStructured;
    TestWithOptimizedBytes testOptimized;

    function setUp() public override {
        super.setUp();
        testBytes = new TestWithBytes();
        testStructured = new TestWithStructured();
        testOptimized = new TestWithOptimizedBytes();
    }

    function test_compareProposedEventGas() public {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = keccak256("blob1");
        blobHashes[1] = keccak256("blob2");

        Proposal memory proposal = Proposal({
            id: 12_345,
            proposer: address(0x1234567890123456789012345678901234567890),
            originTimestamp: 1_234_567_890,
            originBlockNumber: 9_876_543,
            isForcedInclusion: true,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 123,
                timestamp: 1_234_567_890
            }),
            coreStateHash: keccak256("coreStateHash")
        });

        CoreState memory coreState = CoreState({
            nextProposalId: 12_346,
            lastFinalizedProposalId: 12_344,
            lastFinalizedClaimHash: keccak256("lastFinalizedClaimHash"),
            bondInstructionsHash: keccak256("bondInstructionsHash")
        });

        uint256 gasBefore = gasleft();
        testBytes.emitProposed(proposal, coreState);
        uint256 gasUsedBytes = gasBefore - gasleft();

        gasBefore = gasleft();
        testStructured.emitProposed(proposal, coreState);
        uint256 gasUsedStructured = gasBefore - gasleft();

        gasBefore = gasleft();
        testOptimized.emitProposed(proposal, coreState);
        uint256 gasUsedOptimized = gasBefore - gasleft();

        console2.log("=== Proposed Event Gas Comparison ===");
        console2.log("Bytes (abi.encode) gas:  ", gasUsedBytes);
        console2.log("Structured event gas:     ", gasUsedStructured);
        console2.log("Optimized bytes gas:      ", gasUsedOptimized);
        console2.log("");
        if (gasUsedOptimized < gasUsedBytes) {
            console2.log("Optimized saves", gasUsedBytes - gasUsedOptimized, "gas vs abi.encode");
        }
        if (gasUsedOptimized < gasUsedStructured) {
            console2.log(
                "Optimized saves", gasUsedStructured - gasUsedOptimized, "gas vs structured"
            );
        }
    }

    function test_compareProvedEventGas() public {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 12_345,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x2222222222222222222222222222222222222222),
            receiver: address(0x3333333333333333333333333333333333333333)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 12_346,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x4444444444444444444444444444444444444444),
            receiver: address(0x5555555555555555555555555555555555555555)
        });

        ClaimRecord memory claimRecord = ClaimRecord({
            claim: Claim({
                proposalId: 12_345,
                proposalHash: keccak256("proposalHash"),
                parentClaimHash: keccak256("parentClaimHash"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("endBlockHash"),
                endStateRoot: keccak256("endStateRoot"),
                designatedProver: address(0x5555555555555555555555555555555555555555),
                actualProver: address(0x6666666666666666666666666666666666666666)
            }),
            span: 5,
            bondInstructions: bondInstructions
        });

        uint256 gasBefore = gasleft();
        testBytes.emitProved(claimRecord);
        uint256 gasUsedBytes = gasBefore - gasleft();

        gasBefore = gasleft();
        testStructured.emitProved(claimRecord);
        uint256 gasUsedStructured = gasBefore - gasleft();

        gasBefore = gasleft();
        testOptimized.emitProved(claimRecord);
        uint256 gasUsedOptimized = gasBefore - gasleft();

        console2.log("=== Proved Event Gas Comparison ===");
        console2.log("Bytes (abi.encode) gas:  ", gasUsedBytes);
        console2.log("Structured event gas:     ", gasUsedStructured);
        console2.log("Optimized bytes gas:      ", gasUsedOptimized);
        console2.log("");
        if (gasUsedOptimized < gasUsedBytes) {
            console2.log("Optimized saves", gasUsedBytes - gasUsedOptimized, "gas vs abi.encode");
        }
        if (gasUsedOptimized < gasUsedStructured) {
            console2.log(
                "Optimized saves", gasUsedStructured - gasUsedOptimized, "gas vs structured"
            );
        }
    }

    struct Proposal {
        uint48 id;
        address proposer;
        uint48 originTimestamp;
        uint48 originBlockNumber;
        bool isForcedInclusion;
        uint8 basefeeSharingPctg;
        LibBlobs.BlobSlice blobSlice;
        bytes32 coreStateHash;
    }

    struct Claim {
        uint48 proposalId;
        bytes32 proposalHash;
        bytes32 parentClaimHash;
        uint48 endBlockNumber;
        bytes32 endBlockHash;
        bytes32 endStateRoot;
        address designatedProver;
        address actualProver;
    }

    struct ClaimRecord {
        Claim claim;
        uint8 span;
        LibBonds.BondInstruction[] bondInstructions;
    }

    struct CoreState {
        uint48 nextProposalId;
        uint48 lastFinalizedProposalId;
        bytes32 lastFinalizedClaimHash;
        bytes32 bondInstructionsHash;
    }
}

contract TestWithBytes {
    event Proposed(bytes data);
    event Proved(bytes data);

    function emitProposed(
        EventGasComparison.Proposal memory _proposal,
        EventGasComparison.CoreState memory _coreState
    )
        external
    {
        emit Proposed(abi.encode(_proposal, _coreState));
    }

    function emitProved(EventGasComparison.ClaimRecord memory _claimRecord) external {
        emit Proved(abi.encode(_claimRecord));
    }
}

contract TestWithStructured {
    event Proposed(EventGasComparison.Proposal proposal, EventGasComparison.CoreState coreState);

    event Proved(EventGasComparison.ClaimRecord claimRecord);

    function emitProposed(
        EventGasComparison.Proposal memory _proposal,
        EventGasComparison.CoreState memory _coreState
    )
        external
    {
        emit Proposed(_proposal, _coreState);
    }

    function emitProved(EventGasComparison.ClaimRecord memory _claimRecord) external {
        emit Proved(_claimRecord);
    }
}

contract TestWithOptimizedBytes {
    event Proposed(bytes data);
    event Proved(bytes data);

    function emitProposed(
        EventGasComparison.Proposal memory _proposal,
        EventGasComparison.CoreState memory _coreState
    )
        external
    {
        bytes memory packed;
        packed = abi.encodePacked(
            _proposal.id, _proposal.proposer, _proposal.originTimestamp, _proposal.originBlockNumber
        );
        packed = abi.encodePacked(
            packed,
            _proposal.isForcedInclusion,
            _proposal.basefeeSharingPctg,
            uint8(_proposal.blobSlice.blobHashes.length)
        );
        for (uint256 i = 0; i < _proposal.blobSlice.blobHashes.length; i++) {
            packed = abi.encodePacked(packed, _proposal.blobSlice.blobHashes[i]);
        }
        packed = abi.encodePacked(
            packed,
            _proposal.blobSlice.offset,
            _proposal.blobSlice.timestamp,
            _proposal.coreStateHash
        );
        packed = abi.encodePacked(
            packed,
            _coreState.nextProposalId,
            _coreState.lastFinalizedProposalId,
            _coreState.lastFinalizedClaimHash,
            _coreState.bondInstructionsHash
        );
        emit Proposed(packed);
    }

    function emitProved(EventGasComparison.ClaimRecord memory _claimRecord) external {
        bytes memory packed;
        packed = abi.encodePacked(
            _claimRecord.claim.proposalId,
            _claimRecord.claim.proposalHash,
            _claimRecord.claim.parentClaimHash,
            _claimRecord.claim.endBlockNumber
        );
        packed = abi.encodePacked(
            packed,
            _claimRecord.claim.endBlockHash,
            _claimRecord.claim.endStateRoot,
            _claimRecord.claim.designatedProver,
            _claimRecord.claim.actualProver
        );
        packed =
            abi.encodePacked(packed, _claimRecord.span, uint8(_claimRecord.bondInstructions.length));

        for (uint256 i = 0; i < _claimRecord.bondInstructions.length; i++) {
            packed = abi.encodePacked(
                packed,
                _claimRecord.bondInstructions[i].proposalId,
                uint8(_claimRecord.bondInstructions[i].bondType),
                _claimRecord.bondInstructions[i].payer,
                _claimRecord.bondInstructions[i].receiver
            );
        }

        emit Proved(packed);
    }
}
