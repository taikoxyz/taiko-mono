// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../test/DeployCapability.sol";
import "../contracts/signal/SignalService.sol";

contract AuthorizeTaikoForMultihop is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public sharedSignalService = vm.envAddress("SHARED_SIGNAL_SERVICE");
    // TaikoL1 and TaikoL2 contracts
    address[] public taikoContracts = vm.envAddress("TAIKO_CONTRACTS", ",");

    function run() external {
        require(taikoContracts.length != 0, "invalid taiko contracts");

        vm.startBroadcast(privateKey);
        for (uint256 i; i < taikoContracts.length; ++i) {
            SignalService(sharedSignalService).authorize(taikoContracts[i], true);
        }

        vm.stopBroadcast();
    }
}
