// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/automata-attestation/AutomataDcapV3Attestation.sol";
import "src/layer1/verifiers/LibPublicInput.sol";
import "src/layer1/preconf/libs/LibBlockHeader.sol";
import "src/layer1/verifiers/SgxVerifier.sol";

/// @title GasComparisonTest
/// @notice Comprehensive gas comparison for all optimized keccak256 implementations
contract GasComparisonTest is Test {
    /// @notice Test gas for LibPublicInput.hashPublicInputs (optimized version)
    function test_LibPublicInput_GasOptimized() public view {
        bytes32 aggregatedProvingHash = bytes32(uint256(12_345));
        address verifierContract = address(0x1234567890123456789012345678901234567890);
        address newInstance = address(0);
        uint64 chainId = 167_000;

        uint256 gasBefore = gasleft();
        LibPublicInput.hashPublicInputs(
            aggregatedProvingHash, verifierContract, newInstance, chainId
        );
        uint256 gasUsed = gasBefore - gasleft();

        console.log("LibPublicInput.hashPublicInputs (optimized):", gasUsed, "gas");
    }

    /// @notice Test gas for LibPublicInput using original keccak256
    function test_LibPublicInput_GasOriginal() public view {
        bytes32 aggregatedProvingHash = bytes32(uint256(12_345));
        address verifierContract = address(0x1234567890123456789012345678901234567890);
        address newInstance = address(0);
        uint64 chainId = 167_000;

        uint256 gasBefore = gasleft();
        bytes32 result = keccak256(
            abi.encode("VERIFY_PROOF", chainId, verifierContract, aggregatedProvingHash, newInstance)
        );
        uint256 gasUsed = gasBefore - gasleft();

        console.log("LibPublicInput.hashPublicInputs (original):", gasUsed, "gas");
        console.log("Result:", uint256(result)); // Prevent optimization
    }

    /// @notice Compare gas for SgxVerifier keccak256(abi.encodePacked(publicInputs))
    function test_SgxVerifier_GasOptimized() public view {
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = bytes32(uint256(uint160(address(0x1234567890123456789012345678901234567890))));
        publicInputs[1] = keccak256(
            abi.encode("VERIFY_PROOF", uint64(167_000), address(0x5678), bytes32(uint256(12_345)), address(0))
        );

        uint256 gasBefore = gasleft();
        bytes32 signatureHash;
        assembly {
            signatureHash := keccak256(add(publicInputs, 0x20), 0x40)
        }
        uint256 gasUsed = gasBefore - gasleft();

        console.log("SgxVerifier.keccak256 (optimized):", gasUsed, "gas");
        console.log("Result:", uint256(signatureHash)); // Prevent optimization
    }

    /// @notice Original version for SgxVerifier
    function test_SgxVerifier_GasOriginal() public view {
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = bytes32(uint256(uint160(address(0x1234567890123456789012345678901234567890))));
        publicInputs[1] = keccak256(
            abi.encode("VERIFY_PROOF", uint64(167_000), address(0x5678), bytes32(uint256(12_345)), address(0))
        );

        uint256 gasBefore = gasleft();
        bytes32 signatureHash = keccak256(abi.encodePacked(publicInputs));
        uint256 gasUsed = gasBefore - gasleft();

        console.log("SgxVerifier.keccak256 (original):", gasUsed, "gas");
        console.log("Result:", uint256(signatureHash)); // Prevent optimization
    }

    /// @notice Test gas for LibBlockHeader.hash (optimized version)
    function test_LibBlockHeader_GasOptimized() public view {
        LibBlockHeader.BlockHeader memory blockHeader = _createSampleBlockHeader();

        uint256 gasBefore = gasleft();
        LibBlockHeader.hash(blockHeader);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("LibBlockHeader.hash (optimized):", gasUsed, "gas");
    }

    /// @notice Test gas for LibBlockHeader using original keccak256
    function test_LibBlockHeader_GasOriginal() public view {
        LibBlockHeader.BlockHeader memory blockHeader = _createSampleBlockHeader();

        uint256 gasBefore = gasleft();
        bytes memory rlpEncoded = LibBlockHeader.encodeRLP(blockHeader);
        bytes32 result = keccak256(rlpEncoded);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("LibBlockHeader.hash (original):", gasUsed, "gas");
        console.log("Result:", uint256(result)); // Prevent optimization
    }

    /// @notice Test gas for AutomataDcapV3Attestation keccak256(pubKey) - optimized
    function test_AutomataDcapV3_GasOptimized() public view {
        bytes memory pubKey = _createSamplePubKey();

        uint256 gasBefore = gasleft();
        bytes32 hash;
        assembly {
            hash := keccak256(add(pubKey, 0x20), mload(pubKey))
        }
        uint256 gasUsed = gasBefore - gasleft();

        console.log("AutomataDcapV3Attestation.keccak256 (optimized):", gasUsed, "gas");
        console.log("Result:", uint256(hash)); // Prevent optimization
    }

    /// @notice Test gas for AutomataDcapV3Attestation keccak256(pubKey) - original
    function test_AutomataDcapV3_GasOriginal() public view {
        bytes memory pubKey = _createSamplePubKey();

        uint256 gasBefore = gasleft();
        bytes32 hash = keccak256(pubKey);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("AutomataDcapV3Attestation.keccak256 (original):", gasUsed, "gas");
        console.log("Result:", uint256(hash)); // Prevent optimization
    }

    /// @notice Comprehensive gas comparison summary
    function test_GasComparisonSummary() public view {
        console.log("\n=== GAS COMPARISON SUMMARY ===\n");

        // LibPublicInput
        {
            bytes32 aggregatedProvingHash = bytes32(uint256(12_345));
            address verifierContract = address(0x1234567890123456789012345678901234567890);
            address newInstance = address(0);
            uint64 chainId = 167_000;

            uint256 gasOriginal = gasleft();
            keccak256(
                abi.encode("VERIFY_PROOF", chainId, verifierContract, aggregatedProvingHash, newInstance)
            );
            gasOriginal = gasOriginal - gasleft();

            uint256 gasOptimized = gasleft();
            LibPublicInput.hashPublicInputs(aggregatedProvingHash, verifierContract, newInstance, chainId);
            gasOptimized = gasOptimized - gasleft();

            console.log("1. LibPublicInput.hashPublicInputs");
            console.log("   Original:  ", gasOriginal, "gas");
            console.log("   Optimized: ", gasOptimized, "gas");
            if (gasOriginal > gasOptimized) {
                console.log("   Saved:     ", gasOriginal - gasOptimized, "gas");
                console.log("   Reduction: ", ((gasOriginal - gasOptimized) * 100) / gasOriginal, "%\n");
            } else {
                console.log("   NOTE: View function overhead affects measurement\n");
            }
        }

        // SgxVerifier
        {
            bytes32[] memory publicInputs = new bytes32[](2);
            publicInputs[0] = bytes32(uint256(uint160(address(0x1234))));
            publicInputs[1] = bytes32(uint256(5678));

            uint256 gasOriginal = gasleft();
            keccak256(abi.encodePacked(publicInputs));
            gasOriginal = gasOriginal - gasleft();

            uint256 gasOptimized = gasleft();
            assembly {
                let hash := keccak256(add(publicInputs, 0x20), 0x40)
                mstore(0, hash) // Use result
            }
            gasOptimized = gasOptimized - gasleft();

            console.log("2. SgxVerifier.keccak256(abi.encodePacked)");
            console.log("   Original:  ", gasOriginal, "gas");
            console.log("   Optimized: ", gasOptimized, "gas");
            if (gasOriginal > gasOptimized) {
                console.log("   Saved:     ", gasOriginal - gasOptimized, "gas");
                console.log("   Reduction: ", ((gasOriginal - gasOptimized) * 100) / gasOriginal, "%\n");
            } else {
                console.log("   NOTE: View function overhead affects measurement\n");
            }
        }

        // LibBlockHeader
        {
            LibBlockHeader.BlockHeader memory blockHeader = _createSampleBlockHeader();

            uint256 gasOriginal = gasleft();
            bytes memory rlpEncoded = LibBlockHeader.encodeRLP(blockHeader);
            keccak256(rlpEncoded);
            gasOriginal = gasOriginal - gasleft();

            uint256 gasOptimized = gasleft();
            LibBlockHeader.hash(blockHeader);
            gasOptimized = gasOptimized - gasleft();

            console.log("3. LibBlockHeader.hash");
            console.log("   Original:  ", gasOriginal, "gas");
            console.log("   Optimized: ", gasOptimized, "gas");
            if (gasOriginal > gasOptimized) {
                console.log("   Saved:     ", gasOriginal - gasOptimized, "gas");
                console.log("   Reduction: ", ((gasOriginal - gasOptimized) * 100) / gasOriginal, "%\n");
            } else {
                console.log("   NOTE: View function overhead affects measurement\n");
            }
        }

        // AutomataDcapV3Attestation
        {
            bytes memory pubKey = _createSamplePubKey();

            uint256 gasOriginal = gasleft();
            keccak256(pubKey);
            gasOriginal = gasOriginal - gasleft();

            uint256 gasOptimized = gasleft();
            assembly {
                let hash := keccak256(add(pubKey, 0x20), mload(pubKey))
                mstore(0, hash) // Use result
            }
            gasOptimized = gasOptimized - gasleft();

            console.log("4. AutomataDcapV3Attestation.keccak256(bytes)");
            console.log("   Original:  ", gasOriginal, "gas");
            console.log("   Optimized: ", gasOptimized, "gas");
            if (gasOriginal > gasOptimized) {
                console.log("   Saved:     ", gasOriginal - gasOptimized, "gas");
                console.log("   Reduction: ", ((gasOriginal - gasOptimized) * 100) / gasOriginal, "%");
            } else {
                console.log("   NOTE: View function overhead affects measurement");
            }
        }

        console.log("\n================================\n");
    }

    function _createSampleBlockHeader() internal view returns (LibBlockHeader.BlockHeader memory) {
        return LibBlockHeader.BlockHeader({
            parentHash: bytes32(uint256(1)),
            ommersHash: bytes32(uint256(2)),
            coinbase: address(0x1234),
            stateRoot: bytes32(uint256(3)),
            transactionsRoot: bytes32(uint256(4)),
            receiptRoot: bytes32(uint256(5)),
            bloom: new bytes(256),
            difficulty: 1000,
            number: 12_345,
            gasLimit: 30_000_000,
            gasUsed: 15_000_000,
            timestamp: block.timestamp,
            extraData: hex"1234567890",
            prevRandao: bytes32(uint256(6)),
            nonce: bytes8(uint64(123)),
            baseFeePerGas: 1 gwei,
            withdrawalsRoot: bytes32(uint256(7))
        });
    }

    function _createSamplePubKey() internal pure returns (bytes memory) {
        // 65-byte uncompressed public key (typical size)
        bytes memory pubKey = new bytes(65);
        pubKey[0] = 0x04; // Uncompressed key prefix
        for (uint256 i = 1; i < 65; i++) {
            pubKey[i] = bytes1(uint8(i));
        }
        return pubKey;
    }
}
