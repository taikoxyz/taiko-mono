// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { UserOpsSubmitter } from "./UserOpsSubmitter.sol";

contract UserOpsSubmitterFactory {
    event SubmitterCreated(
        address indexed submitter, address indexed owner, address indexed deployer
    );

    function createSubmitter(address _owner) external returns (address submitter_) {
        UserOpsSubmitter submitter = new UserOpsSubmitter(_owner);
        submitter_ = address(submitter);

        emit SubmitterCreated(submitter_, _owner, msg.sender);
    }
}
