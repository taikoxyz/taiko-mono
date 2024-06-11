// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../test/DeployCapability.sol";
import "../../contracts/L1/gov/TaikoTimelockController.sol";
import "../../contracts/L1/tiers/ITierProvider.sol";
import "../../contracts/L1/tiers/TierProviderV1.sol";

contract UpgradeTierProvider is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
    address public addressManagerAddress = vm.envAddress("ADDRESS_MANAGER_ADDRESS");

    function run() external {
        vm.startBroadcast(privateKey);

        ITierProvider newTierProvider = new TierProviderV1();

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
