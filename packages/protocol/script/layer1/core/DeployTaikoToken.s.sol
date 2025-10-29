// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/mainnet/TaikoToken.sol";
import "test/shared/DeployCapability.sol";

contract DeployTaikoToken is DeployCapability {

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
       address taikoToken = address(new TaikoToken());
       console2.log("TaikoToken deployed:", taikoToken);
    }
}

// FOUNDRY_PROFILE=layer1 forge script script/layer1/core/DeployTaikoToken.s.sol:DeployTaikoToken --chain-id 1 --rpc-url https://mainnet.infura.io/v3/29974e05282b45c89417014706857666 \
    // --etherscan-api-key ZH85M18BZKJXSUT9RWFPB8JFIHYJ19E5ER --verifier etherscan  \
    // --private-key 0x687d8a1aa66aef7f87c561f6c7c05260b9cbd39c34d7ba4d479f674810adc695 \
    // --broadcast --verify