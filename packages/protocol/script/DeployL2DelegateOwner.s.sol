// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/L2/DelegateOwner.sol";

//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/DeployL2DelegateOwner.s.sol
contract DeployL2DelegateOwner is DeployCapability {
    address public l2Sam = 0x1670000000000000000000000000000000000006;
    address public l1Owner = 0x8F13E3a9dFf52e282884aA70eAe93F57DD601298; // Daniel's EOA
    address public l2Admin = 0x8F13E3a9dFf52e282884aA70eAe93F57DD601298; // same

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        deployProxy({
            name: "delegate_owner",
            impl: address(new DelegateOwner()),
            data: abi.encodeCall(DelegateOwner.init, (l1Owner, l2Sam, 1, l2Admin))
        });
    }
}
