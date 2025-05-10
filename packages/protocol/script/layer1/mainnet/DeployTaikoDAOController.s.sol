// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/governance/TaikoDAOController.sol";
import "script/BaseScript.sol";

contract DeployTaikoDAOController is BaseScript {
    function run() external broadcast {
        address dao = vm.envAddress("TAIKO_DAO");
        deploy({
            name: "TaikoDAOController",
            impl: address(new TaikoDAOController()),
            data: abi.encodeCall(TaikoDAOController.init, (dao))
        });
    }
}
