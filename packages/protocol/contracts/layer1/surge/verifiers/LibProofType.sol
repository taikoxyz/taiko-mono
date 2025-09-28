// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibProofType
/// @dev This library offers a custom type to represent proofs.
/// @custom:security-contact security@nethermind.io
library LibProofType {
    // This represents a bitmap of proof types, allowing for up to 16 distinct proof types.
    // Bitmap layout:
    // [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, SGX_GETH, SP1_RETH, RISC0_RETH, TDX_RETH, SGX_RETH]
    type ProofType is uint16;

    uint8 internal constant NUM_PROOF_TYPES = 5;

    uint16 internal constant ZK_MASK = 0x0C; // 0b01100
    uint16 internal constant TEE_MASK = 0x13; // 0b10011

    // Invidual proof types
    // --------------------

    /// @dev Empty proof type (0b0000)
    function empty() internal pure returns (ProofType) {
        return ProofType.wrap(0x00);
    }

    /// @dev SGX Reth proof type (0b0001)
    function sgxReth() internal pure returns (ProofType) {
        return ProofType.wrap(0x01);
    }

    /// @dev RISC-0 Reth proof type (0b0100)
    function risc0Reth() internal pure returns (ProofType) {
        return ProofType.wrap(0x04);
    }

    /// @dev SP1 Reth proof type (0b1000)
    function sp1Reth() internal pure returns (ProofType) {
        return ProofType.wrap(0x08);
    }

    /// @dev SGX Geth proof type (0b10000)
    function sgxGeth() internal pure returns (ProofType) {
        return ProofType.wrap(0x10);
    }

    // ZK / TEE type detectors
    // -----------------------

    function isZkProof(ProofType _proofType) internal pure returns (bool) {
        uint16 pt = ProofType.unwrap(_proofType);
        return (pt & ZK_MASK) != 0 && (pt & TEE_MASK) == 0;
    }

    function isTeeProof(ProofType _proofType) internal pure returns (bool) {
        uint16 pt = ProofType.unwrap(_proofType);
        return (pt & ZK_MASK) == 0 && (pt & TEE_MASK) != 0;
    }

    function isZkTeeProof(ProofType _proofType) internal pure returns (bool) {
        uint16 pt = ProofType.unwrap(_proofType);
        return (pt & ZK_MASK) != 0 && (pt & TEE_MASK) != 0;
    }

    // Misc helpers
    // ------------

    function equals(ProofType _proofType1, ProofType _proofType2) internal pure returns (bool) {
        uint16 pt1 = ProofType.unwrap(_proofType1);
        uint16 pt2 = ProofType.unwrap(_proofType2);
        return pt1 == pt2;
    }

    function combine(
        ProofType _proofType1,
        ProofType _proofType2
    )
        internal
        pure
        returns (ProofType)
    {
        uint16 pt1 = ProofType.unwrap(_proofType1);
        uint16 pt2 = ProofType.unwrap(_proofType2);
        return ProofType.wrap(pt1 | pt2);
    }
}
