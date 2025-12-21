// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProverAuction
/// @custom:security-contact security@taiko.xyz
interface IProverAuction { 

    /// @notice Get the current prover.
    /// @return currentProver_ The address of the current prover.
    /// @return provingFee_ The current proving fee per proposal in ETH.
    function getCurrentProverAndFee() external view returns (address currentProver_, uint256 provingFee_);

    /// @notice Penalize a prover for its late proof submission.
    /// @param _designatedProver The designated prover to be penalized by burning liveness bond.
    /// @param _actualProver The actual prover to be rewarded with part of the liveness bond.
    function penalizeProver(address _designatedProver, address _actualProver) external;
}
