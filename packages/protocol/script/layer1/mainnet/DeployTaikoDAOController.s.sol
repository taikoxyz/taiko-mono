// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/governance/TaikoDAOController.sol";
import "script/BaseScript.sol";

contract DeployTaikoDAOController is BaseScript {
    function run() external broadcast {
        address taikoDaoControllerImpl2 = address(new TaikoDAOController());
        console2.log("taikoDaoControllerImpl2:", taikoDaoControllerImpl2);
    }
}
