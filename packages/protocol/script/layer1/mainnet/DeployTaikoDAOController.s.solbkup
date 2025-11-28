// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import "src/layer1/mainnet/MainnetDAOController.sol";

contract DeployMainnetDAOController is BaseScript {
    function run() external broadcast {
        address MainnetDAOControllerImpl2 = address(new MainnetDAOController());
        console2.log("MainnetDAOControllerImpl2:", MainnetDAOControllerImpl2);
    }
}
