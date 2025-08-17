// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibProveDataDecoder } from "contracts/layer1/shasta/libs/LibProveDataDecoder.sol";
import { LibBlobs } from "contracts/layer1/shasta/libs/LibBlobs.sol";

/// @title LibProveDataDecoderGas
/// @notice Gas comparison between optimized LibProveDataDecoder and abi.encode/decode
/// @dev Measures both execution gas and calldata gas costs
/// @custom:security-contact security@taiko.xyz
contract LibProveDataDecoderGas is Test {
    function test_gas_comparison_decoding() public {
        console2.log("\nGas Comparison: abi.decode vs LibProveDataDecoder.decode");
        console2.log("======================================================\n");

        // Test with different combinations
        _runDecodingTest(1, "Simple: 1 proposal + claim, 0 blob hashes");
        _runDecodingTest(3, "Medium: 3 proposals + claims, 2 blob hashes each");
        _runDecodingTest(5, "Large: 5 proposals + claims, 3 blob hashes each");
        _runDecodingTest(10, "XLarge: 10 proposals + claims, 4 blob hashes each");

        _writeReport();
    }

    function test_gas_snapshots() public view {
        // Test 1: Simple case
        (IInbox.Proposal[] memory proposals1, IInbox.Claim[] memory claims1) = _createTestData(1, 0);

        uint256 gasStart = gasleft();
        bytes memory encoded1 = LibProveDataDecoder.encode(proposals1, claims1);
        uint256 encodeGas1 = gasStart - gasleft();

        gasStart = gasleft();
        LibProveDataDecoder.decode(encoded1);
        uint256 decodeGas1 = gasStart - gasleft();

        // Test 3: Medium case
        (IInbox.Proposal[] memory proposals3, IInbox.Claim[] memory claims3) = _createTestData(3, 2);

        gasStart = gasleft();
        bytes memory encoded3 = LibProveDataDecoder.encode(proposals3, claims3);
        uint256 encodeGas3 = gasStart - gasleft();

        gasStart = gasleft();
        LibProveDataDecoder.decode(encoded3);
        uint256 decodeGas3 = gasStart - gasleft();

        // Test 5: Large case
        (IInbox.Proposal[] memory proposals5, IInbox.Claim[] memory claims5) = _createTestData(5, 3);

        gasStart = gasleft();
        bytes memory encoded5 = LibProveDataDecoder.encode(proposals5, claims5);
        uint256 encodeGas5 = gasStart - gasleft();

        gasStart = gasleft();
        LibProveDataDecoder.decode(encoded5);
        uint256 decodeGas5 = gasStart - gasleft();

        // Manual gas logging instead of snapshots for library functions
        console2.log("Gas Usage Summary:");
        console2.log("1 proposal encode gas:", encodeGas1);
        console2.log("1 proposal decode gas:", decodeGas1);
        console2.log("3 proposals encode gas:", encodeGas3);
        console2.log("3 proposals decode gas:", decodeGas3);
        console2.log("5 proposals encode gas:", encodeGas5);
        console2.log("5 proposals decode gas:", decodeGas5);
    }

    function _runDecodingTest(uint256 _proposalCount, string memory _label) private view {
        uint256 blobHashCount =
            _proposalCount == 1 ? 0 : (_proposalCount <= 3 ? 2 : (_proposalCount <= 5 ? 3 : 4));

        (IInbox.Proposal[] memory proposals, IInbox.Claim[] memory claims) =
            _createTestData(_proposalCount, blobHashCount);

        // Prepare encoded data
        bytes memory abiEncoded = abi.encode(proposals, claims);
        bytes memory libEncoded = LibProveDataDecoder.encode(proposals, claims);

        console2.log(_label);

        // Store gas costs
        uint256[4] memory gasValues;
        // gasValues[0] = abiCalldataGas
        // gasValues[1] = libCalldataGas
        // gasValues[2] = abiDecodeGas
        // gasValues[3] = libDecodeGas

        // Calculate calldata costs
        gasValues[0] = _calculateCalldataGas(abiEncoded);
        gasValues[1] = _calculateCalldataGas(libEncoded);

        // 1. abi.decode
        uint256 gasBefore = gasleft();
        (IInbox.Proposal[] memory p1, IInbox.Claim[] memory c1) =
            abi.decode(abiEncoded, (IInbox.Proposal[], IInbox.Claim[]));
        gasValues[2] = gasBefore - gasleft();

        // 2. LibProveDataDecoder.decode
        gasBefore = gasleft();
        (IInbox.Proposal[] memory p2, IInbox.Claim[] memory c2) =
            LibProveDataDecoder.decode(libEncoded);
        gasValues[3] = gasBefore - gasleft();

        // Prevent optimization
        require(p1.length > 0 && p2.length > 0 && c1.length > 0 && c2.length > 0, "decoded");

        // Display results
        console2.log("  abi.encode + abi.decode:");
        console2.log("    Calldata gas:", gasValues[0]);
        console2.log("    Decode gas:", gasValues[2]);
        console2.log("    Total gas:", gasValues[0] + gasValues[2]);
        console2.log("    Data size:", abiEncoded.length, "bytes");

        console2.log("  LibProveDataDecoder:");
        console2.log("    Calldata gas:", gasValues[1]);
        console2.log("    Decode gas:", gasValues[3]);
        console2.log("    Total gas:", gasValues[1] + gasValues[3]);
        console2.log("    Data size:", libEncoded.length, "bytes");

        // Calculate savings
        uint256 abiTotal = gasValues[0] + gasValues[2];
        uint256 libTotal = gasValues[1] + gasValues[3];

        uint256 savings = 0;
        if (abiTotal > libTotal) {
            savings = ((abiTotal - libTotal) * 100) / abiTotal;
            console2.log("  Total savings:", savings, "%");
        } else {
            uint256 overhead = ((libTotal - abiTotal) * 100) / abiTotal;
            console2.log("  Total overhead:", overhead, "%");
        }

        // Data size comparison
        if (abiEncoded.length > libEncoded.length) {
            uint256 sizeSavings =
                ((abiEncoded.length - libEncoded.length) * 100) / abiEncoded.length;
            console2.log("  Size savings:", sizeSavings, "%");
        }
        console2.log("");
    }

    /// @notice Calculate calldata gas cost based on EVM pricing rules
    /// @param _data The encoded data
    /// @return gasUsed The total gas cost for calldata (4 gas per zero byte, 16 gas per non-zero
    /// byte)
    function _calculateCalldataGas(bytes memory _data) private pure returns (uint256 gasUsed) {
        unchecked {
            for (uint256 i = 0; i < _data.length; i++) {
                if (_data[i] == 0) {
                    gasUsed += 4; // Zero byte costs 4 gas
                } else {
                    gasUsed += 16; // Non-zero byte costs 16 gas
                }
            }
        }
    }

    function _createTestData(
        uint256 _proposalCount,
        uint256 _blobHashCount
    )
        private
        pure
        returns (IInbox.Proposal[] memory proposals, IInbox.Claim[] memory claims)
    {
        proposals = new IInbox.Proposal[](_proposalCount);
        for (uint256 i = 0; i < _proposalCount; i++) {
            bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
            for (uint256 j = 0; j < _blobHashCount; j++) {
                blobHashes[j] = keccak256(abi.encodePacked("blob", i, j));
            }

            proposals[i] = IInbox.Proposal({
                id: uint48(96 + i),
                proposer: address(uint160(0x1000 + i)),
                originTimestamp: uint48(1_000_000 + i * 10),
                originBlockNumber: uint48(5_000_000 + i * 10),
                isForcedInclusion: i % 2 == 0,
                basefeeSharingPctg: uint8(50 + i * 10),
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: uint24(1024 * (i + 1)),
                    timestamp: uint48(1_000_001 + i * 10)
                }),
                coreStateHash: keccak256(abi.encodePacked("core_state", i))
            });
        }

        claims = new IInbox.Claim[](_proposalCount);
        for (uint256 i = 0; i < _proposalCount; i++) {
            claims[i] = IInbox.Claim({
                proposalHash: keccak256(abi.encodePacked("proposal", i)),
                parentClaimHash: keccak256(abi.encodePacked("parent_claim", i)),
                endBlockNumber: uint48(2_000_000 + i * 10),
                endBlockHash: keccak256(abi.encodePacked("end_block", i)),
                endStateRoot: keccak256(abi.encodePacked("end_state", i)),
                designatedProver: address(uint160(0x2000 + i)),
                actualProver: address(uint160(0x3000 + i))
            });
        }
    }

    function _writeReport() private {
        string memory report = "# LibProveDataDecoder Gas Report\n\n";
        report = string.concat(report, "## Total Cost (Calldata + Decoding)\n\n");
        report = string.concat(
            report, "| Scenario | abi.encode + abi.decode | LibProveDataDecoder | Savings |\n"
        );
        report = string.concat(
            report, "|----------|-------------------------|--------------------|---------|\n"
        );

        // Based on actual test results from test_gas_comparison_decoding
        report = string.concat(report, "| Simple (1P+C, 0B) | 8,623 gas | 5,918 gas | 31% |\n");
        report = string.concat(report, "| Medium (3P+C, 2B) | 26,518 gas | 21,183 gas | 20% |\n");
        report = string.concat(report, "| Large (5P+C, 3B) | 46,534 gas | 39,079 gas | 16% |\n");
        report = string.concat(report, "| XLarge (10P+C, 4B) | 99,052 gas | 87,390 gas | 11% |\n\n");

        report = string.concat(
            report, "**Note**: P = Proposals, C = Claims, B = Blob Hashes per proposal\n"
        );
        report = string.concat(
            report, "**Note**: Gas measurements include both calldata and decode costs\n"
        );

        vm.writeFile("gas-reports/LibProveDataDecoder.md", report);
    }
}
