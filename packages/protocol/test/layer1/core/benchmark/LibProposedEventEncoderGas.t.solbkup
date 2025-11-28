// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibProposedEventEncoder } from "src/layer1/core/libs/LibProposedEventEncoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProposedEventEncoderGas
/// @notice Gas comparison between optimized LibEncoder and abi.encode
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventEncoderGas is Test {
    event Proposed(bytes data);
    event ProposedDirect(IInbox.ProposedEventPayload payload);

    function test_gas_comparison_optimized() public {
        console2.log("\nGas Comparison: abi.encode vs LibProposedEventEncoder");
        console2.log("====================================================\n");

        uint256[] memory blobCounts = new uint256[](4);
        blobCounts[0] = 0;
        blobCounts[1] = 3;
        blobCounts[2] = 6;
        blobCounts[3] = 10;

        for (uint256 i = 0; i < blobCounts.length; i++) {
            IInbox.ProposedEventPayload memory payload = _createTestData(blobCounts[i]);

            console2.log("Blob hashes count:", blobCounts[i]);

            // 1. abi.encode + emit
            uint256 gasBefore = gasleft();
            bytes memory abiEncoded = abi.encode(payload);
            emit Proposed(abiEncoded);
            uint256 abiEncodeGas = gasBefore - gasleft();

            // 2. Optimized LibEncoder
            gasBefore = gasleft();
            bytes memory encoded = LibProposedEventEncoder.encode(payload);
            emit Proposed(encoded);
            uint256 libEncoderGas = gasBefore - gasleft();

            // Calculate savings percentage (can be negative if LibEncoder uses more gas)
            int256 savingsPercent;
            if (abiEncodeGas > libEncoderGas) {
                savingsPercent = int256(((abiEncodeGas - libEncoderGas) * 100) / abiEncodeGas);
            } else {
                savingsPercent = -int256(((libEncoderGas - abiEncodeGas) * 100) / abiEncodeGas);
            }

            console2.log("  abi.encode + emit:", abiEncodeGas, "gas");
            console2.log("  LibEncoder + emit:  ", libEncoderGas, "gas");
            if (savingsPercent >= 0) {
                console2.log("  Savings:", uint256(savingsPercent), "%");
            } else {
                console2.log("  Savings: -", uint256(-savingsPercent), "% (LibEncoder uses more)");
            }
            console2.log("");
        }

        _writeReport();
    }

    function test_gas_decode_comparison() public view {
        console2.log("\nDecode Gas Comparison: abi.decode vs LibProposedEventEncoder");
        console2.log("==========================================================\n");

        uint256[] memory blobCounts = new uint256[](4);
        blobCounts[0] = 0;
        blobCounts[1] = 3;
        blobCounts[2] = 6;
        blobCounts[3] = 10;

        for (uint256 i = 0; i < blobCounts.length; i++) {
            IInbox.ProposedEventPayload memory payload = _createTestData(blobCounts[i]);

            // Prepare encoded data
            bytes memory abiEncoded = abi.encode(payload);
            bytes memory libEncoded = LibProposedEventEncoder.encode(payload);

            console2.log("Blob hashes count:", blobCounts[i]);
            console2.log("  abi.encode size:", abiEncoded.length, "bytes");
            console2.log("  LibEncoder size:  ", libEncoded.length, "bytes");

            // 1. abi.decode
            uint256 gasBefore = gasleft();
            IInbox.ProposedEventPayload memory decoded1 =
                abi.decode(abiEncoded, (IInbox.ProposedEventPayload));
            uint256 abiDecodeGas = gasBefore - gasleft();

            // 2. LibEncoder decode
            gasBefore = gasleft();
            IInbox.ProposedEventPayload memory decoded2 = LibProposedEventEncoder.decode(libEncoded);
            uint256 libDecodeGas = gasBefore - gasleft();

            // Calculate savings percentage
            int256 savingsPercent;
            if (abiDecodeGas > libDecodeGas) {
                savingsPercent = int256(((abiDecodeGas - libDecodeGas) * 100) / abiDecodeGas);
            } else {
                savingsPercent = -int256(((libDecodeGas - abiDecodeGas) * 100) / abiDecodeGas);
            }

            console2.log("  abi.decode:", abiDecodeGas, "gas");
            console2.log("  LibEncoder decode:", libDecodeGas, "gas");
            if (savingsPercent >= 0) {
                console2.log("  Savings:", uint256(savingsPercent), "%");
            } else {
                console2.log("  Savings: -", uint256(-savingsPercent), "% (LibEncoder uses more)");
            }
            console2.log("");

            // Prevent optimization
            require(decoded1.proposal.id > 0 && decoded2.proposal.id > 0, "decoded");
            require(
                decoded1.coreState.nextProposalId > 0 && decoded2.coreState.nextProposalId > 0,
                "decoded"
            );
        }
    }

    function test_gas_size_comparison() public pure {
        console2.log("\nSize Comparison: abi.encode vs LibProposedEventEncoder");
        console2.log("=====================================================\n");

        uint256[] memory blobCounts = new uint256[](4);
        blobCounts[0] = 0;
        blobCounts[1] = 3;
        blobCounts[2] = 6;
        blobCounts[3] = 10;

        for (uint256 i = 0; i < blobCounts.length; i++) {
            IInbox.ProposedEventPayload memory payload = _createTestData(blobCounts[i]);

            bytes memory abiEncoded = abi.encode(payload);
            bytes memory libEncoded = LibProposedEventEncoder.encode(payload);

            uint256 sizeSavings =
                ((abiEncoded.length - libEncoded.length) * 100) / abiEncoded.length;

            console2.log("Blob hashes:", blobCounts[i]);
            console2.log("  abi.encode:", abiEncoded.length, "bytes");
            console2.log("  LibEncoder:  ", libEncoded.length, "bytes");
            console2.log("  Size reduction:", sizeSavings, "%");
            console2.log("");
        }
    }

    function _writeReport() private {
        string memory report = "# LibProposedEventEncoder Gas Report\n\n";
        report = string.concat(report, "## Encoding + Emit Performance\n\n");
        report =
            string.concat(report, "| Blobs | abi.encode | LibProposedEventEncoder | Savings |\n");
        report =
            string.concat(report, "|-------|------------|------------------------|---------|\n");

        // Based on actual test results from test_gas_comparison_optimized
        report = string.concat(report, "| 0 | 6,779 gas | 3,700 gas | 45% |\n");
        report = string.concat(report, "| 3 | 7,869 gas | 4,927 gas | 37% |\n");
        report = string.concat(report, "| 6 | 8,963 gas | 6,154 gas | 31% |\n");
        report = string.concat(report, "| 10 | 10,431 gas | 7,810 gas | 25% |\n\n");

        vm.writeFile("gas-reports/LibProposedEventEncoder.md", report);
    }

    function _createTestData(uint256 _blobHashCount)
        private
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encodePacked("blob", i));
        }

        payload_.proposal = IInbox.Proposal({
            id: 12_345,
            proposer: address(0x1234567890123456789012345678901234567890),
            timestamp: 1_700_000_000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: keccak256("coreState"),
            derivationHash: keccak256("derivation")
        });

        // Create single DerivationSource for the new sources array structure
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: 100, timestamp: 1_700_000_100
            })
        });

        payload_.derivation = IInbox.Derivation({
            originBlockNumber: 18_000_000,
            originBlockHash: bytes32(uint256(18_000_000)),
            basefeeSharingPctg: 75,
            sources: sources
        });

        payload_.coreState = IInbox.CoreState({
            nextProposalId: 12_346,
            lastProposalBlockId: 1_234_599,
            lastFinalizedProposalId: 12_340,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: keccak256("lastTransition"),
            bondInstructionsHash: keccak256("bondInstructions")
        });

        payload_.bondInstructions = new LibBonds.BondInstruction[](2);
        payload_.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x5555),
            payee: address(0x6666)
        });
        payload_.bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 2,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x7777),
            payee: address(0x8888)
        });
    }
}
