// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BaseSgxVerifier } from "./BaseSgxVerifier.sol";

/// @title TestnetSgxVerifier
/// @notice SGX verifier intended for testnet/devnet. It shares the same enclave-attribute policy as
/// the mainnet `SgxVerifier`; the policy is kept as an overridable hook so testnet liveness needs
/// can relax it independently of mainnet without touching shared logic.
/// @custom:security-contact security@taiko.xyz
contract TestnetSgxVerifier is BaseSgxVerifier {
    constructor(
        uint64 _taikoChainId,
        address _owner,
        address _automataDcapAttestation,
        address _registrar
    )
        BaseSgxVerifier(_taikoChainId, _owner, _automataDcapAttestation, _registrar)
    { }

    /// @dev Reject application enclaves that set DEBUG(0x02) or PROVISION_KEY(0x10). A DEBUG
    /// enclave's memory (including the in-enclave signing key) is readable/writable by the host, and
    /// PROVISION_KEY lets the enclave derive platform-identifying keys; neither must be trusted
    /// on-chain. The bits live in the first byte of the little-endian 16-byte attributes field.
    /// @return The forbidden ATTRIBUTES.FLAGS bitmask checked against an enclave's attributes.
    function _forbiddenAttributeMask() internal pure override returns (bytes16) {
        return bytes16(0x12000000000000000000000000000000);
    }
}
