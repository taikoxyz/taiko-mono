// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProverAuction } from "./IProverAuction.sol";

/// @title IProverAuction2
/// @notice Extension of IProverAuction with active prover pool introspection.
/// @custom:security-contact security@taiko.xyz
interface IProverAuction2 is IProverAuction {
    /// @notice Get the active prover addresses in insertion order.
    /// @return provers_ The active prover list.
    function getActiveProvers() external view returns (address[] memory provers_);

    /// @notice Get a prover's current fee and active status.
    /// @param _prover The prover address to query.
    /// @return feeInGwei_ The prover's fee in Gwei (0 if inactive).
    /// @return active_ True if the prover is in the active pool.
    function getProverStatus(
        address _prover
    )
        external
        view
        returns (uint32 feeInGwei_, bool active_);

    /// @notice Get the maximum number of active provers.
    /// @return maxActiveProvers_ The pool capacity.
    function getMaxActiveProvers() external view returns (uint16 maxActiveProvers_);
}
