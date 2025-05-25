// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/libs/LibL1Addrs.sol";
import { FooUpgradeable } from "src/layer1/mainnet/FooUpgradeable.sol";

//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/DeployDelegateController.s.sol
contract DeployFooUpgradeable is BaseScript {
    function run() external broadcast {
        // To verify the contract, run the following command:
        // FOUNDRY_PROFILE=layer2 forge verify-contract \
        // 0x0919082b1e30d212e0359ea10cCCD6955ddc8263 \
        // contracts/layer2/mainnet/Barupgradeable.sol:BarUpgradeable \
        // --watch \
        // --verifier-url https://api.taikoscan.io/api \
        // --etherscan-api-key (echo $ETHERSCAN_API_KEY)

        //   > 'bar_upgradeable'
        //          proxy   : 0x877DDC3AebDD3010714B16769d6dB0Cb11abaF30
        //          impl    : 0x0919082b1e30d212e0359ea10cCCD6955ddc8263
        //          owner   : 0xe1eFEd95aDc9250A633ac3f6Ff8BA3F2cD0855A4
        //          chain id: 167000
        address fooUpgradeableImpl1 = address(new FooUpgradeable());

        console.log("fooUpgradeableImpl1", fooUpgradeableImpl1);
        deploy({
            name: "foo_upgradeable",
            impl: fooUpgradeableImpl1,
            data: abi.encodeCall(FooUpgradeable.init, (L1.DAO_CONTROLLER))
        });
    }
}
