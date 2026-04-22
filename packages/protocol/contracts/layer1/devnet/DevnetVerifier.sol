// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../verifiers/compose/ComposeVerifier.sol";

/// @title DevnetVerifier
/// @notice SGX + (OP or RISC0 or SP1) verifier for devnet
/// @dev In production, use AnyTwoVerifier. This is for testing with OpVerifier support.
/// @custom:security-contact security@taiko.xyz
contract DevnetVerifier is ComposeVerifier {
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

    /// @notice Check if the provided verifiers are sufficient
    /// @dev Requires exactly 2 verifiers: SGX + (OP or RISC0 or SP1)
    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 2) return false;

        // Determine which verifier is SGX and which is the second verifier
        uint256 secondVerifierIdx;
        if (_verifiers[0] == sgxGethVerifier) {
            secondVerifierIdx = 1;
        } else if (_verifiers[1] == sgxGethVerifier) {
            secondVerifierIdx = 0;
        } else {
            // One of the verifiers MUST be SGX
            return false;
        }

        // The second verifier must be one of: OP, RISC0, or SP1
        return _verifiers[secondVerifierIdx] == sgxRethVerifier
            || _verifiers[secondVerifierIdx] == risc0RethVerifier
            || _verifiers[secondVerifierIdx] == sp1RethVerifier;
    }
}
