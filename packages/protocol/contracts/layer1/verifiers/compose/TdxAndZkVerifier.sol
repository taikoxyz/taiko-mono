// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title TdxAndZkVerifier
/// @notice TDX + (SP1 or Risc0) verifier
/// @custom:security-contact security@taiko.xyz
contract TdxAndZkVerifier is ComposeVerifier {
    constructor(
        address _tdxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    )
        ComposeVerifier(
            address(0),
            address(0),
            address(0),
            address(0),
            _risc0RethVerifier,
            _sp1RethVerifier,
            _tdxRethVerifier
        )
    { }

    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 2) return false;

        // ComposeVerifier iterates sub-proofs in strictly ascending VerifierType order
        // (RISC0_RETH = 5, SP1_RETH = 6, TDX_RETH = 7), so the ZK verifier appears at
        // index 0 and the TDX verifier at index 1.
        return (_verifiers[0] == risc0RethVerifier || _verifiers[0] == sp1RethVerifier)
            && _verifiers[1] == tdxRethVerifier;
    }
}
