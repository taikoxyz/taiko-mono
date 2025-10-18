// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title AnyTwoVerifier
/// @notice (SGX + RISC0) or (RISC0 + SP1) or (SGX + SP1) verifier
/// @custom:security-contact security@taiko.xyz
contract AnyTwoVerifier is ComposeVerifier {
    constructor(
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        ComposeVerifier(
            address(0),
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
        // [SGX_RETH, RISC0_RETH], [SGX_RETH, SP1_RETH], [RISC0_RETH, SP1_RETH]
        if (_verifiers[0] == sgxRethVerifier) {
            return _verifiers[1] == risc0RethVerifier || _verifiers[1] == sp1RethVerifier;
        } else if (_verifiers[0] == risc0RethVerifier) {
            return _verifiers[1] == sp1RethVerifier;
        }

        return false;
    }
}
