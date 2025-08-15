// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibProposalCoreStateCodec } from "src/layer1/shasta/libs/LibProposalCoreStateCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { LibCodecBenchmark } from "./LibCodecBenchmark.sol";
import "forge-std/src/console2.sol";

/// @title LibProposalCoreStateCodec_Gas
/// @notice Gas comparison tests between optimized and baseline implementations
/// @custom:security-contact security@taiko.xyz
contract LibProposalCoreStateCodec_Gas is CommonTest {
    event GasReport(
        string method,
        uint256 encodeGas,
        uint256 decodeGas,
        uint256 dataSize,
        uint256 encodeSavings,
        uint256 decodeSavings,
        uint256 sizeSavings
    );

    IInbox.Proposal private proposal;
    IInbox.CoreState private coreState;

    // ---------------------------------------------------------------
    // Baseline implementations using abi.encode/decode
    // ---------------------------------------------------------------

    function encodeBaseline(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encode(_proposal, _coreState);
    }

    function decodeBaseline(bytes memory _data)
        private
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        (proposal_, coreState_) = abi.decode(_data, (IInbox.Proposal, IInbox.CoreState));
    }

    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------

    function setUp() public override {
        super.setUp();

        bytes32[] memory blobHashes = new bytes32[](3);
        blobHashes[0] = keccak256("blob1");
        blobHashes[1] = keccak256("blob2");
        blobHashes[2] = keccak256("blob3");

        proposal = IInbox.Proposal({
            id: 12_345,
            proposer: address(0x1234567890123456789012345678901234567890),
            originTimestamp: 1_234_567_890,
            originBlockNumber: 999_999,
            isForcedInclusion: true,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 1024,
                timestamp: 1_234_567_891
            }),
            coreStateHash: keccak256("coreState")
        });

        coreState = IInbox.CoreState({
            nextProposalId: 12_346,
            lastFinalizedProposalId: 12_344,
            lastFinalizedClaimHash: keccak256("lastClaim"),
            bondInstructionsHash: keccak256("bondInstructions")
        });
    }

    // ---------------------------------------------------------------
    // Gas comparison tests
    // ---------------------------------------------------------------

    /// @notice Compare gas usage with standard setup (3 blob hashes)
    function test_gasComparison_standard() public {
        _runComparison(proposal, coreState, "Standard (3 hashes)");
    }

    /// @notice Compare gas usage with minimal data
    function test_gasComparison_minimal() public {
        bytes32[] memory minHashes = new bytes32[](1);
        IInbox.Proposal memory minProposal = proposal;
        minProposal.blobSlice.blobHashes = minHashes;

        _runComparison(minProposal, coreState, "Minimal (1 hash)");
    }

    /// @notice Compare gas usage with maximum array size
    function test_gasComparison_maximum() public {
        bytes32[] memory maxHashes = new bytes32[](64);
        for (uint256 i = 0; i < 64; i++) {
            maxHashes[i] = keccak256(abi.encode(i));
        }

        IInbox.Proposal memory maxProposal = proposal;
        maxProposal.blobSlice.blobHashes = maxHashes;

        _runComparison(maxProposal, coreState, "Maximum (64 hashes)");
    }

    /// @notice Test gas scaling with different array sizes
    function test_gasScaling() public {
        uint256[] memory sizes = new uint256[](6);
        sizes[0] = 1;
        sizes[1] = 5;
        sizes[2] = 10;
        sizes[3] = 20;
        sizes[4] = 32;
        sizes[5] = 64;

        for (uint256 i = 0; i < sizes.length; i++) {
            bytes32[] memory hashes = new bytes32[](sizes[i]);
            for (uint256 j = 0; j < sizes[i]; j++) {
                hashes[j] = keccak256(abi.encode(i, j));
            }

            IInbox.Proposal memory testProposal = proposal;
            testProposal.blobSlice.blobHashes = hashes;

            _runComparison(
                testProposal,
                coreState,
                string(abi.encodePacked(vm.toString(sizes[i]), " blob hashes"))
            );
        }
    }

    /// @notice Comprehensive benchmark across multiple scenarios
    function test_comprehensiveBenchmark() public {
        uint256 totalBaselineEncode;
        uint256 totalBaselineDecode;
        uint256 totalOptimizedEncode;
        uint256 totalOptimizedDecode;
        uint256 totalBaselineSize;
        uint256 totalOptimizedSize;

        for (uint256 scenario = 1; scenario <= 10; scenario++) {
            uint256 numHashes = scenario * 6;
            if (numHashes > 64) numHashes = 64;

            bytes32[] memory hashes = new bytes32[](numHashes);
            for (uint256 i = 0; i < numHashes; i++) {
                hashes[i] = keccak256(abi.encode(scenario, i));
            }

            IInbox.Proposal memory testProposal = proposal;
            testProposal.blobSlice.blobHashes = hashes;
            testProposal.id = uint48(scenario * 1000);
            testProposal.basefeeSharingPctg = uint8((scenario * 10) % 101);

            // Baseline
            uint256 gas = gasleft();
            bytes memory baselineData = encodeBaseline(testProposal, coreState);
            totalBaselineEncode += gas - gasleft();
            totalBaselineSize += baselineData.length;

            gas = gasleft();
            decodeBaseline(baselineData);
            totalBaselineDecode += gas - gasleft();

            // Optimized
            gas = gasleft();
            bytes memory optimizedData = LibProposalCoreStateCodec.encode(testProposal, coreState);
            totalOptimizedEncode += gas - gasleft();
            totalOptimizedSize += optimizedData.length;

            gas = gasleft();
            LibProposalCoreStateCodec.decode(optimizedData);
            totalOptimizedDecode += gas - gasleft();
        }

        // Report totals
        emit GasReport(
            "Comprehensive (10 scenarios)",
            totalOptimizedEncode,
            totalOptimizedDecode,
            totalOptimizedSize,
            totalBaselineEncode > totalOptimizedEncode
                ? totalBaselineEncode - totalOptimizedEncode
                : 0,
            totalBaselineDecode > totalOptimizedDecode
                ? totalBaselineDecode - totalOptimizedDecode
                : 0,
            totalBaselineSize > totalOptimizedSize ? totalBaselineSize - totalOptimizedSize : 0
        );

        // Verify optimization
        assertTrue(totalOptimizedSize <= totalBaselineSize, "Optimized should use less space");
    }

    /// @notice Test gas cost of validation overhead
    function test_validationOverhead() public view {
        // Test with valid value (no revert)
        IInbox.Proposal memory validProposal = proposal;
        validProposal.basefeeSharingPctg = 100;

        // Compare optimized encoding with baseline
        bytes memory optimized = LibProposalCoreStateCodec.encode(validProposal, coreState);
        bytes memory baseline = encodeBaseline(validProposal, coreState);

        // Our optimized version should still be more efficient than baseline despite validation
        assertTrue(optimized.length <= baseline.length, "Optimized should use less or equal space");
    }

    /// @notice Generate comprehensive benchmark report
    function test_generateBenchmarkReport() public {
        // Test configurations
        uint256[] memory sizes = new uint256[](7);
        sizes[0] = 0;
        sizes[1] = 1;
        sizes[2] = 3;
        sizes[3] = 8;
        sizes[4] = 16;
        sizes[5] = 32;
        sizes[6] = 64;
        
        // Prepare results and labels
        LibCodecBenchmark.BenchmarkResult[] memory results = new LibCodecBenchmark.BenchmarkResult[](sizes.length);
        string[] memory labels = new string[](sizes.length);
        
        for (uint256 i = 0; i < sizes.length; i++) {
            bytes32[] memory hashes = new bytes32[](sizes[i]);
            for (uint256 j = 0; j < sizes[i]; j++) {
                hashes[j] = keccak256(abi.encode(i, j));
            }
            
            IInbox.Proposal memory testProposal = proposal;
            testProposal.blobSlice.blobHashes = hashes;
            
            // Measure baseline
            uint256 gas = gasleft();
            bytes memory baselineData = encodeBaseline(testProposal, coreState);
            results[i].baselineEncode = gas - gasleft();
            results[i].baselineSize = baselineData.length;
            
            gas = gasleft();
            decodeBaseline(baselineData);
            results[i].baselineDecode = gas - gasleft();
            
            // Measure optimized
            gas = gasleft();
            bytes memory optimizedData = LibProposalCoreStateCodec.encode(testProposal, coreState);
            results[i].optimizedEncode = gas - gasleft();
            results[i].optimizedSize = optimizedData.length;
            
            gas = gasleft();
            LibProposalCoreStateCodec.decode(optimizedData);
            results[i].optimizedDecode = gas - gasleft();
            
            // Set label
            labels[i] = string.concat(vm.toString(sizes[i]), " hashes");
        }
        
        // Configure report
        LibCodecBenchmark.BenchmarkConfig memory config = LibCodecBenchmark.BenchmarkConfig({
            reportTitle: "LibProposalCoreStateCodec Benchmark Report",
            summary: "Optimized codec implementation using bit-packing and assembly optimizations for Proposal and CoreState encoding/decoding.",
            testLabels: labels,
            keyFeatures: string.concat(
                "- **Variable-size encoding**: Adapts to blob hash array size\n",
                "- **Compact layout**: 158 bytes base + 32 bytes per blob hash\n",
                "- **Max blob hashes**: 64 (validated)\n",
                "- **Bit-packed fields**: 6-byte IDs and timestamps\n"
            ),
            optimizations: string.concat(
                "- Bit-packing for compact storage\n",
                "- Assembly-optimized memory operations\n",
                "- Loop unrolling for small arrays (1-4 hashes)\n",
                "- Cached memory pointers\n",
                "- Minimal memory allocations\n",
                "- Unchecked arithmetic blocks for safe operations\n"
            ),
            outputFile: "gas-reports/LibProposalCoreStateCodec_benchmark.md"
        });
        
        // Generate report
        LibCodecBenchmark.generateReport(results, config);
    }

    // ---------------------------------------------------------------
    // Helper functions
    // ---------------------------------------------------------------

    function _runComparison(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState,
        string memory _label
    )
        private
    {
        uint256[6] memory metrics; // [baselineEncode, baselineDecode, optEncode, optDecode,
            // baselineSize, optSize]

        // Baseline
        uint256 gas = gasleft();
        bytes memory baselineData = encodeBaseline(_proposal, _coreState);
        metrics[0] = gas - gasleft();
        metrics[4] = baselineData.length;

        gas = gasleft();
        decodeBaseline(baselineData);
        metrics[1] = gas - gasleft();

        // Optimized
        gas = gasleft();
        bytes memory optimizedData = LibProposalCoreStateCodec.encode(_proposal, _coreState);
        metrics[2] = gas - gasleft();
        metrics[5] = optimizedData.length;

        gas = gasleft();
        LibProposalCoreStateCodec.decode(optimizedData);
        metrics[3] = gas - gasleft();

        // Log markdown table for comparison
        console2.log("");
        console2.log(string.concat("Gas Comparison: ", _label));
        console2.log("| Operation | Baseline | Optimized | Difference |");
        console2.log("|-----------|----------|-----------|------------|");
        console2.log(
            string.concat(
                "| Encode    | ",
                vm.toString(metrics[0]),
                "     | ",
                vm.toString(metrics[2]),
                "      | ",
                metrics[0] > metrics[2] ? "-" : "+",
                vm.toString(
                    metrics[0] > metrics[2] ? metrics[0] - metrics[2] : metrics[2] - metrics[0]
                ),
                "    |"
            )
        );
        console2.log(
            string.concat(
                "| Decode    | ",
                vm.toString(metrics[1]),
                "     | ",
                vm.toString(metrics[3]),
                "      | ",
                metrics[1] > metrics[3] ? "-" : "+",
                vm.toString(
                    metrics[1] > metrics[3] ? metrics[1] - metrics[3] : metrics[3] - metrics[1]
                ),
                "    |"
            )
        );

        // Report results
        emit GasReport(
            _label,
            metrics[2], // optimized encode
            metrics[3], // optimized decode
            metrics[5], // optimized size
            metrics[0] > metrics[2] ? metrics[0] - metrics[2] : 0, // encode savings
            metrics[1] > metrics[3] ? metrics[1] - metrics[3] : 0, // decode savings
            metrics[4] > metrics[5] ? metrics[4] - metrics[5] : 0 // size savings
        );
    }

    function _verifyProposal(
        IInbox.Proposal memory _expected,
        IInbox.Proposal memory _actual
    )
        private
        pure
    {
        assertEq(_expected.id, _actual.id);
        assertEq(_expected.proposer, _actual.proposer);
        assertEq(_expected.originTimestamp, _actual.originTimestamp);
        assertEq(_expected.originBlockNumber, _actual.originBlockNumber);
        assertEq(_expected.isForcedInclusion, _actual.isForcedInclusion);
        assertEq(_expected.basefeeSharingPctg, _actual.basefeeSharingPctg);
        assertEq(_expected.coreStateHash, _actual.coreStateHash);
        assertEq(_expected.blobSlice.offset, _actual.blobSlice.offset);
        assertEq(_expected.blobSlice.timestamp, _actual.blobSlice.timestamp);
        assertEq(_expected.blobSlice.blobHashes.length, _actual.blobSlice.blobHashes.length);

        for (uint256 i = 0; i < _expected.blobSlice.blobHashes.length; i++) {
            assertEq(_expected.blobSlice.blobHashes[i], _actual.blobSlice.blobHashes[i]);
        }
    }

    function _verifyCoreState(
        IInbox.CoreState memory _expected,
        IInbox.CoreState memory _actual
    )
        private
        pure
    {
        assertEq(_expected.nextProposalId, _actual.nextProposalId);
        assertEq(_expected.lastFinalizedProposalId, _actual.lastFinalizedProposalId);
        assertEq(_expected.lastFinalizedClaimHash, _actual.lastFinalizedClaimHash);
        assertEq(_expected.bondInstructionsHash, _actual.bondInstructionsHash);
    }
}
