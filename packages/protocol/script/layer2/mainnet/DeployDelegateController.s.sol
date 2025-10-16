// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import "src/layer2/governance/DelegateController.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import "src/shared/common/IResolver.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/libs/LibNetwork.sol";

//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/DeployDelegateController.s.sol
contract DeployDelegateController is BaseScript {
    function run() external broadcast {
        address delegateControllerImpl1 = address(
            new DelegateController(
                uint64(LibNetwork.ETHEREUM_MAINNET), L2.BRIDGE, L1.DAO_CONTROLLER
            )
        );

        deploy({
            name: "delegate_controller",
            impl: delegateControllerImpl1,
            data: abi.encodeCall(DelegateController.init, ())
        });
    }
}
