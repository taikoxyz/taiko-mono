// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/layer1/Layer1Test.sol";

contract GuardianProverTarget is GuardianProver {
    uint256 public operationId;

    function init() external initializer {
        __Essential_init(address(0));
    }

    function approve(bytes32 hash) external returns (bool) {
        return _saveApproval(operationId++, hash);
    }
}
