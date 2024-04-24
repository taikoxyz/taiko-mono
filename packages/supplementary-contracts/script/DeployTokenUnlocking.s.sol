// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../contracts/TokenUnlocking.sol";

contract DeployTokenUnlocking is Script {
    address public CONTRACT_OWNER = vm.envAddress("TAIKO_LABS_MULTISIG");
    address public TAIKO_TOKEN = vm.envAddress("TAIKO_TOKEN");
    address public COST_TOKEN = vm.envAddress("COST_TOKEN");
    address public SHARED_TOKEN_VAULT = vm.envAddress("SHARED_TOKEN_VAULT");
    address public GRANTEE = vm.envAddress("GRANTEE");

    address tokenUnlocking;

    function setUp() public { }

    function run() external {
        vm.startBroadcast();
        tokenUnlocking = deployProxy({
            impl: address(new TokenUnlocking()),
            data: abi.encodeCall(
                TokenUnlocking.init,
                (CONTRACT_OWNER, TAIKO_TOKEN, COST_TOKEN, SHARED_TOKEN_VAULT, GRANTEE)
                )
        });
        vm.stopBroadcast();
    }

    function deployProxy(address impl, bytes memory data) public returns (address proxy) {
        proxy = address(new ERC1967Proxy(impl, data));

        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
