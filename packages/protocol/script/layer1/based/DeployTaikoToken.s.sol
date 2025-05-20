// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/DeployCapability.sol";
import "src/layer2/DelegateOwner.sol";

contract DeployTaikoToken is DeployCapability {
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address l2Bridge = 0x1670000000000000000000000000000000000001;
        address daoController = 0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3;
        DelegateOwner delegateOwner = new DelegateOwner(1, l2Bridge, daoController);

        console2.log("DelegateOwner deployed at", address(delegateOwner));
    }
}
