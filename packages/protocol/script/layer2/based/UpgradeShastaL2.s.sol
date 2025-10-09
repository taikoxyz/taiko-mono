// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../contracts/layer2/based/TaikoAnchor.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";

contract UpgradeShastaL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    uint64 public pacayaForkHeight = uint64(vm.envUint("PACAYA_FORK_HEIGHT"));
    uint64 public shastaForkHeight = uint64(vm.envUint("SHASTA_FORK_HEIGHT"));
    address public taikoAnchor = vm.envAddress("TAIKO_ANCHOR");
    address public signalService = vm.envAddress("SIGNAL_SERVICE");
    address public bondManager = vm.envAddress("BOND_MANAGER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(taikoAnchor != address(0), "invalid taiko anchor");
        require(signalService != address(0), "invalid signal service");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
         UUPSUpgradeable(taikoAnchor).upgradeTo(
             address(new TaikoAnchor(125e9, 125e9,signalService, pacayaForkHeight, shastaForkHeight, bondManager))
         );
    }
}
