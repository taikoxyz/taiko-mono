// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/mainnet/DelegateController.sol";
import "src/layer2/mainnet/BarUpgradeable.sol";
import "script/BaseScript.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/common/IResolver.sol";
import { LibMainnetL1Addresses as L1 } from "src/layer1/mainnet/libs/LibMainnetL1Addresses.sol";
import { LibMainnetL2Addresses as L2 } from "src/layer2/mainnet/LibMainnetL2Addresses.sol";

//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/DeployDelegateController.s.sol
contract DeployDelegateController is BaseScript {
    function run() external broadcast {
        address delegateControllerImpl1 = address(
            new DelegateController(
                uint64(LibNetwork.ETHEREUM_MAINNET), L2.BRIDGE, L1.DAO_CONTROLLER
            )
        );

        address delegateControllerImpl2 = address(
            new DelegateController(
                uint64(LibNetwork.ETHEREUM_MAINNET), L2.BRIDGE, L1.DAO_CONTROLLER
            )
        );

        console2.log("delegateControllerImpl 1:", delegateControllerImpl1);
        console2.log("delegateControllerImpl 2:", delegateControllerImpl2);

        address delegateController = deploy({
            name: "delegate_controller",
            impl: delegateControllerImpl1,
            data: abi.encodeCall(DelegateController.init, ())
        });

        address barUpgradeableImpl1 = address(new BarUpgradeable());
        address barUpgradeableImpl2 = address(new BarUpgradeable());

        console2.log("barUpgradeableImpl 1:", barUpgradeableImpl1);
        console2.log("barUpgradeableImpl 2:", barUpgradeableImpl2);

        deploy({
            name: "bar_upgradeable",
            impl: barUpgradeableImpl1,
            data: abi.encodeCall(BarUpgradeable.init, (delegateController))
        });
    }
}
