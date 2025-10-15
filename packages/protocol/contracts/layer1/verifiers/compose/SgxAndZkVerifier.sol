// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ComposeVerifier.sol";

/// @title SgxAndZkVerifier
/// @notice SGX + (SP1 or Risc0) verifier
/// @custom:security-contact security@taiko.xyz
contract SgxAndZkVerifier is ComposeVerifier {
    uint256 public immutable unprovabilityThreshold;

    constructor(
        uint256 _unprovabilityThreshold,
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
    {
        unprovabilityThreshold = _unprovabilityThreshold;
    }

    function areVerifiersSufficient(uint256 _youngestProposalAge, uint8[] memory _verifierIds)
        internal
        view
        virtual
        override
        returns (bool)
    {
        if (_verifierIds.length == 2) {
            return _verifierIds[0] == SGX_RETH && isZKVerifier(_verifierIds[1]);
        } else if (_verifierIds.length == 1) {
            return _verifierIds[0] == SGX_RETH && _youngestProposalAge >= unprovabilityThreshold;
        } else {
            return false;
        }
    }

    function isZKVerifier(uint8 _verifierId) internal pure returns (bool) {
        return _verifierId == RISC0_RETH || _verifierId == SP1_RETH;
    }
}
