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

//  delegateControllerImpl 1: 0xD1Ed20C8fEc53db3274c2De09528f45dF6c06A65
//   delegateControllerImpl 2: 0x4f6Ac87E2E9925D13a5689588F035a7a207273ce
//   > 'delegate_controller'
//          proxy   : 0xAB3968A0DBcC15bc1654dC9e557b8bF6148Ed525
//          impl    : 0xD1Ed20C8fEc53db3274c2De09528f45dF6c06A65
//          owner   : 0xAB3968A0DBcC15bc1654dC9e557b8bF6148Ed525
//          chain id: 167000
//   barUpgradeableImpl 1: 0x87C752b0F70cAa237Edd7571B0845470A37DE040
//   barUpgradeableImpl 2: 0x80654149145E1521c857e7df6305b934ce95185c
//   > 'bar_upgradeable'
//          proxy   : 0x5c475bB14727833394b0704266f14157678A72b6
//          impl    : 0x87C752b0F70cAa237Edd7571B0845470A37DE040
//          owner   : 0xAB3968A0DBcC15bc1654dC9e557b8bF6148Ed525
//          chain id: 167000
