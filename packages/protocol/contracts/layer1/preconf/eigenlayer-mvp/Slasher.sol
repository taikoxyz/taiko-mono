// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISlasher} from "../interfaces/eigenlayer-mvp/ISlasher.sol";

contract Slasher is ISlasher {
    mapping(address operator => mapping(address avs => bool canSlash)) internal slashingAllowed;
    mapping(address operator => bool slashed) internal isSlashed;

    modifier onlyIfSlashingAllowed(address operator, address caller) {
        require(slashingAllowed[operator][caller], "Slasher: Caller is not allowed to slash the operator");
        _;
    }

    function optIntoSlashing(address avs) external {
        slashingAllowed[msg.sender][avs] = true;
        emit OptedIntoSlashing(msg.sender, avs);
    }

    function slashOperator(address operator) external onlyIfSlashingAllowed(operator, msg.sender) {
        isSlashed[operator] = true;
        emit OperatorSlashed(operator, msg.sender);
    }

    function isOperatorSlashed(address operator) external view returns (bool) {
        return isSlashed[operator];
    }
}
