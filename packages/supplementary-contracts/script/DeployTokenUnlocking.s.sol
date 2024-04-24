// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Script, console2} from "forge-std/Script.sol";
import {TokenUnlocking} from "../contracts/TokenUnlocking.sol";

contract DeployTokenUnlocking is Script {
    address public constant CONTRACT_OWNER = vm.envAddress("TAIKO_LABS_MULTISIG");
    address public constant TAIKO_TOKEN = vm.envAddress("TAIKO_TOKEN");
    address public constant COST_TOKEN = vm.envAddress("COST_TOKEN");
    address public constant SHARED_TOKEN_VAULT = vm.envAddress("SHARED_TOKEN_VAULT");
    address public constant GRANTEE = vm.envAddress("GRANTEE");

    address tokenUnlocking;

    function setUp() public {}

    function run() external{
        vm.startBroadcast();
        tokenUnlocking = deployProxy({
            impl: address(new TokenUnlocking()),
            data: abi.encodeCall(
                    TokenUnlocking.init, (CONTRACT_OWNER, TAIKO_TOKEN, COST_TOKEN, SHARED_TOKEN_VAULT, GRANTEE )
                )
        });
        vm.stopBroadcast();
    }
    

    function deployProxy(
        address impl,
        bytes memory data
    )
        public
        returns (address proxy)
    {
        proxy = address(new ERC1967Proxy(impl, data));

        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
