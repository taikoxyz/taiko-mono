// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/libs/LibL2Addrs.sol";
import { BarUpgradeable } from "src/layer2/mainnet/Barupgradeable.sol";

//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/DeployDelegateController.s.sol
contract DeployBarUpgradeable is BaseScript {
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
        address barUpgradeableImpl2 = address(new BarUpgradeable());

        console.log("barUpgradeableImpl2", barUpgradeableImpl2);
        // deploy({
        //     name: "bar_upgradeable",
        //     impl: barUpgradeableImpl1,
        //     data: abi.encodeCall(BarUpgradeable.init, (L2.DELEGATE_CONTROLLER))
        // });
    }
}
