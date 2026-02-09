// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { UserOpsSubmitter } from "./UserOpsSubmitter.sol";

contract UserOpsSubmitterFactory {
    /// @notice Mapping from owner EOA to their submitter contract
    mapping(address owner => address submitter) public submitters;

    event SubmitterCreated(
        address indexed submitter, address indexed owner, address indexed deployer
    );

    /// @notice Create a new UserOpsSubmitter for the given owner
    /// @param _owner The EOA that will own the submitter
    /// @return submitter_ The address of the created submitter
    function createSubmitter(address _owner) external returns (address submitter_) {
        if (submitters[_owner] != address(0)) revert SUBMITTER_EXISTS();

        UserOpsSubmitter submitter = new UserOpsSubmitter(_owner);
        submitter_ = address(submitter);

        submitters[_owner] = submitter_;

        emit SubmitterCreated(submitter_, _owner, msg.sender);
    }

    /// @notice Get the submitter for a given owner
    /// @param _owner The EOA to look up
    /// @return submitter_ The submitter address, or address(0) if none exists
    function getSubmitter(address _owner) external view returns (address submitter_) {
        return submitters[_owner];
    }

    error SUBMITTER_EXISTS();
}
