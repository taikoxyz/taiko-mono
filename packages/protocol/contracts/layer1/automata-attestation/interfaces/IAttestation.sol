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

    /// @notice Whether an application-enclave MRENCLAVE (code measurement) is trusted.
    /// @param mrEnclave The application enclave's MRENCLAVE.
    /// @return trusted_ Whether the measurement is on the trusted allowlist.
    function trustedUserMrEnclave(bytes32 mrEnclave) external view returns (bool trusted_);

    /// @notice Whether an application-enclave MRSIGNER (enclave signer) is trusted.
    /// @param mrSigner The application enclave's MRSIGNER.
    /// @return trusted_ Whether the signer is on the trusted allowlist.
    function trustedUserMrSigner(bytes32 mrSigner) external view returns (bool trusted_);
}
