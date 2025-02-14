// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title AllTypeVerifier.sol
/// @notice OP or SGX or TDX or SP1 or Risc0 verifier
/// @custom:security-contact security@taiko.xyz
contract AllTypeVerifier is ComposeVerifier {
    uint256[50] private __gap;

    address public immutable opVerifier;
    address public immutable sgxVerifier;
    address public immutable tdxVerifier;
    address public immutable risc0Verifier;
    address public immutable sp1Verifier;

    constructor(
        address _resolver,
        address _opVerifier,
        address _sgxVerifier,
        address _tdxVerifier,
        address _risc0Verifier,
        address _sp1Verifier
    )
        EssentialContract(_resolver)
    {
        opVerifier = _opVerifier;
        sgxVerifier = _sgxVerifier;
        tdxVerifier = _tdxVerifier;
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

        return _verifiers[0] == opVerifier || _verifiers[0] == sgxVerifier
            || _verifiers[0] == tdxVerifier || _verifiers[0] == risc0Verifier
            || _verifiers[0] == sp1Verifier;
    }
}
