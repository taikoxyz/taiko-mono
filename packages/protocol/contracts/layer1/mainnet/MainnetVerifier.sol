// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../verifiers/compose/ComposeVerifier.sol";

/// @title MainnetVerifier
/// @notice SGX-GETH + (SGX or RISC0 or SP1) verifier
/// @custom:security-contact security@taiko.xyz
contract MainnetVerifier is ComposeVerifier {
    /// @notice Creates a new MainnetVerifier instance
    /// @param _sgxGethVerifier Address of the SGX-GETH verifier
    /// @param _sgxRethVerifier Address of the SGX-RETH verifier
    /// @param _risc0RethVerifier Address of the RISC0-RETH verifier
    /// @param _sp1RethVerifier Address of the SP1-RETH verifier
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
    /// @dev Requires exactly 2 verifiers: SGX-GETH + (SGX or RISC0 or SP1)
    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        override
        returns (bool)
    {
        if (_verifiers.length != 2) return false;

        return _verifiers[0] == sgxGethVerifier
            && (_verifiers[1] == sgxRethVerifier
                || _verifiers[1] == risc0RethVerifier
                || _verifiers[1] == sp1RethVerifier);
    }
}
