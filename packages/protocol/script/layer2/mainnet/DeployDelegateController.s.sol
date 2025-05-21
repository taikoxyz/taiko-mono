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

        console2.logBytes(
            abi.encode(uint64(LibNetwork.ETHEREUM_MAINNET), L2.BRIDGE, L1.DAO_CONTROLLER)
        );
    }
}
//   delegateControllerImpl 1: 0xd85BC772a1B8Db1291CDbf4965c3e3fF72AD3aF5
//   delegateControllerImpl 2: 0x15a4109238d5673C9E6Cca27831AEF1AfdA99830
//   > 'delegate_controller'
//          proxy   : 0x6D840cCbAea6077331A394B9104a7bAfe93AEa4A
//          impl    : 0xd85BC772a1B8Db1291CDbf4965c3e3fF72AD3aF5
//          owner   : 0x6D840cCbAea6077331A394B9104a7bAfe93AEa4A
//          chain id: 167000
//   barUpgradeableImpl 1: 0xC56F503eee0e30E746bdA93Ff22dCe6398271D11
//   barUpgradeableImpl 2: 0x8f752026dC3f53003C4772a81c7b38EA7430fECB
//   > 'bar_upgradeable'
//          proxy   : 0x31de0330c9FDa46FE8a7d84A88531bB8Fc72185f
//          impl    : 0xC56F503eee0e30E746bdA93Ff22dCe6398271D11
//          owner   : 0x6D840cCbAea6077331A394B9104a7bAfe93AEa4A
//          chain id: 167000
