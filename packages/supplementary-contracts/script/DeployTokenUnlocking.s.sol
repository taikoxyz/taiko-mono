// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../contracts/TokenUnlocking.sol";

contract DeployTokenUnlocking is Script {
    address public OWNER = vm.envAddress("OWNER");
    address public TAIKO_TOKEN = vm.envAddress("TAIKO_TOKEN");
    address public RECIPIENT = vm.envAddress("RECIPIENT");
    uint256 public TGE = vm.envUint("TGE_TIMESTAMP");

    address tokenUnlocking;

    function setUp() public { }

    function run() external {
        vm.startBroadcast();
        tokenUnlocking = deployProxy({
            impl: address(new TokenUnlocking()),
            data: abi.encodeCall(TokenUnlocking.init, (OWNER, TAIKO_TOKEN, RECIPIENT, uint64(TGE)))
        });
        vm.stopBroadcast();
    }

    function deployProxy(address impl, bytes memory data) public returns (address proxy) {
        proxy = address(new ERC1967Proxy(impl, data));

        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
