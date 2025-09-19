// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaComposeVerifier.sol";

/// @title ShastaAnyTwoVerifier
/// @notice (SGX + RISC0) or (RISC0 + SP1) or (SGX + SP1) verifier
/// @custom:security-contact security@taiko.xyz
contract AnyTwoVerifier is ShastaComposeVerifier {
    uint256[50] private __gap;

    constructor(
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        ShastaComposeVerifier(
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

        if (_verifiers[0] == sgxRethVerifier) {
            return _verifiers[1] == risc0RethVerifier || _verifiers[1] == sp1RethVerifier;
        } else if (_verifiers[0] == risc0RethVerifier) {
            return _verifiers[1] == sgxRethVerifier || _verifiers[1] == sp1RethVerifier;
        } else if (_verifiers[0] == sp1RethVerifier) {
            return _verifiers[1] == sgxRethVerifier || _verifiers[1] == risc0RethVerifier;
        }

        return false;
    }
}
