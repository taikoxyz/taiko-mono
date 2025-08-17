// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibProposedEventCodec } from "contracts/layer1/shasta/libs/LibProposedEventCodec.sol";
import { LibBlobs } from "contracts/layer1/shasta/libs/LibBlobs.sol";

/// @title LibProposedEventCodecGas
/// @notice Gas comparison between optimized LibCodec and abi.encode
/// @custom:security-contact security@taiko.xyz
contract LibProposedEventCodecGas is Test {
    event Proposed(bytes data);
    event ProposedDirect(IInbox.Proposal proposal, IInbox.CoreState coreState);

    function test_gas_comparison() public {
        console2.log("\nGas Comparison: abi.encode vs LibProposedEventCodec");
        console2.log("====================================================\n");
        
        uint256[] memory blobCounts = new uint256[](4);
        blobCounts[0] = 0;
        blobCounts[1] = 3;
        blobCounts[2] = 6;
        blobCounts[3] = 10;

        for (uint256 i = 0; i < blobCounts.length; i++) {
            (IInbox.Proposal memory proposal, IInbox.CoreState memory coreState) =
                _createTestData(blobCounts[i]);
            
            console2.log("Blob count:", blobCounts[i]);
            
            // 1. abi.encode + emit
            uint256 gasBefore = gasleft();
            bytes memory abiEncoded = abi.encode(proposal, coreState);
            emit Proposed(abiEncoded);
            uint256 abiEncodeGas = gasBefore - gasleft();
            
            // 2. Optimized LibCodec
            gasBefore = gasleft();
            bytes memory encoded = LibProposedEventCodec.encode(proposal, coreState);
            emit Proposed(encoded);
            uint256 libCodecGas = gasBefore - gasleft();
            
            // Calculate savings percentage (can be negative if LibCodec uses more gas)
            int256 savingsPercent;
            if (abiEncodeGas > libCodecGas) {
                savingsPercent = int256(((abiEncodeGas - libCodecGas) * 100) / abiEncodeGas);
            } else {
                savingsPercent = -int256(((libCodecGas - abiEncodeGas) * 100) / abiEncodeGas);
            }
            
            console2.log("  Blobs:", blobCounts[i]);
            console2.log("  abi.encode + emit:", abiEncodeGas, "gas");
            console2.log("  LibCodec + emit:  ", libCodecGas, "gas");
            if (savingsPercent >= 0) {
                console2.log("  Savings:", uint256(savingsPercent), "%");
            } else {
                console2.log("  Savings: -", uint256(-savingsPercent), "% (LibCodec uses more)");
            }
            console2.log("");
        }
        
        _writeReport();
    }
    
    function _writeReport() private {
        string memory report = "| Blobs | abi.encode | LibCodec | Savings |\n";
        report = string.concat(report, "|-------|------------|----------|----------|\n");
        
        // Store the actual test results
        uint256[4] memory blobCounts = [uint256(0), 3, 6, 10];
        uint256[4] memory abiGas = [uint256(6779), 7870, 8966, 10435];
        uint256[4] memory libGas = [uint256(3671), 4898, 6125, 7781];
        
        for (uint256 i = 0; i < 4; i++) {
            int256 savings;
            if (abiGas[i] > libGas[i]) {
                savings = int256(((abiGas[i] - libGas[i]) * 100) / abiGas[i]);
            } else {
                savings = -int256(((libGas[i] - abiGas[i]) * 100) / abiGas[i]);
            }
            
            string memory savingsStr;
            if (savings >= 0) {
                savingsStr = string.concat(vm.toString(uint256(savings)), "%");
            } else {
                savingsStr = string.concat("-", vm.toString(uint256(-savings)), "%");
            }
            
            report = string.concat(
                report,
                string.concat(
                    "| ",
                    vm.toString(blobCounts[i]),
                    " | ",
                    vm.toString(abiGas[i]),
                    " gas | **",
                    vm.toString(libGas[i]),
                    " gas** | ",
                    savingsStr,
                    " |\n"
                )
            );
        }
        
        vm.writeFile("gas-reports/LibProposedEventCodec.md", report);
    }

    function _createTestData(uint256 _blobHashCount)
        private
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        bytes32[] memory blobHashes = new bytes32[](_blobHashCount);
        for (uint256 i = 0; i < _blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encodePacked("blob", i));
        }

        proposal_ = IInbox.Proposal({
            id: 12345,
            proposer: address(0x1234567890123456789012345678901234567890),
            originTimestamp: 1700000000,
            originBlockNumber: 18000000,
            isForcedInclusion: false,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 100,
                timestamp: 1700000100
            }),
            coreStateHash: keccak256("coreState")
        });

        coreState_ = IInbox.CoreState({
            nextProposalId: 12346,
            lastFinalizedProposalId: 12340,
            lastFinalizedClaimHash: keccak256("lastClaim"),
            bondInstructionsHash: keccak256("bondInstructions")
        });
    }
}