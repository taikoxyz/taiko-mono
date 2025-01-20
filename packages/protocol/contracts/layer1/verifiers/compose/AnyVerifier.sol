// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title AnyVerifier.sol
/// @notice SGX or SP1 or Risc0 verifier
/// @custom:security-contact security@taiko.xyz
contract AnyVerifier is ComposeVerifier {
    uint256[50] private __gap;

    address public immutable sgxVerifier;
    address public immutable risc0Verifier;
    address public immutable sp1Verifier;

    constructor(address _resolver, address _sgxVerifier, address _risc0Verifier, address _sp1Verifier) EssentialContract(_resolver) {
        sgxVerifier = _sgxVerifier;
        risc0Verifier = _risc0Verifier;
        sp1Verifier = _sp1Verifier;
    }

    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 1) return false;

        return _verifiers[0] == sgxVerifier || _verifiers[0] == risc0Verifier
            || _verifiers[0] == sp1Verifier;
    }
}
