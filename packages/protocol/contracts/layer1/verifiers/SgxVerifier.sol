// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BaseSgxVerifier } from "./BaseSgxVerifier.sol";

/// @title SgxVerifier
/// @notice SGX verifier with the strict enclave-attribute policy intended for mainnet/production.
/// @custom:security-contact security@taiko.xyz
contract SgxVerifier is BaseSgxVerifier {
    constructor(
        uint64 _taikoChainId,
        address _owner,
        address _automataDcapAttestation,
        address _registrar
    )
        BaseSgxVerifier(_taikoChainId, _owner, _automataDcapAttestation, _registrar)
    { }

    /// @dev Strict policy: reject application enclaves that set DEBUG(0x02) or PROVISION_KEY(0x10).
    /// A DEBUG enclave's memory (including the in-enclave signing key) is readable/writable by the
    /// host, and PROVISION_KEY lets the enclave derive platform-identifying keys; neither must be
    /// trusted on-chain. The bits live in the first byte of the little-endian 16-byte attributes
    /// field.
    /// @return The forbidden ATTRIBUTES.FLAGS bitmask checked against an enclave's attributes.
    function _forbiddenAttributeMask() internal pure override returns (bytes16) {
        return bytes16(0x12000000000000000000000000000000);
    }
}
