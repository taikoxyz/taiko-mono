// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title SgxAndZkVerifier
/// @notice SGX + (SP1 or Risc0) verifier
/// @custom:security-contact security@taiko.xyz
contract SgxAndZkVerifier is ComposeVerifier {
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

    function areVerifiersSufficient(uint8[] memory _verifierIds)
        internal
        pure
        override
        returns (bool)
    {
        if (_verifierIds.length != 2) return false;

        if (_verifierIds[0] == SGX_RETH) {
            return _verifierIds[1] == RISC0_RETH || _verifierIds[1] == SP1_RETH;
        }

        if (_verifierIds[1] == SGX_RETH) {
            return _verifierIds[0] == RISC0_RETH || _verifierIds[0] == SP1_RETH;
        }

        return false;
    }
}
