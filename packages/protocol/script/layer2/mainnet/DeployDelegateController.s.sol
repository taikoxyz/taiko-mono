// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/common/IResolver.sol";
import "src/layer2/mainnet/DelegateController.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/libs/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/libs/LibL2Addrs.sol";

//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/DeployDelegateController.s.sol
contract DeployDelegateController is BaseScript {
    function run() external broadcast {
        // To verify the contract, run the following command:
        // FOUNDRY_PROFILE=layer2 forge verify-contract \
        // 0x6f4006D0f805B55D1106dFdDfb73C3D53d12c12D \
        // contracts/layer2/mainnet/DelegateController.sol:DelegateController \
        // --watch \
        // --constructor-args
        // 0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000001670000000000000000000000000000000000001000000000000000000000000fc3c4ca95a8c4e5a587373f1718cd91301d6b2d3
        // \
        // --verifier-url https://api.taikoscan.io/api \
        // --etherscan-api-key (echo $ETHERSCAN_API_KEY)

        address delegateControllerImpl4 = address(
            new DelegateController(
                uint64(LibNetwork.ETHEREUM_MAINNET), L2.BRIDGE, L1.DAO_CONTROLLER
            )
        );

        deploy({
            name: "delegate_controller",
            impl: delegateControllerImpl4,
            data: abi.encodeCall(DelegateController.init, ())
        });
    }
}
