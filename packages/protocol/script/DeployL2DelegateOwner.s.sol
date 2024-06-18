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
        // Deploy the QuotaManager contract on Ethereum
        // 0x08c82ab90f86bf8d98440b96754a67411d656130
        address delegateowner = deployProxy({
            name: "delegate_owner",
            impl: address(new DelegateOwner()), // 0xdaf15cfa36c2188e3e0f4fb15a80e476e5e2ceb9
            data: abi.encodeCall(DelegateOwner.init, (l1Owner, l2Sam, 1, l2Admin))
        });

        // 0xf4707c2821b3067bdf9c4d48eb133851ff3e7ea7
        deployProxy({
            name: "test_address_am",
            impl: address(new AddressManager()), // 0x66489c2932a906ea7971eeb0a7379593ea32eb79
            data: abi.encodeCall(AddressManager.init, (delegateowner))
        });
    }
}
