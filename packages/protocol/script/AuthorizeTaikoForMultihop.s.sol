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
import "../contracts/signal/SignalService.sol";

contract AuthorizeTaikoForMultihop is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public sharedSignalService = vm.envAddress("SHARED_SIGNAL_SERVICE");
    address public timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
    address[] public taikoContracts = vm.envAddress("TAIKO_CONTRACTS", ","); // TaikoL1 and TaikoL2
        // contracts

    function run() external {
        require(taikoContracts.length != 0, "invalid taiko contracts");

        vm.startBroadcast(privateKey);

        for (uint256 i; i < taikoContracts.length; ++i) {
            bytes32 salt = bytes32(block.timestamp);

            bytes memory payload =
                abi.encodeCall(SignalService.authorize, (taikoContracts[i], true));

            TaikoTimelockController timelock = TaikoTimelockController(payable(timelockAddress));

            timelock.schedule(sharedSignalService, 0, payload, bytes32(0), salt, 0);

            timelock.execute(sharedSignalService, 0, payload, bytes32(0), salt);
        }

        vm.stopBroadcast();
    }
}
