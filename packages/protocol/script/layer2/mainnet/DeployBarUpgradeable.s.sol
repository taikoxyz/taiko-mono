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

        //  > 'bar_upgradeable'
        //          proxy   : 0x0e577Bb67d38c18E4B9508984DA36d6D316ade58
        //          impl    : 0x49c3a8c535c42939D38d46dF56d49e8B2cb58409
        //          owner   : 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C
        //          chain id: 167000
        address barUpgradeableImpl3 = address(new BarUpgradeable());
        console.log("barUpgradeableImpl3", barUpgradeableImpl3);

        // deploy({
        //     name: "bar_upgradeable",
        //     impl: barUpgradeableImpl3,
        //     data: abi.encodeCall(BarUpgradeable.init, (L2.DELEGATE_CONTROLLER))
        // });
    }
}
