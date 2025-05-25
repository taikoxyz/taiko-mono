// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/mainnet/TaikoDAOController.sol";
import "src/layer1/mainnet/libs/LibL1Addrs.sol";
import "script/BaseScript.sol";

contract DeployTaikoDAOController is BaseScript {
    function run() external broadcast {
        address taikoDaoControllerImpl3 = address(new TaikoDAOController());
        console2.log("taikoDaoControllerImpl3:", taikoDaoControllerImpl3);
        // 0x4347df63bdC82b8835fC9FF47bC5a71a12cC0f06

        // 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a
        deploy({
            name: "taiko_dao_controller2",
            impl: taikoDaoControllerImpl3,
            data: abi.encodeCall(TaikoDAOController.init, (LibL1Addrs.DAO))
        });
    }
}
