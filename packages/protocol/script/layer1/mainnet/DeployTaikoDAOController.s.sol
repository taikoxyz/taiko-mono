// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/governance/TaikoDAOController.sol";
import "script/BaseScript.sol";

contract DeployTaikoDAOController is BaseScript {
    address private constant TAIKO_DAO = 0x9CDf589C941ee81D75F34d3755671d614f7cf261;

    function run() external broadcast {
        deploy({
            name: "TaikoDAOController",
            impl: address(new TaikoDAOController()),
            data: abi.encodeCall(TaikoDAOController.init, (TAIKO_DAO))
        });
    }
}
