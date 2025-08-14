// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibCodec } from "src/layer1/shasta/libs/LibCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { console2 } from "forge-std/src/console2.sol";

contract EventGasComparison is CommonTest {
    TestWithBytes testBytes;
    TestWithStructured testStructured;
    TestWithLibCodec testLibCodec;
    
    // Storage for gas measurements
    uint256 proposedStructured;
    uint256 proposedAbiEncode;
    uint256 proposedLibCodec;
    uint256 provedStructured;
    uint256 provedAbiEncode;
    uint256 provedLibCodec;

    function setUp() public override {
        super.setUp();
        testBytes = new TestWithBytes();
        testStructured = new TestWithStructured();
        testLibCodec = new TestWithLibCodec();
    }

    function test_compareProposedEventGas() public {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = keccak256("blob1");
        blobHashes[1] = keccak256("blob2");

        IInbox.Proposal memory proposal = IInbox.Proposal({
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

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 12_346,
            lastFinalizedProposalId: 12_344,
            lastFinalizedClaimHash: keccak256("lastFinalizedClaimHash"),
            bondInstructionsHash: keccak256("bondInstructionsHash")
        });

        // Measure gas for structured (baseline)
        uint256 gasBefore = gasleft();
        testStructured.emitProposed(proposal, coreState);
        uint256 gasUsedStructured = gasBefore - gasleft();

        // Measure gas for abi.encode
        gasBefore = gasleft();
        testBytes.emitProposed(proposal, coreState);
        uint256 gasUsedBytes = gasBefore - gasleft();

        // Measure gas for LibCodec
        gasBefore = gasleft();
        testLibCodec.emitProposed(proposal, coreState);
        uint256 gasUsedLibCodec = gasBefore - gasleft();

        // Store results for table output
        proposedStructured = gasUsedStructured;
        proposedAbiEncode = gasUsedBytes;
        proposedLibCodec = gasUsedLibCodec;
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

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            claim: IInbox.Claim({
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

        // Measure gas for structured (baseline)
        uint256 gasBefore = gasleft();
        testStructured.emitProved(claimRecord);
        uint256 gasUsedStructured = gasBefore - gasleft();

        // Measure gas for abi.encode
        gasBefore = gasleft();
        testBytes.emitProved(claimRecord);
        uint256 gasUsedBytes = gasBefore - gasleft();

        // Measure gas for LibCodec
        gasBefore = gasleft();
        testLibCodec.emitProved(claimRecord);
        uint256 gasUsedLibCodec = gasBefore - gasleft();

        // Store results for table output
        provedStructured = gasUsedStructured;
        provedAbiEncode = gasUsedBytes;
        provedLibCodec = gasUsedLibCodec;
    }
    
    function test_printComparisonTable() public {
        // Run both tests to populate measurements
        test_compareProposedEventGas();
        test_compareProvedEventGas();
        
        // Print markdown table
        console2.log("\n# Gas Comparison Table\n");
        console2.log("| Event Type | Baseline (Structured) | Bytes(abi.encode) | Packed(LibCodec) |");
        console2.log("|------------|----------------------|------------------|-----------------|");
        
        // Proposed event row
        console2.log(
            string.concat(
                "| Proposed   | ",
                _toString(proposedStructured),
                " | ",
                _toString(proposedAbiEncode),
                " | ",
                _toString(proposedLibCodec),
                " |"
            )
        );
        
        // Proved event row
        console2.log(
            string.concat(
                "| Proved     | ",
                _toString(provedStructured),
                " | ",
                _toString(provedAbiEncode),
                " | ",
                _toString(provedLibCodec),
                " |"
            )
        );
        
        // Calculate and display savings
        console2.log("\n## Gas Savings Analysis\n");
        console2.log("### Proposed Event:");
        if (proposedLibCodec < proposedStructured) {
            uint256 saving = ((proposedStructured - proposedLibCodec) * 100) / proposedStructured;
            console2.log(
                string.concat(
                    "- LibCodec saves ",
                    _toString(proposedStructured - proposedLibCodec),
                    " gas (",
                    _toString(saving),
                    "%) vs Structured"
                )
            );
        }
        if (proposedLibCodec < proposedAbiEncode) {
            uint256 saving = ((proposedAbiEncode - proposedLibCodec) * 100) / proposedAbiEncode;
            console2.log(
                string.concat(
                    "- LibCodec saves ",
                    _toString(proposedAbiEncode - proposedLibCodec),
                    " gas (",
                    _toString(saving),
                    "%) vs abi.encode"
                )
            );
        }
        
        console2.log("\n### Proved Event:");
        if (provedLibCodec < provedStructured) {
            uint256 saving = ((provedStructured - provedLibCodec) * 100) / provedStructured;
            console2.log(
                string.concat(
                    "- LibCodec saves ",
                    _toString(provedStructured - provedLibCodec),
                    " gas (",
                    _toString(saving),
                    "%) vs Structured"
                )
            );
        }
        if (provedLibCodec < provedAbiEncode) {
            uint256 saving = ((provedAbiEncode - provedLibCodec) * 100) / provedAbiEncode;
            console2.log(
                string.concat(
                    "- LibCodec saves ",
                    _toString(provedAbiEncode - provedLibCodec),
                    " gas (",
                    _toString(saving),
                    "%) vs abi.encode"
                )
            );
        }
    }
    
    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

contract TestWithBytes {
    event Proposed(bytes data);
    event Proved(bytes data);

    function emitProposed(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        external
    {
        emit Proposed(abi.encode(_proposal, _coreState));
    }

    function emitProved(IInbox.ClaimRecord memory _claimRecord) external {
        emit Proved(abi.encode(_claimRecord));
    }
}

contract TestWithStructured {
    event Proposed(IInbox.Proposal proposal, IInbox.CoreState coreState);

    event Proved(IInbox.ClaimRecord claimRecord);

    function emitProposed(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        external
    {
        emit Proposed(_proposal, _coreState);
    }

    function emitProved(IInbox.ClaimRecord memory _claimRecord) external {
        emit Proved(_claimRecord);
    }
}

contract TestWithLibCodec {
    event Proposed(bytes data);
    event Proved(bytes data);

    function emitProposed(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        external
    {
        emit Proposed(LibCodec.encodeProposedEventData(_proposal, _coreState));
    }

    function emitProved(IInbox.ClaimRecord memory _claimRecord) external {
        emit Proved(LibCodec.encodeProveEventData(_claimRecord));
    }
}
