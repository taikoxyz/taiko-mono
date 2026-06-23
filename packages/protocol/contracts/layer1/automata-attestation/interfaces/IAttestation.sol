// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../lib/QuoteV3Auth/V3Struct.sol";

/// @title IAttestation
/// @custom:security-contact security@taiko.xyz
interface IAttestation {
    function verifyAttestation(bytes calldata data) external returns (bool);
    function verifyParsedQuote(V3Struct.ParsedV3QuoteStruct calldata v3quote)
        external
        returns (bool success, bytes memory retData);

    /// @notice Returns whether an application enclave measurement (MRENCLAVE) is on the trusted
    /// allowlist.
    /// @dev Lets a consumer independently confirm the attested enclave identity, instead of relying
    /// solely on the attestation's internal enforcement. The MRENCLAVE pins the exact enclave
    /// binary, so this is the authoritative identity of a trusted prover enclave.
    /// @param _mrEnclave The application enclave measurement to check.
    /// @return Whether the measurement is trusted.
    function isMrEnclaveTrusted(bytes32 _mrEnclave) external view returns (bool);
}
