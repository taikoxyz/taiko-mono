// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/layer1/provers/GuardianProver.sol";
import "./UpgradeScript.s.sol";

contract UpgradeGuardianProver is UpgradeScript {
    function run() external setUp {
        upgrade("GuardianProver", address(new GuardianProver()));
    }
}
