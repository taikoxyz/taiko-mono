// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Minimal vendored interface for Succinct's SP1 on-chain verifier.
/// @dev Vendored locally so that AttestationEntrypointBase's ZK-coprocessor import resolves
/// without pulling the full `sp1-contracts` package or adding a conflicting remapping.
/// Taiko uses on-chain (non-ZK) SGX attestation, so this route is unused; the signature
/// matches `sp1-contracts`' `ISP1Verifier.verifyProof`.
interface ISP1Verifier {
    function verifyProof(
        bytes32 programVKey,
        bytes calldata publicValues,
        bytes calldata proofBytes
    )
        external
        view;
}
