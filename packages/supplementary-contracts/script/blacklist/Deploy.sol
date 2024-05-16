// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "../../contracts/blacklist/Blacklist.sol";

contract DeployBlacklist is Script {
    using stdJson for string;

    function setUp() public { }

    function run() external {
        string memory path = "/script/blacklist/Deploy.data.json";

        string memory json = vm.readFile(string.concat(vm.projectRoot(), path));
        // get admin address
        bytes memory rawPortion = json.parseRaw(".admin");
        address admin = abi.decode(rawPortion, (address));
        // get updater address
        rawPortion = json.parseRaw(".updater");
        address updater = abi.decode(rawPortion, (address));
        // get initial blacklist
        rawPortion = json.parseRaw(".blacklist");
        address[] memory blacklist = abi.decode(rawPortion, (address[]));

        vm.startBroadcast();

        Blacklist target = new Blacklist(admin, updater, blacklist);
        console2.log("Deployed!\n", address(target));
    }
}
