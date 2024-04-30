// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../contracts/tokenunlocking/TokenUnlocking.sol";

contract DeployTokenUnlocking is Script {
    using stdJson for string;

    address public OWNER = vm.envAddress("OWNER");
    address public TAIKO_TOKEN = vm.envAddress("TAIKO_TOKEN");
    uint256 public TGE = vm.envUint("TGE_TIMESTAMP");
    address public IMPL = vm.envAddress("TOKEN_VESTING_IMPL");

    function setUp() public { }

    function run() external {
        address impl = IMPL == address(0) ? address(new TokenUnlocking()) : IMPL;

        string memory path = "/script/tokenvesting/Deploy.data.json";
        address[] memory recipients = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (address[])
        );

        for (uint256 i; i < recipients.length; i++) {
            console2.log("Grantee:", recipients[i]);

            vm.startBroadcast();
            deployProxy({
                impl: impl,
                data: abi.encodeCall(
                    TokenUnlocking.init, (OWNER, TAIKO_TOKEN, recipients[i], uint64(TGE))
                    )
            });
            vm.stopBroadcast();
            console2.log("Deployed!\n");
        }
    }

    function deployProxy(address impl, bytes memory data) public returns (address proxy) {
        proxy = address(new ERC1967Proxy(impl, data));
        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
