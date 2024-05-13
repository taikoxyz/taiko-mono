// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../contracts/tokenUnlocking/TokenUnlocking.sol";

contract DeployTokenUnlocking is Script {
    using stdJson for string;

    uint256 public PRIVATE_KEY = vm.envUint("PRIVATE_KEY"); // deployer
    address public OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F;  // admin.taiko.eth
    address public TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800; // token.taiko.eth
    uint256 public TGE = 1716767999; // Date and time (GMT): Sunday, May 26, 2024 11:59:59 PM
    address public IMPL = vm.envAddress("TOKEN_VESTING_IMPL");

    function setUp() public { }

    function run() external {
        address impl = IMPL == address(0) ? address(new TokenUnlocking()) : IMPL;

        string memory path = "/script/tokenUnlocking/Deploy.data.json";
        address[] memory recipients = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (address[])
        );

        for (uint256 i; i < recipients.length; i++) {
            console2.log("Grantee:", recipients[i]);

            vm.startBroadcast(PRIVATE_KEY);
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
