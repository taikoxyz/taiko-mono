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

contract AuthorizeRelayer is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
    address public sharedSignalService = vm.envAddress("SHARED_SIGNAL_SERVICE");
    address[] public relayers = vm.envAddress("RELAYERS", ",");

    function run() external {
        require(relayers.length != 0, "invalid relayers");

        vm.startBroadcast(privateKey);

        authorizeRelayerByTimelock(timelockAddress);

        vm.stopBroadcast();
    }

    function authorizeRelayerByTimelock(address timelock) internal {
        TaikoTimelockController timelockController = TaikoTimelockController(payable(timelock));
        bytes32 salt = bytes32(block.timestamp);

        for (uint256 i; i < relayers.length; ++i) {
            bytes memory payload =
                abi.encodeCall(SignalService.authorizeRelayer, (relayers[i], true));

            timelockController.schedule(sharedSignalService, 0, payload, bytes32(0), salt, 0);

            timelockController.execute(sharedSignalService, 0, payload, bytes32(0), salt);

            console2.log("New relayer authorized:");
            console2.log("index: ", i);
            console2.log("relayer: ", relayers[i]);
        }
    }
}
