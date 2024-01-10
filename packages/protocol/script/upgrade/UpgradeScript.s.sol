// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.20;

import "../../contracts/L1/gov/TaikoTimelockController.sol";
import "../../contracts/common/UUPSUpgradeable.sol";

import "forge-std/console2.sol";
import "forge-std/Script.sol";

contract UpgradeScript is Script {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
    address public proxyAddress = vm.envAddress("PROXY_ADDRESS");

    UUPSUpgradeable proxy;
    TaikoTimelockController timelock;

    modifier setUp() {
        require(privateKey != 0, "PRIVATE_KEY not set");
        require(proxyAddress != address(0), "PROXY_ADDRESS not set");
        require(timelockAddress != address(0), "TIMELOCK_ADDRESS not set");

        proxy = UUPSUpgradeable(payable(proxyAddress));
        timelock = TaikoTimelockController(payable(timelockAddress));

        vm.startBroadcast(privateKey);

        _;

        vm.stopBroadcast();
    }

    function upgrade(address newImpl) public {
        bytes32 salt = bytes32(block.timestamp);

        bytes memory payload =
            abi.encodeWithSelector(bytes4(keccak256("upgradeTo(address)")), newImpl);

        timelock.schedule(address(proxy), 0, payload, bytes32(0), salt, 0);

        timelock.execute(address(proxy), 0, payload, bytes32(0), salt);
    }
}
