// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title ZkRequiredVerifier
/// @notice Requires exactly two sub-proofs of which at least one is a ZK proof:
/// (SGX_GETH or SGX_RETH) + (RISC0 or SP1), or RISC0 + SP1.
/// @dev The ZK mandate is structural, not configurational: the second element of every accepted
/// combination is a ZK verifier, so no TEE-only (SGX + SGX) pair can ever satisfy this
/// verifier — the exact combination that finalized the June 2026 forged proofs on the old
/// MainnetVerifier.
/// @custom:security-contact security@taiko.xyz
contract ZkRequiredVerifier is ComposeVerifier {
    constructor(
        address _sgxGethVerifier,
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        ComposeVerifier(
            _sgxGethVerifier,
            address(0),
            address(0),
            _sgxRethVerifier,
            _risc0RethVerifier,
            _sp1RethVerifier
        )
    { }

    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 2) return false;

        // Valid combinations (in ascending ID order):
        // [SGX_GETH, RISC0_RETH], [SGX_GETH, SP1_RETH],
        // [SGX_RETH, RISC0_RETH], [SGX_RETH, SP1_RETH],
        // [RISC0_RETH, SP1_RETH]
        // The second element is always a ZK verifier; SGX_GETH + SGX_RETH does not satisfy.
        if (_verifiers[0] == sgxGethVerifier || _verifiers[0] == sgxRethVerifier) {
            return _verifiers[1] == risc0RethVerifier || _verifiers[1] == sp1RethVerifier;
        } else if (_verifiers[0] == risc0RethVerifier) {
            return _verifiers[1] == sp1RethVerifier;
        }

        return false;
    }
}
