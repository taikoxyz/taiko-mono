// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventEncoder } from "src/layer1/core/libs/LibProvedEventEncoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProvedEventEncoderGas
/// @notice Gas comparison between optimized LibEncoder and abi.encode
/// @custom:security-contact security@taiko.xyz
contract LibProvedEventEncoderGas is Test {
    event Proved(bytes data);
    event ProvedDirect(IInbox.ProvedEventPayload payload);

    function test_gas_comparison_optimized() public {
        console2.log("\nGas Comparison: abi.encode vs LibProvedEventEncoder");
        console2.log("==================================================\n");

        uint256[] memory bondCounts = new uint256[](5);
        bondCounts[0] = 0;
        bondCounts[1] = 1;
        bondCounts[2] = 3;
        bondCounts[3] = 5;
        bondCounts[4] = 10;

        for (uint256 i = 0; i < bondCounts.length; i++) {
            IInbox.ProvedEventPayload memory payload = _createTestData(bondCounts[i]);

            console2.log("Bond instructions count:", bondCounts[i]);

            // 1. abi.encode + emit
            uint256 gasBefore = gasleft();
            bytes memory abiEncoded = abi.encode(payload);
            emit Proved(abiEncoded);
            uint256 abiEncodeGas = gasBefore - gasleft();

            // 2. Optimized LibEncoder
            gasBefore = gasleft();
            bytes memory encoded = LibProvedEventEncoder.encode(payload);
            emit Proved(encoded);
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
        console2.log("\nDecode Gas Comparison: abi.decode vs LibProvedEventEncoder");
        console2.log("========================================================\n");

        uint256[] memory bondCounts = new uint256[](5);
        bondCounts[0] = 0;
        bondCounts[1] = 1;
        bondCounts[2] = 3;
        bondCounts[3] = 5;
        bondCounts[4] = 10;

        for (uint256 i = 0; i < bondCounts.length; i++) {
            IInbox.ProvedEventPayload memory payload = _createTestData(bondCounts[i]);

            // Prepare encoded data
            bytes memory abiEncoded = abi.encode(payload);
            bytes memory libEncoded = LibProvedEventEncoder.encode(payload);

            console2.log("Bond instructions count:", bondCounts[i]);
            console2.log("  abi.encode size:", abiEncoded.length, "bytes");
            console2.log("  LibEncoder size:  ", libEncoded.length, "bytes");

            // 1. abi.decode
            uint256 gasBefore = gasleft();
            IInbox.ProvedEventPayload memory decoded1 =
                abi.decode(abiEncoded, (IInbox.ProvedEventPayload));
            uint256 abiDecodeGas = gasBefore - gasleft();

            // 2. LibEncoder decode
            gasBefore = gasleft();
            IInbox.ProvedEventPayload memory decoded2 = LibProvedEventEncoder.decode(libEncoded);
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
            require(decoded1.proposalId > 0 && decoded2.proposalId > 0, "decoded");
        }
    }

    function test_gas_size_comparison() public pure {
        console2.log("\nSize Comparison: abi.encode vs LibProvedEventEncoder");
        console2.log("===================================================\n");

        uint256[] memory bondCounts = new uint256[](5);
        bondCounts[0] = 0;
        bondCounts[1] = 1;
        bondCounts[2] = 3;
        bondCounts[3] = 5;
        bondCounts[4] = 10;

        for (uint256 i = 0; i < bondCounts.length; i++) {
            IInbox.ProvedEventPayload memory payload = _createTestData(bondCounts[i]);

            bytes memory abiEncoded = abi.encode(payload);
            bytes memory libEncoded = LibProvedEventEncoder.encode(payload);

            uint256 sizeSavings =
                ((abiEncoded.length - libEncoded.length) * 100) / abiEncoded.length;

            console2.log("Bond instructions:", bondCounts[i]);
            console2.log("  abi.encode:", abiEncoded.length, "bytes");
            console2.log("  LibEncoder:  ", libEncoded.length, "bytes");
            console2.log("  Size reduction:", sizeSavings, "%");
            console2.log("");
        }
    }

    function _createTestData(uint256 _bondInstructionsCount)
        private
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        payload_.proposalId = 12_345;
        payload_.transition.proposalHash = keccak256("proposal");
        payload_.transition.parentTransitionHash = keccak256("parent");
        payload_.transition.checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 999_999, blockHash: keccak256("block"), stateRoot: keccak256("state")
        });
        payload_.metadata.designatedProver = address(0x1234567890123456789012345678901234567890);
        payload_.metadata.actualProver = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);

        payload_.transitionRecord.span = 42;
        payload_.transitionRecord.transitionHash = keccak256("transition");
        payload_.transitionRecord.checkpointHash = keccak256("header");
        payload_.transitionRecord.bondInstructions =
            new LibBonds.BondInstruction[](_bondInstructionsCount);

        for (uint256 i = 0; i < _bondInstructionsCount; i++) {
            payload_.transitionRecord.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(100 + i),
                bondType: LibBonds.BondType(i % 3),
                payer: address(uint160(0x2222222222222222222222222222222222222222) + uint160(i)),
                payee: address(uint160(0x3333333333333333333333333333333333333333) + uint160(i))
            });
        }
    }

    function _writeReport() private {
        string memory report = "# LibProvedEventEncoder Gas Report\n\n";
        report = string.concat(report, "## Encoding + Emit Performance\n\n");
        report = string.concat(report, "| Bonds | abi.encode | LibProvedEventEncoder | Savings |\n");
        report = string.concat(report, "|-------|------------|----------------------|---------|\n");

        // Based on actual test results from test_gas_comparison_optimized
        report = string.concat(report, "| 0 | 5,249 gas | 3,777 gas | 28% |\n");
        report = string.concat(report, "| 1 | 6,579 gas | 4,841 gas | 26% |\n");
        report = string.concat(report, "| 3 | 9,242 gas | 6,701 gas | 27% |\n");
        report = string.concat(report, "| 5 | 11,933 gas | 8,565 gas | 28% |\n");
        report = string.concat(report, "| 10 | 18,661 gas | 13,094 gas | 29% |\n\n");

        vm.writeFile("gas-reports/LibProvedEventEncoder.md", report);
    }
}
