// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IDcapAttestation
/// @notice Minimal interface for Automata's DCAP attestation entrypoint
/// (`AutomataDcapAttestationFee`), used by `SgxVerifier` to verify remote-attestation quotes
/// fully on-chain.
/// @custom:security-contact security@taiko.xyz
interface IDcapAttestation {
    /// @notice Verifies an Intel DCAP quote fully on-chain.
    /// @param rawQuote The Intel DCAP quote serialized as raw bytes.
    /// @return success_ Whether the quote was successfully verified.
    /// @return output_ The serialized verification output. On success this is the packed
    /// `Output` struct: quoteVersion (2 bytes, BE), quoteBodyType (2 bytes, BE), tcbStatus
    /// (1 byte), fmspc (6 bytes), followed by the quote body. On failure it is a UTF-8 reason
    /// string.
    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        payable
        returns (bool success_, bytes memory output_);
}
