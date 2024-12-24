// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/DelegateOwner.sol";
import "script/BaseScript.sol";
//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/DeployDelegateOwner.s.sol

contract DeployDelegateOwner is BaseScript {
    address public l2Sam = 0x1670000000000000000000000000000000000006;
    address public testAccount2 = 0x3c181965C5cFAE61a9010A283e5e0C1445649810;

    address public l1Owner = testAccount2;
    address public l2Admin = testAccount2;

    function run() external broadcast {
        deploy({
            name: "delegate_owner",
            impl: address(new DelegateOwner()),
            data: abi.encodeCall(DelegateOwner.init, (l1Owner, l2Sam, 1, l2Admin))
        });
    }
}
