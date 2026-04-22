// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockPreconfWhitelist {
    address internal operator;

    function setOperatorForCurrentEpoch(address _operator) external {
        operator = _operator;
    }

    function getOperatorForCurrentEpoch() external view returns (address) {
        return operator;
    }
}
