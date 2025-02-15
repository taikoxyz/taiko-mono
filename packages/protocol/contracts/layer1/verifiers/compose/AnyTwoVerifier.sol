// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title AnyTwoVerifier
/// @notice (SGX + RISC0) or (RISC0 + SP1) or (SGX + SP1) verifier
/// @custom:security-contact security@taiko.xyz
contract AnyTwoVerifier is ComposeVerifier {
    uint256[50] private __gap;

    constructor(
        address _taikoInbox,
        address _sgxVerifier,
        address _risc0Verifier,
        address _sp1Verifier
    )
        ComposeVerifier(_taikoInbox, address(0), _sgxVerifier, address(0), _risc0Verifier, _sp1Verifier)
    { }

    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 2) return false;

        if (_verifiers[0] == sgxVerifier) {
            return _verifiers[1] == risc0Verifier || _verifiers[1] == sp1Verifier;
        } else if (_verifiers[0] == risc0Verifier) {
            return _verifiers[1] == sgxVerifier || _verifiers[1] == sp1Verifier;
        } else if (_verifiers[0] == sp1Verifier) {
            return _verifiers[1] == sgxVerifier || _verifiers[1] == risc0Verifier;
        }

        return false;
    }
}
