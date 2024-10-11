// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract MockTaikoToken {
    address public lastAddr;
    uint256 public lastAmount;

    function approve(address spender, uint256 amount) external returns (bool) {
        lastAddr = spender;
        lastAmount = amount;
        return true;
    }
}
