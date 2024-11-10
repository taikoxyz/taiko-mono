// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "src/layer1/preconf/mock/MockTaikoToken.sol";
import "../../BaseScript.sol";

contract DeployMockTaikoToken is BaseScript {
    function run() external broadcast {
        MockTaikoToken myContract = new MockTaikoToken();
        console2.log("MockTaikoToken:", address(myContract));
    }
}
