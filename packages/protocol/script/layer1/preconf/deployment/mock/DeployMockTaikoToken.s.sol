// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../../BaseScript.sol";

import {MockTaikoToken} from "src/layer1/preconf/mock/MockTaikoToken.sol";

import {console2} from "forge-std/src/Script.sol";

contract DeployMockTaikoToken is BaseScript {
    function run() external broadcast {
        MockTaikoToken myContract = new MockTaikoToken();
        console2.log("MockTaikoToken:", address(myContract));
    }
}
