// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibProposeInputDecoder } from "src/layer1/core/libs/LibProposeInputDecoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProposeInputDecoderGas
/// @notice Gas comparison between optimized LibProposeInputDecoder and abi.encode/decode
/// @dev Measures both execution gas and calldata gas costs
/// @custom:security-contact security@taiko.xyz
contract LibProposeInputDecoderGas is Test {
    // Storage for gas values to write to report
    uint256[4] private simpleGas;
    uint256[4] private mediumGas;
    uint256[4] private complexGas;
    uint256[4] private largeGas;

    function test_gas_comparison_decoding() public {
        console2.log("\nGas Comparison: abi.decode vs LibProposeInputDecoder.decode");
        console2.log("========================================================\n");

        // Test with different combinations
        _runDecodingTest(1, 0, 0, "Simple: 1 proposal, 0 transitions, 0 bonds", simpleGas);
        _runDecodingTest(2, 1, 0, "Medium: 2 proposals, 1 transition, 0 bonds", mediumGas);
        _runDecodingTest(3, 2, 2, "Complex: 3 proposals, 2 transitions, 2 bonds", complexGas);
        _runDecodingTest(5, 5, 10, "Large: 5 proposals, 5 transitions, 10 bonds", largeGas);

        _writeReport();
    }

    function _runDecodingTest(
        uint256 _proposalCount,
        uint256 _transitionCount,
        uint256 _totalBondInstructions,
        string memory _label,
        uint256[4] storage _gasStorage
    )
        private
    {
        IInbox.ProposeInput memory input =
            _createTestData(_proposalCount, _transitionCount, _totalBondInstructions);

        // Prepare encoded data
        bytes memory abiEncoded = abi.encode(input);
        bytes memory libEncoded = LibProposeInputDecoder.encode(input);

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
        IInbox.ProposeInput memory decoded1 = abi.decode(abiEncoded, (IInbox.ProposeInput));
        gasValues[2] = gasBefore - gasleft();

        // 2. LibProposeInputDecoder.decode
        gasBefore = gasleft();
        IInbox.ProposeInput memory decoded2 = LibProposeInputDecoder.decode(libEncoded);
        gasValues[3] = gasBefore - gasleft();

        // Prevent optimization
        require(
            decoded1.deadline > 0 && decoded2.deadline > 0 && decoded1.coreState.nextProposalId > 0
                && decoded2.coreState.nextProposalId > 0,
            "decoded"
        );

        // Display results
        console2.log("  abi.encode + abi.decode:");
        console2.log("    Calldata gas:", gasValues[0]);
        console2.log("    Decode gas:", gasValues[2]);
        console2.log("    Total gas:", gasValues[0] + gasValues[2]);

        console2.log("  LibProposeInputDecoder:");
        console2.log("    Calldata gas:", gasValues[1]);
        console2.log("    Decode gas:", gasValues[3]);
        console2.log("    Total gas:", gasValues[1] + gasValues[3]);

        // Calculate savings
        uint256 abiTotal = gasValues[0] + gasValues[2];
        uint256 libTotal = gasValues[1] + gasValues[3];

        if (abiTotal > libTotal) {
            uint256 savings = ((abiTotal - libTotal) * 100) / abiTotal;
            console2.log("  Total savings:", savings, "%");
        } else {
            uint256 overhead = ((libTotal - abiTotal) * 100) / abiTotal;
            console2.log("  Total overhead:", overhead, "%");
        }
        console2.log("");

        // Store gas values for report
        _gasStorage[0] = abiTotal;
        _gasStorage[1] = libTotal;
        _gasStorage[2] = abiTotal > libTotal ? ((abiTotal - libTotal) * 100) / abiTotal : 0;
        _gasStorage[3] = abiTotal <= libTotal ? ((libTotal - abiTotal) * 100) / abiTotal : 0;
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
        uint256 _transitionCount,
        uint256 _totalBondInstructions
    )
        private
        pure
        returns (IInbox.ProposeInput memory input)
    {
        input.deadline = 2_000_000;

        input.coreState = IInbox.CoreState({
            nextProposalId: 100,
            lastProposalBlockId: 9999,
            lastFinalizedProposalId: 95,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: keccak256("last_finalized"),
            bondInstructionsHash: keccak256("bond_instructions")
        });

        input.parentProposals = new IInbox.Proposal[](_proposalCount);
        for (uint256 i = 0; i < _proposalCount; i++) {
            input.parentProposals[i] = IInbox.Proposal({
                id: uint48(96 + i),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint48(1_000_000 + i * 10),
                endOfSubmissionWindowTimestamp: uint48(1_000_000 + i * 10 + 12),
                coreStateHash: keccak256(abi.encodePacked("core_state", i)),
                derivationHash: keccak256(abi.encodePacked("derivation", i))
            });
        }

        input.blobReference = LibBlobs.BlobReference({
            blobStartIndex: 1, numBlobs: uint16(_proposalCount * 2), offset: 512
        });

        input.transitionRecords = new IInbox.TransitionRecord[](_transitionCount);
        uint256 bondIndex = 0;
        for (uint256 i = 0; i < _transitionCount; i++) {
            // Distribute bond instructions across transition records
            uint256 bondsForThisTransition = 0;
            if (i < _transitionCount - 1) {
                bondsForThisTransition = _totalBondInstructions / _transitionCount;
            } else {
                // Last transition gets remaining bonds
                bondsForThisTransition = _totalBondInstructions - bondIndex;
            }

            LibBonds.BondInstruction[] memory bondInstructions =
                new LibBonds.BondInstruction[](bondsForThisTransition);
            for (uint256 j = 0; j < bondsForThisTransition; j++) {
                bondInstructions[j] = LibBonds.BondInstruction({
                    proposalId: uint48(96 + i),
                    bondType: j % 2 == 0
                        ? LibBonds.BondType.LIVENESS
                        : LibBonds.BondType.PROVABILITY,
                    payer: address(uint160(0xaaaa + bondIndex)),
                    payee: address(uint160(0xbbbb + bondIndex))
                });
                bondIndex++;
            }

            input.transitionRecords[i] = IInbox.TransitionRecord({
                span: uint8(1 + (i % 3)),
                transitionHash: keccak256(abi.encodePacked("transition", i)),
                checkpointHash: keccak256(abi.encodePacked("end_header", i)),
                bondInstructions: bondInstructions
            });
        }

        // Add checkpoint if needed
        input.checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
        });
    }

    function _writeReport() private {
        string memory report = "# LibProposeInputDecoder Gas Report\n\n";
        report = string.concat(report, "## Total Cost (Calldata + Decoding)\n\n");
        report = string.concat(
            report, "| Scenario | abi.encode + abi.decode | LibProposeInputDecoder | Savings |\n"
        );
        report = string.concat(
            report, "|----------|-------------------------|----------------------|---------|\n"
        );

        // Format gas values with commas for readability
        report = string.concat(
            report,
            "| Simple (1P, 0C, 0B) | ",
            _formatGas(simpleGas[0]),
            " gas | ",
            _formatGas(simpleGas[1]),
            " gas | ",
            vm.toString(simpleGas[2]),
            "% |\n"
        );
        report = string.concat(
            report,
            "| Medium (2P, 1C, 0B) | ",
            _formatGas(mediumGas[0]),
            " gas | ",
            _formatGas(mediumGas[1]),
            " gas | ",
            vm.toString(mediumGas[2]),
            "% |\n"
        );
        report = string.concat(
            report,
            "| Complex (3P, 2C, 2B) | ",
            _formatGas(complexGas[0]),
            " gas | ",
            _formatGas(complexGas[1]),
            " gas | ",
            vm.toString(complexGas[2]),
            "% |\n"
        );
        report = string.concat(
            report,
            "| Large (5P, 5C, 10B) | ",
            _formatGas(largeGas[0]),
            " gas | ",
            _formatGas(largeGas[1]),
            " gas | ",
            vm.toString(largeGas[2]),
            "% |\n\n"
        );

        report = string.concat(
            report, "**Note**: P = Proposals, C = Transition Records, B = Bond Instructions\n"
        );
        report = string.concat(
            report, "**Note**: Gas measurements include both calldata and decode costs\n"
        );

        vm.writeFile("gas-reports/LibProposeInputDecoder.md", report);
    }

    function _formatGas(uint256 _gas) private pure returns (string memory) {
        if (_gas >= 1000) {
            uint256 thousands = _gas / 1000;
            uint256 remainder = _gas % 1000;
            if (remainder < 10) {
                return string.concat(vm.toString(thousands), ",00", vm.toString(remainder));
            } else if (remainder < 100) {
                return string.concat(vm.toString(thousands), ",0", vm.toString(remainder));
            } else {
                return string.concat(vm.toString(thousands), ",", vm.toString(remainder));
            }
        }
        return vm.toString(_gas);
    }
}
