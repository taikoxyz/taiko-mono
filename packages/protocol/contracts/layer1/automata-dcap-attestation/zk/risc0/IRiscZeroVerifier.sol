// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Minimal vendored interface for RISC Zero's on-chain verifier.
/// @dev Vendored locally so that AttestationEntrypointBase's ZK-coprocessor import resolves
/// without pulling the full `risc0-ethereum` package or adding a conflicting remapping.
/// Taiko uses on-chain (non-ZK) SGX attestation, so this route is unused; the signature
/// matches `risc0-ethereum`'s `IRiscZeroVerifier.verify`.
interface IRiscZeroVerifier {
    function verify(bytes calldata seal, bytes32 imageId, bytes32 journalDigest) external view;
}
