// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverAuction
/// @custom:security-contact security@taiko.xyz
interface IProverAuction { 

    /// @notice Get the current prover.
    /// @return currentProver_ The address of the current prover.
    function getCurrentProver() external view returns (address currentProver_);

    /// @notice Pay a designated prover for delivering proofs on time.
    /// @param _payer The proposer responsible for rewarding the prover.
    /// @param _prover The designated prover that should be rewarded.
    function payProver(address _payer, address _prover) external;

    /// @notice Penalize a prover for its late proof submission.
    /// @param _prover The address of the prover to be penalized.
    function penalizeProver(address _prover) external;
}
