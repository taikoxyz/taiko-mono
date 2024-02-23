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

pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/L1/gov/TaikoTimelockController.sol";
import "../contracts/L1/gov/TaikoTimelockController.sol";
import "../contracts/L1/tiers/ITierProvider.sol";
import "../contracts/L1/tiers/TaikoA6TierProvider.sol";

contract UpdateTierProvider is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
    address public addressManagerAddress = vm.envAddress("ADDRESS_MANAGER_ADDRESS");

    function run() external {
        vm.startBroadcast(privateKey);

        ITierProvider newTierProvider = new TaikoA6TierProvider();

        registerByTimelock(
            addressManagerAddress, "tier_provider", address(newTierProvider), uint64(block.chainid)
        );

        vm.stopBroadcast();
    }

    function registerByTimelock(
        address registerTo,
        string memory name,
        address addr,
        uint64 chainId
    )
        internal
    {
        bytes32 salt = bytes32(block.timestamp);

        bytes memory payload =
            abi.encodeCall(AddressManager.setAddress, (chainId, bytes32(bytes(name)), addr));

        TaikoTimelockController timelock = TaikoTimelockController(payable(timelockAddress));

        timelock.schedule(registerTo, 0, payload, bytes32(0), salt, 0);

        timelock.execute(registerTo, 0, payload, bytes32(0), salt);

        console2.log("> ", name, "@", registerTo);
        console2.log("\t addr : ", addr);
    }
}
